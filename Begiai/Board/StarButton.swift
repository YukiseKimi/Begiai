import BegiaiKit
import SwiftData
import SwiftUI
import os

/// Stars a line or a station, or takes its star away. It saves the change itself, so the rows
/// that show it pass only what they show, and no action.
struct StarButton: View {
    let kind: StarKind
    let name: String
    let starred: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.timeSource) private var time

    var body: some View {
        Button {
            modelContext.toggleStarOrRollBack(kind, name: name, at: time.now)
        } label: {
            Image(systemName: starred ? "star.fill" : "star")
                .foregroundStyle(starred ? .yellow : .secondary)
                // At least 44 points, and as large as the symbol at large text sizes; the whole
                // frame takes the tap, not only the symbol.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: starred)
        .accessibilityLabel(Text(starred ? .starRemove(name: name) : .starAdd(name: name)))
    }
}

extension ModelContext {
    /// Adds or removes a star; if the save fails, the change goes back and the error goes to the log.
    func toggleStarOrRollBack(_ kind: StarKind, name: String, at date: Date) {
        do {
            try withAnimation { try toggleStar(kind, name: name, at: date) }
        } catch {
            rollback()
            Logger.begiai("stars")
                .error("A star did not save: \(String(describing: error), privacy: .public)")
        }
    }
}

extension Sequence where Element == Star {
    /// The names starred as this kind; a star is saved by name, so it outlives a new timetable.
    func names(_ kind: StarKind) -> Set<String> {
        Set(filter { $0.kind == kind.rawValue }.map(\.name))
    }
}
