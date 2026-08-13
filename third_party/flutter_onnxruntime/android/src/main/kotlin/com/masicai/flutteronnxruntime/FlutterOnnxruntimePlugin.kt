// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

package com.masicai.flutteronnxruntime

import ai.onnxruntime.OnnxJavaType
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OnnxValue
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtException
import ai.onnxruntime.OrtLoggingLevel
import ai.onnxruntime.OrtSession
import ai.onnxruntime.providers.OrtTensorRTProviderOptions
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.nio.ByteBuffer
import java.nio.FloatBuffer
import java.nio.IntBuffer
import java.nio.LongBuffer
import java.nio.ShortBuffer
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Utility class for float16 conversions
 *
 * Implementation based on the MLAS approach mentioned in OnnxRuntime
 *
 * Reference: https://github.com/microsoft/onnxruntime/commit/a8e776b78bfa0d0b1fec8b34b4545d91c2a9d175
 */
class Float16Utils {
    companion object {
        // Constants for float16 <-> float32 conversion
        private const val FLOAT16_EXPONENT_BIAS = 15
        private const val FLOAT32_EXPONENT_BIAS = 127
        private const val FLOAT16_SIGN_MASK = 0x8000
        private const val FLOAT16_EXPONENT_MASK = 0x7C00
        private const val FLOAT16_MANTISSA_MASK = 0x03FF

        /**
         * Convert float32 to float16
         */
        fun floatToFloat16(value: Float): Short {
            val floatBits = java.lang.Float.floatToIntBits(value)

            // Extract sign, exponent, and mantissa from float32
            val sign = (floatBits ushr 31) and 0x1
            val exponent = ((floatBits ushr 23) and 0xFF) - FLOAT32_EXPONENT_BIAS + FLOAT16_EXPONENT_BIAS
            val mantissa = floatBits and 0x7FFFFF

            // Handle special cases
            if (exponent <= 0) {
                // Zero or denormal
                return (sign shl 15).toShort()
            } else if (exponent >= 31) {
                // Infinity or NaN
                if (mantissa == 0) {
                    // Infinity
                    return ((sign shl 15) or FLOAT16_EXPONENT_MASK).toShort()
                } else {
                    // NaN
                    return ((sign shl 15) or FLOAT16_EXPONENT_MASK or 0x200).toShort()
                }
            }

            // Regular numbers
            val float16Bits = (sign shl 15) or (exponent shl 10) or (mantissa ushr 13)
            return float16Bits.toShort()
        }

        /**
         * Convert float16 to float32
         */
        fun float16ToFloat(value: Short): Float {
            val float16Bits = value.toInt() and 0xFFFF

            // Extract sign, exponent, and mantissa from float16
            val sign = (float16Bits and FLOAT16_SIGN_MASK) shl 16
            val exponent = (float16Bits and FLOAT16_EXPONENT_MASK) ushr 10
            val mantissa = float16Bits and FLOAT16_MANTISSA_MASK

            // Handle special cases
            if (exponent == 0) {
                // Zero or denormal
                if (mantissa == 0) {
                    return java.lang.Float.intBitsToFloat(sign)
                }
                // Denormal - convert to normal
                var e = 1
                var m = mantissa
                while ((m and 0x400) == 0) {
                    m = m shl 1
                    e++
                }
                val normalizedExponent = exponent - e + 1
                val float32Bits =
                    sign or (
                        (
                            normalizedExponent + FLOAT32_EXPONENT_BIAS -
                                FLOAT16_EXPONENT_BIAS
                        ) shl 23
                    ) or ((m and 0x3FF) shl 13)
                return java.lang.Float.intBitsToFloat(float32Bits)
            } else if (exponent == 31) {
                // Infinity or NaN
                if (mantissa == 0) {
                    // Infinity
                    return java.lang.Float.intBitsToFloat(sign or 0x7F800000)
                } else {
                    // NaN
                    return java.lang.Float.intBitsToFloat(sign or 0x7FC00000)
                }
            }

            // Regular numbers
            val float32Bits = sign or ((exponent + FLOAT32_EXPONENT_BIAS - FLOAT16_EXPONENT_BIAS) shl 23) or (mantissa shl 13)
            return java.lang.Float.intBitsToFloat(float32Bits)
        }
    }
}

/** FlutterOnnxruntimePlugin */
class FlutterOnnxruntimePlugin : FlutterPlugin, MethodCallHandler {
    /** The MethodChannel that will the communication between Flutter and native Android

     This local reference serves to register the plugin with the Flutter Engine and unregister it
     when the Flutter Engine is detached from the Activity
     */
    private lateinit var channel: MethodChannel
    private lateinit var ortEnvironment: OrtEnvironment
    private val sessions = ConcurrentHashMap<String, OrtSession>()

    // Store OrtValues (tensors) by ID
    private val ortValues = ConcurrentHashMap<String, OnnxValue>()

    // Lock to serialize method handler and cleanup to prevent use-after-close races
    private val lock = Any()

    private fun ortTypeToString(type: OnnxJavaType): String {
        return when (type.toString()) {
            "FLOAT" -> "float32"
            "FLOAT16" -> "float16"
            "INT32" -> "int32"
            "INT64" -> "int64"
            "UINT8" -> "uint8"
            "INT8" -> "int8"
            "BOOL" -> "bool"
            "UINT16" -> "uint16"
            "INT16" -> "int16"
            "DOUBLE" -> "float64"
            "STRING" -> "string"
            // Add other types as needed
            else -> type.toString().lowercase()
        }
    }

    /**
     * Map provider name to enum name
     */
    private fun mapProviderNameToEnumName(providerName: String): String {
        return when (providerName) {
            "ACL" -> "ACL"
            "ARM_NN" -> "ARM_NN"
            "CORE_ML" -> "CORE_ML"
            "CPU" -> "CPU"
            "CUDA" -> "CUDA"
            "DIRECT_ML" -> "DIRECT_ML"
            "DNNL" -> "DNNL"
            "NNAPI" -> "NNAPI"
            "OPEN_VINO" -> "OPEN_VINO"
            "QNN" -> "QNN"
            "ROCM" -> "ROCM"
            "TENSOR_RT" -> "TENSOR_RT"
            "XNNPACK" -> "XNNPACK"
            else -> providerName
        }
    }

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
    ) {
        val taskQueue = flutterPluginBinding.binaryMessenger.makeBackgroundTaskQueue()
        channel =
            MethodChannel(
                flutterPluginBinding.binaryMessenger,
                "flutter_onnxruntime",
                io.flutter.plugin.common.StandardMethodCodec.INSTANCE,
                taskQueue,
            )
        channel.setMethodCallHandler(this)
        ortEnvironment = OrtEnvironment.getEnvironment()
    }

    override fun onMethodCall(
        @NonNull call: MethodCall,
        @NonNull result: Result,
    ): Unit =
        synchronized(lock) {
            when (call.method) {
                "getPlatformVersion" -> {
                    result.success("Android ${android.os.Build.VERSION.RELEASE}")
                }
                "createSession" -> {
                    try {
                        val modelPath = call.argument<String>("modelPath")
                        val sessionOptions = call.argument<Map<String, Any>>("sessionOptions") ?: emptyMap()

                        if (modelPath == null) {
                            result.error("INVALID_ARGUMENT", "Model path cannot be null", null)
                            return
                        }

                        val ortSessionOptions = OrtSession.SessionOptions()

                        // These values are produced by the Dart safety policy.
                        // Validate them at the native boundary as well so a
                        // malformed channel payload cannot silently disable a
                        // memory guard.
                        val inputShape = sessionOptions["inputShape"] as? List<*>
                        if (inputShape != null && inputShape.any {
                                val dimension = (it as? Number)?.toLong()
                                dimension == null || dimension <= 0L
                            }) {
                            result.error("INVALID_ARGUMENT", "inputShape must contain positive integers", null)
                            return
                        }
                        val memoryBudgetBytes = (sessionOptions["memoryBudgetBytes"] as? Number)?.toLong()
                        if (memoryBudgetBytes != null && memoryBudgetBytes <= 0L) {
                            result.error("INVALID_ARGUMENT", "memoryBudgetBytes must be positive", null)
                            return
                        }

                        val providerOptions = sessionOptions["providerOptions"] as? Map<*, *> ?: emptyMap<Any, Any>()
                        val sessionConfigEntries = sessionOptions["sessionConfigEntries"] as? Map<*, *> ?: emptyMap<Any, Any>()
                        for ((key, value) in sessionConfigEntries) {
                            if (key is String && value is String) {
                                ortSessionOptions.addConfigEntry(key, value)
                            }
                        }

                        // Configure session options based on the provided map
                        if (sessionOptions.containsKey("intraOpNumThreads")) {
                            ortSessionOptions.setIntraOpNumThreads((sessionOptions["intraOpNumThreads"] as Number).toInt())
                        }

                        if (sessionOptions.containsKey("interOpNumThreads")) {
                            ortSessionOptions.setInterOpNumThreads((sessionOptions["interOpNumThreads"] as Number).toInt())
                        }

                        // get list of providers, default is empty list
                        var providers = emptyList<String>()
                        if (sessionOptions.containsKey("providers")) {
                            providers = sessionOptions["providers"] as List<String>
                        }
                        // if providers is empty, add CPU provider
                        if (providers.isEmpty()) {
                            providers = listOf("CPU")
                        }
                        var useArena = true
                        if (sessionOptions.containsKey("useArena")) {
                            useArena = sessionOptions["useArena"] as Boolean
                        }
                        ortSessionOptions.setCPUArenaAllocator(useArena)
                        var deviceId = 0
                        if (sessionOptions.containsKey("deviceId")) {
                            deviceId = sessionOptions["deviceId"] as Int
                        }
                        // loop through the providers and add them to the ortSessionOptions
                        for (provider in providers) {
                            // add providers with default parameters
                            when (provider) {
                                "ACL" -> {
                                    ortSessionOptions.addACL(true)
                                }
                                "ARM_NN" -> {
                                    ortSessionOptions.addArmNN(useArena)
                                }
                                "CORE_ML" -> {
                                    val coreMlOptions = (providerOptions[provider] as? Map<*, *>)
                                        ?.mapNotNull { (key, value) ->
                                            if (key is String && value is String) key to value else null
                                        }
                                        ?.toMap()
                                        ?: emptyMap()
                                    if (coreMlOptions.isEmpty()) {
                                        ortSessionOptions.addCoreML()
                                    } else {
                                        ortSessionOptions.addCoreML(coreMlOptions)
                                    }
                                }
                                "CPU" -> {
                                    ortSessionOptions.addCPU(useArena)
                                }
                                "CUDA" -> {
                                    ortSessionOptions.addCUDA(deviceId)
                                }
                                "DIRECT_ML" -> {
                                    ortSessionOptions.addDirectML(deviceId)
                                }
                                "DNNL" -> {
                                    ortSessionOptions.addDnnl(useArena)
                                }
                                "NNAPI" -> {
                                    ortSessionOptions.addNnapi()
                                }
                                "OPEN_VINO" -> {
                                    ortSessionOptions.addOpenVINO(deviceId.toString())
                                }
                                "QNN" -> {
                                    ortSessionOptions.addQnn(mapOf())
                                }
                                "ROCM" -> {
                                    ortSessionOptions.addROCM(deviceId)
                                }
                                "TENSOR_RT" -> {
                                    ortSessionOptions.addTensorrt(OrtTensorRTProviderOptions(deviceId))
                                }
                                "XNNPACK" -> {
                                    // use an empty map as the parameter
                                    ortSessionOptions.addXnnpack(mapOf())
                                }
                                else -> {
                                    result.error("INVALID_PROVIDER", "Provider $provider is not supported", null)
                                    return
                                }
                            }
                        }

                        // Load model from file path
                        val modelFile = File(modelPath)
                        if (!modelFile.exists()) {
                            result.error("FILE_NOT_FOUND", "Model file not found at path: $modelPath", null)
                            return
                        }

                        val session = ortEnvironment.createSession(modelPath, ortSessionOptions)
                        val sessionId = UUID.randomUUID().toString()
                        sessions[sessionId] = session

                        // Get input and output names
                        val inputNames = session.inputNames.toList()
                        val outputNames = session.outputNames.toList()

                        result.success(
                            mapOf(
                                "sessionId" to sessionId,
                                "inputNames" to inputNames,
                                "outputNames" to outputNames,
                            ),
                        )
                    } catch (e: OrtException) {
                        result.error("ORT_ERROR", e.message, e.stackTraceToString())
                    } catch (e: Exception) {
                        result.error("PLUGIN_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "getAvailableProviders" -> {
                    val providers = OrtEnvironment.getAvailableProviders()
                    val providerList = providers.map { mapProviderNameToEnumName(it.toString()) }.toList()
                    result.success(providerList)
                }
                "getRuntimeInfo" -> {
                    val providers = OrtEnvironment.getAvailableProviders()
                        .map { mapProviderNameToEnumName(it.toString()) }
                        .toList()
                    result.success(
                        mapOf(
                            "ortVersion" to ortEnvironment.getVersion(),
                            "providers" to providers,
                            "platform" to "android",
                        ),
                    )
                }
                "runInference" -> {
                    try {
                        val sessionId = call.argument<String>("sessionId")
                        val inputs = call.argument<Map<String, Any>>("inputs")
                        val runOptions = call.argument<Map<String, Any>>("runOptions")

                        if (sessionId == null || !sessions.containsKey(sessionId)) {
                            result.error("INVALID_SESSION", "Session not found", null)
                            return
                        }

                        if (inputs == null) {
                            result.error("INVALID_ARGUMENT", "Inputs must be a non-null map", null)
                            return
                        }

                        val session = sessions[sessionId]!!
                        val ortInputs = HashMap<String, OnnxValue>()

                        try {
                            // Process inputs - now expecting only OrtValue references
                            for ((name, value) in inputs) {
                                // Only process value as a Map with valueId
                                if (value is Map<*, *> && value.containsKey("valueId")) {
                                    val valueId = value["valueId"] as String
                                    val existingTensor = ortValues[valueId]
                                    if (existingTensor != null) {
                                        ortInputs[name] = existingTensor
                                    } else {
                                        result.error(
                                            "INVALID_ORT_VALUE",
                                            "OrtValue with ID $valueId not found",
                                            null,
                                        )
                                        return
                                    }
                                } else {
                                    result.error(
                                        "INVALID_INPUT_FORMAT",
                                        "Input for '$name' must be an OrtValue reference with value ID",
                                        null,
                                    )
                                    return
                                }
                            }

                            // Convert inputs to the required type for session.run
                            val runInputs = HashMap<String, OnnxTensor>()
                            for ((name, value) in ortInputs) {
                                if (value is OnnxTensor) {
                                    runInputs[name] = value
                                }
                            }

                            // Create OrtSession.RunOptions if provided
                            val ortRunOptions =
                                if (runOptions != null && runOptions.isNotEmpty()) {
                                    val options = OrtSession.RunOptions()

                                    // Configure log severity level if provided
                                    if (runOptions.containsKey("logSeverityLevel")) {
                                        val level = (runOptions["logSeverityLevel"] as Number).toInt()
                                        val logLevel =
                                            when (level) {
                                                0 -> OrtLoggingLevel.ORT_LOGGING_LEVEL_VERBOSE
                                                1 -> OrtLoggingLevel.ORT_LOGGING_LEVEL_INFO
                                                2 -> OrtLoggingLevel.ORT_LOGGING_LEVEL_WARNING
                                                3 -> OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR
                                                4 -> OrtLoggingLevel.ORT_LOGGING_LEVEL_FATAL
                                                // Handle unexpected levels
                                                else -> OrtLoggingLevel.ORT_LOGGING_LEVEL_WARNING // default to warning
                                            }
                                        options.setLogLevel(logLevel)
                                    }

                                    // Configure log verbosity level if provided
                                    if (runOptions.containsKey("logVerbosityLevel")) {
                                        val level = (runOptions["logVerbosityLevel"] as Number).toInt()
                                        options.setLogVerbosityLevel(level)
                                    }

                                    // Configure terminate flag if provided
                                    if (runOptions.containsKey("terminate")) {
                                        val terminate = runOptions["terminate"] as Boolean
                                        options.setTerminate(terminate)
                                    }

                                    options
                                } else {
                                    null
                                }

                            // Run inference with correctly typed inputs and optional run options
                            val ortOutputs =
                                if (ortRunOptions != null) {
                                    session.run(runInputs, ortRunOptions)
                                } else {
                                    session.run(runInputs)
                                }

                            // Process outputs
                            // Outputs will be a map of outputName -> OrtValue parameters
                            // OrtValue parameters are: valueId, elementType, shape
                            val outputs = HashMap<String, Any>()

                            // Convert tensor outputs to Flutter-compatible types
                            for (outputName in session.outputNames) {
                                // `Result.get(name)` returns Optional<OnnxValue>; unwrap it and keep tensor outputs only
                                val outputValue = ortOutputs[outputName].orElse(null)
                                // create a list of outputValue parameters
                                val outputValueParams = ArrayList<Any>()

                                val outputTensor = outputValue as? OnnxTensor

                                if (outputTensor != null) {
                                    // add outputTensor to ortvalues
                                    val valueId = UUID.randomUUID().toString()
                                    ortValues[valueId] = outputTensor

                                    outputValueParams.add(valueId)
                                    outputValueParams.add(ortTypeToString(outputTensor.info.type))
                                    outputValueParams.add(outputTensor.info.shape.toList())
                                } else {
                                    val errorMessage = "Output is null or not a tensor: ${outputValue?.javaClass?.name}"
                                    outputValueParams.add(errorMessage)
                                }
                                outputs[outputName] = outputValueParams
                            }

                            // Clean up run options if created
                            ortRunOptions?.close()

                            result.success(outputs)
                        } catch (e: Exception) {
                            throw e
                        }
                    } catch (e: OrtException) {
                        result.error("INFERENCE_ERROR", e.message, e.stackTraceToString())
                    } catch (e: Exception) {
                        result.error("PLUGIN_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "closeSession" -> {
                    try {
                        val sessionId = call.argument<String>("sessionId")

                        if (sessionId == null || !sessions.containsKey(sessionId)) {
                            result.error("INVALID_SESSION", "Session not found", null)
                            return
                        }

                        val session = sessions[sessionId]!!
                        session.close()
                        sessions.remove(sessionId)

                        result.success(null)
                    } catch (e: OrtException) {
                        result.error("ORT_ERROR", e.message, e.stackTraceToString())
                    } catch (e: Exception) {
                        result.error("PLUGIN_ERROR", e.message, e.stackTraceToString())
                    }
                }
                /** Get metadata about the model

                 Returns metadata about the model such as producer name, graph name, domain, description, version, and custom metadata.

                 Reference: https://onnxruntime.ai/docs/api/java/ai/onnxruntime/OrtSession.html#getMetadata()
                 */
                "getMetadata" -> {
                    try {
                        val sessionId = call.argument<String>("sessionId")

                        if (sessionId == null || !sessions.containsKey(sessionId)) {
                            result.error("INVALID_SESSION", "Session not found", null)
                            return
                        }

                        val session = sessions[sessionId]!!
                        val metadata = session.getMetadata()

                        // Convert custom metadata map to a standard Map
                        val customMetadataMap = metadata.customMetadata

                        val metadataMap =
                            mapOf(
                                "producerName" to metadata.producerName,
                                "graphName" to metadata.graphName,
                                "domain" to metadata.domain,
                                "description" to metadata.description,
                                "version" to metadata.version,
                                "customMetadataMap" to customMetadataMap,
                            )

                        result.success(metadataMap)
                    } catch (e: OrtException) {
                        result.error("ORT_ERROR", e.message, e.stackTraceToString())
                    } catch (e: Exception) {
                        result.error("PLUGIN_ERROR", e.message, e.stackTraceToString())
                    }
                }
                /** Get input info about the model

                 Returns information about the model's inputs such as name, type, and shape.

                 Reference: https://onnxruntime.ai/docs/api/java/ai/onnxruntime/OrtSession.html#getInputInfo()
                 */
                "getInputInfo" -> {
                    try {
                        val sessionId = call.argument<String>("sessionId")

                        if (sessionId == null || !sessions.containsKey(sessionId)) {
                            result.error("INVALID_SESSION", "Session not found", null)
                            return
                        }

                        val session = sessions[sessionId]!!
                        val nodeInfoList = ArrayList<Map<String, Any>>()

                        // Get all input info as Map<String, NodeInfo>
                        val inputInfoMap = session.getInputInfo()

                        // Convert to a list of maps for Flutter
                        for ((name, nodeInfo) in inputInfoMap) {
                            val infoMap = HashMap<String, Any>()
                            infoMap["name"] = name

                            // Get the info object and check its type
                            val info = nodeInfo.info

                            // Only extract shape if it's a TensorInfo
                            if (info is ai.onnxruntime.TensorInfo) {
                                val shape = info.shape
                                infoMap["shape"] = shape.toList()
                                infoMap["type"] = ortTypeToString(info.type)
                            } else {
                                // For non-tensor types, provide an empty shape
                                infoMap["shape"] = emptyList<Long>()
                            }

                            nodeInfoList.add(infoMap)
                        }

                        result.success(nodeInfoList)
                    } catch (e: OrtException) {
                        result.error("ORT_ERROR", e.message, e.stackTraceToString())
                    } catch (e: Exception) {
                        result.error("PLUGIN_ERROR", e.message, e.stackTraceToString())
                    }
                }
                /** Get output info about the model

                 Returns information about the model's outputs such as name, type, and shape.

                 Reference: https://onnxruntime.ai/docs/api/java/ai/onnxruntime/OrtSession.html#getOutputInfo()
                 */
                "getOutputInfo" -> {
                    try {
                        val sessionId = call.argument<String>("sessionId")

                        if (sessionId == null || !sessions.containsKey(sessionId)) {
                            result.error("INVALID_SESSION", "Session not found", null)
                            return
                        }

                        val session = sessions[sessionId]!!
                        val nodeInfoList = ArrayList<Map<String, Any>>()

                        // Get all output info as Map<String, NodeInfo>
                        val outputInfoMap = session.getOutputInfo()

                        // Convert to a list of maps for Flutter
                        for ((name, nodeInfo) in outputInfoMap) {
                            val infoMap = HashMap<String, Any>()
                            infoMap["name"] = name

                            // Get the info object and check its type
                            val info = nodeInfo.info

                            // Only extract shape if it's a TensorInfo
                            if (info is ai.onnxruntime.TensorInfo) {
                                val shape = info.shape
                                infoMap["shape"] = shape.toList()
                                infoMap["type"] = ortTypeToString(info.type)
                            } else {
                                // For non-tensor types, provide an empty shape
                                infoMap["shape"] = emptyList<Long>()
                            }

                            nodeInfoList.add(infoMap)
                        }

                        result.success(nodeInfoList)
                    } catch (e: OrtException) {
                        result.error("ORT_ERROR", e.message, e.stackTraceToString())
                    } catch (e: Exception) {
                        result.error("PLUGIN_ERROR", e.message, e.stackTraceToString())
                    }
                }
                // OrtValue methods
                "createOrtValue" -> {
                    try {
                        val sourceType = call.argument<String>("sourceType")
                        val data = call.argument<Any>("data")
                        val shape = call.argument<List<Int>>("shape")

                        if (sourceType == null || data == null || shape == null) {
                            result.error("INVALID_ARG", "Missing required arguments", null)
                            return
                        }

                        // Convert shape to long array for OnnxRuntime
                        val longShape = shape.map { it.toLong() }.toLongArray()

                        // Create tensor based on source data type
                        val tensor =
                            when (sourceType) {
                                "float32" -> {
                                    val floatData =
                                        when (data) {
                                            is List<*> -> data.map { (it as Number).toFloat() }.toFloatArray()
                                            is FloatArray -> data
                                            else -> {
                                                result.error("INVALID_DATA", "Data must be a list of numbers for float32 type", null)
                                                return
                                            }
                                        }
                                    OnnxTensor.createTensor(ortEnvironment, FloatBuffer.wrap(floatData), longShape)
                                }
                                "float16" -> {
                                    when (data) {
                                        is List<*> -> {
                                            if (data.isEmpty()) {
                                                result.error("INVALID_DATA", "Data list cannot be empty for float16 type", null)
                                                return
                                            }

                                            // Handle both short values (already in float16 format) and float values (need conversion)
                                            val shortData = ShortArray(data.size)
                                            when (data[0]) {
                                                is Number -> {
                                                    // If source is float, convert to float16
                                                    for (i in data.indices) {
                                                        val floatValue = (data[i] as Number).toFloat()
                                                        shortData[i] = Float16Utils.floatToFloat16(floatValue)
                                                    }
                                                }
                                                else -> {
                                                    result.error("INVALID_DATA", "Data must be a list of numbers for float16 type", null)
                                                    return
                                                }
                                            }

                                            // Create tensor with float16 type
                                            OnnxTensor.createTensor(
                                                ortEnvironment,
                                                ShortBuffer.wrap(shortData),
                                                longShape,
                                                OnnxJavaType.FLOAT16,
                                            )
                                        }
                                        else -> {
                                            result.error("INVALID_DATA", "Data must be a list of numbers for float16 type", null)
                                            return
                                        }
                                    }
                                }
                                "int32" -> {
                                    val intData =
                                        when (data) {
                                            is List<*> -> data.map { (it as Number).toInt() }.toIntArray()
                                            is IntArray -> data
                                            else -> {
                                                result.error("INVALID_DATA", "Data must be a list of numbers for int32 type", null)
                                                return
                                            }
                                        }
                                    OnnxTensor.createTensor(ortEnvironment, IntBuffer.wrap(intData), longShape)
                                }
                                "int64" -> {
                                    val longData =
                                        when (data) {
                                            is List<*> -> data.map { (it as Number).toLong() }.toLongArray()
                                            is LongArray -> data
                                            else -> {
                                                result.error("INVALID_DATA", "Data must be a list of numbers for int64 type", null)
                                                return
                                            }
                                        }
                                    OnnxTensor.createTensor(ortEnvironment, LongBuffer.wrap(longData), longShape)
                                }
                                "uint8" -> {
                                    val byteData =
                                        when (data) {
                                            is List<*> -> {
                                                val bytes = ByteArray(data.size)
                                                for (i in data.indices) {
                                                    bytes[i] = (data[i] as Number).toByte()
                                                }
                                                bytes
                                            }
                                            is ByteArray -> data
                                            else -> {
                                                result.error("INVALID_DATA", "Data must be a list of numbers for uint8 type", null)
                                                return
                                            }
                                        }
                                    OnnxTensor.createTensor(ortEnvironment, ByteBuffer.wrap(byteData), longShape, OnnxJavaType.UINT8)
                                }
                                "bool" -> {
                                    val boolData =
                                        when (data) {
                                            is List<*> -> {
                                                val bytes = ByteArray(data.size)
                                                for (i in data.indices) {
                                                    bytes[i] = if (data[i] as Boolean) 1.toByte() else 0.toByte()
                                                }
                                                bytes
                                            }
                                            else -> {
                                                result.error("INVALID_DATA", "Data must be a list of booleans for bool type", null)
                                                return
                                            }
                                        }
                                    // Boolean tensors are stored as bytes in ONNX Runtime
                                    OnnxTensor.createTensor(ortEnvironment, ByteBuffer.wrap(boolData), longShape, OnnxJavaType.BOOL)
                                }
                                "string" -> {
                                    val stringData =
                                        when (data) {
                                            is List<*> -> {
                                                data.map { it as String }.toTypedArray()
                                            }
                                            else -> {
                                                result.error("INVALID_DATA", "Data must be a list of strings for string type", null)
                                                return
                                            }
                                        }
                                    OnnxTensor.createTensor(ortEnvironment, stringData, longShape)
                                }
                                else -> {
                                    result.error("UNSUPPORTED_TYPE", "Unsupported source data type: $sourceType", null)
                                    return
                                }
                            }

                        // Store the tensor with a unique ID
                        val valueId = UUID.randomUUID().toString()
                        ortValues[valueId] = tensor

                        // Return tensor information
                        val tensorInfo =
                            mapOf(
                                "valueId" to valueId,
                                "dataType" to sourceType,
                                "shape" to shape,
                            )

                        result.success(tensorInfo)
                    } catch (e: Exception) {
                        result.error("TENSOR_CREATION_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "convertOrtValue" -> {
                    try {
                        val valueId = call.argument<String>("valueId")
                        val targetType = call.argument<String>("targetType")

                        if (valueId == null || targetType == null) {
                            result.error("INVALID_ARG", "Missing required arguments", null)
                            return
                        }

                        val tensor = ortValues[valueId]
                        if (tensor == null) {
                            result.error("INVALID_VALUE", "OrtValue with ID $valueId not found", null)
                            return
                        }

                        if (tensor !is OnnxTensor) {
                            result.error("INVALID_TENSOR_TYPE", "OrtValue is not a tensor", null)
                            return
                        }

                        // Get tensor information
                        val shape = tensor.info.shape
                        val dataType = ortTypeToString(tensor.info.type)

                        // For now, we'll implement a simple conversion for certain type pairs
                        // A full implementation would handle all possible conversions
                        val newTensor =
                            when {
                                // Float32 to float16
                                dataType == "float32" && targetType == "float16" -> {
                                    // Extract the float data from the tensor
                                    val floatBuffer = tensor.floatBuffer
                                    val floatArray = FloatArray(floatBuffer.remaining())
                                    floatBuffer.get(floatArray)

                                    // Convert float array to short array using OnnxRuntime's float16 utilities
                                    // Use ShortBuffer to store float16 values
                                    val shortArray = ShortArray(floatArray.size)
                                    for (i in floatArray.indices) {
                                        // Use ai.onnxruntime.OnnxRuntime utility method to convert float to float16
                                        shortArray[i] = Float16Utils.floatToFloat16(floatArray[i])
                                    }

                                    // Create a new tensor with float16 data
                                    val shortBuffer = ShortBuffer.wrap(shortArray)
                                    // Use OnnxTensor.createTensor with the appropriate float16 type
                                    OnnxTensor.createTensor(ortEnvironment, shortBuffer, shape, OnnxJavaType.FLOAT16)
                                }
                                // Float16 to float32
                                dataType == "float16" && targetType == "float32" -> {
                                    val shortBuffer = tensor.shortBuffer
                                    val shortArray = ShortArray(shortBuffer.remaining())
                                    shortBuffer.get(shortArray)

                                    val floatArray = FloatArray(shortArray.size) { Float16Utils.float16ToFloat(shortArray[it]) }
                                    OnnxTensor.createTensor(ortEnvironment, FloatBuffer.wrap(floatArray), shape)
                                }
                                // Int32 to Float32
                                dataType == "int32" && targetType == "float32" -> {
                                    val intBuffer = tensor.intBuffer
                                    val intArray = IntArray(intBuffer.remaining())
                                    intBuffer.get(intArray)

                                    val floatArray = FloatArray(intArray.size) { intArray[it].toFloat() }
                                    OnnxTensor.createTensor(ortEnvironment, FloatBuffer.wrap(floatArray), shape)
                                }
                                // Int64 to Float32
                                dataType == "int64" && targetType == "float32" -> {
                                    val longBuffer = tensor.longBuffer
                                    val longArray = LongArray(longBuffer.remaining())
                                    longBuffer.get(longArray)

                                    val floatArray = FloatArray(longArray.size) { longArray[it].toFloat() }
                                    OnnxTensor.createTensor(ortEnvironment, FloatBuffer.wrap(floatArray), shape)
                                }
                                // Uint8 to Float32
                                dataType == "uint8" && targetType == "float32" -> {
                                    val byteBuffer = tensor.byteBuffer
                                    val byteArray = ByteArray(byteBuffer.remaining())
                                    byteBuffer.get(byteArray)

                                    val floatArray = FloatArray(byteArray.size) { (byteArray[it].toInt() and 0xFF).toFloat() }
                                    OnnxTensor.createTensor(ortEnvironment, FloatBuffer.wrap(floatArray), shape)
                                }
                                // Uint8 to Int32
                                dataType == "uint8" && targetType == "int32" -> {
                                    val byteBuffer = tensor.byteBuffer
                                    val byteArray = ByteArray(byteBuffer.remaining())
                                    byteBuffer.get(byteArray)

                                    val intArray = IntArray(byteArray.size) { byteArray[it].toInt() and 0xFF }
                                    OnnxTensor.createTensor(ortEnvironment, IntBuffer.wrap(intArray), shape)
                                }
                                // Uint8 to Int64
                                dataType == "uint8" && targetType == "int64" -> {
                                    val byteBuffer = tensor.byteBuffer
                                    val byteArray = ByteArray(byteBuffer.remaining())
                                    byteBuffer.get(byteArray)

                                    val longArray = LongArray(byteArray.size) { (byteArray[it].toInt() and 0xFF).toLong() }
                                    OnnxTensor.createTensor(ortEnvironment, LongBuffer.wrap(longArray), shape)
                                }
                                // Float32 to Int32
                                dataType == "float32" && targetType == "int32" -> {
                                    val floatBuffer = tensor.floatBuffer
                                    val floatArray = FloatArray(floatBuffer.remaining())
                                    floatBuffer.get(floatArray)

                                    val intArray = IntArray(floatArray.size) { floatArray[it].toInt() }
                                    OnnxTensor.createTensor(ortEnvironment, IntBuffer.wrap(intArray), shape)
                                }
                                // Float32 to Int64
                                dataType == "float32" && targetType == "int64" -> {
                                    val floatBuffer = tensor.floatBuffer
                                    val floatArray = FloatArray(floatBuffer.remaining())
                                    floatBuffer.get(floatArray)

                                    val longArray = LongArray(floatArray.size) { floatArray[it].toLong() }
                                    OnnxTensor.createTensor(ortEnvironment, LongBuffer.wrap(longArray), shape)
                                }
                                // Int32 to Int64
                                dataType == "int32" && targetType == "int64" -> {
                                    val intBuffer = tensor.intBuffer
                                    val intArray = IntArray(intBuffer.remaining())
                                    intBuffer.get(intArray)

                                    val longArray = LongArray(intArray.size) { intArray[it].toLong() }
                                    OnnxTensor.createTensor(ortEnvironment, LongBuffer.wrap(longArray), shape)
                                }
                                // Int64 to Int32 (with potential loss of precision)
                                dataType == "int64" && targetType == "int32" -> {
                                    val longBuffer = tensor.longBuffer
                                    val longArray = LongArray(longBuffer.remaining())
                                    longBuffer.get(longArray)

                                    // Check for potential data loss
                                    val hasDataLoss = longArray.any { it > Int.MAX_VALUE || it < Int.MIN_VALUE }
                                    if (hasDataLoss) {
                                        Log.w("ORT_CONVERSION", "Converting Int64 to Int32 with data loss")
                                    }

                                    val intArray = IntArray(longArray.size) { longArray[it].toInt() }
                                    OnnxTensor.createTensor(ortEnvironment, IntBuffer.wrap(intArray), shape)
                                }
                                // Float32 to Uint8
                                dataType == "float32" && targetType == "uint8" -> {
                                    val floatBuffer = tensor.floatBuffer
                                    val floatArray = FloatArray(floatBuffer.remaining())
                                    floatBuffer.get(floatArray)

                                    // Clamp to valid uint8 range [0, 255]
                                    val byteData = ByteArray(floatArray.size) { floatArray[it].toInt().coerceIn(0, 255).toByte() }
                                    OnnxTensor.createTensor(ortEnvironment, ByteBuffer.wrap(byteData), shape, OnnxJavaType.UINT8)
                                }
                                // Int32 to Uint8
                                dataType == "int32" && targetType == "uint8" -> {
                                    val intBuffer = tensor.intBuffer
                                    val intArray = IntArray(intBuffer.remaining())
                                    intBuffer.get(intArray)

                                    // Clamp to valid uint8 range [0, 255]
                                    val byteData = ByteArray(intArray.size) { intArray[it].coerceIn(0, 255).toByte() }
                                    OnnxTensor.createTensor(ortEnvironment, ByteBuffer.wrap(byteData), shape, OnnxJavaType.UINT8)
                                }
                                // Int64 to Uint8
                                dataType == "int64" && targetType == "uint8" -> {
                                    val longBuffer = tensor.longBuffer
                                    val longArray = LongArray(longBuffer.remaining())
                                    longBuffer.get(longArray)

                                    // Clamp to valid uint8 range [0, 255]
                                    val byteData = ByteArray(longArray.size) { longArray[it].coerceIn(0, 255).toByte() }
                                    OnnxTensor.createTensor(ortEnvironment, ByteBuffer.wrap(byteData), shape, OnnxJavaType.UINT8)
                                }
                                // Boolean to Float32
                                dataType == "bool" && targetType == "float32" -> {
                                    val byteBuffer = tensor.byteBuffer
                                    val byteArray = ByteArray(byteBuffer.remaining())
                                    byteBuffer.get(byteArray)

                                    val floatArray = FloatArray(byteArray.size) { if (byteArray[it] != 0.toByte()) 1.0f else 0.0f }
                                    OnnxTensor.createTensor(ortEnvironment, FloatBuffer.wrap(floatArray), shape)
                                }
                                // Boolean to Int32
                                dataType == "bool" && targetType == "int32" -> {
                                    val byteBuffer = tensor.byteBuffer
                                    val byteArray = ByteArray(byteBuffer.remaining())
                                    byteBuffer.get(byteArray)

                                    val intArray = IntArray(byteArray.size) { if (byteArray[it] != 0.toByte()) 1 else 0 }
                                    OnnxTensor.createTensor(ortEnvironment, IntBuffer.wrap(intArray), shape)
                                }
                                // Boolean to Int64
                                dataType == "bool" && targetType == "int64" -> {
                                    val byteBuffer = tensor.byteBuffer
                                    val byteArray = ByteArray(byteBuffer.remaining())
                                    byteBuffer.get(byteArray)

                                    val longArray = LongArray(byteArray.size) { if (byteArray[it] != 0.toByte()) 1L else 0L }
                                    OnnxTensor.createTensor(ortEnvironment, LongBuffer.wrap(longArray), shape)
                                }
                                // Boolean to Int8/Uint8
                                dataType == "bool" && (targetType == "int8" || targetType == "uint8") -> {
                                    val byteBuffer = tensor.byteBuffer
                                    val byteArray = ByteArray(byteBuffer.remaining())
                                    byteBuffer.get(byteArray)

                                    // Boolean values are already stored as bytes (0 or 1)
                                    val javaType = if (targetType == "uint8") OnnxJavaType.UINT8 else OnnxJavaType.INT8
                                    OnnxTensor.createTensor(ortEnvironment, ByteBuffer.wrap(byteArray), shape, javaType)
                                }
                                // Int8/Uint8 to Boolean
                                (dataType == "int8" || dataType == "uint8") && targetType == "bool" -> {
                                    val byteBuffer = tensor.byteBuffer
                                    val byteArray = ByteArray(byteBuffer.remaining())
                                    byteBuffer.get(byteArray)

                                    // Convert to boolean representation (non-zero values become true)
                                    val boolArray =
                                        ByteArray(byteArray.size) { if (byteArray[it] != 0.toByte()) 1.toByte() else 0.toByte() }
                                    OnnxTensor.createTensor(ortEnvironment, ByteBuffer.wrap(boolArray), shape, OnnxJavaType.BOOL)
                                }
                                // Same type conversion (no-op)
                                (dataType == "float32" && targetType == "float32") ||
                                    (dataType == "float16" && targetType == "float16") ||
                                    (dataType == "int32" && targetType == "int32") ||
                                    (dataType == "int64" && targetType == "int64") ||
                                    (dataType == "uint8" && targetType == "uint8") ||
                                    (dataType == "int8" && targetType == "int8") ||
                                    (dataType == "bool" && targetType == "bool") ||
                                    (dataType == "string" && targetType == "string") -> {
                                    // clone the original tensor to a new tensor
                                    OnnxTensor.createTensor(ortEnvironment, tensor.getValue())
                                }
                                else -> {
                                    // Unsupported conversion
                                    result.error(
                                        "CONVERSION_ERROR",
                                        "Conversion from $dataType to $targetType is not supported",
                                        null,
                                    )
                                    return
                                }
                            }

                        // register the new tensor to ortValues
                        val id = UUID.randomUUID().toString()
                        ortValues[id] = newTensor
                        val newValueId = id

                        // Return tensor information
                        val tensorInfo =
                            mapOf(
                                "valueId" to newValueId,
                                "dataType" to targetType,
                                "shape" to shape.toList(),
                            )

                        result.success(tensorInfo)
                    } catch (e: Exception) {
                        result.error("CONVERSION_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "getOrtValueData" -> {
                    try {
                        val valueId = call.argument<String>("valueId")

                        if (valueId == null) {
                            result.error("INVALID_ARG", "Missing value ID", null)
                            return
                        }

                        val tensor = ortValues[valueId]
                        if (tensor == null) {
                            result.error("INVALID_VALUE", "Tensor not found or already being disposed", null)
                            return
                        }

                        if (tensor !is OnnxTensor) {
                            result.error("INVALID_TENSOR_TYPE", "OrtValue is not a tensor", null)
                            return
                        }

                        // Get tensor shape
                        val shape = tensor.info.shape
                        val flatSize = shape.fold(1L) { acc, dim -> acc * dim }.toInt()

                        // Return data in its native type without conversion
                        val data =
                            when (ortTypeToString(tensor.info.type)) {
                                "float32" -> {
                                    val floatArray = FloatArray(flatSize)
                                    tensor.floatBuffer.get(floatArray)
                                    floatArray
                                }
                                "float16" -> {
                                    // For float16, convert to float32 for easier use in Dart
                                    val shortArray = ShortArray(flatSize)
                                    tensor.shortBuffer.get(shortArray)
                                    shortArray.map { Float16Utils.float16ToFloat(it) }
                                }
                                "int32" -> {
                                    val intArray = IntArray(flatSize)
                                    tensor.intBuffer.get(intArray)
                                    intArray
                                }
                                "int64" -> {
                                    val longArray = LongArray(flatSize)
                                    tensor.longBuffer.get(longArray)
                                    longArray
                                }
                                "int16", "uint16" -> {
                                    val shortArray = ShortArray(flatSize)
                                    tensor.shortBuffer.get(shortArray)
                                    shortArray.map { it.toInt() }
                                }
                                "int8", "uint8" -> {
                                    val byteArray = ByteArray(flatSize)
                                    tensor.byteBuffer.get(byteArray)
                                    byteArray
                                }
                                "bool" -> {
                                    val byteArray = ByteArray(flatSize)
                                    tensor.byteBuffer.get(byteArray)
                                    byteArray.map { it != 0.toByte() }
                                }
                                "string" -> {
                                    // flatten multi-dim string array to 1D list
                                    fun flattenStringArray(arr: Any): List<String> {
                                        return when (arr) {
                                            is String -> listOf(arr)
                                            is Array<*> -> arr.flatMap { flattenStringArray(it!!) }
                                            else -> throw IllegalArgumentException("Unexpected type in string tensor: ${arr::class.java}")
                                        }
                                    }
                                    flattenStringArray(tensor.value)
                                }
                                else -> {
                                    result.error("UNSUPPORTED_NATIVE_TYPE", "Unsupported native data type: ${tensor.info.type}", null)
                                    return
                                }
                            }
                        // Return data with shape
                        val resultMap =
                            mapOf(
                                "data" to data,
                                "shape" to shape.toList(),
                            )

                        result.success(resultMap)
                    } catch (e: Exception) {
                        result.error("DATA_EXTRACTION_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "releaseOrtValue" -> {
                    try {
                        val valueId = call.argument<String>("valueId")

                        if (valueId == null) {
                            result.error("INVALID_ARGUMENT", "Invalid value ID", null)
                            return
                        }

                        val tensor = ortValues.remove(valueId)
                        if (tensor != null) {
                            try {
                                tensor.close()
                            } catch (e: Exception) {
                                // Log error but continue
                                Log.e("ORT_ERROR", "Error closing tensor: ${e.message}")
                            }
                        }

                        result.success(null)
                    } catch (e: Exception) {
                        result.error("RELEASE_ERROR", e.message, e.stackTraceToString())
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

    override fun onDetachedFromEngine(
        @NonNull binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        // Stop accepting new calls before acquiring the lock
        channel.setMethodCallHandler(null)

        // Wait for any in-flight handler call to finish, then clean up
        synchronized(lock) {
            // Close all OrtValues
            for (value in ortValues.values) {
                try {
                    value.close()
                } catch (e: Exception) {
                    // Ignore exceptions during cleanup
                }
            }
            ortValues.clear()

            // Close all sessions
            for (session in sessions.values) {
                try {
                    session.close()
                } catch (e: Exception) {
                    // Ignore exceptions during cleanup
                }
            }
            sessions.clear()

            // Close the environment
            try {
                ortEnvironment.close()
            } catch (e: Exception) {
                // Ignore exceptions during cleanup
            }
        }
    }
}
