import os

extension Logger {
    /// The one subsystem every log line of the app and the package carries.
    public static let begiaiSubsystem = "com.mannychau.begiai"

    public static func begiai(_ category: String) -> Logger {
        Logger(subsystem: begiaiSubsystem, category: category)
    }
}
