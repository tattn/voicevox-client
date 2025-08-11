// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "voicevox-client",
  platforms: [
    .iOS(.v16), .macOS(.v13),
  ],
  products: [
    .library(
      name: "VOICEVOX",
      targets: ["VOICEVOX"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0")
  ],
  targets: [
    .target(
      name: "VOICEVOX",
      dependencies: ["voicevox_common"]
    ),
    .testTarget(
      name: "VOICEVOXTests",
      dependencies: ["VOICEVOX"],
      resources: [.copy("lib")],
      linkerSettings: [
        .unsafeFlags(
          [
            "-L", "Tests/VOICEVOXTests/lib",
            "-lvoicevox_core",
            "-lvoicevox_onnxruntime.1.17.3",
            "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../Resources/voicevox-client_VOICEVOXTests.bundle/Contents/Resources/lib",
          ],
          .when(platforms: [.macOS])
        )
      ]
    ),

    .target(
      name: "voicevox_common",
      dependencies: [
        .target(name: "onnxruntime", condition: .when(platforms: [.iOS])),
        .target(name: "voicevox_core_ios", condition: .when(platforms: [.iOS])),
        .target(name: "voicevox_core_macos", condition: .when(platforms: [.macOS])),
      ]
    ),
    .target(
      name: "voicevox_core_macos"
    ),
    .binaryTarget(
      name: "onnxruntime",
      url:
        "https://github.com/tattn/voicevox-client-onnxruntime/releases/download/v1.17.3/voicevox_onnxruntime-ios-xcframework-1.17.3-modified.zip",
      checksum: "d69d4bea8aed28414ec5d590351245ff02f7d50415255b2872ceb1c925d2debf"
    ),
    .binaryTarget(
      name: "voicevox_core_ios",
      url: "https://github.com/VOICEVOX/voicevox_core/releases/download/0.16.0/voicevox_core-ios-xcframework-cpu-0.16.0.zip",
      checksum: "2cc4d209d594f7815b87348c2157635fa9288d2e2cd8c342887ee68442ba2ee1"
    ),
  ]
)
