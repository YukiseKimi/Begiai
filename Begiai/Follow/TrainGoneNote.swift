import SwiftUI

/// Over the map, after a tap on the Live Activity of a train that has finished its trip: the
/// map opens with this note, not a page with no train. It goes after a few seconds or a tap.
struct TrainGoneNote: View {
    /// True while the note shows: a tap, or a few seconds, clears it.
    @Binding var shown: Bool

    var body: some View {
        Button {
            shown = false
        } label: {
            Label {
                Text(.trainGone)
            } icon: {
                Image(systemName: "flag.checkered")
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, 8)
        .padding(.horizontal)
        .accessibilityIdentifier(A11yID.Map.trainGone)
        .task {
            try? await Task.sleep(for: .seconds(6))
            shown = false
        }
    }
}

#Preview {
    Color.gray.opacity(0.2)
        .overlay(alignment: .top) {
            TrainGoneNote(shown: .constant(true))
        }
}
