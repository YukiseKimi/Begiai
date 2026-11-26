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
                .widgetURL(context.attributes.link?.url)
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
                        HStack(spacing: 8) {
                            ScheduledLabel()
                            Spacer(minLength: 0)
                            Text(verbatim: facts.train.line)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    // Clear of the island's rounded ends, so a long line name ends in “…”.
                    .padding(.horizontal, 8)
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
            .widgetURL(context.attributes.link?.url)
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
}

private struct LockScreenView: View {
    let facts: TrainFacts

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(facts.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
                // The last stop's name gives way before its time, and before the next stop.
                HStack(spacing: 4) {
                    Text(verbatim: facts.train.destination)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(verbatim: facts.train.arrival.vilniusTime)
                        .monospacedDigit()
                        .fixedSize()
                }
                .font(.subheadline.weight(.semibold))
                .layoutPriority(1)
                .accessibilityElement(children: .combine)
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
        // It keeps its room: a long title or line name gives way instead.
        .fixedSize()
        .layoutPriority(2)
        .accessibilityElement(children: .combine)
    }
}

/// “▶ 08:48”: the time the train is due at its next stop, or leaves the one it stands at.
/// Where the island is narrow, as on the open iPhone Duo or an iPhone in landscape, the
/// journey ring alone: the HIG asks for a graphic that fits a 28-point circle there, and no
/// time does.
private struct CompactNext: View {
    let facts: TrainFacts

    var body: some View {
        if #available(iOS 27.0, *) {
            NarrowIsland { narrow in
                if narrow {
                    MinimalJourney(facts: facts)
                        .frame(maxWidth: 26, maxHeight: 26)
                } else {
                    wide
                }
            }
        } else {
            wide
        }
    }

    private var wide: some View {
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

/// “Kaunas 34m” or “Kaunas 1h 5m”: the last stop and the minutes left to it, which count
/// down by themselves. Where both do not fit, as in Lithuanian on a 6.3-inch iPhone, the
/// minutes alone; the expanded island and the Lock Screen name the stop. Once the train is
/// in, its arrival time. Where the island is narrow, nothing, so the system hides this side,
/// as the HIG says.
private struct CompactEnd: View {
    let facts: TrainFacts

    var body: some View {
        if #available(iOS 27.0, *) {
            NarrowIsland { narrow in content(narrow: narrow) }
        } else {
            content(narrow: false)
        }
    }

    @ViewBuilder
    private func content(narrow: Bool) -> some View {
        if !narrow {
            let destination = Text(verbatim: facts.train.destination)
            Group {
                if facts.next == nil {
                    HStack(spacing: 4) {
                        destination
                        Text(verbatim: facts.train.arrival.vilniusTime)
                    }
                } else {
                    // The name and the minutes where both fit, else the minutes alone.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            destination
                            Countdown(train: facts.train)
                        }
                        Countdown(train: facts.train)
                    }
                }
            }
            .lineLimit(1)
            .monospacedDigit()
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(facts.colour)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier(A11yID.LiveActivity.compactEnd)
            // The system draws a live text in English unless the view sets a locale outright,
            // whatever the format's own locale.
            .environment(\.locale, Countdown.locale)
        }
    }

    /// The stop, and the time left in words, “Kaunas, 34 minutes”, as “m” reads as metres.
    private var accessibilityLabel: Text {
        let destination = Text(verbatim: "\(facts.train.destination), ")
        guard facts.next != nil else { return destination + Text(verbatim: facts.train.arrival.vilniusTime) }
        return destination + Text(.dateRange(endingAt: facts.train.countdownEnd), format: Countdown.style(.wide))
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

/// The minutes left to the last arrival, “34m” or “1h 5m”, counting down by themselves once
/// a minute. A live text takes all the width it is offered, which would stretch the island
/// across the screen, so it sits over a still text of its widest reading, which sets its width.
private struct Countdown: View {
    let train: FollowedTrain

    var body: some View {
        let now = Date.now
        Text(verbatim: (now..<now.addingTimeInterval(train.countdownWidest(at: now))).formatted(Self.style(.narrow)))
            .hidden()
            .overlay(alignment: .trailing) {
                Text(.dateRange(endingAt: train.countdownEnd), format: Self.style(.narrow))
            }
    }

    /// The extension's language and region as a fixed locale. The system draws a live text
    /// with its own current locale, which is English, so `Locale.current` itself does not do.
    static var locale: Locale { Locale(identifier: Locale.current.identifier) }

    static func style(_ style: Date.ComponentsFormatStyle.Style) -> Date.ComponentsFormatStyle {
        Date.ComponentsFormatStyle(style: style, locale: locale, fields: [.hour, .minute])
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
