// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

import Cocoa
import FlutterMacOS
import Foundation

#if canImport(OnnxRuntimeBindings)
  import OnnxRuntimeBindings  // SPM
#else
  import onnxruntime_objc  // CocoaPods
#endif
#if canImport(flutter_onnxruntime_objc)
  // SPM builds the ObjC++ helpers (Float16Helper, MessengerHelper) as a separate module;
  // under CocoaPods they live in the same module as this file.
  import flutter_onnxruntime_objc
#endif

enum OrtError: Error {
    case flutterError(FlutterError)
}

// swiftlint:disable:next type_body_length
public class FlutterOnnxruntimePlugin: NSObject, FlutterPlugin {
  private var sessions = [String: ORTSession]()
  private var env: ORTEnv?
  // Lock to serialize method handler and cleanup to prevent use-after-close races
  private let lock = NSLock()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger
    // Workaround for Flutter macOS issue #184737 — see MessengerHelper.h.
    let taskQueue = MessengerHelper.safeMakeBackgroundTaskQueue(messenger)
    let channel = FlutterMethodChannel(
        name: "flutter_onnxruntime",
        binaryMessenger: messenger,
        codec: FlutterStandardMethodCodec.sharedInstance(),
        taskQueue: taskQueue)
    let instance = FlutterOnnxruntimePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // Register for app termination to cleanup before static destruction
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(handleAppWillTerminate(_:)),
      name: NSApplication.willTerminateNotification,
      object: nil
    )
  }

  deinit {
    cleanupResources()
  }

  @objc private func handleAppWillTerminate(_ notification: Notification) {
    cleanupResources()
  }

  private func cleanupResources() {
    // Wait for any in-flight handler call to finish, then clean up
    lock.lock()
    defer { lock.unlock() }

    // Clear all OrtValues first (they may depend on sessions/env)
    ortValues.removeAll()

    // Clear all sessions (they depend on env)
    sessions.removeAll()

    // Release the environment
    env = nil
  }

  // swiftlint:disable:next cyclomatic_complexity
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    lock.lock()
    defer { lock.unlock() }

    if env == nil {
      do {
        env = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
      } catch {
        result(FlutterError(code: "ENV_INIT_FAILED", message: error.localizedDescription, details: nil))
        return
      }
    }

    switch call.method {
    case "getPlatformVersion":
      // Use macOS-specific system version info
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)

    /** Create a new session

      Create a new session from a model file path.

      Reference: https://onnxruntime.ai/docs/api/objectivec/Classes/ORTSession.html
    */
    case "createSession":
      handleCreateSession(call: call, result: result)
    case "getAvailableProviders":
      handleGetAvailableProviders(call: call, result: result)
    case "getRuntimeInfo":
      handleGetRuntimeInfo(call: call, result: result)
    case "runInference":
      handleRunInference(call: call, result: result)
    case "closeSession":
      handleCloseSession(call: call, result: result)
    case "getMetadata":
      handleGetMetadata(call: call, result: result)
    case "getInputInfo":
      handleGetInputInfo(call: call, result: result)
    case "getOutputInfo":
      handleGetOutputInfo(call: call, result: result)
    case "createOrtValue":
      handleCreateOrtValue(call, result: result)
    case "convertOrtValue":
      handleConvertOrtValue(call, result: result)
    case "getOrtValueData":
      handleGetOrtValueData(call, result: result)
    case "releaseOrtValue":
      handleReleaseOrtValue(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func handleCreateSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let modelPath = args["modelPath"] as? String else {
      result(FlutterError(code: "INVALID_ARG", message: "Model path is required", details: nil))
      return
    }

    do {
      let sessionOptions = try ORTSessionOptions()

      if let options = args["sessionOptions"] as? [String: Any] {
        if let inputShape = options["inputShape"] as? [Int],
           inputShape.contains(where: { $0 <= 0 }) {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "inputShape must contain positive integers", details: nil))
          return
        }
        if let memoryBudgetBytes = options["memoryBudgetBytes"] as? Int,
           memoryBudgetBytes <= 0 {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "memoryBudgetBytes must be positive", details: nil))
          return
        }
        if let useArena = options["useArena"] as? Bool {
          try sessionOptions.addConfigEntry(
            withKey: "session.enable_cpu_mem_arena",
            value: useArena ? "1" : "0")
        }
        if let configEntries = options["sessionConfigEntries"] as? [String: String] {
          for (key, value) in configEntries {
            try sessionOptions.addConfigEntry(withKey: key, value: value)
          }
        }
        if let intraOpNumThreads = options["intraOpNumThreads"] as? Int {
          do {
            try sessionOptions.setIntraOpNumThreads(Int32(intraOpNumThreads))
          } catch {
            result(FlutterError(code: "SESSION_OPTIONS_ERROR",
              message: "Failed to set intraOpNumThreads: \(error.localizedDescription)", details: nil))
            return
          }
        }

        // Note: 14/04/25 interOpNumThreads is not supported in onnxruntime-objc
        // if let interOpNumThreads = options["interOpNumThreads"] as? Int {
        //   try sessionOptions.setInterOpNumThreads(Int32(interOpNumThreads))
        // }

        // get providers from options
        if let providers = options["providers"] as? [String] {
          for provider in providers {
            switch provider {
            case "CPU":
              continue
            case "CORE_ML":
              do {
                var coreMlOptions = ((options["providerOptions"] as? [String: Any])?["CORE_ML"] as? [String: String]) ?? [:]
                if let mlComputeUnits = options["mlComputeUnits"] as? String {
                  coreMlOptions["MLComputeUnits"] = mlComputeUnits
                }
                if let requireStaticShapes = options["requireStaticShapes"] as? Bool {
                  coreMlOptions["RequireStaticInputShapes"] = requireStaticShapes ? "1" : "0"
                }
                if coreMlOptions.isEmpty {
                  try sessionOptions.appendCoreMLExecutionProvider()
                } else {
                  try sessionOptions.appendCoreMLExecutionProvider(withOptionsV2: coreMlOptions)
                }
              } catch {
                result(FlutterError(code: "SESSION_OPTIONS_ERROR",
                  message: "Failed to append CoreML execution provider: \(error.localizedDescription)", details: nil))
                return
              }
            case "XNNPACK":
              do {
                try sessionOptions.appendXnnpackExecutionProvider(with: ORTXnnpackExecutionProviderOptions())
              } catch {
                result(FlutterError(code: "SESSION_OPTIONS_ERROR",
                  message: "Failed to append XNNPACK execution provider: \(error.localizedDescription)", details: nil))
                return
              }
            default:
              result(FlutterError(code: "INVALID_PROVIDER", message: "Provider \(provider) is not supported", details: nil))
              return
            }
          }
        }
      }

      // Check if file exists
      let fileManager = FileManager.default
      if !fileManager.fileExists(atPath: modelPath) {
        result(FlutterError(code: "FILE_NOT_FOUND", message: "Model file not found at path: \(modelPath)", details: nil))
        return
      }

      // Create session from file path
      guard let safeEnv = env else {
        result(FlutterError(code: "ENV_NOT_INITIALIZED", message: "ONNX Runtime environment not initialized", details: nil))
        return
      }

      let session = try ORTSession(env: safeEnv, modelPath: modelPath, sessionOptions: sessionOptions)
      let sessionId = UUID().uuidString
      sessions[sessionId] = session

      // Get input and output names
      var inputNames: [String] = []
      var outputNames: [String] = []

      // Get input names
      if let inputNodeNames = try? session.inputNames() {
        inputNames = inputNodeNames
      }

      // Get output names
      if let outputNodeNames = try? session.outputNames() {
        outputNames = outputNodeNames
      }

      let responseMap: [String: Any] = [
        "sessionId": sessionId,
        "inputNames": inputNames,
        "outputNames": outputNames
      ]

      result(responseMap)
    } catch {
      result(FlutterError(code: "SESSION_CREATION_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  private func handleGetAvailableProviders(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Note: 14/04/25 ORTEnv does not have a method to get available providers so
    // we can only check if CoreML is available
    // Reference: https://onnxruntime.ai/docs/api/objectivec/Functions.html#/c:@F@ORTIsCoreMLExecutionProviderAvailable
    var providers: [String] = ["CPU"]
    let isCoreMLAvailable = ORTIsCoreMLExecutionProviderAvailable()
    if isCoreMLAvailable {
      providers.append("CORE_ML")
    }
    // Note: it's available support for XNNPACK but it's not an official API to check if it's available
    result(providers)
  }

  private func handleGetRuntimeInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
    var providers: [String] = ["CPU"]
    if ORTIsCoreMLExecutionProviderAvailable() {
      providers.append("CORE_ML")
    }
    result([
      "ortVersion": ORTVersion(),
      "providers": providers,
      "platform": "macos",
    ])
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func handleRunInference(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String,
          let inputs = args["inputs"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARG", message: "Missing required arguments", details: nil))
      return
    }

    do {
      // Get run options if provided
      let optionsDict = args["runOptions"] as? [String: Any] ?? [:]

      // Create ORTRunOptions if options are provided
      var runOptions: ORTRunOptions?
      if !optionsDict.isEmpty {
        runOptions = try ORTRunOptions()

        let logSeverityLevel = optionsDict["logSeverityLevel"] as? Int
        // switch on logSeverityLevel to assign a loggingLevel variable
        var loggingLevel: ORTLoggingLevel = ORTLoggingLevel.warning
        switch logSeverityLevel {
        case 0:
          loggingLevel = ORTLoggingLevel.verbose
        case 1:
          loggingLevel = ORTLoggingLevel.info
        case 2:
          loggingLevel = ORTLoggingLevel.warning
        case 3:
          loggingLevel = ORTLoggingLevel.error
        case 4:
          loggingLevel = ORTLoggingLevel.fatal
        default:
          loggingLevel = ORTLoggingLevel.warning
        }
        try runOptions?.setLogSeverityLevel(loggingLevel)
      }

      // Get session
      guard let session = sessions[sessionId] else {
        throw OrtError.flutterError(FlutterError(code: "INVALID_SESSION", message: "Session not found", details: nil))
      }

      // Process inputs - validate OrtValue references directly here
      var ortInputs: [String: ORTValue] = [:]

      for (name, value) in inputs {
        // Only process OrtValue references (sent as dictionary with valueId)
        if let valueDict = value as? [String: Any], let valueId = valueDict["valueId"] as? String {
          if let existingValue = ortValues[valueId] {
            ortInputs[name] = existingValue
          } else {
            throw OrtError.flutterError(FlutterError(code: "INVALID_ORT_VALUE", message: "OrtValue with ID \(valueId) not found", details: nil))
          }
        } else {
          throw OrtError.flutterError(FlutterError(code: "INVALID_INPUT_FORMAT",
            message: "Input for '\(name)' must be an OrtValue reference with valueId",
            details: nil))
        }
      }

      // Get output names
      let outputNames = try session.outputNames()

      // Run inference with prepared output containers and run options if available
      let outputs = try session.run(withInputs: ortInputs, outputNames: Set(outputNames), runOptions: runOptions)

      // store outputs in ortValues dictionary and return metadata in Flutter format
      var flutterOutputs: [String: Any] = [:]
      for (outputName, outputTensor) in outputs {
        let valueId = UUID().uuidString
        ortValues[valueId] = outputTensor

        // Check if output is float16 or bool (ObjC enum doesn't support them, use C++ API)
        if Float16Helper.isFloat16Tensor(outputTensor) || BoolHelper.isBoolTensor(outputTensor) {
          let shapeArr = try Float16Helper.getTensorShape(outputTensor)
          let shape = shapeArr.map { Int(truncating: $0) }
          let typeName = Float16Helper.getElementTypeName(outputTensor)
          flutterOutputs[outputName] = [valueId, typeName, shape]
        } else {
          let tensorInfo = try outputTensor.tensorTypeAndShapeInfo()
          let shape = tensorInfo.shape.map { Int(truncating: $0) }
          let typeName = _getDataTypeName(from: tensorInfo.elementType)
          flutterOutputs[outputName] = [valueId, typeName, shape]
        }
      }
      // Return result
      result(flutterOutputs)
    } catch let error as FlutterError {
      result(error)
    } catch {
      result(FlutterError(code: "INFERENCE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func handleCloseSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String else {
      result(FlutterError(code: "INVALID_ARG", message: "Session ID is required", details: nil))
      return
    }

    if sessions.removeValue(forKey: sessionId) != nil {
      result(nil)
    } else {
      result(FlutterError(code: "INVALID_SESSION", message: "Session not found", details: nil))
    }
  }

  private func handleGetMetadata(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String else {
      result(FlutterError(code: "INVALID_ARG", message: "Session ID is required", details: nil))
      return
    }

    guard sessions[sessionId] != nil else {
      result(FlutterError(code: "INVALID_SESSION", message: "Session not found", details: nil))
      return
    }

    // Return empty map as metadata functionality may not be available
    result([:])
  }

  private func handleGetInputInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String else {
      result(FlutterError(code: "INVALID_ARG", message: "Session ID is required", details: nil))
      return
    }

    guard let session = sessions[sessionId] else {
      result(FlutterError(code: "INVALID_SESSION", message: "Session not found", details: nil))
      return
    }

    do {
      var nodeInfoList: [[String: Any]] = []

      let inputNames = try session.inputNames()

      for name in inputNames {
        let infoMap: [String: Any] = ["name": name]
        nodeInfoList.append(infoMap)
      }

      result(nodeInfoList)
    } catch {
      result(FlutterError(code: "INPUT_INFO_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func handleGetOutputInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String else {
      result(FlutterError(code: "INVALID_ARG", message: "Session ID is required", details: nil))
      return
    }

    guard let session = sessions[sessionId] else {
      result(FlutterError(code: "INVALID_SESSION", message: "Session not found", details: nil))
      return
    }

    do {
      var nodeInfoList: [[String: Any]] = []

      let outputNames = try session.outputNames()

      for name in outputNames {
        let infoMap: [String: Any] = ["name": name]
        nodeInfoList.append(infoMap)
      }

      result(nodeInfoList)
    } catch {
      result(FlutterError(code: "OUTPUT_INFO_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  // MARK: - OrtValue Management

  private var ortValues: [String: ORTValue] = [:]

  // swiftlint:disable:next cyclomatic_complexity
  private func handleCreateOrtValue(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sourceType = args["sourceType"] as? String,
          let data = args["data"],
          let shape = args["shape"] as? [Int] else {
      result(FlutterError(code: "INVALID_ARG", message: "Missing required arguments", details: nil))
      return
    }

    // Convert shape to NSNumber array for ORTValue
    let shapeNumbers = shape.map { NSNumber(value: $0) }

    do {
      // Create tensor based on source data type
      var tensor: ORTValue

      switch sourceType {
      case "float32":
        if let floatArray = data as? [Float] {
          // Create float tensor
          let data = NSMutableData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .float, shape: shapeNumbers)
        } else if let doubleArray = data as? [Double] {
          // Convert double to float
          let floatArray = doubleArray.map { Float($0) }
          let data = NSMutableData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .float, shape: shapeNumbers)
        } else if let anyArray = data as? [Any] {
          // Try to convert Any array to Float array
          let floatArray = try anyArray.map { value -> Float in
            if let number = value as? NSNumber {
              return number.floatValue
            } else {
              throw OrtError.flutterError(FlutterError(code: "CONVERSION_ERROR", message: "Cannot convert \(type(of: value)) to Float", details: nil))
            }
          }
          let data = NSMutableData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .float, shape: shapeNumbers)
        } else if let typedData = data as? FlutterStandardTypedData {
          // Handle FlutterStandardTypedData
          if typedData.data.count % 4 == 0 {
            let mutableData = NSMutableData(data: typedData.data)
            tensor = try ORTValue(tensorData: mutableData, elementType: .float, shape: shapeNumbers)
          } else if typedData.data.count % 8 == 0 {
            // Could be Float64 data, convert to Float32
            let float64Count = typedData.data.count / 8

            var float32Array = [Float](repeating: 0.0, count: float64Count)

            // Extract Float64 values and convert to Float32
            typedData.data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
              let float64Buffer = buffer.bindMemory(to: Float64.self)
              for index in 0..<float64Count {
                float32Array[index] = Float(float64Buffer[index])
              }
            }

            let float32Data = NSMutableData(bytes: float32Array, length: float32Array.count * MemoryLayout<Float>.stride)
            tensor = try ORTValue(tensorData: float32Data, elementType: .float, shape: shapeNumbers)
          } else {
            result(FlutterError(code: "INVALID_DATA_TYPE",
                               message: "Data size \(typedData.data.count) is not consistent with Float32 or Float64 data",
                               details: nil))
            return
          }
        } else {
          result(FlutterError(code: "INVALID_DATA",
                             message: "Data must be a list of numbers for float32 type. Received: \(type(of: data))",
                             details: nil))
          return
        }

      case "int32":
        if let intArray = data as? [Int32] {
          let data = NSMutableData(bytes: intArray, length: intArray.count * MemoryLayout<Int32>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .int32, shape: shapeNumbers)
        } else if let intArray = data as? [Int] {
          let int32Array = intArray.map { Int32($0) }
          let data = NSMutableData(bytes: int32Array, length: int32Array.count * MemoryLayout<Int32>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .int32, shape: shapeNumbers)
        } else if let typedData = data as? FlutterStandardTypedData {
          // Handle FlutterStandardTypedData for Int32
          if typedData.data.count % 4 == 0 {
            let int32Count = typedData.data.count / 4
            var int32Array = [Int32](repeating: 0, count: int32Count)

            typedData.data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
              let int32Buffer = buffer.bindMemory(to: Int32.self)
              for index in 0..<int32Count {
                int32Array[index] = int32Buffer[index]
              }
            }

            let int32Data = NSMutableData(bytes: int32Array, length: int32Array.count * MemoryLayout<Int32>.stride)
            tensor = try ORTValue(tensorData: int32Data, elementType: .int32, shape: shapeNumbers)
          } else {
            result(FlutterError(code: "INVALID_DATA_TYPE",
                               message: "Data size \(typedData.data.count) is not consistent with Int32 data",
                               details: nil))
            return
          }
        } else {
          result(FlutterError(code: "INVALID_DATA",
                             message: "Data must be a list of numbers for int32 type",
                             details: nil))
          return
        }

      case "int64":
        if let longArray = data as? [Int64] {
          let data = NSMutableData(bytes: longArray, length: longArray.count * MemoryLayout<Int64>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .int64, shape: shapeNumbers)
        } else if let intArray = data as? [Int] {
          let int64Array = intArray.map { Int64($0) }
          let data = NSMutableData(bytes: int64Array, length: int64Array.count * MemoryLayout<Int64>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .int64, shape: shapeNumbers)
        } else if let typedData = data as? FlutterStandardTypedData {
          // Handle FlutterStandardTypedData for Int64
          if typedData.data.count % 8 == 0 {
            let int64Count = typedData.data.count / 8
            var int64Array = [Int64](repeating: 0, count: int64Count)

            typedData.data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
              let int64Buffer = buffer.bindMemory(to: Int64.self)
              for index in 0..<int64Count {
                int64Array[index] = int64Buffer[index]
              }
            }

            let int64Data = NSMutableData(bytes: int64Array, length: int64Array.count * MemoryLayout<Int64>.stride)
            tensor = try ORTValue(tensorData: int64Data, elementType: .int64, shape: shapeNumbers)
          } else {
            result(FlutterError(code: "INVALID_DATA_TYPE",
                               message: "Data size \(typedData.data.count) is not consistent with Int64 data",
                               details: nil))
            return
          }
        } else {
          result(FlutterError(code: "INVALID_DATA",
                             message: "Data must be a list of numbers for int64 type",
                             details: nil))
          return
        }

      case "uint8":
        if let uintArray = data as? [UInt8] {
          let data = NSMutableData(bytes: uintArray, length: uintArray.count * MemoryLayout<UInt8>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .uInt8, shape: shapeNumbers)
        } else if let intArray = data as? [Int] {
          let uintArray = intArray.map { UInt8($0) }
          let data = NSMutableData(bytes: uintArray, length: uintArray.count * MemoryLayout<UInt8>.stride)
          tensor = try ORTValue(tensorData: data, elementType: .uInt8, shape: shapeNumbers)
        } else if let typedData = data as? FlutterStandardTypedData {
          // Handle FlutterStandardTypedData for UInt8 - directly use the data for byte arrays
          let uint8Data = NSMutableData(data: typedData.data)
          tensor = try ORTValue(tensorData: uint8Data, elementType: .uInt8, shape: shapeNumbers)
        } else {
          result(FlutterError(code: "INVALID_DATA",
                             message: "Data must be a list of numbers for uint8 type",
                             details: nil))
          return
        }

      case "bool":
        // Bool tensors: ORTTensorElementDataType has no bool case, create via C++ API
        if let boolArray = data as? [Bool] {
          // Swift Bool is stored as one 0/1 byte, so its raw bytes are already valid
          // bool tensor data (the helper normalizes non-zero bytes regardless)
          let bytes = boolArray.withUnsafeBytes { Data($0) }
          tensor = try BoolHelper.createBoolTensor(fromBytes: bytes, shape: shapeNumbers)
        } else if let typedData = data as? FlutterStandardTypedData {
          // Bool values stored as bytes, where non-zero is true (normalized to 0/1 in the helper)
          tensor = try BoolHelper.createBoolTensor(fromBytes: typedData.data, shape: shapeNumbers)
        } else {
          result(FlutterError(code: "INVALID_DATA",
                             message: "Data must be a list of booleans for bool type",
                             details: nil))
          return
        }

      case "string":
        if let stringArray = data as? [String] {
          // Create a string tensor from a string array
          tensor = try ORTValue(tensorStringData: stringArray, shape: shapeNumbers)
        } else {
          result(FlutterError(code: "INVALID_DATA", message: "Data must be a list of strings for string type", details: nil))
          return
        }

      case "float16":
        // Float16 tensors: accept float32 data and convert to float16 via C++ API
        var float32Numbers: [NSNumber] = []
        if let doubleArray = data as? [Double] {
          float32Numbers = doubleArray.map { NSNumber(value: Float($0)) }
        } else if let floatArray = data as? [Float] {
          float32Numbers = floatArray.map { NSNumber(value: $0) }
        } else if let anyArray = data as? [Any] {
          float32Numbers = try anyArray.map { value -> NSNumber in
            if let number = value as? NSNumber {
              return NSNumber(value: number.floatValue)
            } else {
              throw OrtError.flutterError(FlutterError(code: "CONVERSION_ERROR",
                message: "Cannot convert \(type(of: value)) to Float", details: nil))
            }
          }
        } else if let typedData = data as? FlutterStandardTypedData {
          if typedData.data.count % 4 == 0 {
            let float32Count = typedData.data.count / 4
            float32Numbers = [NSNumber](repeating: NSNumber(value: 0), count: float32Count)
            typedData.data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
              let floatBuffer = buffer.bindMemory(to: Float.self)
              for index in 0..<float32Count {
                float32Numbers[index] = NSNumber(value: floatBuffer[index])
              }
            }
          } else if typedData.data.count % 8 == 0 {
            let float64Count = typedData.data.count / 8
            float32Numbers = [NSNumber](repeating: NSNumber(value: 0), count: float64Count)
            typedData.data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
              let float64Buffer = buffer.bindMemory(to: Float64.self)
              for index in 0..<float64Count {
                float32Numbers[index] = NSNumber(value: Float(float64Buffer[index]))
              }
            }
          } else {
            result(FlutterError(code: "INVALID_DATA_TYPE",
                               message: "Data size \(typedData.data.count) is not consistent with Float32 or Float64 data",
                               details: nil))
            return
          }
        } else {
          result(FlutterError(code: "INVALID_DATA",
                             message: "Data must be a list of numbers for float16 type. Received: \(type(of: data))",
                             details: nil))
          return
        }

        tensor = try Float16Helper.createFloat16Tensor(fromFloat32: float32Numbers,
                                                        shape: shapeNumbers)

      default:
        result(FlutterError(code: "UNSUPPORTED_TYPE", message: "Unsupported source data type: \(sourceType)", details: nil))
        return
      }

      // Generate unique ID for the tensor
      let valueId = UUID().uuidString
      ortValues[valueId] = tensor

      // Return tensor information
      let tensorInfo: [String: Any] = [
        "valueId": valueId,
        "dataType": sourceType,
        "shape": shape
      ]

      result(tensorInfo)
    } catch {
      result(FlutterError(code: "TENSOR_CREATION_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func handleConvertOrtValue(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let valueId = args["valueId"] as? String,
          let targetType = args["targetType"] as? String else {
      result(FlutterError(code: "INVALID_ARG", message: "Missing required arguments", details: nil))
      return
    }

    guard let tensor = ortValues[valueId] else {
      result(FlutterError(code: "INVALID_VALUE", message: "OrtValue with ID \(valueId) not found", details: nil))
      return
    }

    do {
      // Check if source is float16 or bool (must use C++ API since ObjC enum doesn't support them)
      let isSourceFloat16 = Float16Helper.isFloat16Tensor(tensor)
      let isSourceBool = BoolHelper.isBoolTensor(tensor)

      var shape: [Int]
      var elementCount: Int
      var sourceType: String

      if isSourceFloat16 || isSourceBool {
        let shapeArr = try Float16Helper.getTensorShape(tensor)
        shape = shapeArr.map { $0.intValue }
        elementCount = shape.reduce(1, *)
        sourceType = Float16Helper.getElementTypeName(tensor)
      } else {
        let tensorInfo = try tensor.tensorTypeAndShapeInfo()
        shape = tensorInfo.shape.map { Int(truncating: $0) }
        elementCount = shape.reduce(1, *)
        sourceType = _getDataTypeName(from: tensorInfo.elementType)
      }

      // If source and target types are the same, just clone the tensor
      if sourceType == targetType {
        // Create a new tensor ID and store reference
        let newValueId = UUID().uuidString
        ortValues[newValueId] = tensor

        // Return tensor information
        let resultInfo: [String: Any] = [
          "valueId": newValueId,
          "dataType": targetType,
          "shape": shape
        ]

        result(resultInfo)
        return
      }

      // Create a new tensor with converted data
      var newTensor: ORTValue

      // Handle float16 conversions via C++ helper (before extracting data via ObjC API)
      if sourceType == "float16" && targetType == "float32" {
        // Float16 -> Float32: extract float16 data as float32 via helper
        let float32Values = try Float16Helper.extractFloat16(asFloat32: tensor)
        let floatArray = float32Values.map { $0.floatValue }
        let newData = NSMutableData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .float, shape: shape.map { NSNumber(value: $0) })

        let newValueId = UUID().uuidString
        ortValues[newValueId] = newTensor
        result(["valueId": newValueId, "dataType": targetType, "shape": shape] as [String: Any])
        return
      }

      if sourceType == "float32" && targetType == "float16" {
        // Float32 -> Float16: extract float32 data, create float16 tensor via helper
        let sourceDataPtr = try tensor.tensorData()
        let floatPtr = sourceDataPtr.bytes.bindMemory(to: Float.self, capacity: elementCount)
        let floatBuffer = UnsafeBufferPointer(start: floatPtr, count: elementCount)
        let float32Numbers = floatBuffer.map { NSNumber(value: $0) }

        let fp16Tensor = try Float16Helper.createFloat16Tensor(fromFloat32: float32Numbers,
                                                               shape: shape.map { NSNumber(value: $0) })

        let newValueId = UUID().uuidString
        ortValues[newValueId] = fp16Tensor
        result(["valueId": newValueId, "dataType": targetType, "shape": shape] as [String: Any])
        return
      }

      if isSourceFloat16 {
        // Float16 source with non-float32 target: not supported
        result(FlutterError(code: "CONVERSION_ERROR",
                           message: "Conversion from float16 to \(targetType) is not supported",
                           details: nil))
        return
      }

      if targetType == "float16" {
        // Non-float32 source to float16: not supported
        result(FlutterError(code: "CONVERSION_ERROR",
                           message: "Conversion from \(sourceType) to float16 is not supported",
                           details: nil))
        return
      }

      // Handle bool source via C++ helper (ObjC tensorData() throws for bool tensors)
      if isSourceBool {
        let boolBytes = try BoolHelper.extractBoolData(tensor)
        let shapeNumbers = shape.map { NSNumber(value: $0) }
        let converted: ORTValue

        switch targetType {
        case "uint8", "int8":
          // Bool bytes are already 0/1, reuse them directly
          let newData = NSMutableData(data: boolBytes)
          converted = try ORTValue(tensorData: newData,
                                   elementType: targetType == "uint8" ? .uInt8 : .int8,
                                   shape: shapeNumbers)
        case "float32":
          let floatArray = boolBytes.map { Float($0) }
          let newData = NSMutableData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.stride)
          converted = try ORTValue(tensorData: newData, elementType: .float, shape: shapeNumbers)
        case "int32":
          let int32Array = boolBytes.map { Int32($0) }
          let newData = NSMutableData(bytes: int32Array, length: int32Array.count * MemoryLayout<Int32>.stride)
          converted = try ORTValue(tensorData: newData, elementType: .int32, shape: shapeNumbers)
        case "int64":
          let int64Array = boolBytes.map { Int64($0) }
          let newData = NSMutableData(bytes: int64Array, length: int64Array.count * MemoryLayout<Int64>.stride)
          converted = try ORTValue(tensorData: newData, elementType: .int64, shape: shapeNumbers)
        default:
          result(FlutterError(code: "CONVERSION_ERROR",
                             message: "Conversion from bool to \(targetType) is not supported",
                             details: nil))
          return
        }

        let newValueId = UUID().uuidString
        ortValues[newValueId] = converted
        result(["valueId": newValueId, "dataType": targetType, "shape": shape] as [String: Any])
        return
      }

      // Handle bool target via C++ helper (only uint8/int8 sources, non-zero = true)
      if targetType == "bool" {
        guard sourceType == "uint8" || sourceType == "int8" else {
          result(FlutterError(code: "CONVERSION_ERROR",
                             message: "Conversion from \(sourceType) to bool is not supported",
                             details: nil))
          return
        }
        let srcPtr = try tensor.tensorData()
        let bytes = Data(bytes: srcPtr.bytes, count: elementCount)
        let boolTensor = try BoolHelper.createBoolTensor(fromBytes: bytes, shape: shape.map { NSNumber(value: $0) })

        let newValueId = UUID().uuidString
        ortValues[newValueId] = boolTensor
        result(["valueId": newValueId, "dataType": "bool", "shape": shape] as [String: Any])
        return
      }

      // Extract original data (safe for non-float16/non-bool tensors)
      let sourceDataPtr = try tensor.tensorData()

      // Convert data based on source type and target type
      switch (sourceType, targetType) {
      case ("float32", "int32"):
        // Float32 -> Int32
        let floatPtr = sourceDataPtr.bytes.bindMemory(to: Float.self, capacity: elementCount)
        let floatBuffer = UnsafeBufferPointer(start: floatPtr, count: elementCount)

        // Convert float values to int32
        let int32Array = floatBuffer.map { Int32($0) }
        let newData = NSMutableData(bytes: int32Array, length: int32Array.count * MemoryLayout<Int32>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .int32, shape: shape.map { NSNumber(value: $0) })

      case ("float32", "int64"):
        // Float32 -> Int64
        let floatPtr = sourceDataPtr.bytes.bindMemory(to: Float.self, capacity: elementCount)
        let floatBuffer = UnsafeBufferPointer(start: floatPtr, count: elementCount)

        // Convert float values to int64
        let int64Array = floatBuffer.map { Int64($0) }
        let newData = NSMutableData(bytes: int64Array, length: int64Array.count * MemoryLayout<Int64>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .int64, shape: shape.map { NSNumber(value: $0) })

      case ("float32", "uint8"):
        // Float32 -> UInt8
        let floatPtr = sourceDataPtr.bytes.bindMemory(to: Float.self, capacity: elementCount)
        let floatBuffer = UnsafeBufferPointer(start: floatPtr, count: elementCount)

        // Convert float values to uint8 (clamping to valid range)
        // Clamp in Float domain first to avoid trapping on NaN/Infinity/huge values
        let uint8Array = floatBuffer.map { UInt8($0.isNaN ? 0 : max(0, min(255, $0))) }
        let newData = NSMutableData(bytes: uint8Array, length: uint8Array.count * MemoryLayout<UInt8>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .uInt8, shape: shape.map { NSNumber(value: $0) })

      case ("int32", "float32"):
        // Int32 -> Float32
        let intPtr = sourceDataPtr.bytes.bindMemory(to: Int32.self, capacity: elementCount)
        let intBuffer = UnsafeBufferPointer(start: intPtr, count: elementCount)

        // Convert int32 values to float
        let floatArray = intBuffer.map { Float($0) }
        let newData = NSMutableData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .float, shape: shape.map { NSNumber(value: $0) })

      case ("int32", "int64"):
        // Int32 -> Int64
        let intPtr = sourceDataPtr.bytes.bindMemory(to: Int32.self, capacity: elementCount)
        let intBuffer = UnsafeBufferPointer(start: intPtr, count: elementCount)

        // Convert int32 values to int64
        let int64Array = intBuffer.map { Int64($0) }
        let newData = NSMutableData(bytes: int64Array, length: int64Array.count * MemoryLayout<Int64>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .int64, shape: shape.map { NSNumber(value: $0) })

      case ("int64", "float32"):
        // Int64 -> Float32
        let int64Ptr = sourceDataPtr.bytes.bindMemory(to: Int64.self, capacity: elementCount)
        let int64Buffer = UnsafeBufferPointer(start: int64Ptr, count: elementCount)

        // Convert int64 values to float (potential precision loss)
        let floatArray = int64Buffer.map { Float($0) }
        let newData = NSMutableData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .float, shape: shape.map { NSNumber(value: $0) })

      case ("int64", "int32"):
        // Int64 -> Int32
        let int64Ptr = sourceDataPtr.bytes.bindMemory(to: Int64.self, capacity: elementCount)
        let int64Buffer = UnsafeBufferPointer(start: int64Ptr, count: elementCount)

        // Convert int64 values to int32 (potential overflow)
        let int32Array = int64Buffer.map { Int32(max(Int64(Int32.min), min(Int64(Int32.max), $0))) }
        let newData = NSMutableData(bytes: int32Array, length: int32Array.count * MemoryLayout<Int32>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .int32, shape: shape.map { NSNumber(value: $0) })

      case ("uint8", "float32"):
        // UInt8 -> Float32
        let uint8Ptr = sourceDataPtr.bytes.bindMemory(to: UInt8.self, capacity: elementCount)
        let uint8Buffer = UnsafeBufferPointer(start: uint8Ptr, count: elementCount)

        // Convert uint8 values to float
        let floatArray = uint8Buffer.map { Float($0) }
        let newData = NSMutableData(bytes: floatArray, length: floatArray.count * MemoryLayout<Float>.stride)
        newTensor = try ORTValue(tensorData: newData, elementType: .float, shape: shape.map { NSNumber(value: $0) })

      case ("uint8", "int32"):
        // UInt8 -> Int32
        let uint8PtrI32 = sourceDataPtr.bytes.bindMemory(to: UInt8.self, capacity: elementCount)
        let uint8BufferI32 = UnsafeBufferPointer(start: uint8PtrI32, count: elementCount)

        let int32FromUint8 = uint8BufferI32.map { Int32($0) }
        let newDataI32 = NSMutableData(bytes: int32FromUint8, length: int32FromUint8.count * MemoryLayout<Int32>.stride)
        newTensor = try ORTValue(tensorData: newDataI32, elementType: .int32, shape: shape.map { NSNumber(value: $0) })

      case ("uint8", "int64"):
        // UInt8 -> Int64
        let uint8PtrI64 = sourceDataPtr.bytes.bindMemory(to: UInt8.self, capacity: elementCount)
        let uint8BufferI64 = UnsafeBufferPointer(start: uint8PtrI64, count: elementCount)

        let int64FromUint8 = uint8BufferI64.map { Int64($0) }
        let newDataI64 = NSMutableData(bytes: int64FromUint8, length: int64FromUint8.count * MemoryLayout<Int64>.stride)
        newTensor = try ORTValue(tensorData: newDataI64, elementType: .int64, shape: shape.map { NSNumber(value: $0) })

      case ("int32", "uint8"):
        // Int32 -> UInt8 (clamping to valid range)
        let intPtrU8 = sourceDataPtr.bytes.bindMemory(to: Int32.self, capacity: elementCount)
        let intBufferU8 = UnsafeBufferPointer(start: intPtrU8, count: elementCount)

        let uint8FromInt32 = intBufferU8.map { UInt8(max(0, min(255, $0))) }
        let newDataU8FromI32 = NSMutableData(bytes: uint8FromInt32, length: uint8FromInt32.count * MemoryLayout<UInt8>.stride)
        newTensor = try ORTValue(tensorData: newDataU8FromI32, elementType: .uInt8, shape: shape.map { NSNumber(value: $0) })

      case ("int64", "uint8"):
        // Int64 -> UInt8 (clamping to valid range)
        let int64PtrU8 = sourceDataPtr.bytes.bindMemory(to: Int64.self, capacity: elementCount)
        let int64BufferU8 = UnsafeBufferPointer(start: int64PtrU8, count: elementCount)

        let uint8FromInt64 = int64BufferU8.map { UInt8(max(0, min(255, $0))) }
        let newDataU8FromI64 = NSMutableData(bytes: uint8FromInt64, length: uint8FromInt64.count * MemoryLayout<UInt8>.stride)
        newTensor = try ORTValue(tensorData: newDataU8FromI64, elementType: .uInt8, shape: shape.map { NSNumber(value: $0) })

      default:
        // Unsupported conversion, return error
        result(FlutterError(code: "CONVERSION_ERROR",
                           message: "Conversion from \(sourceType) to \(targetType) is not supported",
                           details: nil))
        return
      }

      // Generate unique ID for the new tensor
      let newValueId = UUID().uuidString
      ortValues[newValueId] = newTensor

      // Return tensor information
      let resultInfo: [String: Any] = [
        "valueId": newValueId,
        "dataType": targetType,
        "shape": shape
      ]

      result(resultInfo)
    } catch {
      result(FlutterError(code: "CONVERSION_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func handleGetOrtValueData(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let valueId = args["valueId"] as? String else {
      result(FlutterError(code: "INVALID_ARG", message: "Missing valueId", details: nil))
      return
    }

    guard let tensor = ortValues[valueId] else {
      result(FlutterError(code: "INVALID_VALUE", message: "Tensor not found or already being disposed", details: nil))
      return
    }

    do {
      // Check for float16 tensor first (ObjC API doesn't support it)
      if Float16Helper.isFloat16Tensor(tensor) {
        let shapeArr = try Float16Helper.getTensorShape(tensor)
        let shape = shapeArr.map { $0.intValue }

        let float32Values = try Float16Helper.extractFloat16(asFloat32: tensor)

        // Convert to FlutterStandardTypedData(float32:) for efficient transfer
        let floatArray = float32Values.map { $0.floatValue }
        let nsData = Data(bytes: floatArray, count: floatArray.count * MemoryLayout<Float>.stride)
        let data = FlutterStandardTypedData(float32: nsData)

        let resultMap: [String: Any] = [
          "data": data,
          "shape": shape,
          "dataType": "float16"
        ]
        result(resultMap)
        return
      }

      // Bool tensors also bypass the ObjC API (no bool case in ORTTensorElementDataType)
      if BoolHelper.isBoolTensor(tensor) {
        let shapeArr = try Float16Helper.getTensorShape(tensor)
        let shape = shapeArr.map { $0.intValue }

        // One 0/1 byte per element; the Dart side converts them back to booleans
        let boolBytes = try BoolHelper.extractBoolData(tensor)
        let data = FlutterStandardTypedData(bytes: boolBytes)

        let resultMap: [String: Any] = [
          "data": data,
          "shape": shape,
          "dataType": "bool"
        ]
        result(resultMap)
        return
      }

      // Get tensor information
      let tensorInfo = try tensor.tensorTypeAndShapeInfo()
      let shape = tensorInfo.shape.map { Int(truncating: $0) }
      let elementCount = shape.reduce(1, *)
      var data: Any
      let dataType = _getDataTypeName(from: tensorInfo.elementType)

      // Extract data based on the tensor's native type
      // Return FlutterStandardTypedData instead of Array
      switch tensorInfo.elementType {
      case .float:
        // Get float data as FlutterStandardTypedData(float32)
        let dataPtr = try tensor.tensorData()
        let byteCount = elementCount * MemoryLayout<Float>.stride
        let nsData = Data(bytes: dataPtr.bytes, count: byteCount)
        data = FlutterStandardTypedData(float32: nsData)

      case .int32:
        // Get int32 data as FlutterStandardTypedData(int32)
        let dataPtr = try tensor.tensorData()
        let byteCount = elementCount * MemoryLayout<Int32>.stride
        let nsData = Data(bytes: dataPtr.bytes, count: byteCount)
        data = FlutterStandardTypedData(int32: nsData)

      case .int64:
        // Get int64 data as FlutterStandardTypedData(int64)
        let dataPtr = try tensor.tensorData()
        let byteCount = elementCount * MemoryLayout<Int64>.stride
        let nsData = Data(bytes: dataPtr.bytes, count: byteCount)
        data = FlutterStandardTypedData(int64: nsData)

      case .uInt8:
        // Get uint8 data as FlutterStandardTypedData(bytes)
        let dataPtr = try tensor.tensorData()
        let byteCount = elementCount * MemoryLayout<UInt8>.stride
        let nsData = Data(bytes: dataPtr.bytes, count: byteCount)
        data = FlutterStandardTypedData(bytes: nsData)

      case .int8:
        // Get int8 data as FlutterStandardTypedData(bytes)
        // Note: Using bytes for int8 as it's compatible with Int8List in Dart
        let dataPtr = try tensor.tensorData()
        let byteCount = elementCount * MemoryLayout<Int8>.stride
        let nsData = Data(bytes: dataPtr.bytes, count: byteCount)
        data = FlutterStandardTypedData(bytes: nsData)

      case .string:
        // For string tensors, we need to use the special string tensor API
        // Get string data using the dedicated string tensor accessor
        do {
          data = try tensor.tensorStringData()
        } catch {
          // In case of error, return an empty array
          data = []
        }

      default:
        // Try to extract as float for unsupported types
        let dataPtr = try tensor.tensorData()
        let byteCount = elementCount * MemoryLayout<Float>.stride
        let nsData = Data(bytes: dataPtr.bytes, count: byteCount)
        data = FlutterStandardTypedData(float32: nsData)
      }

      // Return data with shape and dataType
      let resultMap: [String: Any] = [
        "data": data,
        "shape": shape,
        "dataType": dataType
      ]

      result(resultMap)
    } catch {
      result(FlutterError(code: "DATA_EXTRACTION_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func handleReleaseOrtValue(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let valueId = args["valueId"] as? String else {
      result(FlutterError(code: "INVALID_ARG", message: "Missing value ID", details: nil))
      return
    }

    // Remove and release tensor
    ortValues.removeValue(forKey: valueId)

    result(nil)
  }

  // Helper function to convert ORTTensorElementDataType to string
  private func _getDataTypeName(from type: ORTTensorElementDataType) -> String {
    switch type {
    case .float: return "float32"
    case .int32: return "int32"
    case .int64: return "int64"
    case .uInt8: return "uint8"
    case .int8: return "int8"
    case .string: return "string"
    // Types missing from ORTTensorElementDataType (float16, bool) are handled via the C++ helpers
    default: return "unknown"
    }
  }
}
