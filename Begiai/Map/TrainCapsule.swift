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

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(heading))
                .frame(width: 26, height: 14)
                .background(color, in: .capsule)
                .overlay(Capsule().stroke(.white, lineWidth: chosen ? 3 : 1.5))
                .scaleEffect(chosen ? 1.3 : 1)
                .shadow(color: color.opacity(atStation ? 0.6 : 0), radius: atStation ? 6 : 0)
                .phaseAnimator(atStation && !reduceMotion ? [false, true] : [false]) { content, wide in
                    content.scaleEffect(wide ? 1.15 : 1)
                } animation: { _ in
                    .easeInOut(duration: 0.8)
                }
            if showsLabel, let destination {
                Text(.mapTrainTo(station: destination))
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 4)
                    .background(.regularMaterial, in: .rect(cornerRadius: 4))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.mapTrainLabel(station: destination ?? "")))
        .accessibilityIdentifier(A11yID.Map.train)
    }
}

#Preview {
    VStack(spacing: 20) {
        TrainCapsule(color: LinePalette.color(forLine: 0), heading: 290, destination: "Kaunas", atStation: false, showsLabel: true)
        TrainCapsule(color: LinePalette.color(forLine: 1), heading: 90, destination: "Vilnius", atStation: true, showsLabel: false)
    }
    .padding()
}
