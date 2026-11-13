import SwiftUI

enum Theme {
    static let cornerRadius: CGFloat = 14
    static let cardMaxWidth: CGFloat = 680

    /// Colors of the three queue counts, as in other spaced-repetition apps.
    static let newColor = Color.accentColor
    static let learningColor = Color.orange
    static let reviewColor = Color.green

    static func color(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: .red
        case .hard: .orange
        case .good: .green
        case .easy: .accentColor
        }
    }
}

/// A rounded, softly filled container used for the panels on the Today screen.
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

/// "12 new · 3 learning · 40 due"-style counts.
struct QueueCounts: View {
    var new: Int
    var learning: Int
    var review: Int

    var body: some View {
        HStack(spacing: 12) {
            count(new, color: Theme.newColor, label: "New")
            count(learning, color: Theme.learningColor, label: "Learning")
            count(review, color: Theme.reviewColor, label: "Due")
        }
        .font(.callout)
    }

    private func count(_ value: Int, color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text(value, format: .number)
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(value > 0 ? color : .secondary)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

enum IntervalText {
    /// Short, localized "10 min" / "3 d" / "2 mo" label for the time until `date`.
    static func string(until date: Date, from now: Date = .now) -> String {
        let seconds = max(60, date.timeIntervalSince(now))
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = switch seconds {
        case ..<3_600: [.minute]
        case ..<86_400: [.hour]
        case ..<(86_400 * 30): [.day]
        case ..<(86_400 * 365): [.month]
        default: [.year]
        }
        return formatter.string(from: seconds) ?? ""
    }
}

/// Current time, refreshed every minute, so due counts stay fresh while the app sits open.
struct MinuteClock<Content: View>: View {
    @ViewBuilder var content: (Date) -> Content
    @State private var now = Date.now

    var body: some View {
        content(now)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    now = .now
                }
            }
    }
}
