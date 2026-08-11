#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_onnxruntime.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_onnxruntime'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for ONNX Runtime'
  s.description      = <<-DESC
Flutter plugin for running ONNX models with the native ONNX Runtime, supporting both CocoaPods and Swift Package Manager.
                       DESC
  s.homepage         = 'https://github.com/masicai/flutter_onnxruntime'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MASIC AI' => 'contact@masicai.com' }

  s.source           = { :path => '.' }
  # Sources live in the Swift Package Manager layout and are shared by both build systems.
  s.source_files = 'flutter_onnxruntime/Sources/**/*.{swift,h,mm}'
  # Expose only the helper headers under include/; everything else (notably the
  # vendored C++ ORT headers) stays private and out of the umbrella / module map,
  # so it is never compiled as Objective-C.
  s.public_header_files = 'flutter_onnxruntime/Sources/flutter_onnxruntime_objc/include/**/*.h'

  s.resource_bundles = {'flutter_onnxruntime_privacy' => ['flutter_onnxruntime/Sources/flutter_onnxruntime/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'
  # Add ONNX Runtime dependency for macOS.
  # Keep this version in lockstep with the `onnxruntime-swift-package-manager`
  # pin in flutter_onnxruntime/Package.swift so CocoaPods and SPM resolve the
  # same ORT (and the vendored internal headers stay matched).
  # 1.23.0: last ORT without the KleidiAI conv memory regression of 1.24.x
  # (microsoft/onnxruntime#29538); bump both pins together once ORT >= 1.28 ships.
  s.dependency 'onnxruntime-objc', '1.23.0'

  s.platform = :osx, '14.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/onnxruntime-objc/objectivec" "${PODS_ROOT}/onnxruntime-objc/objectivec/include"'
  }
  s.swift_version = '5.0'
end
