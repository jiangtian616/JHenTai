// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "flutter_onnxruntime",
  platforms: [
    .macOS("14.0")
  ],
  products: [
    // The Flutter tooling requires the library product name to be the
    // dasherized plugin name (it generates a dependency on "flutter-onnxruntime").
    .library(name: "flutter-onnxruntime", targets: ["flutter_onnxruntime"])
  ],
  dependencies: [
    // Pinned exactly so the vendored internal headers in
    // Sources/flutter_onnxruntime_objc/vendor/ always match the resolved package.
    // masicai fork pinning ORT 1.23.0: Microsoft's SPM repo has no 1.23.x tag, and
    // ORT 1.24.x has a KleidiAI conv memory regression on SME-capable ARM64 devices
    // (microsoft/onnxruntime#29538). Point back to
    // https://github.com/microsoft/onnxruntime-swift-package-manager once a release
    // ships with microsoft/onnxruntime#28571 (expected ORT 1.28) and has an SPM tag.
    .package(url: "https://github.com/masicai/onnxruntime-swift-package-manager", exact: "1.23.1")
  ],
  targets: [
    // Swift target. `import FlutterMacOS` resolves implicitly through the
    // Flutter tooling; do NOT declare a Flutter framework dependency here
    // (the FlutterFramework local package only exists on Flutter master).
    .target(
      name: "flutter_onnxruntime",
      dependencies: [
        "flutter_onnxruntime_objc",
        .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    ),
    // ObjC++ target: SwiftPM does not support mixed-language targets, so the
    // float16 C++ bridge and the messenger workaround live in their own module.
    .target(
      name: "flutter_onnxruntime_objc",
      dependencies: [
        .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager")
      ],
      cxxSettings: [
        // Make the vendored cxx_api.h resolve the ORT C/C++ API headers from
        // the binary xcframework ("onnxruntime/..." prefixed paths).
        .define("SPM_BUILD"),
        .headerSearchPath("vendor")
      ]
    )
  ],
  cxxLanguageStandard: .cxx17
)
