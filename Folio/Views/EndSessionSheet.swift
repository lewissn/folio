import SwiftUI
import SwiftData

struct EndSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let book: Book
    let sessionStart: Date
    let durationMinutes: Int
    @Binding var sessionSaved: Bool

    @State private var pagesRead: String = ""
    @State private var reflection: String = ""
    @State private var selectedMood: String?
    @State private var chapterReference: String = ""

    private let moods = ["calm", "focused", "restless", "inspired"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                        Text("\(durationMinutes) minutes")
                            .font(.serifTitle(.title3))
                            .foregroundStyle(Color.charcoal)
                    }

                    Rectangle().fill(Color.hairline).frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pages read")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                        TextField("Optional", text: $pagesRead)
                            .font(.serifBody())
                            .keyboardType(.numberPad)
                            .foregroundStyle(Color.charcoal)
                    }

                    Rectangle().fill(Color.hairline).frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chapter or page")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                        TextField("e.g. Chapter 4, p.112", text: $chapterReference)
                            .font(.serifBody())
                            .foregroundStyle(Color.charcoal)
                    }

                    Rectangle().fill(Color.hairline).frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reflection")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)
                        TextField("A thought from this session...", text: $reflection, axis: .vertical)
                            .font(.serifBody())
                            .lineLimit(3...6)
                            .foregroundStyle(Color.charcoal)
                    }

                    Rectangle().fill(Color.hairline).frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mood")
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(Color.secondaryText)

                        HStack(spacing: 8) {
                            ForEach(moods, id: \.self) { mood in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedMood = selectedMood == mood ? nil : mood
                                    }
                                } label: {
                                    Text(mood)
                                        .font(.system(.subheadline, design: .serif))
                                        .foregroundStyle(selectedMood == mood ? Color.paper : Color.charcoal)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedMood == mood ? Color.charcoal : Color.elevatedSurface,
                                            in: Capsule()
                                        )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                        .foregroundStyle(Color.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                        sessionSaved = true
                        dismiss()
                    }
                    .foregroundStyle(Color.charcoal)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveSession() {
        let session = ReadingSession(book: book, startedAt: sessionStart, durationMinutes: durationMinutes)
        session.endedAt = Date()
        session.pagesRead = Int(pagesRead)
        session.reflectionText = reflection.isEmpty ? nil : reflection
        session.moodWord = selectedMood
        session.chapterReference = chapterReference.isEmpty ? nil : chapterReference
        modelContext.insert(session)
    }
}
