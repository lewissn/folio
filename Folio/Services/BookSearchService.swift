import Foundation

// MARK: - Open Library Models (Fallback API)

nonisolated struct OpenLibraryResponse: Decodable, Sendable {
    let docs: [OpenLibraryDoc]
    let numFound: Int?
}

nonisolated struct OpenLibraryDoc: Decodable, Sendable {
    let title: String?
    let author_name: [String]?
    let first_publish_year: Int?
    let isbn: [String]?
    let cover_i: Int?
    let subject: [String]?
    let language: [String]?
    let number_of_pages_median: Int?
    let key: String?
    let first_sentence: OpenLibraryFirstSentence?
}

nonisolated struct OpenLibraryFirstSentence: Decodable, Sendable {
    let value: String?
}

// MARK: - Google Books Models (Primary API)

nonisolated struct GoogleBooksResponse: Codable, Sendable {
    let totalItems: Int?
    let items: [GoogleBookItem]?
}

nonisolated struct GoogleBookItem: Codable, Sendable, Identifiable {
    let id: String
    let volumeInfo: VolumeInfo
}

nonisolated struct VolumeInfo: Codable, Sendable {
    let title: String?
    let authors: [String]?
    let publishedDate: String?
    let description: String?
    let industryIdentifiers: [IndustryIdentifier]?
    let categories: [String]?
    let imageLinks: ImageLinks?
    let language: String?
    let pageCount: Int?
    let publisher: String?
    let subtitle: String?
}

nonisolated struct IndustryIdentifier: Codable, Sendable {
    let type: String?
    let identifier: String?
}

nonisolated struct ImageLinks: Codable, Sendable {
    let smallThumbnail: String?
    let thumbnail: String?
}

// MARK: - Shared Result Model

nonisolated struct SearchResult: Sendable, Identifiable {
    let id: String
    let title: String
    let authors: [String]
    let publishYear: Int?
    let coverURL: String?
    let isbn: [String]
    let bookDescription: String?
    let subjects: [String]
    let language: String?
    let pageCount: Int?
}

// MARK: - Search Service

nonisolated enum BookSearchService {
    private static let bannedTerms = [
        "study guide", "analysis", "summary", "workbook",
        "sparknotes", "cliffsnotes", "companion", "exam",
        "revision", "lit chart"
    ]

    static func search(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        do {
            let results = try await searchGoogleBooks(query: query)
            if !results.isEmpty {
                return results
            }
        } catch {
            print("Google Books search failed, falling back to Open Library:", error.localizedDescription)
        }

        return try await searchOpenLibrary(query: query)
    }

    /// Fetch one recommendation using a raw Google Books query (e.g. inauthor:X subject:Y).
    /// Returns first result that passes banned-term filter; use for suggestions.
    static func recommendOne(rawQuery: String) async throws -> SearchResult? {
        try await recommendOne(rawQuery: rawQuery, excludingVolumeIds: [], excludingTitleAuthorKeys: [])
    }

    /// Same as recommendOne but skips any book already in the given sets (so suggestions don’t repeat your library).
    static func recommendOne(
        rawQuery: String,
        excludingVolumeIds: Set<String>,
        excludingTitleAuthorKeys: Set<String>
    ) async throws -> SearchResult? {
        let results = try await searchGoogleBooksWithRawQuery(rawQuery, maxResults: 20)
        for result in results {
            let fullText = "\(result.title) \(result.authors.joined(separator: " ")) \(result.subjects.joined(separator: " "))".lowercased()
            guard !bannedTerms.contains(where: { fullText.contains($0) }) else { continue }
            if excludingVolumeIds.contains(result.id) { continue }
            let key = "\(result.title)|\(result.authors.joined(separator: ","))"
            if excludingTitleAuthorKeys.contains(key) { continue }
            return result
        }
        return nil
    }

    // MARK: - Google Books (Primary)

    private static func searchGoogleBooks(query: String) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        // Use intitle: boost for more precise title matching
        let boostedQuery = "intitle:\"\(query)\""
        components.queryItems = [
            URLQueryItem(name: "q", value: boostedQuery),
            URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "langRestrict", value: "en"),
            URLQueryItem(name: "maxResults", value: "30"),
            URLQueryItem(name: "orderBy", value: "relevance")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("Searching Google Books (primary):", url)

        let (data, urlResponse) = try await URLSession.shared.data(from: url)

        guard let httpResponse = urlResponse as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let response = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)

        guard let items = response.items, !items.isEmpty else {
            // Retry without intitle: if no results
            return try await searchGoogleBooksFallbackQuery(query: query)
        }

        let results = items.compactMap { item -> SearchResult? in
            guard let title = item.volumeInfo.title else { return nil }

            let year = parseYear(from: item.volumeInfo.publishedDate)
            let isbn = item.volumeInfo.industryIdentifiers?.compactMap { $0.identifier } ?? []

            var coverURL = item.volumeInfo.imageLinks?.thumbnail ?? item.volumeInfo.imageLinks?.smallThumbnail
            coverURL = coverURL?.replacingOccurrences(of: "http://", with: "https://")

            return SearchResult(
                id: item.id,
                title: title,
                authors: item.volumeInfo.authors ?? [],
                publishYear: year,
                coverURL: coverURL,
                isbn: isbn,
                bookDescription: item.volumeInfo.description,
                subjects: item.volumeInfo.categories ?? [],
                language: item.volumeInfo.language,
                pageCount: item.volumeInfo.pageCount
            )
        }

        return rankResults(results, query: query)
    }

    private static func searchGoogleBooksFallbackQuery(query: String) async throws -> [SearchResult] {
        let results = try await searchGoogleBooksWithRawQuery(query, maxResults: 30)
        return rankResults(results, query: query)
    }

    private static func searchGoogleBooksWithRawQuery(_ rawQuery: String, maxResults: Int = 30) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        components.queryItems = [
            URLQueryItem(name: "q", value: rawQuery),
            URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "langRestrict", value: "en"),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "orderBy", value: "relevance")
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        let (data, urlResponse) = try await URLSession.shared.data(from: url)

        guard let httpResponse = urlResponse as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let response = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)
        guard let items = response.items else { return [] }

        return items.compactMap { item -> SearchResult? in
            guard let title = item.volumeInfo.title else { return nil }

            let year = parseYear(from: item.volumeInfo.publishedDate)
            let isbn = item.volumeInfo.industryIdentifiers?.compactMap { $0.identifier } ?? []

            var coverURL = item.volumeInfo.imageLinks?.thumbnail ?? item.volumeInfo.imageLinks?.smallThumbnail
            coverURL = coverURL?.replacingOccurrences(of: "http://", with: "https://")

            return SearchResult(
                id: item.id,
                title: title,
                authors: item.volumeInfo.authors ?? [],
                publishYear: year,
                coverURL: coverURL,
                isbn: isbn,
                bookDescription: item.volumeInfo.description,
                subjects: item.volumeInfo.categories ?? [],
                language: item.volumeInfo.language,
                pageCount: item.volumeInfo.pageCount
            )
        }
    }

    // MARK: - Open Library (Fallback)

    private static func searchOpenLibrary(query: String) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "title", value: query),
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "lang", value: "eng")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("Searching Open Library (fallback):", url)

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)

        let results = decoded.docs.compactMap { doc -> SearchResult? in
            guard let title = doc.title else { return nil }

            // Use -M size for faster loading
            let coverURL: String? = doc.cover_i.map {
                "https://covers.openlibrary.org/b/id/\($0)-M.jpg"
            }

            return SearchResult(
                id: doc.key ?? UUID().uuidString,
                title: title,
                authors: doc.author_name ?? [],
                publishYear: doc.first_publish_year,
                coverURL: coverURL,
                isbn: doc.isbn ?? [],
                bookDescription: doc.first_sentence?.value,
                subjects: doc.subject.map { Array($0.prefix(5)) } ?? [],
                language: doc.language?.first,
                pageCount: doc.number_of_pages_median
            )
        }

        return rankResults(results, query: query)
    }

    // MARK: - Ranking

    private static func rankResults(_ results: [SearchResult], query: String) -> [SearchResult] {
        let queryLower = query.lowercased()
        return results.sorted { a, b in
            scoreResult(a, query: queryLower) > scoreResult(b, query: queryLower)
        }
    }

    private static func scoreResult(_ result: SearchResult, query: String) -> Double {
        var score = 0.0

        let titleLower = result.title.lowercased()
        let fullText = "\(result.title) \(result.authors.joined(separator: " "))".lowercased()

        // Title matching
        if titleLower == query { score += 100 }
        else if titleLower.contains(query) { score += 60 }

        // Author matching
        let authorString = result.authors.joined(separator: " ").lowercased()
        if authorString.contains(query) { score += 40 }

        // Language preference
        if result.language == "en" || result.language == "eng" {
            score += 25
        } else if result.language != nil {
            score -= 50
        }

        // Completeness bonuses
        if result.coverURL != nil { score += 10 }
        if result.publishYear != nil { score += 5 }

        // Down-rank banned keywords
        for term in bannedTerms {
            if fullText.contains(term) {
                score -= 80
                break
            }
        }

        return score
    }

    // MARK: - Helpers

    private static func parseYear(from dateString: String?) -> Int? {
        guard let dateString else { return nil }
        let components = dateString.split(separator: "-")
        guard let yearStr = components.first else { return nil }
        return Int(yearStr)
    }
}
