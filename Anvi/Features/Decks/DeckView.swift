import SwiftUI

struct DeckView: View {
    @Environment(AppModel.self) private var model
    let deckID: UUID

    @State private var search = ""

    var body: some View {
        if let deck = model.store.deck(deckID) {
            content(deck)
        }
    }

    private func content(_ deck: Deck) -> some View {
        let rows = deck.cards.map { CardRow(deckID: deck.id, deckName: deck.name, card: $0) }
        let queue = model.store.queue(for: .deck(deck.id))

        return VStack(spacing: 0) {
            header(deck, queue: queue)
            Divider()
            if deck.cards.isEmpty {
                EmptyStateView(
                    title: "No cards yet",
                    message: "Add the first card to this deck. Use **bold**, *italic* and images to make it memorable."
                ) {
                    Button("Add Card") { model.newCard(in: deck.id) }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                CardTable(rows: CardRow.filter(rows, search: search), showsDeck: false)
            }
        }
        .navigationTitle(deck.name)
        .searchable(text: $search, placement: .toolbar, prompt: Text("Search cards"))
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.newCard(in: deck.id)
                } label: {
                    Label("New Card", systemImage: "plus")
                }
                .help(Text("New Card (⌘N)"))

                Menu {
                    Button("Rename…") { model.renameDeck(deck.id) }
                    Button("Export…") { model.exportDeck(deck.id) }
                    Divider()
                    Button("Delete Deck…", role: .destructive) { model.confirmDeleteDeck(deck.id) }
                } label: {
                    Label("Deck Actions", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private func header(_ deck: Deck, queue: StudyQueue) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(deck.name)
                    .font(.title.weight(.bold))
                HStack(spacing: 14) {
                    Text("\(deck.cards.count) cards")
                        .foregroundStyle(.secondary)
                    QueueCounts(new: queue.new.count, learning: queue.learning.count, review: queue.reviews.count)
                }
                .font(.callout)
            }
            Spacer()
            Button {
                model.startStudy(.deck(deck.id))
            } label: {
                Label("Study Cards", systemImage: "play.fill")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(queue.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}

/// All cards with a tag, across decks.
struct TagView: View {
    @Environment(AppModel.self) private var model
    let tag: String

    @State private var search = ""

    var body: some View {
        let rows = model.store.decks.flatMap { deck in
            deck.cards
                .filter { $0.tags.contains(tag) }
                .map { CardRow(deckID: deck.id, deckName: deck.name, card: $0) }
        }
        let queue = model.store.queue(for: .tag(tag))

        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("#\(tag)")
                        .font(.title.weight(.bold))
                    HStack(spacing: 14) {
                        Text("\(rows.count) cards")
                            .foregroundStyle(.secondary)
                        QueueCounts(new: queue.new.count, learning: queue.learning.count, review: queue.reviews.count)
                    }
                    .font(.callout)
                }
                Spacer()
                Button {
                    model.startStudy(.tag(tag))
                } label: {
                    Label("Study Cards", systemImage: "play.fill")
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(queue.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            Divider()
            CardTable(rows: CardRow.filter(rows, search: search), showsDeck: true)
        }
        .navigationTitle("#\(tag)")
        .searchable(text: $search, placement: .toolbar, prompt: Text("Search cards"))
    }
}
