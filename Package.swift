// swift-tools-version: 5.9
// OED2 Reader: no dictionary data included; the user's DB lives in ~/Library/Application Support/OED.
import PackageDescription

let package = Package(
    name: "OED",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "OED", targets: ["OED"])],
    targets: [
        .executableTarget(
            name: "OED",
            path: "Sources/OED",
            linkerSettings: [.linkedFramework("SwiftUI"), .linkedFramework("AppKit"), .linkedFramework("WebKit"), .linkedLibrary("sqlite3")]
        )
    ]
)
