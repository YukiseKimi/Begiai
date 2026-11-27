#if os(iOS)
    import ActivityKit

    /// The followed train is the Live Activity's fixed part, and its status the part that
    /// the app updates. The app and the widget extension share this one type.
    extension FollowedTrain: ActivityAttributes {
        public typealias ContentState = Status
    }
#endif
