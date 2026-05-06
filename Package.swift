// swift-tools-version: 5.7
// Package.swift — SwiftSVGAPlayer SPM support
//
// SPM target 指向 ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer/
// 与 Xcode App target 共用同一份源码，只维护一份代码

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
    dependencies: [],
    targets: [
        .target(
            name: "SwiftSVGAPlayer",
            path: "ZWB_SwiftSVGAPlayer/SwiftSVGAPlayer",
            exclude: [
                "Resource"   // 排除测试素材目录
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
