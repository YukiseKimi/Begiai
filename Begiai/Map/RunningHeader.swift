import SwiftUI

struct RunningHeader: View {
    let count: Int

    var body: some View {
        let running = Text(.mapRunningNow(count: count))
            .accessibilityIdentifier(A11yID.Map.runningCount)
            .accessibilityValue(Text(verbatim: String(count)))
        let scheduled = Text(.mapScheduled)
            .foregroundStyle(.secondary)
        // One line when it fits; at large text sizes “Scheduled” goes under the count, not over it.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                running
                Text(verbatim: "·")
                    .accessibilityHidden(true)
                scheduled
            }
            VStack(spacing: 2) {
                running
                scheduled
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline.weight(.semibold))
    }
}

#Preview {
    RunningHeader(count: 27)
}
