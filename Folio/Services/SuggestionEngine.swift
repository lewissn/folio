import Foundation

/// Three-mode suggestion engine. Generates book recommendations
/// based on reading behaviour; fetches specific books via Google Books.
nonisolated enum SuggestionEngine {

    enum SuggestionMode: String, Sendable {
        case aligned = "In your pattern"
        case adjacent = "One step outside"
        case wildcard = "Something different"
    }

    /// Abstract suggestion (author/genre only) — kept for fallback when API fails.
    struct Suggestion: Sendable, Identifiable {
        let id = UUID()
        let title: String
        let author: String
        let reason: String
        let mode: SuggestionMode
    }

    /// Concrete book suggestion with cover, IDs, and metadata for wishlist.
    struct BookSuggestion: Sendable, Identifiable {
        let id: String
        let title: String
        let authors: [String]
        let reason: String
        let mode: SuggestionMode
        let coverURL: String?
        let volumeId: String?
        let isbn: [String]
        let subjects: [String]
        let publishYear: Int?
        let bookDescription: String?
        let language: String?
        let pageCount: Int?
    }

    // MARK: - Fetch Specific Books (Async)

    static func fetchBookSuggestions(books: [Book], sessions: [ReadingSession]) async -> [BookSuggestion] {
        let profile = ReadingBehaviourEngine.computeProfile(books: books, sessions: sessions)
        let existingVolumeIds = Set(books.compactMap { $0.volumeId })
        let existingTitleAuthorKeys = Set(books.map { "\($0.title)|\($0.authors.joined(separator: ","))" })
        var results: [BookSuggestion] = []

        // Aligned: top author + subject (skip books already in library)
        if let alignedResult = try? await fetchAlignedBook(profile: profile, excludingVolumeIds: existingVolumeIds, excludingTitleAuthorKeys: existingTitleAuthorKeys) {
            results.append(bookSuggestion(from: alignedResult, reason: alignedReason(profile: profile), mode: .aligned))
        }

        // Adjacent: one step outside genre
        if let adjacentResult = try? await fetchAdjacentBook(profile: profile, excludingVolumeIds: existingVolumeIds, excludingTitleAuthorKeys: existingTitleAuthorKeys),
           !results.contains(where: { $0.id == adjacentResult.id }) {
            results.append(bookSuggestion(from: adjacentResult, reason: adjacentReason(profile: profile), mode: .adjacent))
        }

        // Wildcard: emotionally aligned genre
        if let wildcardResult = try? await fetchWildcardBook(profile: profile, excludingVolumeIds: existingVolumeIds, excludingTitleAuthorKeys: existingTitleAuthorKeys),
           !results.contains(where: { $0.id == wildcardResult.id }) {
            results.append(bookSuggestion(from: wildcardResult, reason: "Something slightly outside your usual pattern, but emotionally aligned.", mode: .wildcard))
        }

        // Fallback for new/small library: one general suggestion so the section isn’t empty
        if results.isEmpty, let fallback = try? await BookSearchService.recommendOne(rawQuery: "subject:literary fiction", excludingVolumeIds: existingVolumeIds, excludingTitleAuthorKeys: existingTitleAuthorKeys) {
            results.append(bookSuggestion(from: fallback, reason: "A well-loved pick to get you started.", mode: .aligned))
        }

        return results
    }

    private static func bookSuggestion(from result: SearchResult, reason: String, mode: SuggestionMode) -> BookSuggestion {
        BookSuggestion(
            id: result.id,
            title: result.title,
            authors: result.authors,
            reason: reason,
            mode: mode,
            coverURL: result.coverURL,
            volumeId: result.id,
            isbn: result.isbn,
            subjects: result.subjects,
            publishYear: result.publishYear,
            bookDescription: result.bookDescription,
            language: result.language,
            pageCount: result.pageCount
        )
    }

    private static func fetchAlignedBook(profile: ReadingBehaviourEngine.BehaviourProfile, excludingVolumeIds: Set<String>, excludingTitleAuthorKeys: Set<String>) async throws -> SearchResult? {
        guard let topAuthor = profile.topAuthors.first else { return nil }
        let subject = profile.topGenres.first?.genre.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "fiction"
        let authorEnc = topAuthor.author.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // Prefer inauthor-only first so we get other works by same author; add subject if needed for variety
        let query = "inauthor:\"\(topAuthor.author.replacingOccurrences(of: "\"", with: ""))\" subject:\(subject)"
        if let result = try await BookSearchService.recommendOne(rawQuery: query, excludingVolumeIds: excludingVolumeIds, excludingTitleAuthorKeys: excludingTitleAuthorKeys) {
            return result
        }
        // Fallback: author only (broader)
        return try await BookSearchService.recommendOne(rawQuery: "inauthor:\"\(topAuthor.author.replacingOccurrences(of: "\"", with: ""))\"", excludingVolumeIds: excludingVolumeIds, excludingTitleAuthorKeys: excludingTitleAuthorKeys)
    }

    private static func alignedReason(profile: ReadingBehaviourEngine.BehaviourProfile) -> String {
        guard let topAuthor = profile.topAuthors.first else { return "Fits your reading pattern." }
        return "You've read \(topAuthor.count) of their books and tend to return."
    }

    private static func fetchAdjacentBook(profile: ReadingBehaviourEngine.BehaviourProfile, excludingVolumeIds: Set<String>, excludingTitleAuthorKeys: Set<String>) async throws -> SearchResult? {
        guard let topGenre = profile.topGenres.first else { return nil }
        let existingGenres = Set(profile.topGenres.map { $0.genre.lowercased() })
        for (key, adjacents) in adjacencyMap {
            if topGenre.genre.lowercased().contains(key.lowercased()) || key.lowercased().contains(topGenre.genre.lowercased()) {
                if let adj = adjacents.first(where: { !existingGenres.contains($0.lowercased()) }),
                   let enc = "\(adj) literary".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    let query = "subject:\(enc)"
                    if let result = try await BookSearchService.recommendOne(rawQuery: query, excludingVolumeIds: excludingVolumeIds, excludingTitleAuthorKeys: excludingTitleAuthorKeys) {
                        return result
                    }
                }
            }
        }
        if let enc = profile.topGenres.first.map({ "\($0.genre) biography".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "biography" }) {
            return try await BookSearchService.recommendOne(rawQuery: "subject:\(enc)", excludingVolumeIds: excludingVolumeIds, excludingTitleAuthorKeys: excludingTitleAuthorKeys)
        }
        return nil
    }

    private static func adjacentReason(profile: ReadingBehaviourEngine.BehaviourProfile) -> String {
        guard let top = profile.topGenres.first else { return "One step outside your usual." }
        return "One step from \(top.genre.lowercased()) — a natural bridge."
    }

    private static func fetchWildcardBook(profile: ReadingBehaviourEngine.BehaviourProfile, excludingVolumeIds: Set<String>, excludingTitleAuthorKeys: Set<String>) async throws -> SearchResult? {
        let existingGenres = Set(profile.topGenres.map { $0.genre.lowercased() })
        var emotionalScores: [String: Int] = [:]
        for (emotion, genres) in genreEmotionalMap {
            for genre in existingGenres {
                if genres.contains(where: { $0.lowercased() == genre }) {
                    emotionalScores[emotion, default: 0] += 1
                }
            }
        }
        if let mood = profile.moodProfile {
            switch mood {
            case "calm", "focused": emotionalScores["contemplative", default: 0] += 2
            case "restless": emotionalScores["adventurous", default: 0] += 2
            case "inspired": emotionalScores["introspective", default: 0] += 2
            default: break
            }
        }
        guard let topEmotion = emotionalScores.max(by: { $0.value < $1.value }),
              let emotionalGenres = genreEmotionalMap[topEmotion.key] else { return nil }
        let candidates = emotionalGenres.filter { !existingGenres.contains($0.lowercased()) }
        guard let pick = candidates.randomElement(),
              let enc = pick.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return try await BookSearchService.recommendOne(rawQuery: "subject:\(enc)", excludingVolumeIds: excludingVolumeIds, excludingTitleAuthorKeys: excludingTitleAuthorKeys)
    }

    // MARK: - Legacy (Abstract) Suggestions

    static func generateSuggestions(books: [Book], sessions: [ReadingSession]) -> [Suggestion] {
        let profile = ReadingBehaviourEngine.computeProfile(books: books, sessions: sessions)
        var suggestions: [Suggestion] = []

        if let aligned = generateAligned(profile: profile, books: books) {
            suggestions.append(aligned)
        }
        if let adjacent = generateAdjacent(profile: profile, books: books) {
            suggestions.append(adjacent)
        }
        if let wildcard = generateWildcard(profile: profile, books: books) {
            suggestions.append(wildcard)
        }

        return suggestions
    }

    // MARK: - Mode 1: In-Line (Aligned)

    private static func generateAligned(profile: ReadingBehaviourEngine.BehaviourProfile, books: [Book]) -> Suggestion? {
        guard !profile.topGenres.isEmpty || !profile.topAuthors.isEmpty else { return nil }

        if let topAuthor = profile.topAuthors.first {
            return Suggestion(
                title: "More by \(topAuthor.author)",
                author: topAuthor.author,
                reason: "You've read \(topAuthor.count) of their books and tend to return.",
                mode: .aligned
            )
        }

        if let topGenre = profile.topGenres.first {
            return Suggestion(
                title: "More \(topGenre.genre.lowercased())",
                author: "",
                reason: "This is where most of your reading time concentrates.",
                mode: .aligned
            )
        }

        return nil
    }

    // MARK: - Mode 2: Adjacent

    private static let adjacencyMap: [String: [String]] = [
        "Fiction": ["Literary Fiction", "Historical Fiction", "Short Stories"],
        "Literary Fiction": ["Literary Criticism", "Poetry", "Philosophy"],
        "Science Fiction": ["Speculative Fiction", "Fantasy", "Popular Science"],
        "Fantasy": ["Mythology", "Science Fiction", "Historical Fiction"],
        "Mystery": ["Thriller", "Crime Fiction", "Noir"],
        "Thriller": ["Mystery", "Espionage", "Crime Fiction"],
        "Historical Fiction": ["Biography", "History", "Literary Fiction"],
        "Biography": ["Memoir", "History", "Essays"],
        "Memoir": ["Biography", "Essays", "Personal Essays"],
        "History": ["Historical Fiction", "Biography", "Political Science"],
        "Philosophy": ["Psychology", "Essays", "Literary Criticism"],
        "Psychology": ["Philosophy", "Self-Help", "Neuroscience"],
        "Poetry": ["Literary Fiction", "Essays", "Philosophy"],
        "Essays": ["Memoir", "Journalism", "Philosophy"],
        "Romance": ["Literary Fiction", "Historical Fiction", "Drama"],
        "Horror": ["Gothic Fiction", "Thriller", "Dark Fantasy"],
    ]

    private static func generateAdjacent(profile: ReadingBehaviourEngine.BehaviourProfile, books: [Book]) -> Suggestion? {
        guard let topGenre = profile.topGenres.first else { return nil }

        // Find adjacent genres
        let genreLower = topGenre.genre
        let existingGenres = Set(profile.topGenres.map { $0.genre.lowercased() })

        for (key, adjacents) in adjacencyMap {
            if genreLower.lowercased().contains(key.lowercased()) || key.lowercased().contains(genreLower.lowercased()) {
                if let suggestion = adjacents.first(where: { !existingGenres.contains($0.lowercased()) }) {
                    return Suggestion(
                        title: "Try \(suggestion.lowercased())",
                        author: "",
                        reason: "One step from \(genreLower.lowercased()) — a natural bridge.",
                        mode: .adjacent
                    )
                }
            }
        }

        // Fallback: suggest second genre if different enough
        if profile.topGenres.count >= 3 {
            let third = profile.topGenres[2]
            return Suggestion(
                title: "Explore \(third.genre.lowercased())",
                author: "",
                reason: "It appears in your reading but hasn't been your focus yet.",
                mode: .adjacent
            )
        }

        return nil
    }

    // MARK: - Mode 3: Wildcard (Constrained)

    private static let genreEmotionalMap: [String: Set<String>] = [
        "introspective": ["Literary Fiction", "Memoir", "Philosophy", "Poetry", "Essays", "Psychology"],
        "adventurous": ["Science Fiction", "Fantasy", "Thriller", "Historical Fiction", "Adventure"],
        "contemplative": ["Philosophy", "Essays", "Literary Fiction", "Poetry", "History"],
        "intense": ["Thriller", "Horror", "Mystery", "Crime Fiction", "War Fiction"],
        "warm": ["Romance", "Memoir", "Biography", "Family Saga", "Domestic Fiction"],
    ]

    private static func generateWildcard(profile: ReadingBehaviourEngine.BehaviourProfile, books: [Book]) -> Suggestion? {
        let existingGenres = Set(profile.topGenres.map { $0.genre.lowercased() })
        guard !existingGenres.isEmpty else { return nil }

        // Determine emotional register from mood + genre overlap
        var emotionalScores: [String: Int] = [:]
        for (emotion, genres) in genreEmotionalMap {
            for genre in existingGenres {
                if genres.contains(where: { $0.lowercased() == genre }) {
                    emotionalScores[emotion, default: 0] += 1
                }
            }
        }

        if let mood = profile.moodProfile {
            switch mood {
            case "calm", "focused": emotionalScores["contemplative", default: 0] += 2
            case "restless": emotionalScores["adventurous", default: 0] += 2
            case "inspired": emotionalScores["introspective", default: 0] += 2
            default: break
            }
        }

        guard let topEmotion = emotionalScores.max(by: { $0.value < $1.value }) else { return nil }

        // Find a genre in same emotional register but not in existing set
        if let emotionalGenres = genreEmotionalMap[topEmotion.key] {
            let candidates = emotionalGenres.filter { !existingGenres.contains($0.lowercased()) }
            if let pick = candidates.randomElement() {
                return Suggestion(
                    title: "Try \(pick.lowercased())",
                    author: "",
                    reason: "Something slightly outside your usual pattern, but emotionally aligned.",
                    mode: .wildcard
                )
            }
        }

        return nil
    }
}
