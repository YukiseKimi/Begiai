import BegiaiKit
import SwiftUI

struct LineRow: View {
    let line: LineSummary

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinePalette.color(forLine: line.id))
                .frame(width: 5, height: 28)
            Text(verbatim: line.name)
                .font(.body.weight(.medium))
            Spacer()
            Text(.lineTrainsNow(count: line.trainsNow))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(A11yID.Map.lineRow)
    }
}

#Preview {
    LineRow(line: LineSummary(id: 0, name: "Vilnius – Kaunas", international: false, trainsNow: 4, tripsToday: 42))
        .padding()
}
