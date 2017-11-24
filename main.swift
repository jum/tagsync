//
//  main.swift
//  tagsync
//
//  Created by Jens-Uwe Mager on 21.11.17.
//  Copyright © 2017 Best Search Infobrokerage, Inc. All rights reserved.
//

import Commander
import AppKit

enum SyncSource: String, ArgumentConvertible {
	case finder
	case iptc
	case both

	public init(parser: ArgumentParser) throws {
    if let value = parser.shift() {
		if let value = SyncSource(rawValue: value) {
			self.init(rawValue: value.rawValue)!
		} else {
			throw ArgumentError.invalidType(value: value, type:"SyncSource", argument: nil)
		}
    } else {
		throw ArgumentError.missingValue(argument: nil)
    }
  }
  public var description: String {
	  return self.rawValue
  }
}

let finderTagAttribute = "com.apple.metadata:_kMDItemUserTags"
let extendedAttributesKey = FileAttributeKey(rawValue: "NSFileExtendedAttributes")

func getIPTCTags(_ url: URL) -> Set<String> {
	var tags = Set<String>()
	if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
		if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
			if let iptc = props["{IPTC}"] as? [String: Any] {
				if let kw = iptc["Keywords"] as? [String] {
					tags.formUnion(kw)
				}
			}
		}
	}
	return tags
}

func doFile(_ fileName: String, source: SyncSource, attr: NSDictionary, verbose: Bool, dryrun: Bool) throws {
	let url = URL(fileURLWithPath: fileName)
	var finderTags = Set<String>()
	// The attributes already contain the tag attributes, no need to retrieve them again
	//	if let tagArray = try url.resourceValues(forKeys:[.tagNamesKey]).tagNames {
	//	...
	//}
	if let xattrs = attr[extendedAttributesKey] as? [String: Data] {
		if let tagList = xattrs[finderTagAttribute] {
			if let tagArray = try PropertyListSerialization.propertyList(from: tagList, format: nil) as? [String] {
				finderTags.formUnion(tagArray)
			}
		}
	}
	var iptcTags = getIPTCTags(url)
	var finderModified = false
	var iptcModified = false
	if (verbose) {
		print("finder", finderTags, "iptc", iptcTags)
	}
	switch source  {
		case .finder:
			if iptcTags != finderTags {
				iptcTags = finderTags
				iptcModified = true
			}
			break
		case .iptc:
			if iptcTags != finderTags {
				finderTags = iptcTags
				finderModified = true
			}
			break
		case .both:
			let newTags = finderTags.union(iptcTags)
			if finderTags != newTags {
				finderTags = newTags
				finderModified = true
			}
			if iptcTags != newTags {
				iptcTags = newTags
				iptcModified = true
			}
			break
	}
	if finderModified {
		if verbose || dryrun {
			print("new finder", finderTags)
		}
		if !dryrun {
			let tagData = try PropertyListSerialization.data(fromPropertyList: Array(finderTags), format: .binary, options: 0)
			try url.setExtendedAttribute(data: tagData, forName: finderTagAttribute)
		}
	}
	if iptcModified {
		if verbose || dryrun {
			print("new iptc", iptcTags)
		}
	}
}

command(
	Option("source", default: SyncSource.both, description: "Sync attributes source \([SyncSource.finder.rawValue, SyncSource.iptc.rawValue, SyncSource.both.rawValue])"),
	Flag("verbose", default: false, description: "show what is being done"),
	Flag("dryrun", default: false, description: "do not perform any modification of files"),
	VariadicArgument<String>("files", description: "Input files and directories")
) { (source, verbose, dryrun, files) throws  in
	let fm = FileManager.default
	var processItem: (String) throws -> Void = { (fileName: String) throws in
	}
	processItem = { (fileName: String) in
			let attr = try fm.attributesOfItem(atPath: fileName) as NSDictionary
			switch attr.fileType() ?? "unknown" {
				case FileAttributeType.typeDirectory.rawValue:
					for item in try fm.contentsOfDirectory(atPath: fileName) {
						if item == ".DS_Store" {
							continue
						}
						try processItem(fileName + "/" + item)
					}
				case FileAttributeType.typeRegular.rawValue:
					if verbose || dryrun {
						print("File \(fileName):")
					}
					try doFile(fileName, source: source, attr: attr, verbose: verbose, dryrun: dryrun)
				case let ftype:
					throw ArgumentParserError("Unable to process file \(fileName): type \(ftype)")
			}
	}
	for fileName in files {
		try processItem(fileName)
	}
}.run()
