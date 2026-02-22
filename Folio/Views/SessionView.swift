import SwiftUI
import SwiftData

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let book: Book
    @State private var sessionStart: Date = Date()
    @State private var showEndSheet: Bool = false
    @State private var elapsedSeconds: Int = 0
    @State private var sessionSaved: Bool = false
    @State private var appeared: Bool = false
    @State private var liveActivityService = LiveActivityService()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            BookCoverView(coverURL: book.coverURL, cornerRadius: 8)
                .frame(width: 140, height: 210)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                .scaleEffect(appeared ? 1.0 : 0.96)
                .opacity(appeared ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: appeared)

            Spacer().frame(height: 28)

            Text(book.title)
                .font(.serifTitle(.title2))
                .foregroundStyle(Color.charcoal)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(appeared ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.1), value: appeared)

            if !book.authors.isEmpty {
                Text(book.authors.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .padding(.top, 4)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5).delay(0.15), value: appeared)
            }

            Spacer().frame(height: 48)

            Text(formattedTime)
                .font(.system(size: 42, weight: .light, design: .monospaced))
                .foregroundStyle(Color.charcoal.opacity(0.7))
                .contentTransition(.numericText())
                .animation(.default, value: elapsedSeconds)
                .opacity(appeared ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).delay(0.2), value: appeared)

            Spacer()

            Button {
                showEndSheet = true
            } label: {
                Text("tap to end")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.elevatedSurface, in: Capsule())
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showEndSheet)
            .padding(.bottom, 60)
            .opacity(appeared ? 1 : 0)
            .animation(.easeInOut(duration: 0.5).delay(0.3), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.paper(for: .current)
                .opacity(0.97)
                .ignoresSafeArea()
        )
        .onAppear {
            appeared = true
            sessionStart = Date()
            book.lastOpenedAt = Date()
            liveActivityService.startActivity(
                bookTitle: book.title,
                authorName: book.authors.first ?? ""
            )
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsedSeconds = Int(Date().timeIntervalSince(sessionStart))
                if elapsedSeconds % 30 == 0 {
                    await liveActivityService.updateActivity(elapsedSeconds: elapsedSeconds)
                }
            }
        }
        .sheet(isPresented: $showEndSheet, onDismiss: {
            if sessionSaved {
                Task { await liveActivityService.endActivity() }
                dismiss()
            }
        }) {
            EndSessionSheet(
                book: book,
                sessionStart: sessionStart,
                durationMinutes: max(1, elapsedSeconds / 60),
                sessionSaved: $sessionSaved
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .presentationBackground(Color.paper)
        }
    }

    private var formattedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
