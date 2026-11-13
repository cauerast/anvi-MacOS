import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        @Bindable var store = model.store

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        } detail: {
            detail
        }
        .frame(minWidth: 820, minHeight: 540)
        .sheet(item: $model.editor) { request in
            CardEditorView(request: request)
        }
        .sheet(item: $model.deckPrompt) { prompt in
            DeckNameSheet(prompt: prompt)
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(
                get: { model.deckPendingDeletion != nil },
                set: { if !$0 { model.deckPendingDeletion = nil } }
            ),
            presenting: model.deckPendingDeletion
        ) { deck in
            Button("Delete Deck", role: .destructive) { model.deleteDeck(deck.id) }
        } message: { deck in
            Text("“\(deck.name)” and all of its cards (\(deck.cards.count)) will be deleted. Export the deck first if you want to keep a copy.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            "Import finished",
            isPresented: Binding(
                get: { model.notice != nil },
                set: { if !$0 { model.notice = nil } }
            )
        ) {
            Button("OK") { model.notice = nil }
        } message: {
            Text(model.notice ?? "")
        }
    }

    private var deletionTitle: String {
        String(localized: "Delete “\(model.deckPendingDeletion?.name ?? "")”?")
    }

    @ViewBuilder
    private var detail: some View {
        if let session = model.session {
            ReviewView(session: session)
        } else {
            switch model.selection {
            case .deck(let id) where model.store.deck(id) != nil:
                DeckView(deckID: id)
                    .id(id)
            case .tag(let tag):
                TagView(tag: tag)
                    .id(tag)
            default:
                TodayView()
            }
        }
    }
}

/// Small sheet to name a new deck or rename an existing one.
struct DeckNameSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var prompt: DeckNamePrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prompt.deckID == nil ? "New Deck" : "Rename Deck")
                .font(.headline)
            TextField("Deck name", text: $prompt.name, prompt: Text("e.g. Japanese N5 Vocabulary"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .onSubmit(commit)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(prompt.deckID == nil ? "Create" : "Rename", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(prompt.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    private func commit() {
        guard !prompt.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.commitDeckPrompt(prompt)
    }
}
