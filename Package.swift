// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "StravoCloud",
    platforms: [
       .macOS(.v12)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
        .package(url: "https://github.com/brokenhandsio/fluent-postgis.git", from: "0.3.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/redis", from: "4.2.0"),
        
        .package(url: "https://github.com/raphaelmor/Polyline.git", from: "5.0.2"),
        .package(url: "https://github.com/kiliankoe/GeoJSON.git", from: "0.6.1"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentPostGIS", package: "fluent-postgis"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Redis", package: "redis"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Polyline", package: "Polyline"),
                .product(name: "GeoJSON", package: "GeoJSON"),
                
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
