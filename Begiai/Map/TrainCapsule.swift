import BegiaiKit
import SwiftUI

struct TrainCapsule: View {
    let color: Color
    let heading: Double
    let destination: String?
    let atStation: Bool
    let showsLabel: Bool
    var chosen = false
    /// At country zoom: a smaller marker with no glow.
    var compact = false
    @Environment(\.markerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    /// White on a colour, or a dark ring around it with high contrast.
    private var outline: Color { style.highContrast && colorScheme == .light ? .black : .white }

    /// The width of the marker at the normal scale.
    static let size: CGFloat = 28
    /// The station ring a standing train shows, as wide as a station's ring on the map.
    private static let ring: CGFloat = 10
    /// A tap this near the centre of a standing train is on its station ring.
    static let ringTapRadius: CGFloat = 8
    /// At country zoom the whole marker, its station ring too, is drawn at 0.75 of its size,
    /// so the crowded trains around Vilnius and Kaunas cover less of each other.
    private static let countryZoomFactor: CGFloat = 0.75

    /// How much larger than at the normal scale the marker is drawn: the rider's marker style,
    /// times the country-zoom factor. TrainsMap measures taps with it too.
    static func scale(_ style: MarkerStyle, compact: Bool) -> CGFloat {
        style.scale * (compact ? countryZoomFactor : 1)
    }

    var body: some View {
        let scale = Self.scale(style, compact: compact)
        let size = Self.size * scale
        // The marker alone is the annotation's centre, so it sits on its track; the label
        // hangs to its right and moves nothing.
        marker(size: size, scale: scale)
            .overlay(alignment: .leading) {
                if showsLabel, let destination {
                    Text(.mapTrainTo(station: destination))
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 4)
                        .background(.regularMaterial, in: .rect(cornerRadius: 4))
                        .fixedSize()
                        .offset(x: size * 1.15 + 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(.mapTrainLabel(station: destination ?? "")))
            .accessibilityValue(atStation ? Text(.mapTrainStanding) : Text(verbatim: ""))
            .accessibilityIdentifier(A11yID.Map.train)
    }

    /// The whole body points the way the train runs: a long nose with a windscreen at the
    /// front and a square back, so the direction reads at a glance at any angle.
    private func marker(size: CGFloat, scale: CGFloat) -> some View {
        TrainBullet()
            .fill(color)
            .overlay(TrainBullet().stroke(outline, lineWidth: chosen ? 3 : style.highContrast ? 2.5 : 1.5))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white)
                    .frame(width: size * 0.26, height: size * 0.1)
                    .padding(.top, size * 0.3)
            }
            .frame(width: size * 0.5, height: size * 0.9)
            .rotationEffect(.degrees(heading))
            .frame(width: size, height: size)
            // MapKit draws trains over station rings whatever the order, so a train that
            // stands at a station shows the ring at its centre; TrainsMap opens the station
            // from a tap there.
            .overlay {
                if atStation {
                    Circle()
                        .fill(.background)
                        .stroke(.primary, lineWidth: 2)
                        .frame(width: Self.ring * scale, height: Self.ring * scale)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.circle)
            .scaleEffect(chosen ? 1.3 : 1)
            // A standing train glows, still, at city zoom; at country zoom the glow would
            // blur the crowded markers.
            .shadow(color: color.opacity(glows ? 0.6 : 0), radius: glows ? 6 : 0)
    }

    private var glows: Bool { atStation && !compact }
}

/// A train seen from above, pointing up: a pointed nose over the top 40 %, then straight
/// sides and a rounded back.
nonisolated struct TrainBullet: SwiftUI.Shape {
    func path(in rect: CGRect) -> Path {
        let nose = rect.height * 0.4
        let back = min(rect.width / 2, 4)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + nose), control: CGPoint(x: rect.maxX, y: rect.minY + nose * 0.35))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - back))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - back, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + back, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - back), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + nose))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY + nose * 0.35))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        TrainCapsule(color: LinePalette().color(forLine: 0), heading: 290, destination: "Kaunas", atStation: false, showsLabel: true)
        TrainCapsule(color: LinePalette().color(forLine: 1), heading: 90, destination: "Vilnius", atStation: true, showsLabel: false)
        TrainCapsule(
            color: LinePalette().color(forLine: 1), heading: 90, destination: "Vilnius", atStation: true, showsLabel: false, compact: true)
    }
    .padding()
}
