import ActivityKit
import Foundation

@Observable
class LiveActivityService {
    private var currentActivity: Activity<ReadingActivityAttributes>?

    var isActivityActive: Bool {
        currentActivity != nil
    }

    func startActivity(bookTitle: String, authorName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ReadingActivityAttributes(
            bookTitle: bookTitle,
            authorName: authorName
        )
        let state = ReadingActivityAttributes.ContentState(
            elapsedSeconds: 0,
            startDate: Date()
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch { }
    }

    func updateActivity(elapsedSeconds: Int) async {
        guard let activity = currentActivity else { return }
        let state = ReadingActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            startDate: activity.content.state.startDate
        )
        await activity.update(.init(state: state, staleDate: nil))
    }

    func endActivity() async {
        guard let activity = currentActivity else { return }
        let finalState = activity.content.state
        await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        currentActivity = nil
    }
}
