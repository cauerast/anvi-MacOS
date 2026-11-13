import Foundation

/// A single flashcard. Lives inside a `Deck` and is stored in that deck's JSON file.
struct Flashcard: Identifiable, Hashable, Codable {
    var id: UUID
    var front: String
    var back: String
    /// File name inside the library's `media/` folder.
    var frontImage: String?
    var backImage: String?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var schedule: Schedule
    var reviews: [ReviewEntry]

    init(
        id: UUID = UUID(),
        front: String,
        back: String,
        frontImage: String? = nil,
        backImage: String? = nil,
        tags: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.frontImage = frontImage
        self.backImage = backImage
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.schedule = Schedule.new(at: createdAt)
        self.reviews = []
    }

    // Lenient decoding: a hand-written deck only needs `front` and `back` per card.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date.now
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        front = try c.decodeIfPresent(String.self, forKey: .front) ?? ""
        back = try c.decodeIfPresent(String.self, forKey: .back) ?? ""
        frontImage = try c.decodeIfPresent(String.self, forKey: .frontImage)
        backImage = try c.decodeIfPresent(String.self, forKey: .backImage)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        schedule = try c.decodeIfPresent(Schedule.self, forKey: .schedule) ?? Schedule.new(at: createdAt)
        reviews = try c.decodeIfPresent([ReviewEntry].self, forKey: .reviews) ?? []
    }

    var imageFileNames: [String] { [frontImage, backImage].compactMap { $0 } }

    /// The first time this card was ever studied, if it has been.
    var firstReviewedAt: Date? { reviews.first?.reviewedAt }
}

/// FSRS memory state of a card. Mirrors `FSRS.Card`, with readable state names in JSON.
struct Schedule: Hashable, Codable {
    enum State: String, Codable {
        case new, learning, review, relearning
    }

    var state: State
    var due: Date
    var stability: Double
    var difficulty: Double
    var elapsedDays: Double
    var scheduledDays: Double
    var learningStep: Int
    var reps: Int
    var lapses: Int
    var lastReview: Date?

    static func new(at date: Date) -> Schedule {
        Schedule(
            state: .new, due: date, stability: 0, difficulty: 0, elapsedDays: 0,
            scheduledDays: 0, learningStep: 0, reps: 0, lapses: 0, lastReview: nil
        )
    }

    var isLearning: Bool { state == .learning || state == .relearning }
}

enum ReviewRating: String, Codable, CaseIterable, Identifiable {
    case again, hard, good, easy
    var id: String { rawValue }
}

/// One answer given during a review. Kept for history, statistics and undo.
struct ReviewEntry: Hashable, Codable {
    var rating: ReviewRating
    var reviewedAt: Date
    /// Card state before this answer. `.review` answers count against the daily review limit.
    var previousState: Schedule.State
    /// Interval chosen by the scheduler, in days (can be a fraction for learning steps).
    var scheduledDays: Double
}
