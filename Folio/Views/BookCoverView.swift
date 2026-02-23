import SwiftUI

struct BookCoverView: View {
    let coverURL: String?
    var cornerRadius: CGFloat = 6

    var body: some View {
        if let urlString = coverURL, let url = URL(string: urlString) {
            Color(UIColor.secondarySystemBackground)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.coverPlaceholder)
                .overlay {
                    // Faint vertical spine line
                    HStack {
                        Rectangle()
                            .fill(Color.warmAccent.opacity(0.08))
                            .frame(width: 1)
                            .padding(.leading, 8)
                        Spacer()
                    }
                }
                .overlay {
                    Image(systemName: "book.closed")
                        .font(.title3)
                        .foregroundStyle(Color.secondaryText.opacity(0.6))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.warmAccent.opacity(0.25), lineWidth: 1)
                }
        }
    }
}
