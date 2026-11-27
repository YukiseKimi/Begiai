import Foundation
import Observation

/// What the rider types in the map's search field, and the two facts the panel reads from it,
/// kept as the text changes. A keystroke then updates the field and the results, and the rest
/// of the panel only when one of the facts changes.
@MainActor
@Observable
final class StationQuery {
    var text: String {
        didSet { update() }
    }
    /// True while the field is empty: its prompt shows, and its clear button does not.
    private(set) var isEmpty = true
    /// True while the field holds more than spaces: its results take the lines' place.
    private(set) var searching = false

    init(text: String = "") {
        self.text = text
        update()
    }

    private func update() {
        isEmpty = text.isEmpty
        searching = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
