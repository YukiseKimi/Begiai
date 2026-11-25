import BegiaiKit
import SwiftUI

/// How a page in the panel or a sheet goes away: back to the line list, or the sheet closes.
enum PageExit {
    case back
    case close
}

/// The fixed top of a train's page: where the train goes and where it is now. The facts
/// that stay the same (estimated, notices) scroll with the stops, in `StopList`.
struct TrainPage: View {
    let timeline: TrainTimeline?
    let color: Color
    let now: Date
    /// Nil where nothing can follow the train: the page then shows no Follow button.
    var following: Binding<Bool>?
    var exit = PageExit.back
    /// Opens a station's board: the place line then becomes a link, so the station of a train
    /// is one tap away, also where trains cover its marker on the map.
    var openStation: ((Int) -> Void)?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PageExitButton(exit: exit, close: close)
                    .accessibilityIdentifier(A11yID.Train.back)
                Spacer()
                if timeline != nil, let following {
                    Button {
                        following.wrappedValue.toggle()
                    } label: {
                        Label {
                            Text(following.wrappedValue ? .trainFollowing : .trainFollow)
                        } icon: {
                            Image(systemName: following.wrappedValue ? "location.fill" : "location")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(following.wrappedValue ? color : .secondary)
                    .sensoryFeedback(following.wrappedValue ? .start : .stop, trigger: following.wrappedValue)
                    .accessibilityIdentifier(A11yID.Train.follow)
                }
            }
            // The page's controls stop growing at the first accessibility size, so at the largest
            // sizes they leave the panel to where the train goes and where it is.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            if let timeline {
                HStack(alignment: .top, spacing: 10) {
                    // The line's colour beside the title ties the page to the train on the map.
                    Capsule()
                        .fill(color)
                        .frame(width: 5)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            .trainTitle(
                                time: timeline.firstDeparture.vilniusTime, origin: timeline.origin, destination: timeline.destination)
                        )
                        .font(.headline)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(A11yID.Train.title)
                        TrainWhere(timeline: timeline, now: now, openStation: openStation)
                        ScheduledBadge()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(.trainGone)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

/// “● At Kaišiadorys, leaves at 18:02 · in 3 min”, or the next stop while the train runs:
/// the place, the clock time and the time from now, as a Japanese train page gives them.
private struct TrainWhere: View {
    let timeline: TrainTimeline
    let now: Date
    let openStation: ((Int) -> Void)?

    var body: some View {
        if let standing = timeline.standingAt {
            let stop = timeline.stops[standing]
            line(
                symbol: "smallcircle.filled.circle", Text(.trainAt(station: stop.station, time: stop.departure.vilniusTime)),
                in: stop.departure, station: stop.stationIndex)
        } else if let nextStop = timeline.nextStop {
            let next = timeline.stops[nextStop]
            line(
                symbol: "arrow.right.circle", Text(.trainNext(station: next.station, time: next.arrival.vilniusTime)),
                in: next.arrival, station: next.stationIndex)
        }
    }

    @ViewBuilder
    private func line(symbol: String, _ text: Text, in time: Date, station: Int) -> some View {
        if let openStation {
            Button {
                openStation(station)
            } label: {
                HStack(spacing: 4) {
                    place(symbol: symbol, text, in: time)
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text(.boardStationHint))
            .accessibilityIdentifier(A11yID.Train.now)
        } else {
            place(symbol: symbol, text, in: time)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(A11yID.Train.now)
        }
    }

    private func place(symbol: String, _ text: Text, in time: Date) -> some View {
        Label {
            let minutes = Text(.trainIn(minutes: time.minutes(after: now))).foregroundStyle(.secondary)
            // One line when it fits; at large text sizes the time from now goes under the place.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    text
                    minutes
                }
                VStack(alignment: .leading, spacing: 2) {
                    text
                    minutes
                }
            }
        } icon: {
            Image(systemName: symbol)
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Says on every train page that the train is drawn from the timetable, as Japan Rail Atlas
/// does on its train cards. Symbol and word, so it does not rest on colour.
private struct ScheduledBadge: View {
    var body: some View {
        Label {
            Text(.mapScheduled)
        } icon: {
            Image(systemName: "calendar.badge.clock")
                .symbolRenderingMode(.monochrome)
        }
        .font(.footnote.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.secondary.opacity(0.15), in: .capsule)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(A11yID.Train.source)
    }
}

/// “< Lines” in the panel; the system Close button in a sheet, where Back would mean a step back.
struct PageExitButton: View {
    let exit: PageExit
    let close: () -> Void

    var body: some View {
        switch exit {
        case .back:
            Button(action: close) {
                Label {
                    Text(.trainBack)
                } icon: {
                    Image(systemName: "chevron.left")
                }
            }
        case .close:
            Button(role: .close, action: close)
                .buttonStyle(.glass)
                .labelStyle(.iconOnly)
        }
    }
}

struct StopList: View {
    let timeline: TrainTimeline
    let color: Color

    /// The stop to show first: the one before the train's, so that the page opens on where the train is.
    private var opening: Int? {
        (timeline.standingAt ?? timeline.nextStop).map { max($0 - 1, 0) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            list
                // Once for each train, not each second as the train moves on.
                .task(id: TripKey(origin: timeline.origin, departure: timeline.firstDeparture)) {
                    if let opening, opening > 0 { proxy.scrollTo(opening, anchor: .top) }
                }
        }
    }

    private var list: some View {
        List {
            // Above the first stop: it scrolls away with the stops, so that at large text sizes
            // the stops have room.
            VStack(alignment: .leading, spacing: 6) {
                Text(.trainEstimated)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NoticesLink()
            }
            .listRowBackground(Color.clear)
            ForEach(timeline.stops) { stop in
                StopRow(stop: stop, timeline: timeline, color: color)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct TripKey: Equatable {
    let origin: String
    let departure: Date
}

private struct StopRow: View {
    let stop: TrainTimeline.Stop
    let timeline: TrainTimeline
    let color: Color

    private var here: Bool { stop.id == timeline.standingAt }
    private var next: Bool { stop.id == timeline.nextStop && timeline.standingAt == nil }

    var body: some View {
        HStack(spacing: 12) {
            StopMark(
                color: color, passed: stop.passed, isNext: here || next,
                progress: stop.id == timeline.nextStop ? timeline.progressToNext : nil)
            Text(verbatim: stop.station)
                .foregroundStyle(stop.passed ? .secondary : .primary)
                .fontWeight(here || next ? .semibold : nil)
            Spacer()
            Text(verbatim: (stop.id == 0 ? stop.departure : stop.arrival).vilniusTime)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        // The row takes the height of its tallest part, and the stop mark stretches to it.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        // The dot and the grey say where the train is; VoiceOver says it in words.
        .accessibilityValue(state.map { Text($0) } ?? Text(verbatim: ""))
        .accessibilityIdentifier(A11yID.Train.stop)
    }

    private var state: LocalizedStringResource? {
        if here { return .trainStopHere }
        if next { return .trainStopNext }
        if stop.passed { return .trainStopPassed }
        return nil
    }
}

private struct StopMark: View {
    let color: Color
    let passed: Bool
    let isNext: Bool
    let progress: Double?

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(passed ? color.opacity(0.35) : color)
                .frame(width: 4)
            Circle()
                .strokeBorder(color, lineWidth: 3)
                .background(Circle().fill(passed ? color : Color(.systemBackground)))
                .frame(width: 14, height: 14)
                .padding(.top, 15)
            if let progress, progress > 0 {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .offset(y: 17 - 22 * (1 - progress))
            }
        }
        // At least 44 points tall, and as tall as the row at large text sizes, so the line
        // runs on from row to row unbroken.
        .frame(width: 16)
        .frame(minHeight: 44, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

#Preview {
    TrainPage(timeline: nil, color: .blue, now: .now, following: .constant(false)) {}
}
