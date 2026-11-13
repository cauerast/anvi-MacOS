import Foundation
import Observation

/// One study session over a scope (all decks, a deck or a tag).
/// The store stays the source of truth: after each answer the queue is rebuilt from it.
@Observable
final class ReviewSession {
    let scope: StudyScope
    let title: String
    private let store: LibraryStore

    private(set) var queue = StudyQueue()
    private(set) var current: StudyQueue.Entry?
    private(set) var intervals: [ReviewRating: Date] = [:]
    private(set) var answeredCount = 0
    private var undoStack: [LibraryStore.ReviewUndo] = []
    var isRevealed = false

    init(store: LibraryStore, scope: StudyScope, title: String) {
        self.store = store
        self.scope = scope
        self.title = title
        refresh(avoiding: nil)
    }

    var isFinished: Bool { current == nil }
    var canUndo: Bool { !undoStack.isEmpty }

    /// When nothing is available right now but learning cards come back later today.
    var nextCardDate: Date? { current == nil ? queue.nextLearningDue : nil }

    func reveal() {
        guard current != nil else { return }
        isRevealed = true
    }

    func answer(_ rating: ReviewRating) {
        guard let current, isRevealed else { return }
        if let undo = store.answer(cardID: current.card.id, in: current.deckID, rating: rating) {
            undoStack.append(undo)
            answeredCount += 1
        }
        refresh(avoiding: current.card.id)
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        store.undo(last)
        answeredCount = max(0, answeredCount - 1)
        queue = store.queue(for: scope)
        current = StudyQueue.Entry(deckID: last.deckID, card: last.previousCard)
        isRevealed = false
        updateIntervals()
    }

    /// Re-reads the queue, e.g. when waiting learning cards become due.
    func refresh(avoiding previousCardID: UUID? = nil) {
        let now = Date.now
        queue = store.queue(for: scope, now: now)
        current = queue.next(now: now, avoiding: previousCardID)
        isRevealed = false
        updateIntervals()
    }

    private func updateIntervals() {
        guard let current else {
            intervals = [:]
            return
        }
        let scheduler = Scheduler(desiredRetention: store.settings.desiredRetention)
        intervals = scheduler.preview(current.card.schedule, at: .now)
    }
}
