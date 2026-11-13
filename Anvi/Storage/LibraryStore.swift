import Foundation
import Observation

/// In-memory copy of the library plus every operation that changes it.
/// Each change is written to disk right away, so there is no "save" step.
@Observable
final class LibraryStore {
    private(set) var files: LibraryFiles
    private(set) var decks: [Deck] = []
    private(set) var settings = StudySettings()
    private(set) var activity: [String: Int] = [:]
    /// Deck files that could not be read. They are never overwritten.
    private(set) var unreadableFiles: [String] = []
    /// Set when `library.json` exists but cannot be read; settings are then not saved over it.
    private(set) var libraryFileUnreadable = false
    var errorMessage: String?

    init(root: URL = LibraryLocation.current) {
        files = LibraryFiles(root: root)
        load()
    }

    var folderURL: URL { files.root }

    var allTags: [String] {
        Set(decks.flatMap(\.allTags)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var streak: StreakSummary { StreakSummary(activity: activity) }

    func deck(_ id: UUID) -> Deck? { decks.first { $0.id == id } }

    func queue(for scope: StudyScope, now: Date = .now) -> StudyQueue {
        StudyQueue.build(decks: decks, scope: scope, settings: settings, now: now)
    }

    // MARK: Loading

    func load() {
        do {
            try files.prepare()
        } catch {
            report(error, String(localized: "Could not create the library folder."))
        }
        files.makeDailyBackup()

        libraryFileUnreadable = false
        do {
            let library = try files.loadLibrary()
            settings = library.settings
            activity = library.activity
        } catch {
            libraryFileUnreadable = true
            settings = StudySettings()
            activity = [:]
            report(error, String(localized: "library.json could not be read. Settings and streak will not be saved until it is fixed."))
        }

        let result = files.loadDecks()
        decks = sorted(result.decks)
        unreadableFiles = result.unreadable
    }

    // MARK: Settings

    func updateSettings(_ newSettings: StudySettings) {
        guard newSettings != settings else { return }
        settings = newSettings
        saveLibrary()
    }

    // MARK: Decks

    @discardableResult
    func createDeck(named name: String) -> UUID {
        let deck = Deck(name: cleanName(name))
        decks = sorted(decks + [deck])
        save(deck)
        return deck.id
    }

    func renameDeck(_ id: UUID, to name: String) {
        mutateDeck(id) { $0.name = cleanName(name) }
        decks = sorted(decks)
    }

    func updateDeckNotes(_ id: UUID, notes: String) {
        mutateDeck(id) { $0.notes = notes }
    }

    func deleteDeck(_ id: UUID) {
        guard let deck = deck(id) else { return }
        files.deleteMedia(deck.cards.flatMap(\.imageFileNames))
        files.deleteDeckFile(id)
        decks.removeAll { $0.id == id }
    }

    // MARK: Cards

    func addCard(_ card: Flashcard, to deckID: UUID) {
        mutateDeck(deckID) { $0.cards.append(card) }
    }

    func updateCard(_ card: Flashcard, in deckID: UUID) {
        guard let old = deck(deckID)?.cards.first(where: { $0.id == card.id }) else { return }
        var card = card
        card.updatedAt = .now
        mutateDeck(deckID) { deck in
            if let index = deck.cards.firstIndex(where: { $0.id == card.id }) {
                deck.cards[index] = card
            }
        }
        let removedImages = Set(old.imageFileNames).subtracting(card.imageFileNames)
        files.deleteMedia(Array(removedImages))
    }

    func deleteCards(_ ids: Set<UUID>, from deckID: UUID) {
        guard let deck = deck(deckID) else { return }
        let removed = deck.cards.filter { ids.contains($0.id) }
        mutateDeck(deckID) { $0.cards.removeAll { ids.contains($0.id) } }
        files.deleteMedia(removed.flatMap(\.imageFileNames))
    }

    func moveCards(_ ids: Set<UUID>, from sourceID: UUID, to targetID: UUID) {
        guard sourceID != targetID, let source = deck(sourceID), deck(targetID) != nil else { return }
        let moving = source.cards.filter { ids.contains($0.id) }
        mutateDeck(sourceID) { $0.cards.removeAll { ids.contains($0.id) } }
        mutateDeck(targetID) { $0.cards.append(contentsOf: moving) }
    }

    func resetProgress(_ ids: Set<UUID>, in deckID: UUID) {
        mutateDeck(deckID) { deck in
            for index in deck.cards.indices where ids.contains(deck.cards[index].id) {
                deck.cards[index].schedule = Schedule.new(at: .now)
                deck.cards[index].reviews = []
            }
        }
    }

    // MARK: Reviewing

    struct ReviewUndo {
        var deckID: UUID
        var previousCard: Flashcard
        var dayKey: String
    }

    /// Records an answer and reschedules the card. Returns what is needed to undo it.
    func answer(cardID: UUID, in deckID: UUID, rating: ReviewRating, at now: Date = .now) -> ReviewUndo? {
        guard let card = deck(deckID)?.cards.first(where: { $0.id == cardID }) else { return nil }
        let scheduler = Scheduler(desiredRetention: settings.desiredRetention)
        let next: Schedule
        do {
            next = try scheduler.next(card.schedule, rating: rating, at: now)
        } catch {
            report(error, String(localized: "This card could not be scheduled."))
            return nil
        }

        var updated = card
        updated.reviews.append(ReviewEntry(
            rating: rating,
            reviewedAt: now,
            previousState: card.schedule.state,
            scheduledDays: next.due.timeIntervalSince(now) / 86_400
        ))
        updated.schedule = next
        replaceCard(updated, in: deckID)

        let dayKey = DayKey.string(for: now)
        activity[dayKey, default: 0] += 1
        saveLibrary()
        return ReviewUndo(deckID: deckID, previousCard: card, dayKey: dayKey)
    }

    func undo(_ undo: ReviewUndo) {
        replaceCard(undo.previousCard, in: undo.deckID)
        let remaining = (activity[undo.dayKey] ?? 0) - 1
        activity[undo.dayKey] = remaining > 0 ? remaining : nil
        saveLibrary()
    }

    // MARK: Import / export

    struct ImportResult {
        var deckID: UUID
        var deckName: String
        var added: Int
        var updated: Int
    }

    /// Imports an exported deck. A deck that already exists (same id) is merged card by card,
    /// keeping whichever copy of each card was changed or reviewed most recently.
    func importDeck(from url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let document: DeckDocument
        if let wrapped = try? JSONCoding.decoder.decode(DeckDocument.self, from: data) {
            document = wrapped
        } else {
            document = DeckDocument(deck: try JSONCoding.decoder.decode(Deck.self, from: data))
        }
        guard document.format == DeckDocument.formatName else { throw ImportError.notADeck }
        guard document.schemaVersion <= DeckDocument.currentSchemaVersion else { throw ImportError.newerVersion }

        for (name, bytes) in document.media ?? [:] where !name.contains("/") {
            if !FileManager.default.fileExists(atPath: files.mediaURL(name).path) {
                try files.writeMedia(bytes, named: name)
            }
        }

        let incoming = document.deck
        guard let existing = deck(incoming.id) else {
            decks = sorted(decks + [incoming])
            save(incoming)
            return ImportResult(deckID: incoming.id, deckName: incoming.name, added: incoming.cards.count, updated: 0)
        }

        var added = 0
        var updated = 0
        mutateDeck(existing.id) { deck in
            for card in incoming.cards {
                if let index = deck.cards.firstIndex(where: { $0.id == card.id }) {
                    if card.isNewer(than: deck.cards[index]) {
                        deck.cards[index] = card
                        updated += 1
                    }
                } else {
                    deck.cards.append(card)
                    added += 1
                }
            }
        }
        return ImportResult(deckID: existing.id, deckName: existing.name, added: added, updated: updated)
    }

    /// Writes a single self-contained JSON file with the deck and its images.
    func exportDeck(_ id: UUID, to url: URL) throws {
        guard let deck = deck(id) else { return }
        var media: [String: Data] = [:]
        for name in Set(deck.cards.flatMap(\.imageFileNames)) {
            if let data = try? Data(contentsOf: files.mediaURL(name)) { media[name] = data }
        }
        let document = DeckDocument(deck: deck, media: media.isEmpty ? nil : media)
        try JSONCoding.encoder.encode(document).write(to: url, options: .atomic)
    }

    enum ImportError: LocalizedError {
        case notADeck, newerVersion

        var errorDescription: String? {
            switch self {
            case .notADeck: String(localized: "This file is not an Anvi deck.")
            case .newerVersion: String(localized: "This deck was made by a newer version of Anvi. Update the app to import it.")
            }
        }
    }

    // MARK: Library folder

    /// Points Anvi at another folder. If that folder already holds a library, it is opened
    /// as is; otherwise the current library is copied into it. The old folder is left in place.
    func changeFolder(to url: URL) throws {
        let target = LibraryFiles(root: url)
        if url.standardizedFileURL == files.root.standardizedFileURL { return }
        if !target.containsLibrary {
            try files.copyContents(to: url)
        }
        LibraryLocation.setCurrent(url)
        files = target
        load()
    }

    // MARK: Private

    private func mutateDeck(_ id: UUID, _ change: (inout Deck) -> Void) {
        guard let index = decks.firstIndex(where: { $0.id == id }) else { return }
        change(&decks[index])
        decks[index].updatedAt = .now
        save(decks[index])
    }

    private func replaceCard(_ card: Flashcard, in deckID: UUID) {
        mutateDeck(deckID) { deck in
            if let index = deck.cards.firstIndex(where: { $0.id == card.id }) {
                deck.cards[index] = card
            }
        }
    }

    private func save(_ deck: Deck) {
        do {
            try files.save(deck)
        } catch {
            report(error, String(localized: "The deck “\(deck.name)” could not be saved."))
        }
    }

    private func saveLibrary() {
        guard !libraryFileUnreadable else { return }
        var library = LibraryDocument()
        library.settings = settings
        library.activity = activity
        do {
            try files.save(library)
        } catch {
            report(error, String(localized: "Settings could not be saved."))
        }
    }

    private func report(_ error: Error, _ message: String) {
        errorMessage = "\(message)\n\n\(error.localizedDescription)"
    }

    private func sorted(_ decks: [Deck]) -> [Deck] {
        decks.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func cleanName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Untitled Deck") : trimmed
    }
}

extension Flashcard {
    /// Latest moment this card's content or progress changed. Used when merging imports.
    var lastModified: Date { max(updatedAt, schedule.lastReview ?? .distantPast) }

    /// Whether this copy should replace `other` when merging an import.
    func isNewer(than other: Flashcard) -> Bool {
        if lastModified != other.lastModified { return lastModified > other.lastModified }
        return reviews.count > other.reviews.count
    }
}
