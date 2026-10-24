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
        // SwiftUI components and screens. Depends only on domain types, never on processes.
        .target(name: "HavenUI", dependencies: ["HavenCore"], path: "Sources/HavenUI"),
        // The app.
        .executableTarget(name: "Haven", dependencies: ["HavenCore", "HavenRuntime", "HavenUI"], path: "Sources/Haven", resources: [.process("Resources")]),
        .testTarget(
            name: "HavenRuntimeTests",
            dependencies: ["HavenCore", "HavenRuntime"],
            path: "Tests/HavenRuntimeTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
