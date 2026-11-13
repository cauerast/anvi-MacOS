import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Sheet for adding cards (stays open for the next card) or editing one card.
struct CardEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let request: CardEditorRequest

    @State private var deckID: UUID
    @State private var front: String
    @State private var back: String
    @State private var frontImage: String?
    @State private var backImage: String?
    @State private var tagsText: String
    @State private var addedCount = 0
    /// Images copied into the library while this sheet is open, removed again if unused.
    @State private var importedImages: Set<String> = []
    @State private var savedImages: Set<String> = []
    @FocusState private var focusedField: Field?

    private enum Field { case front, back, tags }

    init(request: CardEditorRequest) {
        self.request = request
        let card = request.card
        _deckID = State(initialValue: request.deckID)
        _front = State(initialValue: card?.front ?? "")
        _back = State(initialValue: card?.back ?? "")
        _frontImage = State(initialValue: card?.frontImage)
        _backImage = State(initialValue: card?.backImage)
        _tagsText = State(initialValue: (card?.tags ?? request.initialTags).joined(separator: ", "))
    }

    private var isNew: Bool { request.card == nil }

    private var canSave: Bool {
        let hasFront = !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || frontImage != nil
        let hasBack = !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || backImage != nil
        return hasFront && hasBack
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(isNew ? "New Card" : "Edit Card")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker("Deck", selection: $deckID) {
                    ForEach(model.store.decks) { deck in
                        Text(deck.name).tag(deck.id)
                    }
                }
                .fixedSize()
            }

            side(title: "Front", text: $front, image: $frontImage, field: .front)
            side(title: "Back", text: $back, image: $backImage, field: .back)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tags").font(.headline)
                TextField("Tags", text: $tagsText, prompt: Text("verbs, chapter 1"))
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .tags)
                Text("Separate tags with commas. Text supports **bold**, *italic*, `code` and [links](https://example.com).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if addedCount > 0 {
                    Label("Added \(addedCount) cards", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
                Spacer()
                if isNew {
                    Button(addedCount > 0 ? "Done" : "Cancel", action: close)
                        .keyboardShortcut(.cancelAction)
                    Button("Add Card", action: save)
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                } else {
                    Button("Cancel", action: close)
                        .keyboardShortcut(.cancelAction)
                    Button("Save", action: save)
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                }
            }
        }
        .padding(24)
        .frame(width: 640)
        .onAppear { focusedField = .front }
    }

    private func side(title: LocalizedStringKey, text: Binding<String>, image: Binding<String?>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            HStack(alignment: .top, spacing: 12) {
                TextEditor(text: text)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 96)
                    .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(focusedField == field ? Color.accentColor : Color.secondary.opacity(0.3),
                                          lineWidth: focusedField == field ? 2 : 1)
                    }
                    .focused($focusedField, equals: field)
                ImageWell(fileName: image, files: model.store.files) { imported in
                    importedImages.insert(imported)
                } onError: { message in
                    model.store.errorMessage = message
                }
            }
        }
    }

    private var tags: [String] {
        var seen = Set<String>()
        return tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#")) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private func save() {
        guard canSave else { return }
        let front = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let back = back.trimmingCharacters(in: .whitespacesAndNewlines)

        if var card = request.card {
            card.front = front
            card.back = back
            card.frontImage = frontImage
            card.backImage = backImage
            card.tags = tags
            model.store.updateCard(card, in: request.deckID)
            if deckID != request.deckID {
                model.store.moveCards([card.id], from: request.deckID, to: deckID)
            }
            savedImages.formUnion(card.imageFileNames)
            close()
        } else {
            let card = Flashcard(front: front, back: back, frontImage: frontImage, backImage: backImage, tags: tags)
            model.store.addCard(card, to: deckID)
            savedImages.formUnion(card.imageFileNames)
            addedCount += 1
            self.front = ""
            self.back = ""
            frontImage = nil
            backImage = nil
            focusedField = .front
        }
    }

    private func close() {
        let unused = importedImages.subtracting(savedImages)
        model.store.files.deleteMedia(Array(unused))
        dismiss()
    }
}

/// Image slot for one side of a card. Accepts a dropped file, a chosen file or a pasted image.
private struct ImageWell: View {
    @Binding var fileName: String?
    let files: LibraryFiles
    var onImport: (String) -> Void
    var onError: (String) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                                  style: StrokeStyle(lineWidth: 1, dash: fileName == nil ? [4, 3] : []))
                if let fileName, let image = NSImage(contentsOf: files.mediaURL(fileName)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 72)
                        .clipShape(.rect(cornerRadius: 7))
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 72)
            .contentShape(.rect)
            .onTapGesture(perform: choose)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                importFile(url)
                return true
            } isTargeted: { isTargeted = $0 }
            .help(Text("Drop an image here, click to choose one, or paste with the Paste button."))

            HStack(spacing: 8) {
                if fileName == nil {
                    Button("Paste", action: paste)
                } else {
                    Button("Remove") { fileName = nil }
                }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url)
    }

    private func importFile(_ url: URL) {
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) else {
            onError(String(localized: "Only image files can be added to a card."))
            return
        }
        do {
            let name = try files.importImage(from: url)
            onImport(name)
            fileName = name
        } catch {
            onError(String(localized: "The image could not be added.") + "\n\n" + error.localizedDescription)
        }
    }

    private func paste() {
        guard
            let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
            let tiff = image.tiffRepresentation,
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else {
            onError(String(localized: "There is no image on the clipboard."))
            return
        }
        let name = "\(UUID().uuidString.lowercased()).png"
        do {
            try files.writeMedia(png, named: name)
            onImport(name)
            fileName = name
        } catch {
            onError(String(localized: "The image could not be added.") + "\n\n" + error.localizedDescription)
        }
    }
}
