import BegiaiKit
import BundleBuilder
import Foundation

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 3, let feedDate = Int(arguments[arguments.startIndex + 1]) else {
    FileHandle.standardError.write(Data("usage: begiai-bundle <unzipped GTFS folder> <feed date YYYYMMDD> <out timetable.json>\n".utf8))
    exit(2)
}
let feed = URL(filePath: arguments[arguments.startIndex])
let output = URL(filePath: arguments[arguments.startIndex + 2])

do {
    let (timetable, report) = try BundleBuilder().build(feed: feed, feedDate: feedDate)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(timetable)
    try data.write(to: output, options: .atomic)
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
