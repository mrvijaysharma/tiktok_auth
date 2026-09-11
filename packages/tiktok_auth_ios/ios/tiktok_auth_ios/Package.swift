// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tiktok_auth_ios",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "tiktok-auth-ios", targets: ["tiktok_auth_ios"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/tiktok/tiktok-opensdk-ios", from: "2.5.0"),
    ],
    targets: [
        .target(
            name: "tiktok_auth_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "TikTokOpenAuthSDK", package: "tiktok-opensdk-ios"),
                .product(name: "TikTokOpenSDKCore", package: "tiktok-opensdk-ios"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
