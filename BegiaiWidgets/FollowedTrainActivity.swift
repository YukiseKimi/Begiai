import ActivityKit
import BegiaiKit
import SwiftUI
import WidgetKit

/// The Live Activity of the train the rider follows: on the Lock Screen and in the Dynamic
/// Island. Its times come from the timetable when Follow starts it; the bar and the countdown
/// run by themselves, and the app updates the next stop while it runs.
struct FollowedTrainActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FollowedTrain.self) { context in
            LockScreenView(facts: TrainFacts(context))
                .activitySystemActionForegroundColor(.secondary)
        } dynamicIsland: { context in
            let facts = TrainFacts(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedNext(facts: facts)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedEnd(facts: facts)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        JourneyBar(train: facts.train, passed: facts.passed, standing: facts.standing, colour: facts.colour)
                        HStack {
                            ScheduledLabel()
                            Spacer()
                            Text(verbatim: facts.train.line)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                CompactNext(facts: facts)
            } compactTrailing: {
                CompactEnd(facts: facts)
            } minimal: {
                MinimalJourney(facts: facts)
            }
            .keylineTint(facts.colour)
        }
    }
}

/// What every presentation reads: where the train was at the last update, or arrived once
/// the activity is stale, as its stale date is the last arrival.
struct TrainFacts {
    let train: FollowedTrain
    let place: FollowedTrain.Place

    init(train: FollowedTrain, status: FollowedTrain.Status, isStale: Bool) {
        self.train = train
        place = isStale ? .arrived : status.place
    }

    init(_ context: ActivityViewContext<FollowedTrain>) {
        self.init(train: context.attributes, status: context.state, isStale: context.isStale)
    }

    var passed: Int { train.passed(place) }

    var standing: Int? {
        switch place {
        case .boarding: 0
        case .at(let stop): stop
        case .leaving, .arrived: nil
        }
    }

    var next: (stop: FollowedTrain.Stop, time: Date, standing: Bool)? {
        train.next(place).map { (train.stops[$0.stop], $0.time, $0.standing) }
    }

    var colour: Color { Color(lineSlot: train.colour) }

    var title: LocalizedStringResource { .activityTitle(origin: train.origin, destination: train.destination) }

    /// From now to the last arrival, on the device clock, for the countdowns.
    var toArrival: Range<Date> {
        let end = train.deviceDate(train.arrival)
        return min(Date.now, end)..<end
    }
}

private struct LockScreenView: View {
    let facts: TrainFacts

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(facts.title)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(A11yID.LiveActivity.title)
                Spacer(minLength: 8)
                ScheduledLabel()
            }
            JourneyBar(train: facts.train, passed: facts.passed, standing: facts.standing, colour: facts.colour)
            HStack(alignment: .firstTextBaseline) {
                NextLine(facts: facts)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                Text(verbatim: "\(facts.train.destination) \(facts.train.arrival.vilniusTime)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .accessibilityIdentifier(A11yID.LiveActivity.end)
            }
        }
        .padding(14)
    }
}

/// “Next: Kaišiadorys 08:48”, “At Kaišiadorys, leaves 08:50”, or “Arrived”.
private struct NextLine: View {
    let facts: TrainFacts

    var body: some View {
        Group {
            if let next = facts.next {
                if next.standing {
                    Text(.activityAt(station: next.stop.name, time: next.time.vilniusTime))
                } else {
                    Text(.activityNext(station: next.stop.name, time: next.time.vilniusTime))
                }
            } else {
                Text(.activityArrived)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityIdentifier(A11yID.LiveActivity.next)
    }
}

/// Says that the train is drawn from the timetable, as the app's train page does.
private struct ScheduledLabel: View {
    var body: some View {
        Label {
            Text(.activityScheduled)
        } icon: {
            Image(systemName: "calendar.badge.clock")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

/// “▶ 08:48”: the time the train is due at its next stop, or leaves the one it stands at.
private struct CompactNext: View {
    let facts: TrainFacts

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: facts.next == nil ? "checkmark" : "play.fill")
                .font(.caption2)
            if let next = facts.next {
                Text(verbatim: next.time.vilniusTime)
                    .monospacedDigit()
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(facts.colour)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nextLabel)
        .accessibilityIdentifier(A11yID.LiveActivity.compactNext)
    }

    private var nextLabel: Text {
        guard let next = facts.next else { return Text(.activityArrived) }
        return next.standing
            ? Text(.activityAt(station: next.stop.name, time: next.time.vilniusTime))
            : Text(.activityNext(station: next.stop.name, time: next.time.vilniusTime))
    }
}

/// “Kaunas 34 minutes”: the last stop and the time left to it, which counts down by itself.
/// Where the island is narrow, only the time left.
private struct CompactEnd: View {
    let facts: TrainFacts

    var body: some View {
        if #available(iOS 27.0, *) {
            NarrowIsland { narrow in content(narrow: narrow) }
        } else {
            content(narrow: false)
        }
    }

    private func content(narrow: Bool) -> some View {
        HStack(spacing: 4) {
            if !narrow {
                Text(verbatim: facts.train.destination)
                    .lineLimit(1)
            }
            Countdown(facts: facts)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(facts.colour)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(A11yID.LiveActivity.compactEnd)
    }
}

/// Reads whether the Dynamic Island is narrow, as on iPhone in landscape.
@available(iOS 27.0, *)
private struct NarrowIsland<Content: View>: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var narrow
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        content(narrow)
    }
}

/// The minutes to the last arrival, counting down by itself. A timer text takes all the
/// width it is offered, so it sits over a still copy of its widest value, the one at the
/// start, which sets its width.
private struct Countdown: View {
    let facts: TrainFacts

    var body: some View {
        let style = SystemFormatStyle.Timer(countingDownIn: facts.toArrival, showsHours: false, maxPrecision: .seconds(60))
        Text(facts.toArrival.lowerBound, format: style)
            .hidden()
            .overlay(alignment: .trailing) {
                Text(.currentDate, format: style)
                    .multilineTextAlignment(.trailing)
            }
            .monospacedDigit()
    }
}

private struct ExpandedNext: View {
    let facts: TrainFacts

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = facts.next {
                Text(next.standing ? .activityLeaves : .activityNextCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: next.stop.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: next.time.vilniusTime)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(facts.colour)
            } else {
                Text(.activityArrived)
                    .font(.headline)
            }
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ExpandedEnd: View {
    let facts: TrainFacts

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(.activityArrives)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: facts.train.destination)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(verbatim: facts.train.arrival.vilniusTime)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(facts.colour)
        }
        .padding(.trailing, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A ring that fills over the whole journey, around a train: the minimal presentation,
/// beside another app's activity.
private struct MinimalJourney: View {
    let facts: TrainFacts

    var body: some View {
        ProgressView(
            timerInterval: facts.train.deviceDate(facts.train.departure)...facts.train.deviceDate(facts.train.arrival),
            countsDown: false
        ) {
            EmptyView()
        } currentValueLabel: {
            Image(systemName: "tram.fill")
                .font(.caption2)
        }
        .progressViewStyle(.circular)
        .tint(facts.colour)
        .foregroundStyle(facts.colour)
        .accessibilityLabel(Text(facts.title))
    }
}
