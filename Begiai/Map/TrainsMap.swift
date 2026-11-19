import BegiaiKit
import MapKit
import SwiftUI

/// The map with its tracks, stations and trains. It is the one view that reads the trains
/// each frame, so a frame redraws the markers and not the panel.
struct TrainsMap: View {
    let store: TimetableStore
    let trains: TrainsModel
    @Binding var position: MapCameraPosition
    @Binding var selection: PanelSelection?
    @Binding var following: Bool
    @Binding var panelHeight: PanelHeight
    let bottomInset: CGFloat
    @State private var cameraHeading = 0.0
    @State private var cameraDistance = 400_000.0
    @Namespace private var mapScope
    @Environment(\.linePalette) private var palette

    var body: some View {
        let cityZoom = trains.cityZoom
        let chosen = trains.moving.first { selection == .train($0.id) }
        Map(position: $position, scope: mapScope) {
            UserAnnotation()
            ForEach(store.tracks) { track in
                let colors = palette.colors(forLines: track.lines)
                ForEach(colors.indices, id: \.self) { slot in
                    MapPolyline(coordinates: track.coordinates)
                        .stroke(colors[slot], style: Self.trackStroke(slot: slot, of: colors.count))
                }
            }
            ForEach(stations, id: \.index) { station, info in
                Annotation("", coordinate: info.coordinate.location, anchor: .center) {
                    StationMarker(name: info.name, chosen: selection == .station(station), compact: !cityZoom) {
                        selection = .station(station)
                        if panelHeight == .peek { panelHeight = .half }
                    }
                }
                .annotationTitles(.hidden)
            }
            ForEach(trains.moving) { train in
                Annotation("", coordinate: train.coordinate.location, anchor: .center) {
                    capsule(for: train, cityZoom: cityZoom)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapScaleView()
        }
        .accessibilityIdentifier(A11yID.Map.page)
        .onMapCameraChange { context in
            trains.look(at: context.region, distance: context.camera.distance)
            cameraHeading = context.camera.heading
            cameraDistance = context.camera.distance
        }
        .onChange(of: FollowTarget(following: following, coordinate: chosen?.coordinate), initial: true) {
            _, target in
            guard target.following, let coordinate = target.coordinate else { return }
            position = .camera(
                MapCamera(
                    centerCoordinate: coordinate.location, distance: min(cameraDistance, 25_000),
                    heading: cameraHeading))
        }
        .onChange(of: selection) { following = false }
        .onChange(of: position.positionedByUser) { _, byUser in
            if byUser { following = false }
        }
        .safeAreaPadding(.bottom, bottomInset)
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 10) {
                LocateButton(position: $position) { following = false }
                AboutButton(timetable: store.timetable)
                MapCompass(scope: mapScope)
            }
            .padding()
        }
        .mapScope(mapScope)
    }

    /// The length in points of one line's dash on rail that several lines share.
    private static let dash: CGFloat = 6

    /// A track with one colour is a solid line. On a track that `count` colours share, each
    /// colour is a dash with a gap for the others, and the dashes take turns in line order.
    private static func trackStroke(slot: Int, of count: Int) -> StrokeStyle {
        guard count > 1 else { return StrokeStyle(lineWidth: 3) }
        // MapKit does not scale `dashPhase` as it scales the dashes, so a zero dash and a gap
        // move this line's dash to its turn.
        return StrokeStyle(
            lineWidth: 3, dash: [0, dash * CGFloat(slot), dash, dash * CGFloat(count - 1 - slot)])
    }

    /// At city zoom, the stations in sight and a margin around them; else the big stations.
    /// Fewer station markers make each frame's map update smaller.
    private var stations: [(index: Int, station: Station)] {
        guard let timetable = store.timetable else { return [] }
        let region = trains.region ?? .lithuania
        return timetable.stations.indices.filter { station in
            if selection == .station(station) { return true }
            guard trains.cityZoom else { return store.bigStations.contains(station) }
            return region.holds(timetable.stations[station].coordinate)
        }.map { ($0, timetable.stations[$0]) }
    }

    private func capsule(for train: TrainState, cityZoom: Bool) -> some View {
        let trip = store.timetable?.trips[train.trip]
        let destination = trip?.stops.last.flatMap { stop in
            store.timetable?.stations.indices.contains(stop.station) == true
                ? store.timetable?.stations[stop.station].name : nil
        }
        return Button {
            selection = .train(train.id)
            if panelHeight == .peek { panelHeight = .half }
        } label: {
            TrainCapsule(
                color: palette.color(forLine: trip?.line ?? 0), heading: train.heading - cameraHeading,
                destination: destination, atStation: train.phase == .atStation, showsLabel: cityZoom,
                chosen: selection == .train(train.id))
        }
        .buttonStyle(.plain)
    }
}

private struct FollowTarget: Equatable {
    let following: Bool
    let coordinate: Coordinate?
}
