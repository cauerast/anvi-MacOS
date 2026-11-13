import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.store
        Group {
            if store.decks.isEmpty {
                EmptyStateView(
                    title: "Welcome to Anvi",
                    message: "Create a deck, add a few cards and study a little every day. Everything stays on this Mac."
                ) {
                    Button("Create a Deck") { model.newDeck() }
                        .buttonStyle(.borderedProminent)
                    Button("Import Deck…") { model.importDeck() }
                }
            } else {
                MinuteClock { now in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header(now: now)
                            FocusPanel(queue: store.queue(for: .all, now: now))
                            HStack(alignment: .top, spacing: 20) {
                                StreakPanel(streak: store.streak)
                                ActivityPanel(activity: store.activity, today: now)
                            }
                            DecksPanel(now: now)
                        }
                        .padding(28)
                        .frame(maxWidth: 900)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Today")
    }

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(.largeTitle.weight(.bold))
            Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FocusPanel: View {
    @Environment(AppModel.self) private var model
    var queue: StudyQueue

    var body: some View {
        Panel {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's focus")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if queue.isEmpty {
                        Text("All caught up")
                            .font(.title.weight(.semibold))
                        Text("Nothing is due right now. New cards and reviews come back tomorrow.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Review \(queue.totalCount) cards")
                            .font(.title.weight(.semibold))
                        QueueCounts(new: queue.new.count, learning: queue.learning.count, review: queue.reviews.count)
                    }
                }
                Spacer()
                if !queue.isEmpty {
                    Button {
                        model.startStudy(.all)
                    } label: {
                        Label("Start Review", systemImage: "play.fill")
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }
}

private struct StreakPanel: View {
    var streak: StreakSummary

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your rhythm")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(streak.studiedToday ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                    Text(streak.current, format: .number)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(streak.current == 1 ? "day" : "days")
                        .foregroundStyle(.secondary)
                }
                Text(streak.studiedToday
                     ? "Studied today: \(streak.answersToday) answers."
                     : "Study one card today to keep your streak.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Longest streak: \(streak.longest) days")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 260)
    }
}

/// GitHub-style grid of the last weeks of study.
private struct ActivityPanel: View {
    var activity: [String: Int]
    var today: Date

    private let weeks = 18
    private let cell: CGFloat = 12
    private let gap: CGFloat = 3

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activity")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: gap) {
                    ForEach(columns, id: \.self) { column in
                        VStack(spacing: gap) {
                            ForEach(column, id: \.self) { day in
                                square(for: day)
                            }
                        }
                    }
                }
                HStack(spacing: 4) {
                    Text("Less")
                    ForEach(0..<5) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(level: level))
                            .frame(width: cell, height: cell)
                    }
                    Text("More")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Weeks of days, oldest first; each column starts on the calendar's first weekday.
    private var columns: [[Date]] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: todayStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -offset, to: todayStart),
              let firstDay = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeekStart)
        else { return [] }
        return (0..<weeks).map { week in
            (0..<7).compactMap { day in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstDay),
                      date <= todayStart else { return nil }
                return date
            }
        }
    }

    private func square(for day: Date) -> some View {
        let count = activity[DayKey.string(for: day)] ?? 0
        return RoundedRectangle(cornerRadius: 3)
            .fill(color(level: level(for: count)))
            .frame(width: cell, height: cell)
            .help(Text("Answers on \(day.formatted(date: .abbreviated, time: .omitted)): \(count)"))
    }

    private func level(for count: Int) -> Int {
        switch count {
        case 0: 0
        case 1..<20: 1
        case 20..<50: 2
        case 50..<100: 3
        default: 4
        }
    }

    private func color(level: Int) -> Color {
        level == 0 ? Color.primary.opacity(0.07) : Color.accentColor.opacity([0, 0.3, 0.5, 0.75, 1][level])
    }
}

private struct DecksPanel: View {
    @Environment(AppModel.self) private var model
    var now: Date

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("My decks")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("New Deck") { model.newDeck() }
                        .buttonStyle(.borderless)
                }
                .padding(.bottom, 6)
                ForEach(model.store.decks) { deck in
                    let queue = model.store.queue(for: .deck(deck.id), now: now)
                    HStack(spacing: 12) {
                        Button {
                            model.selection = .deck(deck.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(deck.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                ProgressView(value: deck.progress)
                                    .progressViewStyle(.linear)
                                    .frame(maxWidth: 240)
                                    .help(Text("Studied: \(deck.studiedCount) of \(deck.cards.count)"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        QueueCounts(new: queue.new.count, learning: queue.learning.count, review: queue.reviews.count)
                        Button("Study") { model.startStudy(.deck(deck.id)) }
                            .disabled(queue.isEmpty)
                    }
                    .padding(.vertical, 8)
                    if deck.id != model.store.decks.last?.id { Divider() }
                }
            }
        }
    }
}

extension Deck {
    var studiedCount: Int { cards.filter { $0.schedule.state != .new }.count }
    var progress: Double { cards.isEmpty ? 0 : Double(studiedCount) / Double(cards.count) }
}
