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
        .accessibilityIdentifier(A11yID.Notices.link)
    }
}

#Preview {
    NoticesLink()
}
