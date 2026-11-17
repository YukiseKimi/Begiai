// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BegiaiKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "BegiaiKit", targets: ["BegiaiKit"]),
        .executable(name: "begiai-bundle", targets: ["BundleTool"]),
    ],
    targets: [
        .target(name: "BegiaiKit"),
        .target(name: "BundleBuilder", dependencies: ["BegiaiKit"]),
        .executableTarget(name: "BundleTool", dependencies: ["BegiaiKit", "BundleBuilder"]),
        .target(
            name: "BegiaiKitTestSupport",
            dependencies: ["BegiaiKit"],
            path: "Tests/BegiaiKitTestSupport"
        ),
        .testTarget(name: "TimetableTests", dependencies: ["BegiaiKit", "BegiaiKitTestSupport"]),
        .testTarget(name: "BundleTests", dependencies: ["BundleBuilder", "BegiaiKitTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
