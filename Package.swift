// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CuevoraLogic",
    products: [
        .library(name: "CuevoraLogic", targets: ["CuevoraLogic"])
    ],
    targets: [
        .target(name: "CuevoraLogic", path: "Cuevora/Logic"),
        .testTarget(
            name: "CuevoraLogicTests",
            dependencies: ["CuevoraLogic"],
            path: "CuevoraTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
