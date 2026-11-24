import BegiaiKit
import SwiftUI

enum PanelHeight: CaseIterable {
    case peek, half, full

    /// What VoiceOver says the panel's height is.
    var name: LocalizedStringResource {
        switch self {
        case .peek: .panelPeek
        case .half: .panelHalf
        case .full: .panelFull
        }
    }

    var taller: PanelHeight {
        switch self {
        case .peek: .half
        case .half, .full: .full
        }
    }

    var shorter: PanelHeight {
        switch self {
        case .full: .half
        case .half, .peek: .peek
        }
    }

    func points(in total: CGFloat) -> CGFloat {
        switch self {
        case .peek: 132
        case .half: total * 0.45
        case .full: total * 0.88
        }
    }
}

struct LinePanel<Header: View, Content: View>: View {
    @Binding var height: PanelHeight
    let total: CGFloat
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content
    /// How far the finger has moved the panel. When the finger lifts, it goes back to 0 with the
    /// same spring as the new height, so the panel glides to its height and does not jump first.
    @GestureState(resetTransaction: Transaction(animation: .snappy)) private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.secondary)
                .frame(width: 36, height: 5)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .onTapGesture { step() }
                .gesture(resize)
                .accessibilityElement()
                .accessibilityLabel(Text(.panelResize))
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(Text(height.name))
                .accessibilityAction { step() }
                // Swipe up or down with VoiceOver to make the panel taller or shorter.
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: height = height.taller
                    case .decrement: height = height.shorter
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier(A11yID.Map.panel)
            header()
                .contentShape(.rect)
                .gesture(resize)
            content()
        }
        .frame(height: min(total, max(80, height.points(in: total) - drag)), alignment: .top)
        // With Reduce Motion the panel lands at once when the finger lifts.
        .transaction(value: drag) { if reduceMotion { $0.animation = nil } }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(in: .rect(cornerRadius: 28))
        .padding(.horizontal, 8)
        // With Reduce Motion the panel takes its new height at once, with no spring.
        .animation(reduceMotion ? nil : .snappy, value: height)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: height)
    }

    private var resize: some Gesture {
        // Measured on the screen: the handle moves with the panel, so in its own space the
        // finger would seem to stand still, and the panel would shake and go the wrong way.
        DragGesture(coordinateSpace: .global)
            .updating($drag) { value, state, _ in state = value.translation.height }
            .onEnded { value in
                let target = height.points(in: total) - value.predictedEndTranslation.height
                height = PanelHeight.allCases.min { abs($0.points(in: total) - target) < abs($1.points(in: total) - target) } ?? height
            }
    }

    private func step() {
        height =
            switch height {
            case .peek: .half
            case .half: .full
            case .full: .peek
            }
    }
}
