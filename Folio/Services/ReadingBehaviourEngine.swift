import Foundation

/// Lightweight inference system for reading behaviour analysis.
/// No ML dependencies — pure computation from session and book data.
nonisolated enum ReadingBehaviourEngine {

    // MARK: - Behavioural Profile

    struct BehaviourProfile: Sendable {
        let preferredTimeWindow: String?
        let averageSessionMinutes: Int
        let sessionLengthTrend: Trend
        let completionRate: Double
        let abandonmentRate: Double
        let topGenres: [(genre: String, weight: Double)]
        let topAuthors: [(author: String, count: Int)]
        let moodProfile: String?
        let readingSignature: String
    }

    enum Trend: Sendable {
        case increasing, decreasing, stable, insufficient
    }

    // MARK: - Compute Profile

    static func computeProfile(books: [Book], sessions: [ReadingSession]) -> BehaviourProfile {
        let activeSessions = sessionsFromActiveBooks(books: books, sessions: sessions)

        let preferredTime = computePreferredTimeWindow(sessions: activeSessions)
        let avgMinutes = computeAverageSession(sessions: activeSessions)
        let trend = computeSessionTrend(sessions: activeSessions)
        let completionRate = computeCompletionRate(books: books)
        let abandonmentRate = computeAbandonmentRate(books: books)
        let topGenres = computeGenreDensity(books: books, sessions: sessions)
        let topAuthors = computeAuthorRecurrence(books: books)
        let moodProfile = computeMoodProfile(sessions: activeSessions)
        let signature = generateSignature(
            books: books,
            sessions: activeSessions,
            preferredTime: preferredTime,
            avgMinutes: avgMinutes,
            completionRate: completionRate,
            topGenres: topGenres,
            moodProfile: moodProfile
        )

        return BehaviourProfile(
            preferredTimeWindow: preferredTime,
            averageSessionMinutes: avgMinutes,
            sessionLengthTrend: trend,
            completionRate: completionRate,
            abandonmentRate: abandonmentRate,
            topGenres: topGenres,
            topAuthors: topAuthors,
            moodProfile: moodProfile,
            readingSignature: signature
        )
    }

    // MARK: - Filter out historical sessions

    private static func sessionsFromActiveBooks(books: [Book], sessions: [ReadingSession]) -> [ReadingSession] {
        let historicalTitles = Set(books.filter { $0.isHistorical }.map { $0.title })
        return sessions.filter { session in
            guard let bookTitle = session.book?.title else { return true }
            return !historicalTitles.contains(bookTitle)
        }
    }

    // MARK: - Time Window

    private static func computePreferredTimeWindow(sessions: [ReadingSession]) -> String? {
        guard sessions.count >= 3 else { return nil }

        var hourBuckets: [Int: Int] = [:]
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startedAt)
            hourBuckets[hour, default: 0] += session.durationMinutes
        }

        guard let peakHour = hourBuckets.max(by: { $0.value < $1.value })?.key else { return nil }

        switch peakHour {
        case 5..<9: return "early morning"
        case 9..<12: return "mid-morning"
        case 12..<14: return "midday"
        case 14..<17: return "afternoon"
        case 17..<20: return "early evening"
        case 20..<23: return "late evening"
        default: return "late at night"
        }
    }

    // MARK: - Average Session

    private static func computeAverageSession(sessions: [ReadingSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.durationMinutes } / sessions.count
    }

    // MARK: - Session Trend

    private static func computeSessionTrend(sessions: [ReadingSession]) -> Trend {
        guard sessions.count >= 6 else { return .insufficient }

        let sorted = sessions.sorted(by: { $0.startedAt < $1.startedAt })
        let half = sorted.count / 2
        let firstHalf = sorted.prefix(half)
        let secondHalf = sorted.suffix(half)

        let avgFirst = firstHalf.reduce(0) { $0 + $1.durationMinutes } / max(firstHalf.count, 1)
        let avgSecond = secondHalf.reduce(0) { $0 + $1.durationMinutes } / max(secondHalf.count, 1)

        let diff = avgSecond - avgFirst
        if diff > 3 { return .increasing }
        if diff < -3 { return .decreasing }
        return .stable
    }

    // MARK: - Completion & Abandonment

    private static func computeCompletionRate(books: [Book]) -> Double {
        let activeBooks = books.filter { !$0.isHistorical }
        let finished = activeBooks.filter { $0.status == .read }.count
        let total = activeBooks.filter { $0.status == .read || $0.status == .paused }.count
        guard total > 0 else { return 0 }
        return Double(finished) / Double(total)
    }

    private static func computeAbandonmentRate(books: [Book]) -> Double {
        let activeBooks = books.filter { !$0.isHistorical }
        let paused = activeBooks.filter { $0.status == .paused }.count
        let total = activeBooks.filter { $0.status == .read || $0.status == .paused || $0.status == .reading }.count
        guard total > 0 else { return 0 }
        return Double(paused) / Double(total)
    }

    // MARK: - Genre Density (weighted by session time, not book count)

    static func computeGenreDensity(books: [Book], sessions: [ReadingSession]) -> [(genre: String, weight: Double)] {
        var genreMinutes: [String: Int] = [:]
        var totalMinutes = 0

        for book in books where !book.isHistorical {
            let bookMinutes = book.totalSessionMinutes
            totalMinutes += bookMinutes
            for subject in book.subjects {
                let clean = subject.trimmingCharacters(in: .whitespaces)
                guard !clean.isEmpty else { continue }
                genreMinutes[clean, default: 0] += max(bookMinutes, 1)
            }
        }

        // Also count historical books but with weight of 1
        for book in books where book.isHistorical {
            for subject in book.subjects {
                let clean = subject.trimmingCharacters(in: .whitespaces)
                guard !clean.isEmpty else { continue }
                genreMinutes[clean, default: 0] += 1
            }
            totalMinutes += 1
        }

        guard totalMinutes > 0 else { return [] }

        return genreMinutes
            .map { (genre: $0.key, weight: Double($0.value) / Double(totalMinutes)) }
            .sorted { $0.weight > $1.weight }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Author Recurrence

    static func computeAuthorRecurrence(books: [Book]) -> [(author: String, count: Int)] {
        var authorCounts: [String: Int] = [:]
        for book in books {
            for author in book.authors {
                authorCounts[author, default: 0] += 1
            }
        }
        return authorCounts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { (author: $0.key, count: $0.value) }
    }

    // MARK: - Mood Profile

    private static func computeMoodProfile(sessions: [ReadingSession]) -> String? {
        let moods = sessions.compactMap { $0.moodWord }
        return moods.mostFrequent
    }

    // MARK: - Reading Signature

    private static func generateSignature(
        books: [Book],
        sessions: [ReadingSession],
        preferredTime: String?,
        avgMinutes: Int,
        completionRate: Double,
        topGenres: [(genre: String, weight: Double)],
        moodProfile: String?
    ) -> String {
        let activeBooks = books.filter { !$0.isHistorical }
        let totalBooks = books.count
        guard totalBooks > 0, sessions.count >= 2 else {
            return "Begin reading to discover your patterns."
        }

        var sentences: [String] = []

        // Genre affinity
        if let primary = topGenres.first {
            let genreLower = primary.genre.lowercased()
            if topGenres.count >= 2 {
                let secondary = topGenres[1].genre.lowercased()
                sentences.append("You gravitate toward \(genreLower) and \(secondary).")
            } else {
                sentences.append("You gravitate toward \(genreLower).")
            }
        }

        // Mood & tempo
        if let mood = moodProfile {
            if avgMinutes > 30 {
                sentences.append("Your sessions tend to feel \(mood), running long and immersive.")
            } else if avgMinutes > 0 {
                sentences.append("Your sessions tend to feel \(mood), in measured intervals.")
            }
        }

        // Time preference
        if let time = preferredTime {
            sentences.append("You tend to read \(time).")
        }

        // Completion behaviour
        if activeBooks.count >= 3 {
            if completionRate > 0.8 {
                sentences.append("Once you begin, you tend to finish.")
            } else if completionRate < 0.4 && completionRate > 0 {
                sentences.append("You're selective — willing to set aside what doesn't hold.")
            }
        }

        if sentences.isEmpty {
            return "Keep reading to reveal your patterns."
        }

        // Cap at 4 sentences
        return sentences.prefix(4).joined(separator: " ")
    }

    // MARK: - Dynamic Home Insight

    static func generateHomeInsight(books: [Book], sessions: [ReadingSession]) -> String? {
        let activeSessions = sessionsFromActiveBooks(books: books, sessions: sessions)
        guard !activeSessions.isEmpty else { return nil }

        let calendar = Calendar.current

        // Check for author recurrence
        let authorCounts = computeAuthorRecurrence(books: books)
        if let topAuthor = authorCounts.first, topAuthor.count >= 3 {
            let year = calendar.component(.year, from: Date())
            let thisYearBooks = books.filter {
                $0.authors.contains(topAuthor.author) &&
                calendar.component(.year, from: $0.createdAt) == year
            }
            if thisYearBooks.count >= 2 {
                return "You've returned to \(topAuthor.author) \(thisYearBooks.count) times this year."
            }
        }

        // Day-of-week pattern
        var dayBuckets: [Int: Int] = [:]
        for session in activeSessions {
            let weekday = calendar.component(.weekday, from: session.startedAt)
            dayBuckets[weekday, default: 0] += session.durationMinutes
        }
        if let peakDay = dayBuckets.max(by: { $0.value < $1.value })?.key, activeSessions.count >= 5 {
            let dayName = calendar.weekdaySymbols[peakDay - 1]
            if let timeWindow = computePreferredTimeWindow(sessions: activeSessions) {
                return "You read most on \(dayName) \(timeWindow)s."
            }
        }

        // Session trend
        let trend = computeSessionTrend(sessions: activeSessions)
        if trend == .increasing {
            return "Your sessions have grown longer recently."
        } else if trend == .decreasing {
            return "Your sessions have been shorter lately."
        }

        // Mood
        let recentMoods = activeSessions.prefix(10).compactMap { $0.moodWord }
        if let mood = recentMoods.mostFrequent {
            return "Recently, your sessions tend to feel \(mood)."
        }

        return nil
    }

    // MARK: - Temporal Awareness

    static func generateTemporalLine(sessions: [ReadingSession]) -> String? {
        guard let lastSession = sessions.sorted(by: { $0.startedAt > $1.startedAt }).first else {
            return nil
        }

        let days = Calendar.current.dateComponents([.day], from: lastSession.startedAt, to: Date()).day ?? 0

        if days >= 14 {
            return "It's been a couple of weeks since you last read."
        } else if days >= 7 {
            return "It's been about a week since your last session."
        } else if days >= 5 {
            return "It's been a few days since you last read."
        }

        return nil
    }

    // MARK: - Monthly Reflection (Interpretive)

    static func generateMonthlyReflection(books: [Book], sessions: [ReadingSession]) -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        let monthSessions = sessions.filter {
            $0.startedAt >= startOfMonth &&
            !(books.first(where: { b in b.title == $0.book?.title })?.isHistorical ?? false)
        }

        let totalMinutes = monthSessions.reduce(0) { $0 + $1.durationMinutes }
        let booksEngaged = Set(monthSessions.compactMap { $0.book?.title })
        let moods = monthSessions.compactMap { $0.moodWord }
        let topMood = moods.mostFrequent

        // Only count actively completed books (with sessions) finished this month
        let completedThisMonth = books.filter {
            $0.isActivelyCompleted &&
            $0.finishedAt != nil &&
            $0.finishedAt! >= startOfMonth
        }

        guard !monthSessions.isEmpty else {
            return "No reading sessions this month yet. The pages will wait."
        }

        var lines: [String] = []

        // Tone-first interpretation
        if totalMinutes > 300 && monthSessions.count > 10 {
            lines.append("You spent sustained time with your books this month, returning often and reading deeply.")
        } else if totalMinutes > 120 {
            lines.append("A steady month. You found time to read with some regularity.")
        } else if totalMinutes > 30 {
            lines.append("A quieter month. You dipped in briefly but didn't linger.")
        } else {
            lines.append("This month was gentle. A few moments with a book, nothing more.")
        }

        // Book engagement
        if booksEngaged.count > 2 {
            lines.append("You moved between \(booksEngaged.count) different books.")
        } else if booksEngaged.count == 1, let title = booksEngaged.first {
            lines.append("Your attention stayed with \(title).")
        }

        // Mood colour
        if let mood = topMood {
            lines.append("The prevailing feeling was \(mood).")
        }

        // Completion
        if !completedThisMonth.isEmpty {
            let titles = completedThisMonth.prefix(2).map { $0.title }
            if completedThisMonth.count == 1 {
                lines.append("You finished \(titles[0]).")
            } else {
                lines.append("You completed \(completedThisMonth.count) books, including \(titles.joined(separator: " and ")).")
            }
        }

        // Secondary numbers (never primary)
        if totalMinutes > 0 {
            lines.append("\(totalMinutes) minutes across \(monthSessions.count) session\(monthSessions.count == 1 ? "" : "s").")
        }

        return lines.joined(separator: " ")
    }

    // MARK: - Engagement Stats

    struct EngagementStats: Sendable {
        let averageSessionTrend: Trend
        let averageSessionMinutes: Int
        let completionRate: Double
        let abandonmentRate: Double
        let totalSessionCount: Int
        let totalMinutes: Int
    }

    static func computeEngagement(books: [Book], sessions: [ReadingSession]) -> EngagementStats {
        let activeSessions = sessionsFromActiveBooks(books: books, sessions: sessions)
        return EngagementStats(
            averageSessionTrend: computeSessionTrend(sessions: activeSessions),
            averageSessionMinutes: computeAverageSession(sessions: activeSessions),
            completionRate: computeCompletionRate(books: books),
            abandonmentRate: computeAbandonmentRate(books: books),
            totalSessionCount: activeSessions.count,
            totalMinutes: activeSessions.reduce(0) { $0 + $1.durationMinutes }
        )
    }
}
