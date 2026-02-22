import SwiftUI

nonisolated enum TimeOfDay: Sendable {
    case morning
    case afternoon
    case evening
    case lateNight

    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<22: return .evening
        default: return .lateNight
        }
    }
}

extension Color {
    static func paper(for time: TimeOfDay = .current) -> Color {
        Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                switch time {
                case .morning:
                    return UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
                case .afternoon:
                    return UIColor(red: 0.11, green: 0.11, blue: 0.10, alpha: 1)
                case .evening:
                    return UIColor(red: 0.12, green: 0.11, blue: 0.09, alpha: 1)
                case .lateNight:
                    return UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)
                }
            } else {
                switch time {
                case .morning:
                    return UIColor(red: 0.95, green: 0.94, blue: 0.93, alpha: 1)
                case .afternoon:
                    return UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1)
                case .evening:
                    return UIColor(red: 0.97, green: 0.94, blue: 0.90, alpha: 1)
                case .lateNight:
                    return UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1)
                }
            }
        })
    }

    static let paper = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.10, alpha: 1)
            : UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1)
    })

    static let elevatedSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1)
            : UIColor(red: 0.94, green: 0.91, blue: 0.87, alpha: 1)
    })

    static let charcoal = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.89, blue: 0.87, alpha: 1)
            : UIColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1)
    })

    static let secondaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.56, green: 0.55, blue: 0.51, alpha: 1)
            : UIColor(red: 0.43, green: 0.42, blue: 0.39, alpha: 1)
    })

    static let hairline = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.08)
            : UIColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 0.08)
    })

    static let warmAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.54, green: 0.50, blue: 0.44, alpha: 1)
            : UIColor(red: 0.78, green: 0.75, blue: 0.68, alpha: 1)
    })
}

extension Font {
    static func serifTitle(_ style: TextStyle = .title) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    static func serifHeadline() -> Font {
        .system(.headline, design: .serif).weight(.semibold)
    }

    static func serifLargeTitle() -> Font {
        .system(.largeTitle, design: .serif).weight(.semibold)
    }

    static func serifBody() -> Font {
        .system(.body, design: .serif)
    }

    static func serifCaption() -> Font {
        .system(.caption, design: .serif)
    }
}

extension Array where Element: Hashable {
    var mostFrequent: Element? {
        let counts = reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

struct AtmosphericBackground: View {
    let timeOfDay: TimeOfDay

    var body: some View {
        Color.paper(for: timeOfDay)
            .overlay {
                if timeOfDay == .lateNight {
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.03)],
                        center: .center,
                        startRadius: 100,
                        endRadius: 400
                    )
                }
            }
            .ignoresSafeArea()
    }
}
