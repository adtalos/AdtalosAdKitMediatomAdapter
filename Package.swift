// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AdtalosAdKitMediatomAdapter",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "AdtalosAdKitMediatomAdapter",
            targets: ["AdtalosAdKitMediatomAdapter"]
        )
    ],
    dependencies: [
	
    ],
    targets: [
        .binaryTarget(
            name: "AdtalosAdKitMediatomAdapter",
	    path: "AdtalosAdKitMediatomAdapter.xcframework"
        )
    ]
)


