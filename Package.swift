// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LaTeXMathSwift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "LaTeXMathSwift", targets: ["LaTeXMathSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/PsychQuant/ooxml-swift.git", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "LaTeXMathSwift",
            dependencies: [
                .product(name: "OOXMLSwift", package: "ooxml-swift")
            ]
        ),
        .testTarget(
            name: "LaTeXMathSwiftTests",
            dependencies: ["LaTeXMathSwift"]
        )
    ]
)
