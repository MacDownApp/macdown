// swift-tools-version:5.9
import PackageDescription

// ViewerCore: everything the iPad viewer needs that does not draw UI. It builds and
// is tested on macOS (`swift test`), and is linked into the iPad app.
// Some files are shared with the macOS app through symlinks in Sources/ViewerCore/Shared.
let package = Package(
    name: "ViewerCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "ViewerCore", targets: ["ViewerCore"])],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", branch: "gfm"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(name: "ViewerCore", dependencies: [
            .product(name: "cmark-gfm", package: "swift-cmark"),
            .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            "Yams",
        ]),
        .testTarget(name: "ViewerCoreTests", dependencies: ["ViewerCore"]),
    ]
)
