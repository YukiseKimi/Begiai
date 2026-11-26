import BegiaiKit
import SwiftUI

/// The stations of one line at equal spaces down a coloured spine. Trains toward the last
/// station go on the left, trains toward the first station on the right.
struct LineSpine: View {
    let diagram: LineDiagram
    let timetable: Timetable
    let color: Color
    let trains: [(train: TrainState, place: LineDiagram.Place)]
    /// The Line Diagram's open page: a tap on a station or a train opens it.
    @Binding var selection: PageSelection?

    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var tagHeight: CGFloat = 30
    /// The space between the spine and the inner edge of a train tag. It grows with the text,
    /// up to 45% of half the width, so the tags keep room at the largest sizes.
    @ScaledMetric(relativeTo: .footnote) private var preferredGutter: CGFloat = 84
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var rotor

    /// At accessibility sizes a tag may take two lines, so the tags keep a taller space.
    private var tagStep: CGFloat { typeSize.isAccessibilitySize ? tagHeight * 1.9 : tagHeight }

    var body: some View {
        let height = rowHeight * CGFloat(max(diagram.stations.count - 1, 0))
        let stations = diagram.stations.enumerated().map { row, station in
            SpineStation(row: row, station: station, name: timetable.stations[station].name)
        }
        let tags = spread(.down) + spread(.up)
        // A tag pushed down past the last station still fits, so the tab bar hides none.
        let lowestTag = tags.map { $0.y + tagStep / 2 }.max() ?? 0
        SpineLayout(rowHeight: rowHeight, preferredGutter: preferredGutter, spineHeight: height) {
            Capsule()
                .fill(color)
                .layoutValue(key: SpinePlace.self, value: .spine)
            ForEach(stations) { station in
                SpineStationButton(station: station, color: color, rotor: rotor, selection: $selection)
                    .accessibilitySortPriority(-Double(station.row) * rowHeight)
                    .layoutValue(key: SpinePlace.self, value: .station(row: station.row))
            }
            ForEach(tags) { tag in
                SpineTrainButton(tag: tag, color: color, rotor: rotor, selection: $selection)
                    .accessibilitySortPriority(-Double(tag.y) - 0.5)
                    .layoutValue(key: SpinePlace.self, value: tag.down ? .down(y: tag.y) : .up(y: tag.y))
            }
        }
        // VoiceOver reads down the line, each train after the station above it, and its
        // rotor jumps from train to train or from station to station.
        .accessibilityElement(children: .contain)
        .accessibilityRotor(Text(.diagramRotorTrains)) {
            ForEach(tags.sorted { $0.row < $1.row }) { tag in
                AccessibilityRotorEntry(tag.label, id: tag.id, in: rotor)
            }
        }
        .accessibilityRotor(Text(.diagramRotorStations)) {
            ForEach(stations) { station in
                AccessibilityRotorEntry(Text(verbatim: station.name), id: station.row, in: rotor)
            }
        }
        .frame(height: max(height, lowestTag))
        .padding(.vertical, 24)
    }

    private func destination(of train: TrainState) -> String {
        let stops = timetable.trips[train.trip].stops
        return timetable.stations[stops[stops.count - 1].station].name
    }

    private func label(_ train: TrainState, _ place: LineDiagram.Place) -> Text {
        let name = { (row: Int) in timetable.stations[diagram.stations[row]].name }
        return place.fraction > 0
            ? Text(.diagramTrainBetween(station: destination(of: train), from: name(place.from), to: name(place.to)))
            : Text(.diagramTrainAt(station: destination(of: train), at: name(place.from)))
    }

    /// The trains of one side, top to bottom, each pushed down so no two tags overlap.
    private func spread(_ direction: LineDiagram.Place.Direction) -> [SpineTag] {
        var last = -CGFloat.infinity
        return trains.filter { $0.place.direction == direction }
            .sorted { $0.place.row < $1.place.row }
            .map { train, place in
                let y = max(CGFloat(place.row) * rowHeight, last + tagStep + 4)
                last = y
                return SpineTag(
                    id: train.id, down: direction == .down, destination: destination(of: train), label: label(train, place),
                    row: place.row, y: y)
            }
    }
}

/// A station on the spine, as its button shows it.
private struct SpineStation: Identifiable {
    /// Its place down the line, from the first station.
    let row: Int
    /// Its index in the timetable.
    let station: Int
    let name: String

    var id: Int { row }
}

/// A train beside the spine, as its tag shows it.
private struct SpineTag: Identifiable {
    let id: TrainState.ID
    /// True for a train toward the last station, on the left of the spine.
    let down: Bool
    let destination: String
    /// What VoiceOver says: where the train goes, and where it is on the line.
    let label: Text
    /// Where the train is down the line, in rows.
    let row: Double
    /// Where its tag goes, pushed down from its row so no two tags overlap.
    let y: CGFloat
}

private struct SpineStationButton: View {
    let station: SpineStation
    let color: Color
    let rotor: Namespace.ID
    @Binding var selection: PageSelection?

    var body: some View {
        Button {
            selection = .station(station.station)
        } label: {
            Text(verbatim: station.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.background, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityRotorEntry(id: station.row, in: rotor)
        .accessibilityHint(Text(.boardStationHint))
        .accessibilityIdentifier(A11yID.LineDiagram.station)
    }
}

private struct SpineTrainButton: View {
    let tag: SpineTag
    let color: Color
    let rotor: Namespace.ID
    @Binding var selection: PageSelection?

    var body: some View {
        Button {
            selection = .train(tag.id)
        } label: {
            TrainTag(color: color, down: tag.down, destination: tag.destination)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tag.label)
        .accessibilityRotorEntry(id: tag.id, in: rotor)
        .accessibilityIdentifier(A11yID.LineDiagram.train)
    }
}

/// Where a view of the spine goes.
nonisolated private enum SpinePlace: LayoutValueKey {
    case spine
    /// A station's button, centred on the spine at its row.
    case station(row: Int)
    /// A train's tag on the left of the spine, centred on `y`.
    case down(y: CGFloat)
    /// A train's tag on the right of the spine, centred on `y`.
    case up(y: CGFloat)

    static let defaultValue = SpinePlace.spine
}

/// Lays out the spine down the middle, the stations on it at equal spaces, and each train's
/// tag beside it: the stations as wide as the space between the tags, the tags as wide as the
/// rest of their side.
nonisolated private struct SpineLayout: Layout {
    let rowHeight: CGFloat
    let preferredGutter: CGFloat
    /// From the first station to the last.
    let spineHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // The spine takes the width it is offered; the frame around it sets the height.
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let centre = bounds.width / 2
        let gutter = min(preferredGutter, centre * 0.45)
        let side = max(centre - gutter - 12, 0)
        let point = { (x: CGFloat, y: CGFloat) in CGPoint(x: bounds.minX + x, y: bounds.minY + y) }
        for subview in subviews {
            switch subview[SpinePlace.self] {
            case .spine:
                subview.place(
                    at: point(centre, spineHeight / 2), anchor: .center, proposal: ProposedViewSize(width: 8, height: spineHeight))
            case .station(let row):
                subview.place(
                    at: point(centre, CGFloat(row) * rowHeight), anchor: .center,
                    proposal: ProposedViewSize(width: min(bounds.width, (gutter - 6) * 2), height: bounds.height))
            case .down(let y):
                // The tag's frame is `side` wide, centred halfway between 12 and the gutter's
                // edge; the tag keeps to that frame's trailing edge.
                subview.place(
                    at: point((centre - gutter + 12) / 2 + side / 2, y), anchor: .trailing,
                    proposal: ProposedViewSize(width: side, height: bounds.height))
            case .up(let y):
                subview.place(
                    at: point(centre + gutter + (centre - gutter - 12) / 2 - side / 2, y), anchor: .leading,
                    proposal: ProposedViewSize(width: side, height: bounds.height))
            }
        }
    }
}
