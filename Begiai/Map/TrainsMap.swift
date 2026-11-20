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
    /// The ground distance one point of the screen covers at its centre, in steps of a quarter
    /// of a doubling, so the stripes are worked out again only when the zoom has moved a step.
    @State private var metresPerPoint = 1_000.0
    @State private var mapSize = CGSize(width: 400, height: 800)
    @State private var stripes: [TrackStripe] = []
    @Namespace private var mapScope
    @Environment(\.linePalette) private var palette

    var body: some View {
        let cityZoom = trains.cityZoom
        let chosen = trains.moving.first { selection == .train($0.id) }
        MapReader { proxy in
            Map(position: $position, scope: mapScope) {
                UserAnnotation()
                ForEach(stripes) { stripe in
                    MapPolyline(coordinates: stripe.coordinates)
                        .stroke(palette.color(forLine: stripe.line), style: stripe.style)
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
            .onMapCameraChange(frequency: .continuous) { _ in measureScale(with: proxy) }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                mapSize = size
                measureScale(with: proxy)
            }
        }
        .onChange(of: metresPerPoint) { buildStripes() }
        .onChange(of: store.tracks.count, initial: true) { buildStripes() }
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

    /// Measures the ground under 100 points across the centre of the screen, so a rotated or
    /// tilted map gives the scale where the rider looks, not that of the box around the view.
    private func measureScale(with proxy: MapProxy) {
        let centre = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)
        guard let left = proxy.convert(CGPoint(x: centre.x - 50, y: centre.y), from: .local),
            let right = proxy.convert(CGPoint(x: centre.x + 50, y: centre.y), from: .local)
        else { return }
        let metres = CLLocation(latitude: left.latitude, longitude: left.longitude)
            .distance(from: CLLocation(latitude: right.latitude, longitude: right.longitude)) / 100
        guard metres > 0 else { return }
        let step = pow(2, (log2(metres) * 4).rounded() / 4)
        if step != metresPerPoint { metresPerPoint = step }
    }

    /// Works out the stripes for the tracks at the map's scale. A track with one line is a solid
    /// line on the rail; on a shared track each line is a stripe of its own beside the others.
    private func buildStripes() {
        let scale = metresPerPoint
        stripes = store.tracks.flatMap { track in
            guard track.lines.count > 1 else {
                return [TrackStripe(track: track.id, line: track.lines.first ?? 0, coordinates: track.coordinates, width: 3)]
            }
            let path = track.coordinates.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
            return zip(track.lines, TrackStripes.offsets(count: track.lines.count, along: path)).map { line, offset in
                TrackStripe(
                    track: track.id, line: line,
                    coordinates: path.offset(by: offset * scale).map(\.location),
                    // A little wider than the spacing, so no map shows through between stripes.
                    width: TrackStripes.width + 0.4)
            }
        }
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

/// One line's colour on one piece of rail, already moved to its place in the band.
private struct TrackStripe: Identifiable {
    let track: Int
    let line: Int
    let coordinates: [CLLocationCoordinate2D]
    let width: CGFloat

    var id: String { "\(track)-\(line)" }
    var style: StrokeStyle { StrokeStyle(lineWidth: width, lineCap: .butt, lineJoin: .round) }
}

private struct FollowTarget: Equatable {
    let following: Bool
    let coordinate: Coordinate?
}
