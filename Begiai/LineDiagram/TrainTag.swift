import SwiftUI

/// “▼ → Kaunas” in the line colour: a train on the line diagram.
struct TrainTag: View {
    let color: Color
    let down: Bool
    let destination: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: down ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                .font(.system(size: 9, weight: .bold))
            Text(.mapTrainTo(station: destination))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color, in: .capsule)
    }
}

#Preview {
    TrainTag(color: .blue, down: true, destination: "Kaunas")
}
