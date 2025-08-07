// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "voicevox-client",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    .library(
      name: "VOICEVOX",
      targets: ["VOICEVOX"]
    )
  ],
  targets: [
    .target(
      name: "VOICEVOX",
      dependencies: [
        "onnxruntime",
        "voicevox_core",
      ]
    ),
    .testTarget(
      name: "VOICEVOXTests",
      dependencies: ["VOICEVOX"],
      resources: [.copy("lib")]
    ),

    .binaryTarget(
      name: "onnxruntime",
      url:
        "https://github.com/VOICEVOX/onnxruntime-builder/releases/download/voicevox_onnxruntime-1.17.3/voicevox_onnxruntime-ios-xcframework-1.17.3.zip",
      checksum: "5b0138f25e68c3fb99771d37978837d5038a67b0720f96d912c900887164494b"
    ),
    .binaryTarget(
      name: "voicevox_core",
      url: "https://github.com/VOICEVOX/voicevox_core/releases/download/0.16.0/voicevox_core-ios-xcframework-cpu-0.16.0.zip",
      checksum: "2cc4d209d594f7815b87348c2157635fa9288d2e2cd8c342887ee68442ba2ee1"
    ),
  ]
)
