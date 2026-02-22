import SwiftUI

struct PauseReasonSheet: View {
    @Environment(\.dismiss) private var dismiss

    let book: Book
    @State private var selectedReasons: Set<PauseReason> = []
    @State private var otherText: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("What shifted?")
                    .font(.serifHeadline())
                    .foregroundStyle(Color.charcoal)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(PauseReason.allCases) { reason in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if selectedReasons.contains(reason) {
                                    selectedReasons.remove(reason)
                                } else {
                                    selectedReasons.insert(reason)
                                }
                            }
                        } label: {
                            Text(reason.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(selectedReasons.contains(reason) ? Color.paper : Color.charcoal)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selectedReasons.contains(reason) ? Color.charcoal : Color.elevatedSurface,
                                    in: Capsule()
                                )
                        }
                    }
                }

                if selectedReasons.contains(.other) {
                    TextField("What happened?", text: $otherText, axis: .vertical)
                        .font(.body)
                        .lineLimit(2...4)
                        .foregroundStyle(Color.charcoal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Pausing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        book.status = .paused
                        dismiss()
                    }
                    .foregroundStyle(Color.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        book.status = .paused
                        book.pauseReasons = Array(selectedReasons)
                        if selectedReasons.contains(.other) && !otherText.isEmpty {
                            book.pausedReason = otherText
                        }
                        dismiss()
                    }
                    .foregroundStyle(Color.charcoal)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
