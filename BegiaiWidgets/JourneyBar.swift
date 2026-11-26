import BegiaiKit
import SwiftUI

/// The journey from the first stop to the last: a dot for each stop, filled once the train
/// has left it, and between each two dots a bar that fills by itself from the departure to
/// the next arrival, so it moves on with no update from the app.
struct JourneyBar: View {
    /// Each run between two stops, on the device clock.
    let runs: [ClosedRange<Date>]
    let passed: Int
    /// The stop the train stands at, which gets a ring around its dot.
    let standing: Int?
    let colour: Color

    private static let height = 12.0

    var body: some View {
        // A Live Activity is laid out by the system, so the bar measures itself here.
        GeometryReader { proxy in
            let marks = JourneyMarks(
                runs: runs, passed: passed, standing: standing, width: proxy.size.width, height: Self.height)
            ZStack(alignment: .leading) {
                ForEach(marks.runs) { RunBar(interval: $0.interval, x: $0.x, width: $0.width) }
                ForEach(marks.stops) { StopDot(x: $0.x, size: $0.size, filled: $0.filled, ringed: $0.ringed) }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: Self.height)
        .tint(colour)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.activityStopsPassed(passed: passed, total: runs.count + 1)))
        .accessibilityIdentifier(A11yID.LiveActivity.bar)
    }
}

/// Where each stop's dot and each run's bar sit on a bar `width` wide. A stop's place in the
/// train's list is its identity: the stops of a followed train never change.
struct JourneyMarks {
    struct Run: Identifiable {
        let id: Int
        let interval: ClosedRange<Date>
        let x: Double
        let width: Double
    }

    struct Stop: Identifiable {
        let id: Int
        let x: Double
        let size: Double
        let filled: Bool
        let ringed: Bool
    }

    let runs: [Run]
    let stops: [Stop]

    init(runs intervals: [ClosedRange<Date>], passed: Int, standing: Int?, width: Double, height: Double) {
        let count = intervals.count + 1
        let dot = min(height - 2, width / Double(count * 3))
        let gap = max(1, dot / 4)
        let span = width - dot
        let fractions = FollowedTrain.stopFractions(of: intervals, minimumShare: (dot + 2 * gap + 2) / max(span, 1))
        runs = intervals.indices.map { k in
            Run(
                id: k, interval: intervals[k], x: fractions[k] * span + dot + gap,
                width: max(0, (fractions[k + 1] - fractions[k]) * span - dot - 2 * gap))
        }
        stops = (0..<count).map { k in
            Stop(id: k, x: fractions[k] * span, size: dot, filled: k < passed || k == standing, ringed: k == standing)
        }
    }
}

/// The bar between two stops, which fills by itself over the run.
private struct RunBar: View {
    let interval: ClosedRange<Date>
    let x: Double
    let width: Double

    var body: some View {
        ProgressView(timerInterval: interval, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .labelsHidden()
        .frame(width: width)
        .offset(x: x)
    }
}

/// A stop's dot in the bar's tint: filled once the train has left the stop, with a ring
/// while it stands there.
private struct StopDot: View {
    let x: Double
    let size: Double
    let filled: Bool
    let ringed: Bool

    var body: some View {
        Circle()
            .strokeBorder(.tint, lineWidth: 2)
            .background(filled ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), in: .circle)
            .padding(ringed ? -2 : 0)
            .frame(width: size, height: size)
            .offset(x: x)
    }
}
