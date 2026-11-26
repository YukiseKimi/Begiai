import BegiaiKit
import SwiftUI

struct StationHeader: View {
    let name: String
    let starred: Bool
    var exit = PageExit.back
    let close: () -> Void

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
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if departures.isEmpty {
                    Text(.boardNone)
                        .foregroundStyle(Self.amber)
                }
                if everyTrainStartsHere {
                    StartsHereLabel(text: .boardEveryTrainStartsHere)
                }
                ForEach(departures) { departure in
                    if departure.tomorrow, departure.id == departures.first(where: \.tomorrow)?.id {
                        Text(.boardTomorrow)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    BoardRow(departure: departure, now: now, showsStartsHere: !everyTrainStartsHere)
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

private struct BoardRow: View {
    let departure: Departure
    let now: Date
    let showsStartsHere: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // At the largest sizes the time and the minutes take a line, the destination the next.
                // In a narrow panel the minutes go under the time rather than break mid-word.
                VStack(alignment: .leading, spacing: 2) {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            time
                            Spacer()
                            countdown
                                .fixedSize()
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            time
                            countdown
                        }
                    }
                    destination
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    time
                    destination
                    Spacer(minLength: 4)
                    countdown
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(A11yID.Board.row)
    }

    private var time: some View {
        Text(verbatim: departure.time.vilniusTime)
            .monospacedDigit()
            // A clock time never breaks across lines; the minutes beside it wrap instead.
            .fixedSize()
    }

    private var destination: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: departure.destination)
                // Two lines hold a name up to the largest sizes, where it may need more.
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            if showsStartsHere, departure.startsHere {
                StartsHereLabel(text: .boardStartsHere)
            }
        }
    }

    /// Within the hour only: past that, the clock time is the easier read.
    @ViewBuilder private var countdown: some View {
        let minutes = departure.time.minutes(after: now)
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
