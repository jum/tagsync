import PackageDescription

let package = Package(
    name: "tagsync",
    targets: [],
    dependencies: [
	.Package(url: "https://github.com/kylef/Commander.git",
		majorVersion: 0),
    ]
)
