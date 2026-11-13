import Foundation

/// What a study session covers.
enum StudyScope: Hashable {
    case all
    case deck(UUID)
    case tag(String)
}

/// The cards that can be studied right now, after applying the per-deck daily limits.
struct StudyQueue {
    struct Entry: Hashable {
        var deckID: UUID
        var card: Flashcard
    }

    /// How far ahead learning cards may be shown when nothing else is left (like Anki).
    static let learnAheadLimit: TimeInterval = 20 * 60

    var learning: [Entry] = []
    var reviews: [Entry] = []
    var new: [Entry] = []

    var isEmpty: Bool { learning.isEmpty && reviews.isEmpty && new.isEmpty }
    var totalCount: Int { learning.count + reviews.count + new.count }

    static func build(
        decks: [Deck],
        scope: StudyScope,
        settings: StudySettings,
        now: Date,
        calendar: Calendar = .current
    ) -> StudyQueue {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        var queue = StudyQueue()

        for deck in decks {
            switch scope {
            case .all, .tag: break
            case .deck(let id): if deck.id != id { continue }
            }
            let usage = DailyUsage(deck: deck, startOfToday: startOfToday)
            var newLeft = max(0, settings.newCardsPerDay - usage.newCards)
            var reviewsLeft = max(0, settings.reviewsPerDay - usage.reviews)

            var cards = deck.cards
            if case .tag(let tag) = scope {
                cards = cards.filter { $0.tags.contains(tag) }
            }

            let learning = cards.filter { $0.schedule.isLearning && $0.schedule.due < startOfTomorrow }
            let reviews = cards
                .filter { $0.schedule.state == .review && $0.schedule.due < startOfTomorrow }
                .sorted { $0.schedule.due < $1.schedule.due }
            let new = cards
                .filter { $0.schedule.state == .new }
                .sorted { $0.createdAt < $1.createdAt }

            queue.learning += learning.map { Entry(deckID: deck.id, card: $0) }
            for card in reviews where reviewsLeft > 0 {
                queue.reviews.append(Entry(deckID: deck.id, card: card))
                reviewsLeft -= 1
            }
            for card in new where newLeft > 0 {
                queue.new.append(Entry(deckID: deck.id, card: card))
                newLeft -= 1
            }
        }

        queue.learning.sort { $0.card.schedule.due < $1.card.schedule.due }
        queue.reviews.sort { $0.card.schedule.due < $1.card.schedule.due }
        return queue
    }

    /// Picks the card to show next: learning cards that are due, then reviews, then new cards,
    /// then learning cards due within the learn-ahead limit. Avoids repeating `previousCardID`
    /// back-to-back when there is something else to show.
    func next(now: Date, avoiding previousCardID: UUID? = nil) -> Entry? {
        let dueLearning = learning.filter { $0.card.schedule.due <= now }
        let learnAhead = learning.filter { $0.card.schedule.due <= now.addingTimeInterval(Self.learnAheadLimit) }
        let candidates = dueLearning + reviews + new + learnAhead
        if let pick = candidates.first(where: { $0.card.id != previousCardID }) {
            return pick
        }
        return candidates.first
    }

    /// Earliest due date among learning cards that are not yet available.
    var nextLearningDue: Date? { learning.map(\.card.schedule.due).min() }
}

/// How much of a deck's daily allowance has already been used today.
struct DailyUsage {
    var newCards = 0
    var reviews = 0

    init(deck: Deck, startOfToday: Date) {
        for card in deck.cards {
            if let first = card.firstReviewedAt, first >= startOfToday {
                newCards += 1
            }
            for entry in card.reviews.reversed() {
                guard entry.reviewedAt >= startOfToday else { break }
                if entry.previousState == .review { reviews += 1 }
            }
        }
    }
}
