import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCoverView(coverURL: book.coverURL, cornerRadius: 4)
                .frame(width: 56, height: 84)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .foregroundStyle(Color.charcoal)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !book.authors.isEmpty {
                    Text(book.authors.joined(separator: ", "))
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }

                if let year = book.publishYear {
                    Text(String(year))
                        .font(.serifCaption())
                        .foregroundStyle(Color.secondaryText)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }
}
