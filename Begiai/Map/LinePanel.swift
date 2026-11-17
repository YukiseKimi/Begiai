import BegiaiKit
import SwiftUI

enum PanelHeight: CaseIterable {
    case peek, half, full

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
    @GestureState private var drag: CGFloat = 0

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
                .accessibilityAction { step() }
                .accessibilityIdentifier(A11yID.Map.panel)
            header()
                .contentShape(.rect)
                .gesture(resize)
            content()
        }
        .frame(height: min(total, max(80, height.points(in: total) - drag)), alignment: .top)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(in: .rect(cornerRadius: 28))
        .padding(.horizontal, 8)
        .animation(.snappy, value: height)
    }

    private var resize: some Gesture {
        DragGesture()
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
