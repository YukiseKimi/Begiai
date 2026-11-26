/// The Follow button on a train's page. Follow does two things: the map keeps the train in
/// its middle, and the Lock Screen shows the train. A drag on the map lets the map go, but the
/// Lock Screen keeps the train, so the button then brings the train back and ends nothing.
public enum FollowState: Hashable, Sendable {
    /// The train is not followed: “Follow”.
    case off
    /// The train is followed, and the map keeps it in the middle: “Following”.
    case following
    /// The train is followed, but the map was moved away from it: “Show train”.
    case released

    public init(followed: Bool, mapFollows: Bool) {
        self = followed ? (mapFollows ? .following : .released) : .off
    }

    /// What a tap on the button makes it: Follow starts both, Following ends both, and Show
    /// train moves the map back to the train.
    public var tapped: FollowState {
        switch self {
        case .off, .released: .following
        case .following: .off
        }
    }

    /// True while the train is followed, whether or not the map keeps it in the middle.
    public var isFollowed: Bool { self != .off }
}
