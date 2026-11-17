import BegiaiKit
import SwiftUI

struct StationHeader: View {
    let name: String
    let starred: Bool
    let close: () -> Void
    let toggleStar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: close) {
                    Label {
                        Text(.trainBack)
                    } icon: {
                        Image(systemName: "chevron.left")
                    }
                }
                .accessibilityIdentifier(A11yID.Board.back)
                Spacer()
                StarButton(name: name, starred: starred, toggle: toggleStar)
                    .accessibilityIdentifier(A11yID.Board.star)
            }
            Text(verbatim: name)
                .font(.headline)
                .accessibilityIdentifier(A11yID.Board.title)
        }
        .padding(.horizontal)
    }
}

struct LEDBoard: View {
    let departures: [Departure]

    private let amber = Color(red: 1, green: 0.69, blue: 0)
    private let green = Color(red: 0.43, green: 0.87, blue: 0.55)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if departures.isEmpty {
                    Text(.boardNone)
                        .foregroundStyle(amber)
                }
                ForEach(departures) { departure in
                    if departure.tomorrow, departure.id == departures.first(where: \.tomorrow)?.id {
                        Text(.boardTomorrow)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    HStack(spacing: 10) {
                        Text(verbatim: departure.time.vilniusTime)
                            .monospacedDigit()
                        Text(verbatim: departure.destination)
                            .lineLimit(1)
                        Spacer()
                        if departure.startsHere {
                            Text(.boardStartsHere)
                                .foregroundStyle(green)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(A11yID.Board.row)
                }
            }
            .font(.system(.callout, design: .monospaced).weight(.medium))
            .foregroundStyle(amber)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.04, green: 0.06, blue: 0.09), in: .rect(cornerRadius: 12))
            .environment(\.colorScheme, .dark)
            .padding(.horizontal)
        }
    }
}

#Preview {
    LEDBoard(departures: [])
}
