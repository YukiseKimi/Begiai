import BegiaiKit
import BundleBuilder
import Foundation

let usage = "usage: begiai-bundle <unzipped GTFS folder> <feed date YYYYMMDD> <out timetable.json> [--manifest <out manifest.json>]\n"
var arguments = Array(CommandLine.arguments.dropFirst())
var manifestURL: URL?
if let flag = arguments.firstIndex(of: "--manifest") {
    guard flag + 1 < arguments.count else {
        FileHandle.standardError.write(Data(usage.utf8))
        exit(2)
    }
    manifestURL = URL(filePath: arguments[flag + 1])
    arguments.removeSubrange(flag...(flag + 1))
}
guard arguments.count == 3, let feedDate = Int(arguments[1]) else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(2)
}
let feed = URL(filePath: arguments[0])
let output = URL(filePath: arguments[2])

do {
    let (timetable, report) = try BundleBuilder().build(feed: feed, feedDate: feedDate)
    try timetable.check()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(timetable)
    try data.write(to: output, options: .atomic)
    if let manifestURL {
        try encoder.encode(Manifest(bundle: data, feedDate: feedDate)).write(to: manifestURL, options: .atomic)
    }
    print("BUNDLE \(output.lastPathComponent) · \(data.count / 1024) KB · \(timetable.stations.count) stations · " +
          "\(timetable.lines.count) lines · \(timetable.trips.count) trips · \(timetable.shapes.count) shapes")
    print("check worst station off its track \(Int(report.worstOffTrack.rounded())) m")
    for section in report.fastSections {
        print("flag over 160 km/h: \(section)")
    }
} catch {
    FileHandle.standardError.write(Data("BUNDLE FAILED \(error)\n".utf8))
    exit(1)
}
