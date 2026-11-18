import BegiaiKit
import SwiftUI

/// The stations of one line at equal spaces down a coloured spine. Trains toward the last
/// station go on the left, trains toward the first station on the right.
struct LineSpine: View {
    let diagram: LineDiagram
    let timetable: Timetable
    let color: Color
    let trains: [(train: TrainState, place: LineDiagram.Place)]
    let open: (DiagramSelection) -> Void

    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var tagHeight: CGFloat = 30
    /// The space between the spine and the inner edge of a train tag. It grows with the text,
    /// up to 45% of half the width, so the tags keep room at the largest sizes.
    @ScaledMetric(relativeTo: .footnote) private var preferredGutter: CGFloat = 84

    var body: some View {
        let height = rowHeight * CGFloat(max(diagram.stations.count - 1, 0))
        GeometryReader { proxy in
            let centre = proxy.size.width / 2
            let gutter = min(preferredGutter, centre * 0.45)
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(color)
                    .frame(width: 8, height: height)
                    .position(x: centre, y: height / 2)
                ForEach(Array(diagram.stations.enumerated()), id: \.offset) { row, station in
                    Button {
                        open(.station(station))
                    } label: {
                        Text(verbatim: timetable.stations[station].name)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.background, in: .rect(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(.boardStationHint))
                    .accessibilityIdentifier(A11yID.LineDiagram.station)
                    .frame(maxWidth: (gutter - 6) * 2)
                    .position(x: centre, y: CGFloat(row) * rowHeight)
                }
                ForEach(spread(.down), id: \.train.id) { item in
                    tag(item.train, item.place)
                        .frame(width: max(centre - gutter - 12, 0), alignment: .trailing)
                        .position(x: (centre - gutter + 12) / 2, y: item.y)
                }
                ForEach(spread(.up), id: \.train.id) { item in
                    tag(item.train, item.place)
                        .frame(width: max(centre - gutter - 12, 0), alignment: .leading)
                        .position(x: centre + gutter + (centre - gutter - 12) / 2, y: item.y)
                }
            }
        }
        .frame(height: height)
        .padding(.vertical, 24)
    }

    private func tag(_ train: TrainState, _ place: LineDiagram.Place) -> some View {
        let stops = timetable.trips[train.trip].stops
        let name = { (row: Int) in timetable.stations[diagram.stations[row]].name }
        let destination = timetable.stations[stops[stops.count - 1].station].name
        return Button {
            open(.train(train.id))
        } label: {
            TrainTag(color: color, down: place.direction == .down, destination: destination)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            place.fraction > 0
                ? Text(.diagramTrainBetween(station: destination, from: name(place.from), to: name(place.to)))
                : Text(.diagramTrainAt(station: destination, at: name(place.from))))
        .accessibilityIdentifier(A11yID.LineDiagram.train)
    }

    /// The trains of one side, top to bottom, each pushed down so no two tags overlap.
    private func spread(_ direction: LineDiagram.Place.Direction) -> [(train: TrainState, place: LineDiagram.Place, y: CGFloat)] {
        var last = -CGFloat.infinity
        return trains.filter { $0.place.direction == direction }
            .sorted { $0.place.row < $1.place.row }
            .map { train, place in
                let y = max(CGFloat(place.row) * rowHeight, last + tagHeight + 4)
                last = y
                return (train, place, y)
            }
    }
}
