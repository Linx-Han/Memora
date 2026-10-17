// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Memora", platforms: [.macOS(.v14)],
  products: [.executable(name: "Memora", targets: ["Memora"])],
  targets: [
    .executableTarget(
      name: "Memora",
      resources: [
        .copy("Resources/ExifTool"), .copy("Resources/AppIcon.png"),
        .copy("Resources/WritableTags.json"), .copy("Resources/Localization.json"),
      ]), .testTarget(name: "MemoraTests", dependencies: ["Memora"]),
  ], swiftLanguageModes: [.v5])
