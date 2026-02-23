import Foundation

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

nonisolated enum BookSearchService {
    private static let excludedTerms = [
        "study guide", "analysis", "summary", "workbook",
        "sparknotes", "cliffsnotes", "companion", "exam",
        "revision", "lit chart"
    ]

    static func search(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.googleapis.com/books/v1/volumes?q=\(encoded)&printType=books&langRestrict=en&maxResults=30&orderBy=relevance"

        guard let url = URL(string: urlString) else { return [] }

        let (data, urlResponse) = try await URLSession.shared.data(from: url)
        guard let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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

            let authors = item.volumeInfo.authors ?? []
            let year = parseYear(from: item.volumeInfo.publishedDate)
            let isbn = item.volumeInfo.industryIdentifiers?.compactMap { $0.identifier } ?? []

            var coverURL = item.volumeInfo.imageLinks?.thumbnail ?? item.volumeInfo.imageLinks?.smallThumbnail
            coverURL = coverURL?.replacingOccurrences(of: "http://", with: "https://")

            return SearchResult(
                id: item.id,
                title: title,
                authors: authors,
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
        if result.language == "en" { score += 20 }
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
