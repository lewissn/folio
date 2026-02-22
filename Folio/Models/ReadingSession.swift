import Foundation
import SwiftData

@Model
class ReadingSession {
    var book: Book?
    var startedAt: Date
    var endedAt: Date?
    var durationMinutes: Int
    var pagesRead: Int?
    var reflectionText: String?
    var moodWord: String?
    var chapterReference: String?

    init(
        book: Book,
        startedAt: Date = Date(),
        durationMinutes: Int = 0
    ) {
        self.book = book
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
    }
}
