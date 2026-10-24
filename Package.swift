// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Haven",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure domain types, no I/O.
        .target(name: "HavenCore", path: "Sources/HavenCore"),
        // Process supervision and agent adapters.
        .target(name: "HavenRuntime", dependencies: ["HavenCore"], path: "Sources/HavenRuntime"),
        // The app.
        .executableTarget(name: "Haven", dependencies: ["HavenCore", "HavenRuntime"], path: "Sources/Haven"),
        .testTarget(
            name: "HavenRuntimeTests",
            dependencies: ["HavenCore", "HavenRuntime"],
            path: "Tests/HavenRuntimeTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
