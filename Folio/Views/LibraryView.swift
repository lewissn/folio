import SwiftUI
import SwiftData

nonisolated enum LibraryDisplayMode: String, Sendable {
    case list
    case shelf
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var allBooks: [Book]

    @State private var selectedFilter: BookStatus = .reading
    @State private var showSearch: Bool = false
    @State private var displayMode: LibraryDisplayMode = .list

    private var filteredBooks: [Book] {
        allBooks.filter { $0.status == selectedFilter }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Picker("Filter", selection: $selectedFilter) {
                            Text("Reading").tag(BookStatus.reading)
                            Text("Read").tag(BookStatus.read)
                            Text("Paused").tag(BookStatus.paused)
                        }
                        .pickerStyle(.segmented)

                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                displayMode = displayMode == .list ? .shelf : .list
                            }
                        } label: {
                            Image(systemName: displayMode == .list ? "square.grid.2x2" : "list.bullet")
                                .font(.body)
                                .foregroundStyle(Color.charcoal)
                                .frame(width: 36, height: 36)
                                .background(Color.elevatedSurface, in: .rect(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal)

                    if filteredBooks.isEmpty {
                        emptyState
                    } else if displayMode == .list {
                        listView
                    } else {
                        shelfView
                    }
                }
                .padding(.top)
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.charcoal)
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                BookSearchView()
                    .presentationBackground(Color.paper)
            }
        }
    }

    private var listView: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredBooks) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    BookRowView(book: book)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.hairline)
                    .frame(height: 0.5)
                    .padding(.leading, 80)
            }
        }
        .padding(.horizontal)
    }

    private var shelfView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 20) {
            ForEach(filteredBooks) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    VStack(spacing: 8) {
                        BookCoverView(coverURL: book.coverURL, cornerRadius: 6)
                            .frame(height: 150)
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                        Text(book.title)
                            .font(.system(.caption, design: .serif, weight: .semibold))
                            .foregroundStyle(Color.charcoal)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 32))
                .foregroundStyle(Color.warmAccent)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .reading: return "No books in progress.\nTap + to add one."
        case .read: return "No finished books yet."
        case .paused: return "No paused books."
        }
    }
}
