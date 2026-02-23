import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedTab: Int

    @Query(filter: #Predicate<Book> { $0.statusRaw == "reading" }, sort: \Book.createdAt, order: .reverse)
    private var readingBooks: [Book]

    @Query private var allBooks: [Book]

    @Query(sort: \ReadingSession.startedAt, order: .reverse)
    private var allSessions: [ReadingSession]

    @State private var sessionBook: Book?
    @State private var appeared: Bool = false
    @State private var breathePhase: Bool = false

    private let timeOfDay = TimeOfDay.current

    private var currentBook: Book? {
        readingBooks.max(by: {
            ($0.lastOpenedAt ?? $0.startedAt ?? .distantPast) <
            ($1.lastOpenedAt ?? $1.startedAt ?? .distantPast)
        })
    }

    private var otherBooksCount: Int { max(0, readingBooks.count - 1) }
    private var lastSession: ReadingSession? { allSessions.first }

    private var greeting: String {
        switch timeOfDay {
        case .morning:   return "Morning reading"
        case .afternoon: return "Afternoon reading"
        case .evening:   return "Evening reading"
        case .lateNight: return "Late night reading"
        }
    }

    private var dynamicInsight: String? {
        ReadingBehaviourEngine.generateHomeInsight(books: allBooks, sessions: allSessions)
    }

    private var temporalLine: String? {
        ReadingBehaviourEngine.generateTemporalLine(sessions: allSessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Title + greeting — tightened typographically
                VStack(alignment: .leading, spacing: 3) {
                    Text("Folio")
                        .font(.serifTitle(.title))
                        .tracking(-0.3)
                        .foregroundStyle(Color.charcoal)

                    Text(greeting)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(2)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeInOut(duration: 0.5), value: appeared)

                // Primary focus card
                Group {
                    if let book = currentBook {
                        currentBookCard(book)
                    } else {
                        emptyState
                    }
                }
                .padding(.top, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(.easeInOut(duration: 0.5).delay(0.15), value: appeared)

                // Dynamic insight line
                if let insight = dynamicInsight {
                    Text(insight)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(2)
                        .padding(.top, 16)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.3), value: appeared)
                }

                // Temporal awareness
                if let temporal = temporalLine, dynamicInsight == nil {
                    Text(temporal)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.secondaryText.opacity(0.8))
                        .lineSpacing(2)
                        .padding(.top, 16)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.3), value: appeared)
                }

                // Other books link
                if otherBooksCount > 0 {
                    Button {
                        selectedTab = 1
                    } label: {
                        Text("\(otherBooksCount) other book\(otherBooksCount == 1 ? "" : "s") in progress")
                            .font(.serifCaption())
                            .foregroundStyle(Color.secondaryText)
                            .underline()
                    }
                    .padding(.top, 6)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.3), value: appeared)
                }

                // Divider + last session
                if currentBook != nil {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.hairline)
                            .frame(width: geo.size.width * 0.65, height: 0.5)
                    }
                    .frame(height: 0.5)
                    .padding(.top, 16)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.35), value: appeared)

                    if let session = lastSession {
                        lastSessionBlock(session)
                            .padding(.top, 14)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5).delay(0.35), value: appeared)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
            .padding(.top, 34)
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

    // MARK: — Subviews

    private func currentBookCard(_ book: Book) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Cover fills card height
            BookCoverView(coverURL: book.coverURL, cornerRadius: 0)
                .frame(width: 100)
                .clipped()

            // Right side: metadata + button
            VStack(alignment: .leading, spacing: 8) {
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SESSIONS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.secondaryText.opacity(0.7))
                            .kerning(0.6)
                        Text("\(book.sessions.count) session\(book.sessions.count == 1 ? "" : "s") · \(totalMin) min")
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(Color.warmAccent)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 8)

                Button {
                    sessionBook = book
                } label: {
                    Text("Continue Reading")
                        .font(.system(.subheadline, design: .serif, weight: .medium))
                        .foregroundStyle(Color.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.charcoal, in: .rect(cornerRadius: 10))
                }
                .sensoryFeedback(.impact(weight: .light), trigger: sessionBook)
            }
            .padding(16)
        }
        .frame(minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.elevatedSurface)
                .stroke(Color.hairline, lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 14))
        .shadow(
            color: .black.opacity(breathePhase ? 0.04 : 0.02),
            radius: breathePhase ? 8 : 5,
            y: breathePhase ? 4 : 2
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 30))
                .foregroundStyle(Color.warmAccent.opacity(0.45))

            Text("No book in progress")
                .font(.serifHeadline())
                .foregroundStyle(Color.charcoal)

            Text("Add a book from the Library to begin.")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.elevatedSurface)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func lastSessionBlock(_ session: ReadingSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last session")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.secondaryText.opacity(0.7))

            Text(sessionDescription(session))
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.secondaryText)
        }
    }

    private func sessionDescription(_ session: ReadingSession) -> String {
        let minutes = session.durationMinutes
        let duration = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        let when: String
        let cal = Calendar.current
        if cal.isDateInToday(session.startedAt) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            when = "Today at \(f.string(from: session.startedAt))"
        } else if cal.isDateInYesterday(session.startedAt) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            when = "Yesterday at \(f.string(from: session.startedAt))"
        } else {
            let f = DateFormatter(); f.dateFormat = "d MMM 'at' HH:mm"
            when = f.string(from: session.startedAt)
        }
        return "\(duration) · \(when)"
    }
}
