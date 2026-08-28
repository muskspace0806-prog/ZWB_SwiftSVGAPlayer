// swift-tools-version: 5.7
// Package.swift — SwiftSVGAPlayer SPM support
//
// SPM target 指向 Sources/SwiftSVGAPlayer/（与 CocoaPods 同一份权威源码）
// 只维护这一份代码，避免 SPM 与 Pod 源码不同步

import PackageDescription

let package = Package(
    name: "SwiftSVGAPlayer",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftSVGAPlayer",
            targets: ["SwiftSVGAPlayer"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
        .package(url: "https://github.com/yeatse/KingfisherWebP.git", from: "1.7.3")
    ],
    targets: [
        .target(
            name: "SwiftSVGAPlayer",
            dependencies: [
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "KingfisherWebP", package: "KingfisherWebP")
            ],
            path: "Sources/SwiftSVGAPlayer",
            exclude: [
                "Protobuf/README.md"   // 排除文档，避免被当作源码/资源
            ],
            resources: [
                .copy("PrivacyInfo.xcprivacy")   // 隐私清单随包打入
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),
        .testTarget(
            name: "SwiftSVGAPlayerTests",
            dependencies: ["SwiftSVGAPlayer"],
            path: "Tests/SwiftSVGAPlayerTests"
        )
    ]
)
