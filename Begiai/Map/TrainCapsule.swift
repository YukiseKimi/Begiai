import BegiaiKit
import SwiftUI

struct TrainCapsule: View {
    let color: Color
    let heading: Double
    let destination: String?
    let atStation: Bool
    let showsLabel: Bool
    var chosen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.markerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    /// White on a colour, or a dark ring around it with high contrast.
    private var outline: Color { style.highContrast && colorScheme == .light ? .black : .white }

    var body: some View {
        let size = 28 * style.scale
        // The marker alone is the annotation's centre, so it sits on its track; the label
        // hangs to its right and moves nothing.
        marker(size: size)
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
            .accessibilityIdentifier(A11yID.Map.train)
    }

    /// The whole body points the way the train runs: a long nose with a windscreen at the
    /// front and a square back, so the direction reads at a glance at any angle.
    private func marker(size: CGFloat) -> some View {
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
            .contentShape(.circle)
            .scaleEffect(chosen ? 1.3 : 1)
            .shadow(color: color.opacity(atStation ? 0.6 : 0), radius: atStation ? 6 : 0)
            .phaseAnimator(atStation && !reduceMotion ? [false, true] : [false]) { content, wide in
                content.scaleEffect(wide ? 1.15 : 1)
            } animation: { _ in
                .easeInOut(duration: 0.8)
            }
    }
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
    }
    .padding()
}
