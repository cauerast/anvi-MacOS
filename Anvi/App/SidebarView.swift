import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let store = model.store

        MinuteClock { now in
            List(selection: $model.selection) {
                Label("Today", systemImage: "sun.max")
                    .badge(store.queue(for: .all, now: now).totalCount)
                    .tag(SidebarItem.today)

                Section("Decks") {
                    ForEach(store.decks) { deck in
                        Label(deck.name, systemImage: "rectangle.stack")
                            .badge(store.queue(for: .deck(deck.id), now: now).totalCount)
                            .tag(SidebarItem.deck(deck.id))
                            .contextMenu { deckMenu(deck.id) }
                    }
                    if store.decks.isEmpty {
                        Text("No decks yet")
                            .foregroundStyle(.secondary)
                            .selectionDisabled()
                    }
                }

                if !store.allTags.isEmpty {
                    Section("Tags") {
                        ForEach(store.allTags, id: \.self) { tag in
                            Label(tag, systemImage: "number")
                                .tag(SidebarItem.tag(tag))
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    model.newDeck()
                } label: {
                    Label("New Deck", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
                StreakBadge(streak: store.streak)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .disabled(model.session != nil)
    }

    @ViewBuilder
    private func deckMenu(_ id: UUID) -> some View {
        Button("Study Now") { model.startStudy(.deck(id)) }
        Button("New Card") { model.newCard(in: id) }
        Divider()
        Button("Rename…") { model.renameDeck(id) }
        Button("Export…") { model.exportDeck(id) }
        Divider()
        Button("Delete…", role: .destructive) { model.confirmDeleteDeck(id) }
    }
}

/// Flame + number of consecutive study days.
struct StreakBadge: View {
    var streak: StreakSummary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streak.studiedToday ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
            Text(streak.current, format: .number)
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .font(.callout)
        .help(Text("Study streak: \(streak.current) days"))
    }
}
