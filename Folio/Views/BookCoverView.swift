import SwiftUI

struct BookCoverView: View {
    let coverURL: String?
    var cornerRadius: CGFloat = 6

    @State private var cachedImage: Image?
    @State private var isLoading: Bool = false

    var body: some View {
        Group {
            if let image = cachedImage {
                Color.clear
                    .overlay {
                        image.resizable().aspectRatio(contentMode: .fill)
                    }
                    .clipShape(.rect(cornerRadius: cornerRadius))
            } else if let urlString = coverURL, !urlString.isEmpty {
                Color(UIColor.secondarySystemBackground)
                    .clipShape(.rect(cornerRadius: cornerRadius))
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .tint(Color.warmAccent.opacity(0.5))
                                .scaleEffect(0.7)
                        }
                    }
                    .task(id: urlString) {
                        isLoading = true
                        cachedImage = await CoverImageCache.shared.image(for: urlString)
                        isLoading = false
                    }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.coverPlaceholder)
            .overlay {
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
