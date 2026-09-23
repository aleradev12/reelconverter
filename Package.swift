// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReelConverter",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ReelConverter", targets: ["ReelConverter"])] ,
    targets: [.executableTarget(name: "ReelConverter", path: "Sources/ReelConverter")]
)
