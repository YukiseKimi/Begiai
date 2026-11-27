import SwiftUI

/// Three cards on the first launch: the trains are estimates, how to read one, and what a
/// tap does. About keeps the same facts for later.
struct WelcomeSheet: View {
    /// Start closes the sheet, which marks the welcome as seen.
    @Environment(\.dismiss) private var dismiss
    @State private var card = 0
    /// The card whose title VoiceOver reads. It moves on with the shown card, also to a page
    /// that the TabView builds only as it shows it.
    @AccessibilityFocusState private var focusedCard: Int?

    private static let cards = [
        WelcomeCardText(symbol: "clock.arrow.circlepath", title: .welcomeEstimateTitle, text: .welcomeEstimateText),
        WelcomeCardText(symbol: "location.north.circle", title: .welcomeMarksTitle, text: .welcomeMarksText, showsMarkers: true),
        WelcomeCardText(symbol: "hand.tap", title: .welcomeFollowTitle, text: .welcomeFollowText),
    ]

    var body: some View {
        // The focus binding is the same for the sheet's life: the body takes it once and gives
        // it to each page, so no page reads the sheet.
        let focus = $focusedCard
        VStack(spacing: 24) {
            TabView(selection: $card) {
                ForEach(Self.cards.indices, id: \.self) { index in
                    WelcomePage(card: Self.cards[index], index: index, shown: card == index, focusedCard: focus)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            // VoiceOver reads the new card, not the Next button again.
            .onChange(of: card) { focusedCard = card }

            Button {
                if card < Self.cards.count - 1 {
                    withAnimation { card += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(card < Self.cards.count - 1 ? .welcomeNext : .welcomeStart)
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

/// What one card says.
private struct WelcomeCardText {
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource
    /// The card on how to read a train shows two train markers.
    var showsMarkers = false
}

/// One card: centred when it fits; it scrolls at large text sizes.
private struct WelcomePage: View {
    let card: WelcomeCardText
    let index: Int
    /// True while this card is the one the sheet shows.
    let shown: Bool
    var focusedCard: AccessibilityFocusState<Int?>.Binding

    var body: some View {
        ViewThatFits(in: .vertical) {
            WelcomeCard(card: card, index: index, shown: shown, focusedCard: focusedCard)
                .frame(maxHeight: .infinity)
            ScrollView {
                WelcomeCard(card: card, index: index, shown: shown, focusedCard: focusedCard)
            }
        }
    }
}

private struct WelcomeCard: View {
    let card: WelcomeCardText
    let index: Int
    let shown: Bool
    /// The card whose title VoiceOver reads, which the sheet moves on.
    var focusedCard: AccessibilityFocusState<Int?>.Binding

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: card.symbol)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(card.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(shown ? A11yID.Welcome.title : "")
                .accessibilityFocused(focusedCard, equals: index)
            if card.showsMarkers {
                HStack(spacing: 24) {
                    TrainCapsule(color: LinePalette().color(forLine: 0), heading: 90, destination: nil, atStation: false, showsLabel: false)
                    TrainCapsule(color: LinePalette().color(forLine: 3), heading: 270, destination: nil, atStation: true, showsLabel: false)
                }
                .padding(.vertical, 8)
                .accessibilityHidden(true)
            }
            Text(card.text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }
}

#Preview {
    WelcomeSheet()
}
