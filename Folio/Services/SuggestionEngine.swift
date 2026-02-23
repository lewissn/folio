import Foundation

/// Three-mode suggestion engine. Generates book recommendations
/// based on reading behaviour without external AI dependencies.
nonisolated enum SuggestionEngine {

    enum SuggestionMode: String, Sendable {
        case aligned = "In your pattern"
        case adjacent = "One step outside"
        case wildcard = "Something different"
    }

    struct Suggestion: Sendable, Identifiable {
        let id = UUID()
        let title: String
        let author: String
        let reason: String
        let mode: SuggestionMode
    }

    // MARK: - Generate All Suggestions

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

        // Recommend based on most-read author who has other works
        if let topAuthor = profile.topAuthors.first {
            let existingTitles = Set(books.filter { $0.authors.contains(topAuthor.author) }.map { $0.title })
            return Suggestion(
                title: "More by \(topAuthor.author)",
                author: topAuthor.author,
                reason: "You've read \(topAuthor.count) of their books and tend to return.",
                mode: .aligned
            )
        }

        // Recommend based on top genre
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
