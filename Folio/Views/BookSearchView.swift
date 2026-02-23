import SwiftUI
import SwiftData

struct BookSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchText: String = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @State private var selectedResult: SearchResult?
    @State private var showAddOptions: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty && !isSearching && searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.warmAccent)
                        Text("Search by title or author")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isSearching && results.isEmpty {
                    ProgressView()
                        .tint(Color.warmAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchError != nil && !isSearching {
                    VStack(spacing: 8) {
                        Text("Search unavailable")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                        Text(searchError ?? "Check your connection and try again.")
                            .font(.serifCaption())
                            .foregroundStyle(Color.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !searchText.isEmpty && !isSearching {
                    VStack(spacing: 8) {
                        Text("No results found")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { result in
                                Button {
                                    selectedResult = result
                                    showAddOptions = true
                                } label: {
                                    searchResultRow(result)
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
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .task(id: searchText) {
                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    results = []
                    searchError = nil
                    isSearching = false
                    return
                }
                isSearching = true
                searchError = nil
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else {
                    isSearching = false
                    return
                }
                do {
                    results = try await BookSearchService.search(query: trimmed)
                    searchError = nil
                } catch {
                    print("Search failed:", error.localizedDescription)
                    results = []
                    searchError = error.localizedDescription
                }
                isSearching = false
            }
            .confirmationDialog("Add to Library", isPresented: $showAddOptions, presenting: selectedResult) { result in
                Button("Currently Reading") { addBook(result, status: .reading) }
                Button("Already Read") { addBook(result, status: .historicalRead) }
                Button("Paused") { addBook(result, status: .paused) }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func searchResultRow(_ result: SearchResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BookCoverView(coverURL: result.coverURL, cornerRadius: 4)
                .frame(width: 56, height: 84)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .foregroundStyle(Color.charcoal)
                    .lineLimit(2)

                if !result.authors.isEmpty {
                    Text(result.authors.joined(separator: ", "))
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }

                if let year = result.publishYear {
                    Text(String(year))
                        .font(.serifCaption())
                        .foregroundStyle(Color.secondaryText)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func addBook(_ result: SearchResult, status: BookStatus) {
        let book = Book(
            title: result.title,
            authors: result.authors,
            publishYear: result.publishYear,
            language: result.language,
            coverURL: result.coverURL,
            isbn: result.isbn,
            bookDescription: result.bookDescription,
            subjects: result.subjects,
            status: status,
            startedAt: status == .reading ? Date() : nil,
            finishedAt: (status == .read || status == .historicalRead) ? Date() : nil,
            pageCount: result.pageCount
        )
        modelContext.insert(book)
        dismiss()
    }
}
