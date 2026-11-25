import SwiftUI

/// A link to LTG Link's own notices. ltglink.lt gives no terms that allow an app to show its
/// notices, and the notices name no line, so each line links to the same list.
struct NoticesLink: View {
    static let notices = URL(string: "https://ltglink.lt/svarbus-pranesimai")!

    var body: some View {
        Link(destination: Self.notices) {
            Label {
                Text(.noticesLink)
            } icon: {
                Image(systemName: "arrow.up.right.square")
            }
        }
        .font(.footnote)
        .speaksAsLink()
        .accessibilityIdentifier(A11yID.Notices.link)
    }
}

extension View {
    /// Makes VoiceOver call a `Link` a link, which says that it leaves the app. iOS 26.1 gives a
    /// SwiftUI `Link` the button trait instead; iOS 27 gives it the link trait.
    func speaksAsLink() -> some View {
        accessibilityRemoveTraits(.isButton).accessibilityAddTraits(.isLink)
    }
}

#Preview {
    NoticesLink()
}
