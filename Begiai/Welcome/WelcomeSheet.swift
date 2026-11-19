import SwiftUI

/// Three cards on the first launch: the trains are estimates, how to read one, and what a
/// tap does. About keeps the same facts for later.
struct WelcomeSheet: View {
    let done: () -> Void
    @State private var card = 0
    @AccessibilityFocusState private var focusedTitle: Int?

    private struct Card {
        let symbol: String
        let title: LocalizedStringResource
        let text: LocalizedStringResource
    }

    private let cards = [
        Card(symbol: "clock.arrow.circlepath", title: .welcomeEstimateTitle, text: .welcomeEstimateText),
        Card(symbol: "arrowtriangle.up.circle", title: .welcomeMarksTitle, text: .welcomeMarksText),
        Card(symbol: "hand.tap", title: .welcomeFollowTitle, text: .welcomeFollowText),
    ]

    private func cardContent(_ index: Int) -> some View {
        VStack(spacing: 16) {
            Image(systemName: cards[index].symbol)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(cards[index].title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(card == index ? A11yID.Welcome.title : "")
                .accessibilityFocused($focusedTitle, equals: index)
            if index == 1 {
                HStack(spacing: 24) {
                    TrainCapsule(color: LinePalette.color(forLine: 0), heading: 90, destination: nil, atStation: false, showsLabel: false)
                    TrainCapsule(color: LinePalette.color(forLine: 3), heading: 270, destination: nil, atStation: true, showsLabel: false)
                }
                .padding(.vertical, 8)
                .accessibilityHidden(true)
            }
            Text(cards[index].text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $card) {
                ForEach(cards.indices, id: \.self) { index in
                    // Centred when it fits; it scrolls at large text sizes.
                    ViewThatFits(in: .vertical) {
                        cardContent(index)
                            .frame(maxHeight: .infinity)
                        ScrollView {
                            cardContent(index)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            // VoiceOver reads the new card, not the Next button again.
            .onChange(of: card) { focusedTitle = card }
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if card < cards.count - 1 {
                    withAnimation { card += 1 }
                } else {
                    done()
                }
            } label: {
                Text(card < cards.count - 1 ? .welcomeNext : .welcomeStart)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom)
            .accessibilityIdentifier(A11yID.Welcome.next)
        }
    }
}

#Preview {
    WelcomeSheet {}
}
