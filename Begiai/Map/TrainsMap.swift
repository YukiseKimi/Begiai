import BegiaiKit
import MapKit
import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// The map with its tracks, stations and trains. It is the one view that reads the trains
/// each frame, so a frame redraws the markers and not the panel.
struct TrainsMap: View {
    let store: TimetableStore
    let trains: TrainsModel
    @Binding var position: MapCameraPosition
    @Binding var selection: PageSelection?
    /// The train the map keeps in its middle, nil while the map is free. Only the chosen train
    /// can be followed: choosing another, or none, lets it go.
    @Binding var following: TrainState.ID?
    @Binding var panelHeight: PanelHeight
    @Binding var locationNote: LocationNote?
    /// What the map keeps clear for the panel, from the screen's edges: the bottom for the
    /// panel on an iPhone, the trailing side for the column on a wide screen. The camera, Follow
    /// and Locate keep the chosen train in the rest.
    let insets: EdgeInsets
    @State private var cameraHeading = 0.0
    @State private var cameraDistance = 400_000.0
    /// The ground distance one point of the screen covers at its centre, in steps of a quarter
    /// of a doubling, so the stripes are worked out again only when the zoom has moved a step.
    @State private var metresPerPoint = 1_000.0
    @State private var mapSize = CGSize(width: 400, height: 800)
    @State private var stripes: [TrackStripe] = []
    @Namespace private var mapScope
    @Environment(\.linePalette) private var palette
    @Environment(\.markerStyle) private var markerStyle

    var body: some View {
        let cityZoom = trains.cityZoom
        let moving = trains.moving(for: store.revision)
        let chosen = moving.first { selection == .train($0.id) }
        let followed = chosen.flatMap { $0.id == following ? $0 : nil }
        // At country zoom a station's 44-point tap area reaches past its ring, so while a train
        // stands there the station keeps only its ring and the train gets the taps around it.
        // Each frame reads the trains, and only this view does: O(trains) here is the map's work.
        let underTrains = cityZoom ? [] : Set(moving.compactMap(standingStation(of:)))
        let markers = moving.map(marker(of:))
        let open = MapOpener(selection: $selection, panelHeight: $panelHeight)
        MapReader { proxy in
            Map(position: $position, scope: mapScope) {
                UserAnnotation()
                ForEach(stripes) { stripe in
                    MapPolyline(coordinates: stripe.coordinates)
                        .stroke(stripe.color, style: stripe.style)
                }
                ForEach(stations, id: \.index) { station, info in
                    Annotation("", coordinate: info.coordinate.location, anchor: .center) {
                        StationMarker(
                            name: info.name, station: station, chosen: selection == .station(station), compact: !cityZoom,
                            underTrain: underTrains.contains(station), open: open)
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(markers) { marker in
                    Annotation("", coordinate: marker.coordinate.location, anchor: .center) {
                        MapTrain(look: marker.look, compact: !cityZoom, open: open)
                    }
                    .annotationTitles(.hidden)
                }
                // MapKit draws trains over station rings whatever the order, so a standing
                // train covers its ring: once the rider picks the train, a button over it
                // opens the station.
                if let chosen, let standing = standingStation(of: chosen),
                    let info = store.timetable?.stations[standing]
                {
                    Annotation("", coordinate: info.coordinate.location, anchor: .bottom) {
                        StationChip(name: info.name, station: standing, selection: $selection)
                            .padding(.bottom, 22 * markerStyle.scale)
                    }
                    .annotationTitles(.hidden)
                }
            }
            // A tap on the map away from the markers is a tap outside the panel: it closes the
            // train or station open there, or else lowers the panel to show the map.
            .gesture(
                MapTap {
                    guard selection != nil else { return false }
                    selection = nil
                    return true
                } unlessDoubleTap: {
                    if panelHeight != .peek { panelHeight = .peek }
                }
            )
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
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: { size in
                mapSize = size
                measureScale(with: proxy)
            }
        }
        .onChange(of: metresPerPoint) { buildStripes() }
        .onChange(of: store.revision, initial: true) { buildStripes() }
        .onChange(of: followed?.coordinate, initial: true) { _, coordinate in
            guard let coordinate else { return }
            position = .camera(
                MapCamera(
                    centerCoordinate: coordinate.location, distance: min(cameraDistance, 25_000),
                    heading: cameraHeading))
        }
        .onChange(of: selection) { _, selection in
            if let following, selection != .train(following) { self.following = nil }
        }
        .onChange(of: position.positionedByUser) { _, byUser in
            if byUser { following = nil }
        }
        .safeAreaPadding(insets)
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 10) {
                LocateButton(
                    position: $position, locationNote: $locationNote, panelHeight: $panelHeight, following: $following)
                AboutButton(timetable: store.timetable)
                MapCompass(scope: mapScope)
            }
            .padding()
            // Beside the column, never under it.
            .padding(.trailing, insets.trailing)
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
        let metres =
            CLLocation(latitude: left.latitude, longitude: left.longitude)
            .distance(from: CLLocation(latitude: right.latitude, longitude: right.longitude)) / 100
        guard metres > 0 else { return }
        let step = pow(2, (log2(metres) * 4).rounded() / 4)
        if step != metresPerPoint { metresPerPoint = step }
    }

    /// Works out the stripes for the tracks at the map's scale. A track with one line is a solid
    /// line on the rail; on a shared track each line is a stripe of its own beside the others.
    private func buildStripes() {
        let scale = metresPerPoint
        // The store gives a new timetable its line colours, and the palette with them, so the
        // stripes take their colours here, each time the revision moves.
        stripes = store.tracks.flatMap { track in
            guard track.lines.count > 1 else {
                let line = track.lines.first ?? 0
                return [
                    TrackStripe(
                        id: .init(track: track.id, line: line), color: palette.color(forLine: line), coordinates: track.coordinates,
                        width: 3)
                ]
            }
            let path = track.coordinates.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
            return zip(track.lines, TrackStripes.offsets(count: track.lines.count, along: path)).map { line, offset in
                TrackStripe(
                    id: .init(track: track.id, line: line), color: palette.color(forLine: line),
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

    /// The station a train stands at, by the engine's rule.
    private func standingStation(of train: TrainState) -> Int? {
        store.engine?.standingStation(of: train)
    }

    /// A train's marker, worked out from the train: its colour, its heading on the screen, where
    /// it goes and where it stands.
    private func marker(of train: TrainState) -> TrainMarker {
        let trip = store.timetable?.trips[train.trip]
        let destination = trip?.stops.last.flatMap { stop in
            store.timetable?.stations.indices.contains(stop.station) == true
                ? store.timetable?.stations[stop.station].name : nil
        }
        return TrainMarker(
            coordinate: train.coordinate,
            look: TrainLook(
                id: train.id, color: palette.color(forLine: trip?.line ?? 0), heading: train.heading - cameraHeading,
                destination: destination,
                // One rule, the engine's, for the ring drawn and the ring tapped: a train boarding at
                // its first station stands there as much as one halfway along its trip.
                standingAt: standingStation(of: train), chosen: selection == .train(train.id)))
    }
}

/// Opens a train's or a station's page from the map, and raises a Small panel to half height
/// so the page shows. A value and not a closure, so a marker that takes it compares as unchanged
/// from frame to frame.
struct MapOpener {
    @Binding var selection: PageSelection?
    @Binding var panelHeight: PanelHeight

    func callAsFunction(_ page: PageSelection) {
        selection = page
        if panelHeight == .peek { panelHeight = .half }
    }
}

/// A train on the map: where it is, and how its marker looks.
private struct TrainMarker: Identifiable {
    let coordinate: Coordinate
    let look: TrainLook

    var id: TrainState.ID { look.id }
}

/// How a train's marker looks, apart from where it is, so the marker's body runs again only
/// when it changes, not each frame as the train moves on.
private struct TrainLook: Equatable {
    let id: TrainState.ID
    let color: Color
    /// The way the train runs, on the screen: its heading less the map's.
    let heading: Double
    let destination: String?
    /// The station the train stands at, if it stands at one.
    let standingAt: Int?
    let chosen: Bool
}

/// A train's marker. MapKit gives a touch on a train to the train, whatever its shape, so the
/// train decides: a tap on the station ring at its centre opens the station, the rest the train.
private struct MapTrain: View {
    let look: TrainLook
    /// At country zoom: a smaller marker, with no label.
    let compact: Bool
    let open: MapOpener
    @Environment(\.markerStyle) private var markerStyle

    var body: some View {
        TrainCapsule(
            color: look.color, heading: look.heading, destination: look.destination, atStation: look.standingAt != nil,
            showsLabel: !compact, chosen: look.chosen, compact: compact
        )
        .onTapGesture(coordinateSpace: .local) { point in
            // The same scale as the marker is drawn at, smaller at country zoom.
            let scale = TrainCapsule.scale(markerStyle, compact: compact)
            let size = TrainCapsule.size * scale
            let away = hypot(point.x - size / 2, point.y - size / 2)
            if let station = look.standingAt, away <= TrainCapsule.ringTapRadius * scale {
                open(.station(station))
            } else {
                open(.train(look.id))
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open(.train(look.id)) }
    }
}

/// “Vievis ›” over a chosen train that stands at a station: one tap opens the station's board.
private struct StationChip: View {
    let name: String
    let station: Int
    @Binding var selection: PageSelection?

    var body: some View {
        Button {
            selection = .station(station)
        } label: {
            // The chevron says the chip opens something; it does not stand for the station,
            // so the name and the chevron stay two views, not a label.
            HStack(spacing: 2) {
                Text(verbatim: name)
                Image(systemName: "chevron.forward")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: .capsule)
            .overlay(Capsule().stroke(.primary.opacity(0.25), lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityHint(Text(.boardStationHint))
        .accessibilityIdentifier(A11yID.Map.stationChip)
    }
}

/// One line's colour on one piece of rail, already moved to its place in the band.
private struct TrackStripe: Identifiable {
    struct ID: Hashable {
        let track: Int
        let line: Int
    }

    let id: ID
    let color: Color
    let coordinates: [CLLocationCoordinate2D]
    let width: CGFloat

    var style: StrokeStyle { StrokeStyle(lineWidth: width, lineCap: .butt, lineJoin: .round) }
}

/// A tap on the map itself, not on a marker. SwiftUI's `onTapGesture` on a `Map` waits about a
/// third of a second to tell a tap from MapKit's double-tap zoom; this tap acts as the finger
/// lifts, through `now`. When `now` has nothing to do, `unlessDoubleTap` acts once that wait is
/// over, unless a second tap came: what it changes would stop the zoom. The second tap of a
/// double-tap zooms, and does not count again.
private struct MapTap: UIGestureRecognizerRepresentable {
    /// Acts at once, and says whether it did anything.
    let now: () -> Bool
    let unlessDoubleTap: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> StillTapRecognizer {
        let tap = StillTapRecognizer()
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        return tap
    }

    func handleUIGestureRecognizerAction(_ recognizer: StillTapRecognizer, context: Context) {
        guard recognizer.state == .ended, !now() else { return }
        context.coordinator.afterTheDoubleTapWait(unlessDoubleTap)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// The longest gap between the two taps of a double-tap.
        static let doubleTapWait = Duration.milliseconds(350)
        private var waiting: Task<Void, Never>?

        func afterTheDoubleTapWait(_ action: @escaping () -> Void) {
            waiting?.cancel()
            waiting = Task {
                try? await Task.sleep(for: Self.doubleTapWait)
                if !Task.isCancelled { action() }
            }
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // The second tap of a double-tap zooms: what waits for it does not happen.
            guard touch.tapCount == 1 else {
                waiting?.cancel()
                return false
            }
            // A train or a station takes its own taps.
            return !sequence(first: touch.view, next: { $0?.superview }).contains { $0 is MKAnnotationView }
        }

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}

/// A tap that fails once the finger moves 10 points, where MapKit starts to pan the map. Less
/// is a hand that shakes on a moving train. A plain tap recognizer lets the finger go much
/// further, so a short drag would both move the map and close the panel.
private final class StillTapRecognizer: UITapGestureRecognizer {
    private var start: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        start = touches.first?.location(in: nil)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let start, let point = touches.first?.location(in: nil) else { return }
        if hypot(point.x - start.x, point.y - start.y) >= 10 { state = .failed }
    }

    override func reset() {
        super.reset()
        start = nil
    }
}
