import Foundation

struct CSVFile {
    let columns: [String: Int]
    private let data: Data
    private let bodyStart: Int

    init(url: URL) throws {
        data = try Data(contentsOf: url, options: .mappedIfSafe)
        let newline = data.firstIndex(of: 0x0A) ?? data.endIndex
        var header = String(decoding: data[data.startIndex..<newline], as: UTF8.self)
        if header.hasPrefix("\u{FEFF}") { header.removeFirst() }
        let names = CSVFile.fields(of: header.trimmingCharacters(in: .newlines))
        columns = Dictionary(names.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        bodyStart = min(newline + 1, data.endIndex)
    }

    func rows(where keep: (Data.SubSequence) -> Bool = { _ in true }, _ body: (Row) throws -> Void) rethrows {
        var start = bodyStart
        while start < data.endIndex {
            let end = data[start...].firstIndex(of: 0x0A) ?? data.endIndex
            var line = data[start..<end]
            if line.last == 0x0D { line = line.dropLast() }
            if !line.isEmpty, keep(line) {
                try body(Row(fields: CSVFile.fields(of: String(decoding: line, as: UTF8.self)), columns: columns))
            }
            start = end + 1
        }
    }

    static func fields(of line: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var quoted = false
        var iterator = line.makeIterator()
        while let character = iterator.next() {
            switch character {
            case "\"" where quoted:
                if let next = iterator.next() {
                    if next == "\"" { field.append("\"") } else {
                        quoted = false
                        if next == "," { fields.append(field); field = "" } else { field.append(next) }
                    }
                } else {
                    quoted = false
                }
            case "\"" where field.isEmpty:
                quoted = true
            case "," where !quoted:
                fields.append(field)
                field = ""
            default:
                field.append(character)
            }
        }
        fields.append(field)
        return fields
    }

    struct Row {
        let fields: [String]
        let columns: [String: Int]

        subscript(_ name: String) -> String {
            guard let index = columns[name], index < fields.count else { return "" }
            return fields[index]
        }
    }
}

extension Data.SubSequence {
    func contains(_ bytes: [UInt8]) -> Bool {
        guard bytes.count <= count else { return false }
        return firstRange(of: bytes) != nil
    }
}
