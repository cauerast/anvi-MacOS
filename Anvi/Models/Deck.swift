import Foundation

struct Deck: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var cards: [Flashcard]

    init(id: UUID = UUID(), name: String, notes: String = "", createdAt: Date = .now, cards: [Flashcard] = []) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.cards = cards
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        cards = try c.decodeIfPresent([Flashcard].self, forKey: .cards) ?? []
    }

    var allTags: Set<String> { Set(cards.flatMap(\.tags)) }
}

/// The JSON document for one deck. The same format is used for the library's own
/// files (`decks/<id>.json`) and for exported decks, which also embed their images.
struct DeckDocument: Codable {
    static let formatName = "anvi-deck"
    static let currentSchemaVersion = 1

    var format: String
    var schemaVersion: Int
    var deck: Deck
    /// Only present in exported files: image file name → image bytes (base64 in JSON).
    var media: [String: Data]?

    init(deck: Deck, media: [String: Data]? = nil) {
        self.format = Self.formatName
        self.schemaVersion = Self.currentSchemaVersion
        self.deck = deck
        self.media = media
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? Self.formatName
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        deck = try c.decode(Deck.self, forKey: .deck)
        media = try c.decodeIfPresent([String: Data].self, forKey: .media)
    }
}

/// `library.json`: study settings and the daily activity used for the streak.
struct LibraryDocument: Codable {
    static let formatName = "anvi-library"
    static let currentSchemaVersion = 1

    var format = LibraryDocument.formatName
    var schemaVersion = LibraryDocument.currentSchemaVersion
    var settings = StudySettings()
    /// Local day (`yyyy-MM-dd`) → number of answers given that day.
    var activity: [String: Int] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? Self.formatName
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        settings = try c.decodeIfPresent(StudySettings.self, forKey: .settings) ?? StudySettings()
        activity = try c.decodeIfPresent([String: Int].self, forKey: .activity) ?? [:]
    }
}

struct StudySettings: Codable, Equatable {
    /// New cards introduced per deck per day.
    var newCardsPerDay = 20
    /// Review answers per deck per day.
    var reviewsPerDay = 200
    /// FSRS target probability of remembering a card when it comes due.
    var desiredRetention = 0.9

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = StudySettings()
        newCardsPerDay = try c.decodeIfPresent(Int.self, forKey: .newCardsPerDay) ?? defaults.newCardsPerDay
        reviewsPerDay = try c.decodeIfPresent(Int.self, forKey: .reviewsPerDay) ?? defaults.reviewsPerDay
        desiredRetention = try c.decodeIfPresent(Double.self, forKey: .desiredRetention) ?? defaults.desiredRetention
    }
}
