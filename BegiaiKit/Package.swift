// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BegiaiKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "BegiaiKit", targets: ["BegiaiKit"]),
    ],
    targets: [
        .target(name: "BegiaiKit"),
        .target(
            name: "BegiaiKitTestSupport",
            dependencies: ["BegiaiKit"],
            path: "Tests/BegiaiKitTestSupport"
        ),
        .testTarget(name: "TimetableTests", dependencies: ["BegiaiKit", "BegiaiKitTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
