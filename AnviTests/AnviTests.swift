import Foundation
import Testing
@testable import Anvi

@MainActor
struct SchedulerTests {
    @Test func newCardAnsweredGoodMovesIntoLearning() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let scheduler = Scheduler(desiredRetention: 0.9)
        let next = try scheduler.next(Schedule.new(at: now), rating: .good, at: now)
        #expect(next.state == .learning)
        #expect(next.due > now)
        #expect(next.reps == 1)
    }

    @Test func easierAnswersNeverComeBackSooner() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let preview = Scheduler(desiredRetention: 0.9).preview(Schedule.new(at: now), at: now)
        let dues = ReviewRating.allCases.compactMap { preview[$0] }
        #expect(dues.count == 4)
        #expect(dues == dues.sorted())
    }

    @Test func scheduleRoundTripsThroughFSRSCard() {
        let original = Schedule(
            state: .relearning, due: Date(timeIntervalSince1970: 1_800_000_000), stability: 3.2,
            difficulty: 5.1, elapsedDays: 4, scheduledDays: 6, learningStep: 1, reps: 7, lapses: 2,
            lastReview: Date(timeIntervalSince1970: 1_799_000_000)
        )
        #expect(Schedule(original.fsrsCard) == original)
    }
}

@MainActor
struct StudyQueueTests {
    let calendar = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func deck(newCards: Int, dueReviews: Int) -> Deck {
        var cards = (0..<newCards).map { Flashcard(front: "n\($0)", back: "b", createdAt: now.addingTimeInterval(Double($0))) }
        for index in 0..<dueReviews {
            var card = Flashcard(front: "r\(index)", back: "b", createdAt: now.addingTimeInterval(-86_400 * 10))
            card.schedule.state = .review
            card.schedule.due = now.addingTimeInterval(-60)
            cards.append(card)
        }
        return Deck(name: "Test", cards: cards)
    }

    @Test func dailyLimitsApplyPerDeck() {
        var settings = StudySettings()
        settings.newCardsPerDay = 5
        settings.reviewsPerDay = 3
        let decks = [deck(newCards: 10, dueReviews: 8), deck(newCards: 2, dueReviews: 1)]
        let queue = StudyQueue.build(decks: decks, scope: .all, settings: settings, now: now, calendar: calendar)
        #expect(queue.new.count == 5 + 2)
        #expect(queue.reviews.count == 3 + 1)
    }

    @Test func newCardsStudiedTodayUseUpTheAllowance() {
        var settings = StudySettings()
        settings.newCardsPerDay = 3
        var testDeck = deck(newCards: 5, dueReviews: 0)
        testDeck.cards[0].reviews = [ReviewEntry(rating: .good, reviewedAt: now, previousState: .new, scheduledDays: 0)]
        testDeck.cards[0].schedule.state = .learning
        testDeck.cards[0].schedule.due = now.addingTimeInterval(600)
        let queue = StudyQueue.build(decks: [testDeck], scope: .all, settings: settings, now: now, calendar: calendar)
        #expect(queue.new.count == 2)
        #expect(queue.learning.count == 1)
    }

    @Test func tagScopeOnlyIncludesTaggedCards() {
        var testDeck = deck(newCards: 4, dueReviews: 0)
        testDeck.cards[1].tags = ["verbs"]
        let queue = StudyQueue.build(decks: [testDeck], scope: .tag("verbs"), settings: StudySettings(), now: now, calendar: calendar)
        #expect(queue.new.map(\.card.id) == [testDeck.cards[1].id])
    }

    @Test func nextPrefersDueLearningThenReviewsThenNew() {
        var testDeck = deck(newCards: 1, dueReviews: 1)
        var learning = Flashcard(front: "l", back: "b", createdAt: now)
        learning.schedule.state = .learning
        learning.schedule.due = now.addingTimeInterval(-5)
        testDeck.cards.append(learning)
        let queue = StudyQueue.build(decks: [testDeck], scope: .all, settings: StudySettings(), now: now, calendar: calendar)
        #expect(queue.next(now: now)?.card.id == learning.id)
        #expect(queue.next(now: now, avoiding: learning.id)?.card.schedule.state == .review)
    }
}

@MainActor
struct StreakTests {
    let calendar = Calendar(identifier: .gregorian)

    private func key(_ daysAgo: Int, from today: Date) -> String {
        DayKey.string(for: calendar.date(byAdding: .day, value: -daysAgo, to: today)!, calendar: calendar)
    }

    @Test func countsConsecutiveDaysIncludingToday() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let activity = [key(0, from: today): 5, key(1, from: today): 3, key(2, from: today): 1, key(4, from: today): 9]
        let streak = StreakSummary(activity: activity, today: today, calendar: calendar)
        #expect(streak.current == 3)
        #expect(streak.studiedToday)
        #expect(streak.answersToday == 5)
    }

    @Test func streakSurvivesUntilTheDayIsOver() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let activity = [key(1, from: today): 3, key(2, from: today): 1]
        let streak = StreakSummary(activity: activity, today: today, calendar: calendar)
        #expect(streak.current == 2)
        #expect(!streak.studiedToday)
    }

    @Test func longestStreakIsTracked() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let activity = [10, 11, 12, 13, 20].reduce(into: [String: Int]()) { $0[key($1, from: today)] = 1 }
        let streak = StreakSummary(activity: activity, today: today, calendar: calendar)
        #expect(streak.current == 0)
        #expect(streak.longest == 4)
    }
}

@MainActor
struct LibraryStoreTests {
    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AnviTests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func decksCardsAndReviewsArePersisted() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let store = LibraryStore(root: folder)
        let deckID = store.createDeck(named: "  Japanese  ")
        let card = Flashcard(front: "**猫**", back: "cat", tags: ["animals"])
        store.addCard(card, to: deckID)
        let undo = try #require(store.answer(cardID: card.id, in: deckID, rating: .good))
        #expect(store.streak.answersToday == 1)

        let reloaded = LibraryStore(root: folder)
        let deck = try #require(reloaded.deck(deckID))
        #expect(deck.name == "Japanese")
        #expect(deck.cards.first?.reviews.count == 1)
        #expect(deck.cards.first?.schedule.state == .learning)
        #expect(reloaded.allTags == ["animals"])
        #expect(reloaded.streak.answersToday == 1)

        store.undo(undo)
        let afterUndo = LibraryStore(root: folder)
        #expect(afterUndo.deck(deckID)?.cards.first?.reviews.isEmpty == true)
        #expect(afterUndo.streak.answersToday == 0)
    }

    @Test func exportThenImportMergesByCardID() throws {
        let folder = temporaryFolder()
        let other = temporaryFolder()
        defer {
            try? FileManager.default.removeItem(at: folder)
            try? FileManager.default.removeItem(at: other)
        }

        let store = LibraryStore(root: folder)
        let deckID = store.createDeck(named: "Words")
        let card = Flashcard(front: "one", back: "1")
        store.addCard(card, to: deckID)
        let exportURL = folder.appendingPathComponent("export.json")
        try store.exportDeck(deckID, to: exportURL)

        // A fresh library gets the whole deck.
        let second = LibraryStore(root: other)
        let first = try second.importDeck(from: exportURL)
        #expect(first.added == 1)
        #expect(second.deck(deckID)?.cards.count == 1)

        // The original gains a card and a review; importing it again adds and updates.
        store.addCard(Flashcard(front: "two", back: "2"), to: deckID)
        _ = store.answer(cardID: card.id, in: deckID, rating: .easy)
        try store.exportDeck(deckID, to: exportURL)
        let again = try second.importDeck(from: exportURL)
        #expect(again.added == 1)
        #expect(again.updated == 1)
        #expect(second.deck(deckID)?.cards.count == 2)
    }

    @Test func handWrittenDeckCanBeImported() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let json = #"{ "name": "Capitals", "cards": [ { "front": "France", "back": "Paris", "tags": ["europe"], "createdAt": "2026-01-02T03:04:05Z" } ] }"#
        let url = folder.appendingPathComponent("capitals.json")
        try Data(json.utf8).write(to: url)

        let store = LibraryStore(root: folder.appendingPathComponent("library"))
        let result = try store.importDeck(from: url)
        #expect(result.deckName == "Capitals")
        #expect(store.deck(result.deckID)?.cards.first?.schedule.state == .new)
        #expect(store.deck(result.deckID)?.cards.first?.createdAt == Date(timeIntervalSince1970: 1_767_323_045))
    }

    @Test func unreadableDeckFilesAreLeftUntouched() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = LibraryFiles(root: folder)
        try files.prepare()
        let broken = files.decksFolder.appendingPathComponent("broken.json")
        try Data("{ not json".utf8).write(to: broken)

        let store = LibraryStore(root: folder)
        #expect(store.unreadableFiles == ["broken.json"])
        #expect(try String(contentsOf: broken, encoding: .utf8) == "{ not json")
    }
}
