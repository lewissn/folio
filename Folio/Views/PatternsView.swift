import SwiftUI
import SwiftData
import Charts

struct PatternsView: View {
    @Query private var allBooks: [Book]
    @Query(sort: \ReadingSession.startedAt, order: .reverse) private var allSessions: [ReadingSession]

    @State private var appeared: Bool = false
    @State private var showMonthlyReflection: Bool = false

    private var readBooks: [Book] {
        allBooks.filter { $0.status == .read }
    }

    private var pausedBooks: [Book] {
        allBooks.filter { $0.status == .paused }
    }

    private var readingSignature: String {
        let totalBooks = allBooks.count
        guard totalBooks > 0 else {
            return "Begin reading to discover your patterns."
        }

        let totalSessions = allSessions.count
        let totalMinutes = allSessions.reduce(0) { $0 + $1.durationMinutes }
        let avgSession = totalSessions > 0 ? totalMinutes / totalSessions : 0
        let moods = allSessions.compactMap { $0.moodWord }
        let topMood = moods.mostFrequent
        let finishedCount = readBooks.count
        let pausedCount = pausedBooks.count

        var sentences: [String] = []

        if totalBooks >= 30 {
            if let mood = topMood {
                sentences.append("You gravitate toward sessions that feel \(mood).")
            }
            if pausedCount > 0 && finishedCount > 0 {
                let ratio = Double(pausedCount) / Double(finishedCount + pausedCount)
                if ratio > 0.4 {
                    sentences.append("You tend to set aside books that don't hold your attention early.")
                } else {
                    sentences.append("Once you begin, you tend to finish.")
                }
            }
            if avgSession > 30 {
                sentences.append("Your reading runs long and immersive.")
            } else if avgSession > 0 {
                sentences.append("You read in measured, focused intervals.")
            }
            let pauseReasons = allBooks.flatMap { $0.pauseReasonTags }
            if let topReason = pauseReasons.mostFrequent {
                sentences.append("When you pause, it's often about \(topReason.lowercased()).")
            }
        } else if totalBooks >= 15 {
            if totalSessions > 0 {
                sentences.append("You have logged \(totalSessions) reading sessions totaling \(totalMinutes) minutes.")
            }
            if let mood = topMood {
                sentences.append("You often feel \(mood) while reading.")
            }
            if avgSession > 0 {
                sentences.append("Your sessions average around \(avgSession) minutes.")
            }
        } else {
            if totalSessions > 0 {
                sentences.append("You have logged \(totalSessions) reading session\(totalSessions == 1 ? "" : "s").")
            }
            if finishedCount > 0 {
                sentences.append("You have finished \(finishedCount) book\(finishedCount == 1 ? "" : "s").")
            }
            if let mood = topMood {
                sentences.append("You often feel \(mood) while reading.")
            }
        }

        return sentences.isEmpty ? "Keep reading to reveal your patterns." : sentences.joined(separator: " ")
    }

    private var hourlyData: [HourlyReading] {
        var distribution: [Int: Int] = [:]
        for session in allSessions {
            let hour = Calendar.current.component(.hour, from: session.startedAt)
            distribution[hour, default: 0] += session.durationMinutes
        }
        return (0..<24).map { HourlyReading(hour: $0, minutes: distribution[$0] ?? 0) }
    }

    private var reflectionThemes: [String] {
        let reflections = allSessions.compactMap { $0.reflectionText }.joined(separator: " ")
        let subjects = allBooks.flatMap { $0.subjects }.joined(separator: " ")
        let pauseReasons = allBooks.compactMap { $0.pausedReason }
        let combined = "\(reflections) \(subjects) \(pauseReasons.joined(separator: " "))"
        guard !combined.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let words = combined.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 4 }

        let stopWords: Set<String> = [
            "about", "would", "could", "should", "their", "there",
            "which", "these", "those", "being", "other", "after",
            "before", "really", "think", "thought", "still", "every",
            "fiction", "general"
        ]

        var freq: [String: Int] = [:]
        for word in words where !stopWords.contains(word) {
            freq[word, default: 0] += 1
        }

        return freq.sorted { $0.value > $1.value }
            .prefix(8)
            .map { $0.key }
    }

    private var readingSeasons: [ReadingSeason] {
        guard allSessions.count >= 5 else { return [] }

        let calendar = Calendar.current
        var seasonMap: [String: [ReadingSession]] = [:]

        for session in allSessions {
            let comps = calendar.dateComponents([.year, .month], from: session.startedAt)
            guard let year = comps.year, let month = comps.month else { continue }
            let quarter: String
            switch month {
            case 1...3: quarter = "Winter \(year)"
            case 4...6: quarter = "Spring \(year)"
            case 7...9: quarter = "Summer \(year)"
            default: quarter = "Autumn \(year)"
            }
            seasonMap[quarter, default: []].append(session)
        }

        return seasonMap.compactMap { name, sessions in
            guard sessions.count >= 2 else { return nil }
            let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
            let moods = sessions.compactMap { $0.moodWord }
            let topMood = moods.mostFrequent

            let bookIds = Set(sessions.compactMap { $0.book?.title })
            let subjects = sessions.compactMap { $0.book }.flatMap { $0.subjects }
            let topSubject = subjects.mostFrequent

            var description = ""
            if let subject = topSubject {
                description = subject.capitalized
            }
            if let mood = topMood {
                description += description.isEmpty ? mood.capitalized : " & \(mood)"
            }

            return ReadingSeason(
                name: name,
                sessionCount: sessions.count,
                totalMinutes: totalMinutes,
                description: description,
                bookTitles: Array(bookIds.prefix(3))
            )
        }
        .sorted { $0.name > $1.name }
    }

    private var monthlyReflectionText: String {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        let monthSessions = allSessions.filter { $0.startedAt >= startOfMonth }
        let totalMinutes = monthSessions.reduce(0) { $0 + $1.durationMinutes }
        let booksRead = Set(monthSessions.compactMap { $0.book?.title })
        let moods = monthSessions.compactMap { $0.moodWord }
        let topMood = moods.mostFrequent

        guard !monthSessions.isEmpty else {
            return "No reading sessions this month yet."
        }

        var lines: [String] = []
        lines.append("This month, you have spent \(totalMinutes) minutes reading across \(monthSessions.count) session\(monthSessions.count == 1 ? "" : "s").")

        if !booksRead.isEmpty {
            let bookList = booksRead.prefix(3).joined(separator: ", ")
            lines.append("You engaged with \(bookList).")
        }

        if let mood = topMood {
            lines.append("Your prevailing mood has been \(mood).")
        }

        let finishedThisMonth = allBooks.filter {
            $0.status == .read && $0.finishedAt != nil && $0.finishedAt! >= startOfMonth
        }
        if !finishedThisMonth.isEmpty {
            lines.append("You completed \(finishedThisMonth.count) book\(finishedThisMonth.count == 1 ? "" : "s").")
        }

        return lines.joined(separator: " ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reading Signature")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)

                        Text(readingSignature)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color.charcoal)
                            .lineSpacing(4)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: appeared)

                    if !allSessions.isEmpty {
                        Rectangle().fill(Color.hairline).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Rhythm")
                                .font(.system(.subheadline, design: .serif))
                                .foregroundStyle(Color.secondaryText)

                            Chart(hourlyData) { item in
                                BarMark(
                                    x: .value("Hour", item.hour),
                                    y: .value("Minutes", item.minutes)
                                )
                                .foregroundStyle(Color.warmAccent)
                                .clipShape(.rect(cornerRadius: 2))
                            }
                            .chartXAxis {
                                AxisMarks(values: [0, 6, 12, 18]) { value in
                                    AxisValueLabel {
                                        if let hour = value.as(Int.self) {
                                            Text(hourLabel(hour))
                                                .font(.caption2)
                                                .foregroundStyle(Color.secondaryText)
                                        }
                                    }
                                }
                            }
                            .chartYAxis(.hidden)
                            .frame(height: 120)

                            let avgSession = allSessions.reduce(0) { $0 + $1.durationMinutes } / max(allSessions.count, 1)
                            Text("Average session: \(avgSession) min")
                                .font(.serifCaption())
                                .foregroundStyle(Color.secondaryText)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.1), value: appeared)

                        Rectangle().fill(Color.hairline).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Completion")
                                .font(.system(.subheadline, design: .serif))
                                .foregroundStyle(Color.secondaryText)

                            HStack(spacing: 32) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(readBooks.count)")
                                        .font(.serifTitle(.title))
                                        .foregroundStyle(Color.charcoal)
                                    Text("Finished")
                                        .font(.serifCaption())
                                        .foregroundStyle(Color.secondaryText)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(pausedBooks.count)")
                                        .font(.serifTitle(.title))
                                        .foregroundStyle(Color.charcoal)
                                    Text("Paused")
                                        .font(.serifCaption())
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.2), value: appeared)
                    }

                    if !readingSeasons.isEmpty {
                        Rectangle().fill(Color.hairline).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reading Seasons")
                                .font(.system(.subheadline, design: .serif))
                                .foregroundStyle(Color.secondaryText)

                            ForEach(readingSeasons) { season in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(season.name)
                                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                                        .foregroundStyle(Color.charcoal)

                                    if !season.description.isEmpty {
                                        Text(season.description)
                                            .font(.system(.caption, design: .serif))
                                            .foregroundStyle(Color.secondaryText)
                                            .italic()
                                    }

                                    Text("\(season.sessionCount) sessions, \(season.totalMinutes) min")
                                        .font(.serifCaption())
                                        .foregroundStyle(Color.secondaryText)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.25), value: appeared)
                    }

                    if !reflectionThemes.isEmpty {
                        Rectangle().fill(Color.hairline).frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Themes")
                                .font(.system(.subheadline, design: .serif))
                                .foregroundStyle(Color.secondaryText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(reflectionThemes, id: \.self) { theme in
                                    Text(theme)
                                        .font(.serifCaption())
                                        .foregroundStyle(Color.charcoal)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.elevatedSurface, in: Capsule())
                                }
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.3), value: appeared)
                    }

                    if !allSessions.isEmpty {
                        Rectangle().fill(Color.hairline).frame(height: 0.5)

                        Button {
                            showMonthlyReflection = true
                        } label: {
                            HStack {
                                Text("Reflect on this month")
                                    .font(.system(.body, design: .serif, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundStyle(Color.charcoal)
                            .padding(16)
                            .background(Color.elevatedSurface, in: .rect(cornerRadius: 12))
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.35), value: appeared)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Patterns")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { appeared = true }
        .sheet(isPresented: $showMonthlyReflection) {
            MonthlyReflectionSheet(reflectionText: monthlyReflectionText)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.paper)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 6: return "6a"
        case 12: return "12p"
        case 18: return "6p"
        default: return ""
        }
    }
}

nonisolated struct HourlyReading: Identifiable, Sendable {
    let hour: Int
    let minutes: Int
    var id: Int { hour }
}

nonisolated struct ReadingSeason: Identifiable, Sendable {
    let name: String
    let sessionCount: Int
    let totalMinutes: Int
    let description: String
    let bookTitles: [String]
    var id: String { name }
}
