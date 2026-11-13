import SwiftUI

@main
struct AnviApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Anvi", id: "main") {
            RootView()
                .environment(model)
        }
        .defaultSize(width: 1080, height: 720)
        .commands { AnviCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

struct AnviCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Card") { model.newCard() }
                .keyboardShortcut("n")
            Button("New Deck…") { model.newDeck() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Import Deck…") { model.importDeck() }
                .keyboardShortcut("o")
            Button("Export Deck…") { model.exportDeck() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.selectedDeckID == nil)
            Divider()
            Button("Show Library in Finder") { model.showLibraryInFinder() }
        }

        CommandMenu("Study") {
            Button("Study Now") { model.studyCurrentSelection() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.session != nil || model.editor != nil)
            Button("End Session") { model.endStudy() }
                .disabled(model.session == nil)
        }
    }
}
