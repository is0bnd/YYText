// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YYText",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "YYText",
            targets: ["YYText"]
        )
    ],
    targets: [
        .target(
            name: "YYText",
            path: "YYText",
            exclude: [
                ".DS_Store"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include/YYText")
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreText"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("UIKit")
            ]
        )
    ]
)
