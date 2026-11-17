import SwiftUI

struct FirstTrainCard: View {
    let time: Date
    let origin: String
    let destination: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(.nightTitle)
                    .font(.headline)
            } icon: {
                Image(systemName: "moon.stars")
            }
            Text(.nightFirst(time: time.vilniusTime, origin: origin, destination: destination))
                .accessibilityIdentifier(A11yID.Map.firstTrain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    FirstTrainCard(time: .now, origin: "Vilnius", destination: "Kaunas")
}
