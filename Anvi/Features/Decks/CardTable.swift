import SwiftUI

struct CardRow: Identifiable, Hashable {
    var deckID: UUID
    var deckName: String
    var card: Flashcard

    var id: UUID { card.id }
    var front: String { Markdown.plain(card.front) }
    var back: String { Markdown.plain(card.back) }
    var tagsText: String { card.tags.joined(separator: ", ") }

    static func filter(_ rows: [CardRow], search: String) -> [CardRow] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return rows }
        return rows.filter { row in
            row.card.front.localizedCaseInsensitiveContains(query)
                || row.card.back.localizedCaseInsensitiveContains(query)
                || row.card.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}

/// Sortable table of cards. Double-click edits; Delete removes; the context menu
/// offers moving cards to another deck and resetting their progress.
struct CardTable: View {
    @Environment(AppModel.self) private var model
    var rows: [CardRow]
    var showsDeck: Bool

    @State private var selection = Set<CardRow.ID>()
    @State private var sortOrder = [KeyPathComparator(\CardRow.card.createdAt)]
    @State private var pendingDeletion: Set<CardRow.ID>?

    var body: some View {
        Table(rows.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Front", value: \.front) { row in
                HStack(spacing: 6) {
                    if row.card.frontImage != nil {
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                    Text(row.front).lineLimit(1)
                }
            }
            TableColumn("Back", value: \.back) { row in
                HStack(spacing: 6) {
                    if row.card.backImage != nil {
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                    Text(row.back).lineLimit(1)
                }
            }
            TableColumn("Tags", value: \.tagsText) { row in
                Text(row.tagsText).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 60, ideal: 110)
            if showsDeck {
                TableColumn("Deck", value: \.deckName) { row in
                    Text(row.deckName).foregroundStyle(.secondary).lineLimit(1)
                }
                .width(min: 60, ideal: 120)
            }
            TableColumn("Due", value: \.card.schedule.due) { row in
                DueLabel(schedule: row.card.schedule)
            }
            .width(min: 70, ideal: 90)
        }
        .contextMenu(forSelectionType: CardRow.ID.self) { ids in
            contextMenu(for: ids)
        } primaryAction: { ids in
            if let id = ids.first, let row = rows.first(where: { $0.id == id }) {
                model.editCard(row.card.id, in: row.deckID)
            }
        }
        .onDeleteCommand {
            if !selection.isEmpty { pendingDeletion = selection }
        }
        .confirmationDialog(
            "Delete the selected cards?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let ids = pendingDeletion { delete(ids) }
                pendingDeletion = nil
            }
        } message: {
            Text("Their review history will be deleted too.")
        }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<CardRow.ID>) -> some View {
        let selected = rows.filter { ids.contains($0.id) }
        if selected.count == 1, let row = selected.first {
            Button("Edit…") { model.editCard(row.card.id, in: row.deckID) }
        }
        if !selected.isEmpty {
            Menu("Move to Deck") {
                ForEach(model.store.decks) { deck in
                    Button(deck.name) { move(selected, to: deck.id) }
                }
            }
            Button("Reset Progress") {
                for (deckID, group) in Dictionary(grouping: selected, by: \.deckID) {
                    model.store.resetProgress(Set(group.map(\.id)), in: deckID)
                }
            }
            Divider()
            Button("Delete…", role: .destructive) { pendingDeletion = ids }
        }
    }

    private func move(_ rows: [CardRow], to target: UUID) {
        for (deckID, group) in Dictionary(grouping: rows, by: \.deckID) {
            model.store.moveCards(Set(group.map(\.id)), from: deckID, to: target)
        }
    }

    private func delete(_ ids: Set<CardRow.ID>) {
        let selected = rows.filter { ids.contains($0.id) }
        for (deckID, group) in Dictionary(grouping: selected, by: \.deckID) {
            model.store.deleteCards(Set(group.map(\.id)), from: deckID)
        }
        selection.subtract(ids)
    }
}

private struct DueLabel: View {
    var schedule: Schedule

    var body: some View {
        if schedule.state == .new {
            Text("New").foregroundStyle(Theme.newColor)
        } else if schedule.due <= .now {
            Text("Now").foregroundStyle(Theme.reviewColor)
        } else {
            Text(schedule.due, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                .foregroundStyle(.secondary)
        }
    }
}
