import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book
    @State private var showStatusChange: Bool = false
    @State private var showRating: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showPauseSheet: Bool = false
    @State private var rating: Int = 0
    @State private var expandedReflection: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    BookCoverView(coverURL: book.coverURL, cornerRadius: 8)
                        .frame(width: 100, height: 150)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .font(.serifTitle(.title2))
                            .foregroundStyle(Color.charcoal)

                        if !book.authors.isEmpty {
                            Text(book.authors.joined(separator: ", "))
                                .font(.system(.subheadline, design: .serif))
                                .foregroundStyle(Color.secondaryText)
                        }

                        HStack(spacing: 8) {
                            if let year = book.publishYear {
                                Text(String(year))
                                    .font(.serifCaption())
                                    .foregroundStyle(Color.secondaryText)
                            }

                            Text(book.status.rawValue.capitalized)
                                .font(.serifCaption())
                                .foregroundStyle(Color.secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.warmAccent.opacity(0.2), in: Capsule())
                        }

                        if let r = book.rating, r > 0 {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= r ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundStyle(Color.warmAccent)
                                }
                            }
                        }
                    }

                    Spacer()
                }

                if let returnNote = book.returnGapDescription {
                    Text(returnNote)
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(Color.secondaryText)
                        .italic()
                        .padding(.vertical, 4)
                }

                VStack(spacing: 10) {
                    Button {
                        showStatusChange = true
                    } label: {
                        HStack {
                            Text("Change Status")
                                .font(.system(.body, design: .serif, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.charcoal)
                        .padding(16)
                        .background(Color.elevatedSurface, in: .rect(cornerRadius: 12))
                    }

                    Button {
                        rating = book.rating ?? 0
                        showRating = true
                    } label: {
                        HStack {
                            Text("Rate This Book")
                                .font(.system(.body, design: .serif, weight: .medium))
                            Spacer()
                            if let r = book.rating, r > 0 {
                                HStack(spacing: 1) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= r ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundStyle(Color.warmAccent)
                                    }
                                }
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(Color.charcoal)
                        .padding(16)
                        .background(Color.elevatedSurface, in: .rect(cornerRadius: 12))
                    }
                }

                if let desc = book.bookDescription, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)

                        Text(desc)
                            .font(.serifBody())
                            .foregroundStyle(Color.charcoal)
                            .lineSpacing(2)
                            .lineLimit(10)
                    }
                }

                if !book.sessions.isEmpty {
                    marginsSection
                }

                if !book.pauseReasonTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why paused")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)

                        HStack(spacing: 6) {
                            ForEach(book.pauseReasonTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.serifCaption())
                                    .foregroundStyle(Color.charcoal)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.elevatedSurface, in: Capsule())
                            }
                        }
                    }
                }

                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("Remove from Library")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { book.lastOpenedAt = Date() }
        .confirmationDialog("Change Status", isPresented: $showStatusChange) {
            Button("Currently Reading") {
                book.status = .reading
                if book.startedAt == nil { book.startedAt = Date() }
            }
            Button("Finished Reading") {
                book.status = .read
                book.finishedAt = Date()
            }
            Button("Paused") {
                showPauseSheet = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Remove Book?", isPresented: $showDeleteConfirm) {
            Button("Remove", role: .destructive) {
                modelContext.delete(book)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove \"\(book.title)\" and all its sessions from your library.")
        }
        .sheet(isPresented: $showRating) {
            ratingSheet
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.paper)
        }
        .sheet(isPresented: $showPauseSheet) {
            PauseReasonSheet(book: book)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.paper)
        }
    }

    private var marginsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Margins")
                .font(.serifHeadline())
                .foregroundStyle(Color.charcoal)

            let sessionsWithReflections = book.sessions
                .sorted(by: { $0.startedAt < $1.startedAt })

            ForEach(sessionsWithReflections) { session in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.serifCaption())
                            .foregroundStyle(Color.secondaryText)

                        Text("\(session.durationMinutes) min")
                            .font(.serifCaption())
                            .foregroundStyle(Color.secondaryText)

                        if let pages = session.pagesRead {
                            Text("\(pages) pages")
                                .font(.serifCaption())
                                .foregroundStyle(Color.secondaryText)
                        }

                        if let mood = session.moodWord {
                            Text(mood)
                                .font(.serifCaption())
                                .foregroundStyle(Color.warmAccent)
                        }
                    }

                    if let chapter = session.chapterReference {
                        Text(chapter)
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                            .italic()
                    }

                    if let reflection = session.reflectionText, !reflection.isEmpty {
                        Text(reflection)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.charcoal)
                            .lineSpacing(3)
                            .padding(.leading, 12)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.warmAccent.opacity(0.3))
                                    .frame(width: 2)
                            }
                    }

                    if session.id != sessionsWithReflections.last?.id {
                        Rectangle().fill(Color.hairline).frame(height: 0.5)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var ratingSheet: some View {
        VStack(spacing: 24) {
            Text("Rate This Book")
                .font(.serifHeadline())
                .foregroundStyle(Color.charcoal)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.title)
                            .foregroundStyle(star <= rating ? Color.warmAccent : Color.warmAccent.opacity(0.3))
                    }
                }
            }

            Button {
                book.rating = rating > 0 ? rating : nil
                showRating = false
            } label: {
                Text("Save")
                    .font(.system(.body, design: .serif, weight: .medium))
                    .foregroundStyle(Color.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.charcoal, in: .rect(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
