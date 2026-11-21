import Foundation

/// Finds stations by what a rider types, without Lithuanian letters: “kaisiad” finds
/// “Kaišiadorys”.
public enum StationSearch {
    /// The indices of the names that hold the query, ignoring case and diacritics: names that
    /// start with it first, then the others, each group in alphabetical order. A query of only
    /// spaces finds nothing.
    public static func matches(_ query: String, in names: [String]) -> [Int] {
        let wanted = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !wanted.isEmpty else { return [] }
        let found = names.indices.compactMap { index -> (index: Int, folded: String, prefix: Bool)? in
            let folded = fold(names[index])
            guard folded.contains(wanted) else { return nil }
            return (index, folded, folded.hasPrefix(wanted))
        }
        return found.sorted { ($0.prefix ? 0 : 1, $0.folded) < ($1.prefix ? 0 : 1, $1.folded) }.map(\.index)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
