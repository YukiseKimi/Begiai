import BegiaiKit
import SwiftUI

struct StationHeader: View {
    let name: String
    let starred: Bool
    var exit = PageExit.back
    let close: PageClose

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PageExitButton(exit: exit, close: close)
                    .accessibilityIdentifier(A11yID.Board.back)
                Spacer()
                StarButton(kind: .station, name: name, starred: starred)
                    .accessibilityIdentifier(A11yID.Board.star)
            }
            // The page's controls stop growing at the first accessibility size, so at the largest
            // sizes they leave the panel to the station's name and its board.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            Text(verbatim: name)
                .font(.headline)
                .accessibilityIdentifier(A11yID.Board.title)
        }
        .padding(.horizontal)
    }
}

/// The next departures, styled as a Japanese LED departure sign (発車標). Each row gives the
/// clock time and, within the hour, the minutes from now, so a rider need not do the sum.
struct LEDBoard: View {
    let departures: [Departure]
    let now: Date

    static let amber = Color(red: 1, green: 0.69, blue: 0)
    static let green = Color(red: 0.43, green: 0.87, blue: 0.55)

    var body: some View {
        // When every train starts here, one line says so, not each row.
        let everyTrainStartsHere = !departures.isEmpty && departures.allSatisfy(\.startsHere)
        let firstTomorrow = departures.first(where: \.tomorrow)?.id
        let lines = departures.map { departure in
            BoardLine(
                departure: departure, minutes: departure.time.minutes(after: now), opensTomorrow: departure.id == firstTomorrow,
                showsStartsHere: !everyTrainStartsHere && departure.startsHere)
        }
        // At most eight departures (the engine's limit), so a plain stack holds them.
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if departures.isEmpty {
                    Text(.boardNone)
                        .foregroundStyle(Self.amber)
                }
                if everyTrainStartsHere {
                    StartsHereLabel(text: .boardEveryTrainStartsHere)
                }
                ForEach(lines) { line in
                    BoardEntry(line: line)
                }
            }
            .font(.system(.callout, design: .monospaced).weight(.medium))
            .foregroundStyle(Self.amber)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.04, green: 0.06, blue: 0.09), in: .rect(cornerRadius: 12))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal)
        }
    }
}

/// One departure as its row shows it.
private struct BoardLine: Identifiable {
    let departure: Departure
    /// The minutes from now to the departure.
    let minutes: Int
    /// The first departure after midnight: “Tomorrow” goes above it.
    let opensTomorrow: Bool
    /// “Starts here” goes under the destination: the train starts here, and not every train does.
    let showsStartsHere: Bool

    var id: Departure.ID { departure.id }
}

/// A departure, with “Tomorrow” above the first one after midnight. The stack keeps the
/// board's spacing, and adds no element of its own for VoiceOver.
private struct BoardEntry: View {
    let line: BoardLine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if line.opensTomorrow {
                Text(.boardTomorrow)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            BoardRow(
                time: line.departure.time, destination: line.departure.destination, minutes: line.minutes,
                showsStartsHere: line.showsStartsHere)
        }
    }
}

private struct BoardRow: View {
    let time: Date
    let destination: String
    let minutes: Int
    let showsStartsHere: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Two arrangements, not one container swapped for another, and nothing in a row keeps
        // state that the switch at the accessibility sizes could lose. The parts take their
        // values straight from the row, so the arrangement stays here in one body.
        Group {
            if typeSize.isAccessibilitySize {
                // At the largest sizes the time and the minutes take a line, the destination the
                // next. In a narrow panel the minutes go under the time rather than break mid-word.
                VStack(alignment: .leading, spacing: 2) {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            BoardTime(time: time)
                            Spacer()
                            BoardCountdown(minutes: minutes)
                                .fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            BoardTime(time: time)
                            BoardCountdown(minutes: minutes)
                        }
                    }
                    BoardDestination(name: destination, showsStartsHere: showsStartsHere)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    BoardTime(time: time)
                    BoardDestination(name: destination, showsStartsHere: showsStartsHere)
                    Spacer(minLength: 4)
                    BoardCountdown(minutes: minutes)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(A11yID.Board.row)
    }
}

private struct BoardTime: View {
    let time: Date

    var body: some View {
        Text(verbatim: time.vilniusTime)
            .monospacedDigit()
            // A clock time never breaks across lines, on purpose; the minutes beside it wrap instead.
            .fixedSize()
    }
}

private struct BoardDestination: View {
    let name: String
    let showsStartsHere: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: name)
                // Two lines hold a name up to the largest sizes, where it may need more.
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            if showsStartsHere {
                StartsHereLabel(text: .boardStartsHere)
            }
        }
    }
}

/// Within the hour only: past that, the clock time is the easier read.
private struct BoardCountdown: View {
    let minutes: Int

    var body: some View {
        if minutes <= 60 {
            Text(minutes == 0 ? .boardNow : .trainIn(minutes: minutes))
                .monospacedDigit()
                .opacity(0.85)
        }
    }
}

/// 当駅始発: the train is empty when it boards. A symbol and a word, not colour alone.
private struct StartsHereLabel: View {
    let text: LocalizedStringResource

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "arrow.up.forward.circle")
        }
        .font(.system(.footnote, design: .monospaced).weight(.semibold))
        .foregroundStyle(LEDBoard.green)
    }
}

#Preview {
    LEDBoard(departures: [], now: .now)
}
