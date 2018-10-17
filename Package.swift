// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "tagsync",
    dependencies: [
	.package(url: "https://github.com/kylef/Commander.git", from: "0.0.0"),
    ],
    targets: [
    	.target(
		name: "tagsync",
		dependencies: ["Commander"],
		path: "."
	)
    ]
)

