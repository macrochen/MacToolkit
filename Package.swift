// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MacToolkit",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacToolkit",
            path: "Sources",
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Modules/StandUpTimer/Resources/Videos/neko1.png"),
                .process("Modules/StandUpTimer/Resources/Videos/neko2.png"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Resources/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "MacToolkitTests",
            dependencies: ["MacToolkit"],
            path: "Tests/MacToolkitTests"
        )
    ]
)
