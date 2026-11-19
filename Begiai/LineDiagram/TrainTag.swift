import SwiftUI

/// “▼ → Kaunas” in the line colour: a train on the line diagram.
struct TrainTag: View {
    let color: Color
    let down: Bool
    let destination: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let large = typeSize.isAccessibilitySize
        HStack(spacing: 4) {
            Image(systemName: down ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                .imageScale(.small)
            // At accessibility sizes the triangle alone gives the way, so the name has the room,
            // on two lines and a little smaller rather than cut to “K…”.
            Group {
                if large {
                    Text(verbatim: destination)
                } else {
                    Text(.mapTrainTo(station: destination))
                }
            }
            .lineLimit(large ? 2 : 1)
            .minimumScaleFactor(large ? 0.5 : 0.8)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color, in: .rect(cornerRadius: large ? 12 : 100))
    }
}

#Preview {
    TrainTag(color: .blue, down: true, destination: "Kaunas")
}
