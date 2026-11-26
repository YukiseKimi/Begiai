import BegiaiKit
import SwiftUI

/// How a page in the panel or a sheet goes away: back to the line list, or the sheet closes.
enum PageExit {
    case back
    case close
}

/// What a page's Back or Close button does: clear the open page, or dismiss the sheet that
/// shows it, with the sheet's own dismiss action. A sheet's content closes with dismiss and
/// leaves the state that presents it alone.
enum PageClose {
    case selection(Binding<PageSelection?>)
    case dismiss(DismissAction)
}

/// The fixed top of a train's page: where the train goes and where it is now. The facts
/// that stay the same (estimated, notices) scroll with the stops, in `StopList`.
struct TrainPage: View {
    let timeline: TrainTimeline?
    let color: Color
    let now: Date
    /// Nil where nothing can follow the train: the page then shows no Follow button.
    var following: Binding<FollowState>?
    /// True while the followed train's Live Activity shows: Follow then says so to VoiceOver.
    var onLockScreen = false
    var exit = PageExit.back
    let close: PageClose
    /// Where the place line opens its station's board, so the station of a train is one tap
    /// away, also where trains cover its marker on the map: the panel's own page, or a page in
    /// place in the Line Diagram's sheet, so the sheet stays up.
    @Binding var stationPage: PageSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PageExitButton(exit: exit, close: close)
                    .accessibilityIdentifier(A11yID.Train.back)
                Spacer()
                if timeline != nil, let following {
                    FollowButton(state: following, color: color, onLockScreen: onLockScreen)
                        .accessibilityIdentifier(A11yID.Train.follow)
                }
            }
            // The page's controls stop growing at the first accessibility size, so at the largest
            // sizes they leave the panel to where the train goes and where it is.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            // At the largest text sizes “Lines” and “Follow” do not fit side by side and were cut
            // to “Li…” and “F…”: there the buttons show their symbols, and VoiceOver still reads
            // their names.
            .labelStyle(IconOnlyAtLargeSizes())
            if let timeline {
                HStack(alignment: .top, spacing: 10) {
                    // The line's colour beside the title ties the page to the train on the map.
                    Capsule()
                        .fill(color)
                        .frame(width: 5)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        TrainTitle(timeline: timeline)
                        TrainWhere(timeline: timeline, now: now, stationPage: $stationPage)
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

/// “17:26 Vilnius → Kaunas”, the page's heading.
private struct TrainTitle: View {
    let timeline: TrainTimeline
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text(.trainTitle(time: timeline.firstDeparture.vilniusTime, origin: timeline.origin, destination: timeline.destination))
            .font(.headline)
            // Three lines hold a title up to the largest sizes, where it may need more.
            .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(A11yID.Train.title)
    }
}

/// Follow; Following while the map keeps the train in the middle; Show train once the map was
/// moved away from the followed train, which the Lock Screen still shows.
private struct FollowButton: View {
    @Binding var state: FollowState
    let color: Color
    /// True while the followed train's Live Activity shows.
    let onLockScreen: Bool

    var body: some View {
        Button {
            state = state.tapped
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
            }
            // The capsule takes the colour; the words and the arrow take a colour that reads on it.
            .foregroundStyle(state.isFollowed ? AnyShapeStyle(LineLabelStyle(line: color)) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.bordered)
        // The line's colour while the train is followed, also once the map was moved away.
        .tint(state.isFollowed ? color : .secondary)
        .sensoryFeedback(trigger: state) { _, state in
            switch state {
            case .following: .start
            case .off: .stop
            // A drag on the map lets the train go, and the drag is feedback enough.
            case .released: nil
            }
        }
        .accessibilityValue(state.isFollowed && onLockScreen ? Text(.trainOnLockScreen) : Text(verbatim: ""))
    }

    /// As in Maps: filled while the map keeps the train in the middle, an outline when not.
    /// Show train has the arrow in a viewfinder, so its shape tells it from Follow also at the
    /// largest text sizes, where the button shows only its symbol.
    private var symbol: String {
        switch state {
        case .off: "location"
        case .following: "location.fill"
        case .released: "location.viewfinder"
        }
    }

    private var title: LocalizedStringResource {
        switch state {
        case .off: .trainFollow
        case .following: .trainFollowing
        case .released: .trainShowTrain
        }
    }
}

/// “● At Kaišiadorys, leaves at 18:02 · in 3 min”, or the next stop while the train runs:
/// the place, the clock time and the time from now, as a Japanese train page gives them.
private struct TrainWhere: View {
    let timeline: TrainTimeline
    let now: Date
    @Binding var stationPage: PageSelection?

    var body: some View {
        if let standing = timeline.standingAt {
            let stop = timeline.stops[standing]
            PlaceLink(
                symbol: "smallcircle.filled.circle", text: Text(.trainAt(station: stop.station, time: stop.departure.vilniusTime)),
                minutes: stop.departure.minutes(after: now), station: stop.stationIndex, stationPage: $stationPage)
        } else if let nextStop = timeline.nextStop {
            let next = timeline.stops[nextStop]
            PlaceLink(
                symbol: "arrow.right.circle", text: Text(.trainNext(station: next.station, time: next.arrival.vilniusTime)),
                minutes: next.arrival.minutes(after: now), station: next.stationIndex, stationPage: $stationPage)
        }
    }
}

/// The place line, a link to the board of its station.
private struct PlaceLink: View {
    let symbol: String
    let text: Text
    /// The minutes from now to the clock time in `text`.
    let minutes: Int
    let station: Int
    @Binding var stationPage: PageSelection?

    var body: some View {
        Button {
            stationPage = .station(station)
        } label: {
            HStack(spacing: 4) {
                Place(symbol: symbol, text: text, minutes: minutes)
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
    }
}

private struct Place: View {
    let symbol: String
    let text: Text
    let minutes: Int

    var body: some View {
        Label {
            let wait = Text(.trainIn(minutes: minutes)).foregroundStyle(.secondary)
            // One line when it fits; at large text sizes the time from now goes under the place.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    text
                    wait
                }
                VStack(alignment: .leading, spacing: 2) {
                    text
                    wait
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

/// A label with its title and symbol, or only its symbol at the accessibility text sizes.
struct IconOnlyAtLargeSizes: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration)
    }

    private struct Styled: View {
        let configuration: LabelStyleConfiguration
        @Environment(\.dynamicTypeSize) private var typeSize

        var body: some View {
            // Two label styles are two types, so no one modifier takes either: a branch it is.
            // A label keeps no state that the switch at the accessibility sizes could lose.
            if typeSize.isAccessibilitySize {
                Label(configuration).labelStyle(.iconOnly)
            } else {
                Label(configuration).labelStyle(.titleAndIcon)
            }
        }
    }
}

/// “< Lines” in the panel; the system Close button in a sheet, where Back would mean a step back.
struct PageExitButton: View {
    let exit: PageExit
    let close: PageClose

    var body: some View {
        switch exit {
        case .back:
            Button(.trainBack, systemImage: "chevron.left", action: perform)
        case .close:
            Button(role: .close, action: perform)
                .buttonStyle(.glass)
                .labelStyle(.iconOnly)
        }
    }

    private func perform() {
        switch close {
        case .selection(let selection): selection.wrappedValue = nil
        case .dismiss(let dismiss): dismiss()
        }
    }
}

/// A train's stops, under the facts that stay the same; it opens on where the train is.
struct StopList: View {
    /// The train: the list scrolls to where it is once for each train, not each second as the
    /// train moves on.
    let train: TrainState.ID
    let timeline: TrainTimeline
    let color: Color

    /// The stop to show first: the one before the train's, so that the page opens on where the train is.
    private var opening: Int? {
        (timeline.standingAt ?? timeline.nextStop).map { max($0 - 1, 0) }
    }

    var body: some View {
        let lines = timeline.stops.map { stop in
            StopLine(
                stop: stop, color: color, here: stop.id == timeline.standingAt,
                next: stop.id == timeline.nextStop && timeline.standingAt == nil,
                progress: stop.id == timeline.nextStop ? timeline.progressToNext : nil)
        }
        ScrollViewReader { proxy in
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
                ForEach(lines) { line in
                    StopRow(line: line)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .task(id: train) {
                if let opening, opening > 0 { proxy.scrollTo(opening, anchor: .top) }
            }
        }
    }
}

/// One stop as its row shows it: the stop, its line's colour, and where the train is.
private struct StopLine: Identifiable, Equatable {
    let stop: TrainTimeline.Stop
    let color: Color
    /// The train stands at this stop.
    let here: Bool
    /// The train runs to this stop next.
    let next: Bool
    /// How far the train has come toward this stop, while it runs to it.
    let progress: Double?

    var id: Int { stop.id }
}

private struct StopRow: View {
    let line: StopLine

    var body: some View {
        let stop = line.stop
        HStack(spacing: 12) {
            StopMark(color: line.color, passed: stop.passed, progress: line.progress)
            Text(verbatim: stop.station)
                .foregroundStyle(stop.passed ? .secondary : .primary)
                .fontWeight(line.here || line.next ? .semibold : nil)
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
        if line.here { return .trainStopHere }
        if line.next { return .trainStopNext }
        if line.stop.passed { return .trainStopPassed }
        return nil
    }
}

private struct StopMark: View {
    let color: Color
    let passed: Bool
    let progress: Double?

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(passed ? color.opacity(0.35) : color)
                .frame(width: 4)
            Circle()
                .strokeBorder(color, lineWidth: 3)
                .background(passed ? color : Color(.systemBackground), in: .circle)
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
    TrainPage(
        timeline: nil, color: .blue, now: .now, following: .constant(.off), close: .selection(.constant(nil)), stationPage: .constant(nil))
}
