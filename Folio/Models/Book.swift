import Foundation
import SwiftData

nonisolated enum BookStatus: String, Codable, Sendable, CaseIterable {
    case reading
    case read
    case paused
    case historicalRead
    case wishlist
}

nonisolated enum PauseReason: String, Codable, Sendable, CaseIterable, Identifiable {
    case toneMismatch = "Tone mismatch"
    case timing = "Timing"
    case pacing = "Pacing"
    case languageStyle = "Language style"
    case personalMood = "Personal mood"
    case other = "Other"

    var id: String { rawValue }
}

@Model
class Book {
    var title: String
    var authors: [String]
    var publishYear: Int?
    var language: String?
    var coverURL: String?
    var volumeId: String?
    var isbn: [String]
    var bookDescription: String?
    var subjects: [String]
    var statusRaw: String
    var rating: Int?
    var startedAt: Date?
    var finishedAt: Date?
    var pausedReason: String?
    var pauseReasonTags: [String]
    var createdAt: Date
    var lastOpenedAt: Date?
    var pageCount: Int?

    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var sessions: [ReadingSession] = []

    @Transient
    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .reading }
        set { statusRaw = newValue.rawValue }
    }

    @Transient
    var pauseReasons: [PauseReason] {
        get { pauseReasonTags.compactMap { PauseReason(rawValue: $0) } }
        set { pauseReasonTags = newValue.map(\.rawValue) }
    }

    /// True if this book was logged historically (no session data).
    @Transient
    var isHistorical: Bool {
        status == .historicalRead || (status == .read && sessions.isEmpty)
    }

    /// True if this book was actively tracked and completed with session data.
    @Transient
    var isActivelyCompleted: Bool {
        status == .read && !sessions.isEmpty
    }

    @Transient
    var daysSinceLastSession: Int? {
        guard let lastSession = sessions.sorted(by: { $0.startedAt > $1.startedAt }).first else { return nil }
        return Calendar.current.dateComponents([.day], from: lastSession.startedAt, to: Date()).day
    }

    @Transient
    var wasReturned: Bool {
        guard let days = daysSinceLastSession else { return false }
        return days > 30 && status == .reading
    }

    @Transient
    var returnGapDescription: String? {
        guard sessions.count >= 2 else { return nil }
        let sorted = sessions.sorted(by: { $0.startedAt < $1.startedAt })
        var maxGap = 0
        var gapEnd: Date?
        for i in 1..<sorted.count {
            let gap = Calendar.current.dateComponents([.day], from: sorted[i-1].startedAt, to: sorted[i].startedAt).day ?? 0
            if gap > maxGap {
                maxGap = gap
                gapEnd = sorted[i].startedAt
            }
        }
        guard maxGap > 30, let _ = gapEnd else { return nil }
        if maxGap > 365 {
            let years = maxGap / 365
            return "You returned to this after \(years) year\(years == 1 ? "" : "s")."
        } else if maxGap > 30 {
            let months = maxGap / 30
            return "You returned to this after \(months) month\(months == 1 ? "" : "s")."
        }
        return nil
    }

    @Transient
    var totalSessionMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    init(
        title: String,
        authors: [String] = [],
        publishYear: Int? = nil,
        language: String? = nil,
        coverURL: String? = nil,
        volumeId: String? = nil,
        isbn: [String] = [],
        bookDescription: String? = nil,
        subjects: [String] = [],
        status: BookStatus = .reading,
        rating: Int? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        pageCount: Int? = nil
    ) {
        self.title = title
        self.authors = authors
        self.publishYear = publishYear
        self.language = language
        self.coverURL = coverURL
        self.volumeId = volumeId
        self.isbn = isbn
        self.bookDescription = bookDescription
        self.subjects = subjects
        self.statusRaw = status.rawValue
        self.rating = rating
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.pauseReasonTags = []
        self.createdAt = Date()
        self.lastOpenedAt = nil
        self.pageCount = pageCount
    }
}
