import SwiftUI

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
        .accessibilityLabel(Text(starred ? .starRemove(line: name) : .starAdd(line: name)))
    }
}
