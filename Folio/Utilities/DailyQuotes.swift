import Foundation

/// Curated set of quiet, reflective quotes. One per day, deterministic.
nonisolated enum DailyQuotes {
    private static let quotes: [(text: String, author: String)] = [
        ("The happiness of your life depends upon the quality of your thoughts.", "Marcus Aurelius"),
        ("We suffer more often in imagination than in reality.", "Seneca"),
        ("No man is free who is not master of himself.", "Epictetus"),
        ("The soul becomes dyed with the colour of its thoughts.", "Marcus Aurelius"),
        ("It is not that we have a short time to live, but that we waste a great deal of it.", "Seneca"),
        ("In the middle of winter I at last discovered that there was in me an invincible summer.", "Albert Camus"),
        ("The only way to deal with an unfree world is to become so absolutely free that your very existence is an act of rebellion.", "Albert Camus"),
        ("Waste no more time arguing about what a good man should be. Be one.", "Marcus Aurelius"),
        ("He who fears death will never do anything worth of a man who is alive.", "Seneca"),
        ("First say to yourself what you would be; and then do what you have to do.", "Epictetus"),
        ("Perhaps all the dragons in our lives are princesses who are only waiting to see us act with beauty and courage.", "Rainer Maria Rilke"),
        ("The purpose of life is not to be happy. It is to be useful, to be honourable, to be compassionate.", "Seneca"),
        ("You have power over your mind, not outside events. Realise this, and you will find strength.", "Marcus Aurelius"),
        ("Let everything happen to you. Beauty and terror. Just keep going. No feeling is final.", "Rainer Maria Rilke"),
        ("Man is not worried by real problems so much as by his imagined anxieties about real problems.", "Epictetus"),
        ("The best revenge is not to be like your enemy.", "Marcus Aurelius"),
        ("Luck is what happens when preparation meets opportunity.", "Seneca"),
        ("Should you find yourself in a chronically leaking boat, energy devoted to changing vessels is likely to be more productive than energy devoted to patching.", "Seneca"),
        ("The things you think about determine the quality of your mind.", "Marcus Aurelius"),
        ("Wealth consists not in having great possessions, but in having few wants.", "Epictetus"),
        ("Live as if you were to die tomorrow. Learn as if you were to live forever.", "Seneca"),
        ("The impediment to action advances action. What stands in the way becomes the way.", "Marcus Aurelius"),
        ("Be tolerant with others and strict with yourself.", "Marcus Aurelius"),
        ("It is not because things are difficult that we do not dare; it is because we do not dare that things are difficult.", "Seneca"),
        ("How much time he gains who does not look to see what his neighbour says or does or thinks.", "Marcus Aurelius"),
        ("The future enters into us long before it happens.", "Rainer Maria Rilke"),
        ("Caretake this moment.", "Epictetus"),
        ("If it is not right, do not do it. If it is not true, do not say it.", "Marcus Aurelius"),
        ("Difficulties strengthen the mind, as labour does the body.", "Seneca"),
        ("He who has a why to live can bear almost any how.", "Seneca"),
    ]

    /// Today's quote — deterministic, changes once per day.
    static var today: (text: String, author: String) {
        let daysSinceReference = Calendar.current.dateComponents(
            [.day],
            from: Date(timeIntervalSinceReferenceDate: 0),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        let index = abs(daysSinceReference) % quotes.count
        return quotes[index]
    }
}
