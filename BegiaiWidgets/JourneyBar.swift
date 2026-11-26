import BegiaiKit
import SwiftUI

/// The journey from the first stop to the last: a dot for each stop, filled once the train
/// has left it, and between each two dots a bar that fills by itself from the departure to
/// the next arrival, so it moves on with no update from the app.
struct JourneyBar: View {
    let train: FollowedTrain
    let passed: Int
    /// The stop the train stands at, which gets a ring around its dot.
    let standing: Int?
    let colour: Color

    private static let height = 12.0

    var body: some View {
        GeometryReader { proxy in
            let dot = min(Self.height - 2, proxy.size.width / Double(train.stops.count * 3))
            let gap = max(1, dot / 4)
            let span = proxy.size.width - dot
            let fractions = train.stopFractions(minimumShare: Double(dot + 2 * gap + 2) / max(span, 1))
            let runs = train.runs
            ZStack(alignment: .leading) {
                ForEach(runs.indices, id: \.self) { k in
                    let from = fractions[k] * span + dot + gap
                    let width = max(0, (fractions[k + 1] - fractions[k]) * span - dot - 2 * gap)
                    ProgressView(
                        timerInterval: train.deviceDate(runs[k].lowerBound)...train.deviceDate(runs[k].upperBound),
                        countsDown: false
                    ) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.linear)
                    .labelsHidden()
                    .tint(colour)
                    .frame(width: width)
                    .offset(x: from)
                }
                ForEach(train.stops.indices, id: \.self) { k in
                    StopDot(colour: colour, passed: k < passed, standing: k == standing)
                        .frame(width: dot, height: dot)
                        .offset(x: fractions[k] * span)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.activityStopsPassed(passed: passed, total: train.stops.count)))
        .accessibilityIdentifier(A11yID.LiveActivity.bar)
    }
}

private struct StopDot: View {
    let colour: Color
    let passed: Bool
    let standing: Bool

    var body: some View {
        Circle()
            .strokeBorder(colour, lineWidth: 2)
            .background(Circle().fill(passed || standing ? colour : .clear))
            .padding(standing ? -2 : 0)
    }
}
