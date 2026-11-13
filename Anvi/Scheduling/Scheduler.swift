import Foundation
import FSRS

/// Thin wrapper around swift-fsrs (FSRS-6). All scheduling decisions go through here.
struct Scheduler {
    let fsrs: FSRS

    init(desiredRetention: Double) {
        let parameters = FSRSParameters(
            requestRetention: min(max(desiredRetention, 0.7), 0.99),
            maximumInterval: 36_500,
            w: FSRSDefaults.defaultWv6,
            enableFuzz: false,
            enableShortTerm: true,
            learningSteps: ["1m", "10m"],
            relearningSteps: ["10m"]
        )
        fsrs = FSRS(parameters: parameters)
    }

    /// The schedule that results from answering `rating` at `date`.
    func next(_ schedule: Schedule, rating: ReviewRating, at date: Date) throws -> Schedule {
        let item = try fsrs.next(card: schedule.fsrsCard, now: date, grade: rating.fsrsRating)
        return Schedule(item.card)
    }

    /// Next due date for each possible answer, used to label the answer buttons.
    func preview(_ schedule: Schedule, at date: Date) -> [ReviewRating: Date] {
        var result: [ReviewRating: Date] = [:]
        for rating in ReviewRating.allCases {
            if let next = try? next(schedule, rating: rating, at: date) {
                result[rating] = next.due
            }
        }
        return result
    }
}

extension ReviewRating {
    var fsrsRating: Rating {
        switch self {
        case .again: .again
        case .hard: .hard
        case .good: .good
        case .easy: .easy
        }
    }
}

extension Schedule {
    init(_ card: Card) {
        let state: State = switch card.state {
        case .new: .new
        case .learning: .learning
        case .review: .review
        case .relearning: .relearning
        }
        self.init(
            state: state,
            due: card.due,
            stability: card.stability,
            difficulty: card.difficulty,
            elapsedDays: card.elapsedDays,
            scheduledDays: card.scheduledDays,
            learningStep: card.learningSteps,
            reps: card.reps,
            lapses: card.lapses,
            lastReview: card.lastReview
        )
    }

    var fsrsCard: Card {
        let fsrsState: CardState = switch state {
        case .new: .new
        case .learning: .learning
        case .review: .review
        case .relearning: .relearning
        }
        return Card(
            due: due,
            stability: stability,
            difficulty: difficulty,
            elapsedDays: elapsedDays,
            scheduledDays: scheduledDays,
            learningSteps: learningStep,
            reps: reps,
            lapses: lapses,
            state: fsrsState,
            lastReview: lastReview
        )
    }
}
