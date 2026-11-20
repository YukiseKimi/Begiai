import BegiaiKit
import SwiftData
import SwiftUI
import os

struct StarButton: View {
    let name: String
    let starred: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Image(systemName: starred ? "star.fill" : "star")
                .foregroundStyle(starred ? .yellow : .secondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: starred)
        .accessibilityLabel(Text(starred ? .starRemove(line: name) : .starAdd(line: name)))
    }
}

extension ModelContext {
    /// Adds or removes a star; if the save fails, the change goes back and the error goes to the log.
    func toggleStarOrRollBack(_ kind: StarKind, name: String, at date: Date) {
        do {
            try withAnimation { try toggleStar(kind, name: name, at: date) }
        } catch {
            rollback()
            Logger(subsystem: "com.mannychau.begiai", category: "stars")
                .error("A star did not save: \(String(describing: error), privacy: .public)")
        }
    }
}
