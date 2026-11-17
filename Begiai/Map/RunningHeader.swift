import SwiftUI

struct RunningHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(.mapRunningNow(count: count))
                .accessibilityIdentifier(A11yID.Map.runningCount)
                .accessibilityValue(Text(verbatim: String(count)))
            Text(verbatim: "·")
            Text(.mapScheduled)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect()
    }
}

#Preview {
    RunningHeader(count: 27)
}
