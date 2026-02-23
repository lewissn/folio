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

    private let timeOfDay = TimeOfDay.current

    private var currentBook: Book? {
        readingBooks.max(by: {
            ($0.lastOpenedAt ?? $0.startedAt ?? .distantPast) <
            ($1.lastOpenedAt ?? $1.startedAt ?? .distantPast)
        })
    }

    private var otherBooksCount: Int { max(0, readingBooks.count - 1) }
    private var lastSession: ReadingSession? { allSessions.first }

    private var dynamicInsight: String? {
        ReadingBehaviourEngine.generateHomeInsight(books: allBooks, sessions: allSessions)
    }

    private var temporalLine: String? {
        ReadingBehaviourEngine.generateTemporalLine(sessions: allSessions)
    }

    private var dailyQuote: (text: String, author: String) {
        DailyQuotes.today
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Page header — "Folio Reading Room"
                        HStack(alignment: .lastTextBaseline, spacing: 14) {
                            Text("Folio")
                                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                                .foregroundStyle(Color.charcoal)
                            Text("Reading Room")
                                .font(.system(.body, design: .serif, weight: .regular))
                                .foregroundStyle(Color.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4), value: appeared)

                        // Primary focus card
                        Group {
                            if let book = currentBook {
                                currentBookCard(book)
                            } else {
                                emptyState
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(.easeInOut(duration: 0.5).delay(0.15), value: appeared)

                        // Dynamic insight — whisper quiet, one line
                        if let insight = dynamicInsight {
                            Text(insight)
                                .font(.system(size: 12.5, design: .serif))
                                .foregroundStyle(Color.secondaryText.opacity(0.65))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.top, 14)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeInOut(duration: 0.5).delay(0.3), value: appeared)
                        }

                        // Temporal awareness (only when no insight)
                        if let temporal = temporalLine, dynamicInsight == nil {
                            Text(temporal)
                                .font(.system(size: 12.5, design: .serif))
                                .foregroundStyle(Color.secondaryText.opacity(0.6))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.top, 14)
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

                        // Spacer to clear pinned quote block
                        Spacer(minLength: 220)
                    }
                    .padding(.horizontal)
                }
                .background(AtmosphericBackground(timeOfDay: timeOfDay))

                // Quote anchored above tab bar — separated by hairline
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(height: 0.5)
                        .padding(.horizontal, 32)
                    quoteBlock
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 56)
                .opacity(appeared ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.45), value: appeared)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            appeared = true
        }
        .fullScreenCover(item: $sessionBook) { book in
            SessionView(book: book)
        }
    }

    // MARK: — Subviews

    private func currentBookCard(_ book: Book) -> some View {
        HStack(alignment: .top, spacing: 16) {

            // Cover — fixed silhouette, never touches card edges
            BookCoverView(coverURL: book.coverURL, cornerRadius: 10)
                .frame(width: 96, height: 132)
                .clipped()
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)

            // Text column — title, author, metadata, then CTA
            VStack(alignment: .leading, spacing: 0) {
                Text(book.title)
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .foregroundStyle(Color.charcoal)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !book.authors.isEmpty {
                    Text(book.authors.joined(separator: ", "))
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.secondaryText.opacity(0.8))
                        .padding(.top, 4)
                }

                if !book.sessions.isEmpty {
                    let totalMin = book.sessions.reduce(0) { $0 + $1.durationMinutes }
                    Text("\(book.sessions.count) session\(book.sessions.count == 1 ? "" : "s") · \(totalMin) min")
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(Color.secondaryText.opacity(0.65))
                        .padding(.top, 6)
                }

                Spacer(minLength: 12)

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
            .frame(maxHeight: .infinity)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.elevatedSurface)
                .stroke(Color.hairline, lineWidth: 0.5)
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
                .stroke(Color.hairline, lineWidth: 0.5)
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

    private var quoteBlock: some View {
        VStack(spacing: 5) {
            Text(dailyQuote.text)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.secondaryText.opacity(0.45))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Text(dailyQuote.author)
                .font(.system(size: 10.5, weight: .regular, design: .serif))
                .foregroundStyle(Color.secondaryText.opacity(0.4))
        }
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity)
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
