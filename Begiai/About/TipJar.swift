import StoreKit
import SwiftUI

/// Three tips in About. A tip is a consumable that unlocks nothing: the app only finishes
/// the transaction and says thank you.
struct TipJar: View {
    static let products = ["com.mannychau.begiai.tip.coffee", "com.mannychau.begiai.tip.ticket", "com.mannychau.begiai.tip.firstClass"]
    @State private var outcome: Outcome?

    private enum Outcome {
        case thanked, waiting, failed

        var text: LocalizedStringResource {
            switch self {
            case .thanked: .tipThanks
            case .waiting: .tipWaiting
            case .failed: .tipFailed
            }
        }

        var symbol: String {
            switch self {
            case .thanked: "heart.fill"
            case .waiting: "hourglass"
            case .failed: "exclamationmark.triangle"
            }
        }
    }

    var body: some View {
        Section {
            if let outcome {
                Label {
                    Text(outcome.text)
                } icon: {
                    Image(systemName: outcome.symbol)
                        .foregroundStyle(outcome == .thanked ? Color.pink : Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(A11yID.About.tipThanks)
            }
            ForEach(Self.products, id: \.self) { id in
                ProductView(id: id)
                    .productViewStyle(.compact)
            }
        } header: {
            Text(.tipTitle)
        } footer: {
            Text(.tipFooter)
        }
        .onInAppPurchaseCompletion { _, result in
            switch result {
            case .success(.success(.verified(let transaction))):
                await transaction.finish()
                outcome = .thanked
            case .success(.pending):
                outcome = .waiting
            case .success(.userCancelled):
                outcome = nil
            default:
                outcome = .failed
            }
            // The row shows above the buy buttons, where VoiceOver focus is not.
            if let outcome {
                AccessibilityNotification.Announcement(String(localized: outcome.text)).post()
            }
        }
    }

    /// Finishes a tip that completed while the app was away, for example after Ask to Buy.
    static func finishUnfinished() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update { await transaction.finish() }
        }
    }
}
