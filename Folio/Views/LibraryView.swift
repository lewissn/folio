import SwiftUI
import SwiftData

nonisolated enum LibraryDisplayMode: String, Sendable {
    case list
    case shelf
}

nonisolated enum LibrarySortOption: String, CaseIterable, Sendable {
    case recentlyAdded = "Recently Added"
    case recentlyRead = "Recently Read"
    case alphabetical = "Alphabetical"
    case author = "Author"
    case mostTimeSpent = "Most Time Spent"
    case highestRated = "Highest Rated"
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var allBooks: [Book]

    @State private var selectedFilter: BookStatus = .reading
    @State private var showSearch: Bool = false
    @State private var displayMode: LibraryDisplayMode = .list
    @State private var sortOption: LibrarySortOption = .recentlyAdded
    @State private var showSortSheet: Bool = false
    @State private var genreFilter: String? = nil
    @State private var authorFilter: String? = nil
    @State private var showFilterSheet: Bool = false

    private var filteredBooks: [Book] {
        var books = allBooks.filter {
            switch selectedFilter {
            case .reading: return $0.status == .reading
            case .read: return $0.status == .read || $0.status == .historicalRead
            case .paused: return $0.status == .paused
            case .historicalRead: return $0.status == .historicalRead
            case .wishlist: return $0.status == .wishlist
            }
        }

        // Apply genre filter
        if let genre = genreFilter {
            books = books.filter { $0.subjects.contains(where: { $0.localizedCaseInsensitiveContains(genre) }) }
        }

        // Apply author filter
        if let author = authorFilter {
            books = books.filter { $0.authors.contains(author) }
        }

        // Apply sort
        switch sortOption {
        case .recentlyAdded:
            books.sort { $0.createdAt > $1.createdAt }
        case .recentlyRead:
            books.sort {
                ($0.lastOpenedAt ?? $0.createdAt) > ($1.lastOpenedAt ?? $1.createdAt)
            }
        case .alphabetical:
            books.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            books.sort {
                ($0.authors.first ?? "").localizedCaseInsensitiveCompare($1.authors.first ?? "") == .orderedAscending
            }
        case .mostTimeSpent:
            books.sort { $0.totalSessionMinutes > $1.totalSessionMinutes }
        case .highestRated:
            books.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }

        return books
    }

    private var availableGenres: [String] {
        let allGenres = allBooks.flatMap { $0.subjects }
        var seen = Set<String>()
        return allGenres.filter { genre in
            let lowered = genre.lowercased()
            guard !seen.contains(lowered) else { return false }
            seen.insert(lowered)
            return true
        }.sorted()
    }

    private var availableAuthors: [String] {
        let allAuthors = allBooks.flatMap { $0.authors }
        var seen = Set<String>()
        return allAuthors.filter { author in
            guard !seen.contains(author) else { return false }
            seen.insert(author)
            return true
        }.sorted()
    }

    private var hasActiveFilters: Bool {
        genreFilter != nil || authorFilter != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status filter
                    HStack {
                        Picker("Filter", selection: $selectedFilter) {
                            Text("Reading").tag(BookStatus.reading)
                            Text("Read").tag(BookStatus.read)
                            Text("Paused").tag(BookStatus.paused)
                            Text("Wishlist").tag(BookStatus.wishlist)
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

                    // Sort + filter controls
                    HStack(spacing: 8) {
                        Button {
                            showSortSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.caption2)
                                Text(sortOption.rawValue)
                                    .font(.system(.caption, design: .serif))
                            }
                            .foregroundStyle(Color.charcoal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.elevatedSurface, in: Capsule())
                        }

                        Button {
                            showFilterSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.caption2)
                                Text(hasActiveFilters ? "Filtered" : "Filter")
                                    .font(.system(.caption, design: .serif))
                            }
                            .foregroundStyle(hasActiveFilters ? Color.paper : Color.charcoal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(hasActiveFilters ? Color.charcoal : Color.elevatedSurface, in: Capsule())
                        }

                        if hasActiveFilters {
                            Button {
                                withAnimation {
                                    genreFilter = nil
                                    authorFilter = nil
                                }
                            } label: {
                                Text("Clear")
                                    .font(.system(.caption, design: .serif))
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }

                        Spacer()
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
            .sheet(isPresented: $showSortSheet) {
                sortSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.paper)
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.paper)
            }
        }
    }

    // MARK: - Sort Sheet

    private var sortSheet: some View {
        NavigationStack {
            List {
                ForEach(LibrarySortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                        showSortSheet = false
                    } label: {
                        HStack {
                            Text(option.rawValue)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(Color.charcoal)
                            Spacer()
                            if option == sortOption {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundStyle(Color.warmAccent)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSortSheet = false }
                        .foregroundStyle(Color.charcoal)
                }
            }
        }
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            List {
                if !availableGenres.isEmpty {
                    Section("Genre") {
                        ForEach(availableGenres.prefix(12), id: \.self) { genre in
                            Button {
                                genreFilter = genreFilter == genre ? nil : genre
                            } label: {
                                HStack {
                                    Text(genre)
                                        .font(.system(.subheadline, design: .serif))
                                        .foregroundStyle(Color.charcoal)
                                    Spacer()
                                    if genreFilter == genre {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundStyle(Color.warmAccent)
                                    }
                                }
                            }
                        }
                    }
                }

                if !availableAuthors.isEmpty {
                    Section("Author") {
                        ForEach(availableAuthors.prefix(12), id: \.self) { author in
                            Button {
                                authorFilter = authorFilter == author ? nil : author
                            } label: {
                                HStack {
                                    Text(author)
                                        .font(.system(.subheadline, design: .serif))
                                        .foregroundStyle(Color.charcoal)
                                    Spacer()
                                    if authorFilter == author {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundStyle(Color.warmAccent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if hasActiveFilters {
                        Button("Clear All") {
                            genreFilter = nil
                            authorFilter = nil
                        }
                        .foregroundStyle(Color.secondaryText)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showFilterSheet = false }
                        .foregroundStyle(Color.charcoal)
                }
            }
        }
    }

    // MARK: - List & Shelf Views

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
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyMessage: String {
        if hasActiveFilters {
            return "No books match your filters."
        }
        switch selectedFilter {
        case .reading: return "No books in progress.\nTap + to add one."
        case .read: return "No finished books yet."
        case .paused: return "No paused books."
        case .historicalRead: return "No historical books."
        case .wishlist: return "No books in your wishlist yet.\nSave suggestions or search results to add them."
        }
    }
}
