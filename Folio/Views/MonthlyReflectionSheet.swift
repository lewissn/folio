import SwiftUI

struct MonthlyReflectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let reflectionText: String

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(monthName)
                        .font(.serifTitle(.title2))
                        .foregroundStyle(Color.charcoal)

                    Text(reflectionText)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color.charcoal)
                        .lineSpacing(5)
                }
                .padding()
            }
            .navigationTitle("Monthly Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.charcoal)
                }
            }
        }
    }
}
