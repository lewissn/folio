import SwiftUI
import SwiftData
import Charts

struct PatternsView: View {
    @Query private var allBooks: [Book]
    @Query(sort: \ReadingSession.startedAt, order: .reverse) private var allSessions: [ReadingSession]

    @State private var appeared: Bool = false
    @State private var showMonthlyReflection: Bool = false

    // MARK: - Derived Data

    private var activeBooks: [Book] {
        allBooks.filter { !$0.isHistorical }
    }

    private var profile: ReadingBehaviourEngine.BehaviourProfile {
        ReadingBehaviourEngine.computeProfile(books: allBooks, sessions: allSessions)
    }

    private var engagement: ReadingBehaviourEngine.EngagementStats {
        ReadingBehaviourEngine.computeEngagement(books: allBooks, sessions: allSessions)
    }

    private var suggestions: [SuggestionEngine.Suggestion] {
        SuggestionEngine.generateSuggestions(books: allBooks, sessions: allSessions)
    }

    private var hourlyData: [HourlyReading] {
        var distribution: [Int: Int] = [:]
        for session in allSessions {
            let hour = Calendar.current.component(.hour, from: session.startedAt)
            distribution[hour, default: 0] += session.durationMinutes
        }
        return (0..<24).map { HourlyReading(hour: $0, minutes: distribution[$0] ?? 0) }
    }

    private var monthlyReflectionText: String {
        ReadingBehaviourEngine.generateMonthlyReflection(books: allBooks, sessions: allSessions)
    }

    // Active completions only
    private var activeFinished: Int {
        allBooks.filter { $0.isActivelyCompleted }.count
    }

    private var historicalCount: Int {
        allBooks.filter { $0.isHistorical }.count
    }

    private var pausedCount: Int {
        allBooks.filter { $0.status == .paused }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {

                    // MARK: Reading Signature
                    sectionBlock {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Reading Signature")

                            Text(profile.readingSignature)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(Color.charcoal)
                                .lineSpacing(4)
                        }
                    }

                    // MARK: Rhythm
                    if !allSessions.isEmpty {
                        divider

                        sectionBlock {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Rhythm")

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

                                if let timeWindow = profile.preferredTimeWindow {
                                    Text("You tend to read \(timeWindow). Average session: \(profile.averageSessionMinutes) min.")
                                        .font(.serifCaption())
                                        .foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                    }

                    // MARK: Engagement
                    if engagement.totalSessionCount > 0 {
                        divider

                        sectionBlock {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Engagement")

                                HStack(spacing: 24) {
                                    statPill(value: "\(activeFinished)", label: "Finished")
                                    statPill(value: "\(pausedCount)", label: "Paused")
                                    if historicalCount > 0 {
                                        statPill(value: "\(historicalCount)", label: "Historical")
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    engagementRow(
                                        label: "Avg session",
                                        value: "\(engagement.averageSessionMinutes) min",
                                        detail: trendDescription(engagement.averageSessionTrend)
                                    )

                                    if engagement.completionRate > 0 {
                                        engagementRow(
                                            label: "Completion",
                                            value: "\(Int(engagement.completionRate * 100))%",
                                            detail: nil
                                        )
                                    }

                                    if engagement.abandonmentRate > 0 {
                                        engagementRow(
                                            label: "Set aside",
                                            value: "\(Int(engagement.abandonmentRate * 100))%",
                                            detail: nil
                                        )
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    // MARK: Authors
                    if !profile.topAuthors.isEmpty {
                        divider

                        sectionBlock {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionHeader("Authors")

                                ForEach(profile.topAuthors, id: \.author) { item in
                                    HStack {
                                        Text(item.author)
                                            .font(.system(.subheadline, design: .serif))
                                            .foregroundStyle(Color.charcoal)

                                        Spacer()

                                        Text("\(item.count) book\(item.count == 1 ? "" : "s")")
                                            .font(.serifCaption())
                                            .foregroundStyle(Color.secondaryText)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Genres (weighted by session time)
                    if !profile.topGenres.isEmpty {
                        divider

                        sectionBlock {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionHeader("Genres")

                                ForEach(profile.topGenres.prefix(6), id: \.genre) { item in
                                    HStack(spacing: 8) {
                                        Text(item.genre)
                                            .font(.system(.subheadline, design: .serif))
                                            .foregroundStyle(Color.charcoal)

                                        Spacer()

                                        // Proportional bar
                                        let maxWeight = profile.topGenres.first?.weight ?? 1
                                        let barWidth = max(20, item.weight / maxWeight * 80)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.warmAccent.opacity(0.5))
                                            .frame(width: barWidth, height: 4)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Suggestions
                    if !suggestions.isEmpty {
                        divider

                        sectionBlock {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Suggestions")

                                ForEach(suggestions) { suggestion in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(suggestion.mode.rawValue.uppercased())
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(Color.secondaryText.opacity(0.7))
                                            .kerning(0.6)

                                        Text(suggestion.title)
                                            .font(.system(.subheadline, design: .serif, weight: .semibold))
                                            .foregroundStyle(Color.charcoal)

                                        Text(suggestion.reason)
                                            .font(.serifCaption())
                                            .foregroundStyle(Color.secondaryText)
                                            .lineSpacing(2)
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }

                    // MARK: Monthly Reflection
                    if !allSessions.isEmpty {
                        divider

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

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .serif))
            .foregroundStyle(Color.secondaryText)
    }

    private func sectionBlock<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(appeared ? 1 : 0)
            .animation(.easeInOut(duration: 0.5).delay(0.1), value: appeared)
    }

    private var divider: some View {
        Rectangle().fill(Color.hairline).frame(height: 0.5)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.serifTitle(.title))
                .foregroundStyle(Color.charcoal)
            Text(label)
                .font(.serifCaption())
                .foregroundStyle(Color.secondaryText)
        }
    }

    private func engagementRow(label: String, value: String, detail: String?) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.secondaryText)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.system(.subheadline, design: .serif, weight: .medium))
                    .foregroundStyle(Color.charcoal)
                if let detail {
                    Text(detail)
                        .font(.system(size: 10, design: .serif))
                        .foregroundStyle(Color.secondaryText.opacity(0.7))
                }
            }
        }
    }

    private func trendDescription(_ trend: ReadingBehaviourEngine.Trend) -> String? {
        switch trend {
        case .increasing: return "growing longer"
        case .decreasing: return "growing shorter"
        case .stable: return "steady"
        case .insufficient: return nil
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
