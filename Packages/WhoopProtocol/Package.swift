// swift-tools-version: 5.9

import PackageDescription

let package = Package(name: "WhoopProtocol",    
        targets: [
            .target(name: "WhoopProtocol"),
            .testTarget(name: "WhoopProtocolTests", dependencies: ["WhoopProtocol"])
        ])