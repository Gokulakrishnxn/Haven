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
        // Credentials, Touch ID approval, origin checks and the audit log.
        .target(name: "HavenSecurity", dependencies: ["HavenCore", "HavenRuntime"], path: "Sources/HavenSecurity"),
        // SwiftUI components and screens. Depends only on domain types, never on processes.
        .target(name: "HavenUI", dependencies: ["HavenCore"], path: "Sources/HavenUI"),
        // The app.
        .executableTarget(name: "Haven", dependencies: ["HavenCore", "HavenRuntime", "HavenUI", "HavenSecurity"], path: "Sources/Haven", resources: [.process("Resources")]),
        // Command-line helper agents run to request a secure fill. It never receives a credential value.
        .executableTarget(name: "haven-vault", dependencies: ["HavenSecurity"], path: "Sources/HavenVault"),
        // Command-line helper agents run to see and control apps. Requests go through the app, which asks the person first.
        .executableTarget(name: "haven-mac", dependencies: ["HavenSecurity"], path: "Sources/HavenMac"),
        // Command-line helper agents run to work in the browser through the Haven extension.
        .executableTarget(name: "haven-browser", dependencies: ["HavenSecurity"], path: "Sources/HavenBrowser"),
        .testTarget(name: "HavenSecurityTests", dependencies: ["HavenCore", "HavenRuntime", "HavenSecurity"], path: "Tests/HavenSecurityTests"),
        .testTarget(
            name: "HavenRuntimeTests",
            dependencies: ["HavenCore", "HavenRuntime"],
            path: "Tests/HavenRuntimeTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
