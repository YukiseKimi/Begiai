import BegiaiKit
import SwiftUI

struct LineRow: View {
    let line: LineSummary
    let starred: Bool
    let toggleStar: () -> Void
    @Environment(\.linePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.color(forLine: line.id))
                .frame(width: 5, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: line.name)
                    .font(.body.weight(.medium))
                Text(.lineTrainsNow(count: line.trainsNow))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(A11yID.Map.lineName)
            Spacer()
            StarButton(name: line.name, starred: starred, toggle: toggleStar)
                .accessibilityIdentifier(A11yID.Map.lineStar)
        }
    }
}

#Preview {
    LineRow(line: LineSummary(id: 0, name: "Vilnius – Kaunas", international: false, trainsNow: 4, tripsToday: 42), starred: true) {}
        .padding()
}
