import AppKit
import Observation
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case today
    case deck(UUID)
    case tag(String)
}

/// Window-level state: what is selected, which sheet is open, the running review session.
@Observable
final class AppModel {
    let store: LibraryStore
    var selection: SidebarItem? = .today
    var session: ReviewSession?
    var editor: CardEditorRequest?
    var deckPrompt: DeckNamePrompt?
    var deckPendingDeletion: Deck?
    var notice: String?

    init(store: LibraryStore = LibraryStore()) {
        self.store = store
    }

    var selectedDeckID: UUID? {
        if case .deck(let id) = selection, store.deck(id) != nil { return id }
        return nil
    }

    // MARK: Studying

    func startStudy(_ scope: StudyScope) {
        editor = nil
        session = ReviewSession(store: store, scope: scope, title: title(for: scope))
    }

    func studyCurrentSelection() {
        switch selection {
        case .deck(let id): startStudy(.deck(id))
        case .tag(let tag): startStudy(.tag(tag))
        case .today, nil: startStudy(.all)
        }
    }

    func endStudy() { session = nil }

    func title(for scope: StudyScope) -> String {
        switch scope {
        case .all: String(localized: "All Decks")
        case .deck(let id): store.deck(id)?.name ?? String(localized: "Deck")
        case .tag(let tag): "#\(tag)"
        }
    }

    // MARK: Decks and cards

    func newDeck() { deckPrompt = DeckNamePrompt(deckID: nil, name: "") }

    func renameDeck(_ id: UUID) {
        guard let deck = store.deck(id) else { return }
        deckPrompt = DeckNamePrompt(deckID: id, name: deck.name)
    }

    func commitDeckPrompt(_ prompt: DeckNamePrompt) {
        if let id = prompt.deckID {
            store.renameDeck(id, to: prompt.name)
        } else {
            let id = store.createDeck(named: prompt.name)
            selection = .deck(id)
        }
        deckPrompt = nil
    }

    func confirmDeleteDeck(_ id: UUID) { deckPendingDeletion = store.deck(id) }

    func deleteDeck(_ id: UUID) {
        if selection == .deck(id) { selection = .today }
        store.deleteDeck(id)
        deckPendingDeletion = nil
    }

    func newCard(in deckID: UUID? = nil, tags: [String] = []) {
        guard session == nil, editor == nil else { return }
        guard let target = deckID ?? selectedDeckID ?? store.decks.first?.id else {
            newDeck()
            return
        }
        editor = CardEditorRequest(deckID: target, card: nil, initialTags: tags)
    }

    func editCard(_ cardID: UUID, in deckID: UUID) {
        guard let card = store.deck(deckID)?.cards.first(where: { $0.id == cardID }) else { return }
        editor = CardEditorRequest(deckID: deckID, card: card, initialTags: [])
    }

    // MARK: Files

    func importDeck() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "Choose one or more exported Anvi decks (.json).")
        guard panel.runModal() == .OK else { return }
        var summaries: [String] = []
        for url in panel.urls {
            do {
                let result = try store.importDeck(from: url)
                selection = .deck(result.deckID)
                summaries.append(String(localized: "“\(result.deckName)”: added \(result.added), updated \(result.updated)."))
            } catch {
                store.errorMessage = String(localized: "“\(url.lastPathComponent)” could not be imported.") + "\n\n" + error.localizedDescription
            }
        }
        if !summaries.isEmpty { notice = summaries.joined(separator: "\n") }
    }

    func exportDeck(_ id: UUID? = nil) {
        guard let id = id ?? selectedDeckID, let deck = store.deck(id) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(deck.name).json"
        panel.message = String(localized: "The exported file contains the deck, its images and your progress.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.exportDeck(id, to: url)
        } catch {
            store.errorMessage = String(localized: "The deck could not be exported.") + "\n\n" + error.localizedDescription
        }
    }

    func showLibraryInFinder() {
        NSWorkspace.shared.open(store.folderURL)
    }

    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Use Folder")
        panel.message = String(localized: "Choose an empty folder to move your library there, or a folder that already has an Anvi library to open it.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        changeLibraryFolder(to: url)
    }

    func useDefaultLibraryFolder() { changeLibraryFolder(to: LibraryLocation.defaultFolder) }

    private func changeLibraryFolder(to url: URL) {
        session = nil
        editor = nil
        do {
            try store.changeFolder(to: url)
            selection = .today
        } catch {
            store.errorMessage = String(localized: "The library could not be moved to that folder.") + "\n\n" + error.localizedDescription
        }
    }
}

struct CardEditorRequest: Identifiable {
    let id = UUID()
    var deckID: UUID
    /// `nil` when creating a new card.
    var card: Flashcard?
    var initialTags: [String]
}

struct DeckNamePrompt: Identifiable {
    let id = UUID()
    /// `nil` when creating a new deck.
    var deckID: UUID?
    var name: String
}
