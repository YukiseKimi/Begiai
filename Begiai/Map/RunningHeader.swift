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
            // Each line keeps the height it needs to wrap.
            VStack(spacing: 2) {
                running
                    .fixedSize(horizontal: false, vertical: true)
                scheduled
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
        }
        .font(.subheadline.weight(.semibold))
    }
}

#Preview {
    RunningHeader(count: 27)
}
