import Foundation

// MARK: - Open Library Models (Primary API)

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

// MARK: - Google Books Models (Fallback API)

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
    private static let excludedTerms = [
        "study guide", "analysis", "summary", "workbook",
        "sparknotes", "cliffsnotes", "companion", "exam",
        "revision", "lit chart"
    ]

    static func search(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        do {
            let results = try await searchOpenLibrary(query: query)
            if !results.isEmpty {
                return results
            }
        } catch {
            print("Open Library search failed, falling back to Google Books:", error.localizedDescription)
        }

        return try await searchGoogleBooks(query: query)
    }

    // MARK: - Open Library (Primary)

    private static func searchOpenLibrary(query: String) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "lang", value: "eng")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("Searching URL:", url)

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)

        let results = decoded.docs.compactMap { doc -> SearchResult? in
            guard let title = doc.title else { return nil }

            let fullText = title.lowercased()
            for term in excludedTerms {
                if fullText.contains(term) { return nil }
            }

            let coverURL: String? = doc.cover_i.map {
                "https://covers.openlibrary.org/b/id/\($0)-L.jpg"
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

    // MARK: - Google Books (Fallback)

    private static func searchGoogleBooks(query: String) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "langRestrict", value: "en"),
            URLQueryItem(name: "maxResults", value: "30"),
            URLQueryItem(name: "orderBy", value: "relevance")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        print("Searching URL (fallback):", url)

        let (data, urlResponse) = try await URLSession.shared.data(from: url)

        guard let httpResponse = urlResponse as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let response = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)

        guard let items = response.items else { return [] }

        let results = items.compactMap { item -> SearchResult? in
            guard let title = item.volumeInfo.title else { return nil }

            let fullText = "\(title) \(item.volumeInfo.subtitle ?? "")".lowercased()
            for term in excludedTerms {
                if fullText.contains(term) { return nil }
            }

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

    // MARK: - Helpers

    private static func rankResults(_ results: [SearchResult], query: String) -> [SearchResult] {
        let queryLower = query.lowercased()
        return results.sorted { a, b in
            scoreResult(a, query: queryLower) > scoreResult(b, query: queryLower)
        }
    }

    private static func scoreResult(_ result: SearchResult, query: String) -> Double {
        var score = 0.0

        let titleLower = result.title.lowercased()
        if titleLower == query { score += 100 }
        else if titleLower.contains(query) { score += 60 }

        let authorString = result.authors.joined(separator: " ").lowercased()
        if authorString.contains(query) { score += 40 }

        if !result.isbn.isEmpty { score += 15 }
        if result.publishYear != nil { score += 10 }
        if result.language == "en" || result.language == "eng" { score += 20 }
        if result.pageCount != nil { score += 5 }
        if result.coverURL != nil { score += 10 }

        return score
    }

    private static func parseYear(from dateString: String?) -> Int? {
        guard let dateString else { return nil }
        let components = dateString.split(separator: "-")
        guard let yearStr = components.first else { return nil }
        return Int(yearStr)
    }
}
