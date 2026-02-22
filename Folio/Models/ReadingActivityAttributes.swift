import ActivityKit
import Foundation

nonisolated struct ReadingActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var elapsedSeconds: Int
        var startDate: Date
    }

    var bookTitle: String
    var authorName: String
}