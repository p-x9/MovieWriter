// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MovieWriter",
    products: [
        .library(
            name: "MovieWriter",
            targets: ["MovieWriter"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MovieWriter",
            dependencies: []
        ),
        .testTarget(
            name: "MovieWriterTests",
            dependencies: ["MovieWriter"]
        ),
    ]
)
