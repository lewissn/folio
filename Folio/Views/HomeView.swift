import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<Book> { $0.statusRaw == "reading" }, sort: \Book.startedAt, order: .reverse)
    private var readingBooks: [Book]

    @Query(sort: \ReadingSession.startedAt, order: .reverse)
    private var allSessions: [ReadingSession]

    @State private var sessionBook: Book?
    @State private var appeared: Bool = false
    @State private var breathePhase: Bool = false

    private let timeOfDay = TimeOfDay.current

    private var currentBook: Book? { readingBooks.first }

    private var greeting: String {
        switch timeOfDay {
        case .morning: return "Morning reading"
        case .afternoon: return "Afternoon reading"
        case .evening: return "Evening reading"
        case .lateNight: return "Late night reading"
        }
    }

    private var insightText: String? {
        guard !allSessions.isEmpty else { return nil }
        let recentMoods = allSessions.prefix(10).compactMap { $0.moodWord }
        if let mood = recentMoods.mostFrequent {
            return "Recently, your sessions tend to feel \(mood)."
        }
        let totalMinutes = allSessions.reduce(0) { $0 + $1.durationMinutes }
        let avg = totalMinutes / max(allSessions.count, 1)
        if avg > 0 {
            return "Your sessions average around \(avg) minutes."
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(greeting)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.secondaryText)

                    Text("Folio")
                        .font(.serifLargeTitle())
                        .foregroundStyle(Color.charcoal)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeInOut(duration: 0.5), value: appeared)

                if let book = currentBook {
                    currentBookCard(book)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(.easeInOut(duration: 0.5).delay(0.15), value: appeared)
                } else {
                    emptyState
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(.easeInOut(duration: 0.5).delay(0.15), value: appeared)
                }

                if let insight = insightText {
                    Text(insight)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(2)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.3), value: appeared)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
            .padding(.top, 60)
        }
        .background(AtmosphericBackground(timeOfDay: timeOfDay))
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breathePhase = true
            }
        }
        .fullScreenCover(item: $sessionBook) { book in
            SessionView(book: book)
        }
    }

    private func currentBookCard(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                BookCoverView(coverURL: book.coverURL)
                    .frame(width: 80, height: 120)
                    .shadow(color: .black.opacity(breathePhase ? 0.08 : 0.04), radius: breathePhase ? 12 : 8, y: breathePhase ? 6 : 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.serifHeadline())
                        .foregroundStyle(Color.charcoal)
                        .lineLimit(2)

                    if !book.authors.isEmpty {
                        Text(book.authors.joined(separator: ", "))
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                    }

                    if !book.sessions.isEmpty {
                        let totalMin = book.sessions.reduce(0) { $0 + $1.durationMinutes }
                        Text("\(book.sessions.count) session\(book.sessions.count == 1 ? "" : "s"), \(totalMin) min")
                            .font(.serifCaption())
                            .foregroundStyle(Color.warmAccent)
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }

            Button {
                sessionBook = book
            } label: {
                Text("Begin Session")
                    .font(.system(.body, design: .serif, weight: .medium))
                    .foregroundStyle(Color.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.charcoal, in: .rect(cornerRadius: 12))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: sessionBook)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.elevatedSurface)
                .stroke(Color.hairline, lineWidth: 1)
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(Color.warmAccent)

            Text("No book in progress")
                .font(.serifHeadline())
                .foregroundStyle(Color.charcoal)

            Text("Add a book from the Library to begin.")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.elevatedSurface)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }
}
