import Foundation

/// Where the library lives. The user can point Anvi at any folder (for example one inside
/// iCloud Drive or Dropbox); the choice is remembered in UserDefaults.
enum LibraryLocation {
    private static let defaultsKey = "libraryFolderPath"

    static var defaultFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Anvi", isDirectory: true)
    }

    static var current: URL {
        if let path = UserDefaults.standard.string(forKey: defaultsKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return defaultFolder
    }

    static func setCurrent(_ url: URL?) {
        if let url, url.standardizedFileURL != defaultFolder.standardizedFileURL {
            UserDefaults.standard.set(url.path, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }
}

/// Reads and writes the files of one library folder:
///
///     library.json         settings + daily activity (streak)
///     decks/<id>.json      one file per deck, cards and review history inside
///     media/<file>         images used by cards
///     backups/<day>/       one automatic copy of library.json + decks per day, last 7 kept
struct LibraryFiles {
    let root: URL

    var libraryFile: URL { root.appendingPathComponent("library.json") }
    var decksFolder: URL { root.appendingPathComponent("decks", isDirectory: true) }
    var mediaFolder: URL { root.appendingPathComponent("media", isDirectory: true) }
    var backupsFolder: URL { root.appendingPathComponent("backups", isDirectory: true) }

    static let backupsToKeep = 7

    private var fileManager: FileManager { .default }

    func deckFile(_ id: UUID) -> URL {
        decksFolder.appendingPathComponent("\(id.uuidString.lowercased()).json")
    }

    func mediaURL(_ name: String) -> URL { mediaFolder.appendingPathComponent(name) }

    var containsLibrary: Bool {
        fileManager.fileExists(atPath: libraryFile.path) || fileManager.fileExists(atPath: decksFolder.path)
    }

    func prepare() throws {
        for folder in [root, decksFolder, mediaFolder] {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    // MARK: Library

    func loadLibrary() throws -> LibraryDocument {
        guard fileManager.fileExists(atPath: libraryFile.path) else { return LibraryDocument() }
        return try JSONCoding.decoder.decode(LibraryDocument.self, from: Data(contentsOf: libraryFile))
    }

    func save(_ library: LibraryDocument) throws {
        try JSONCoding.encoder.encode(library).write(to: libraryFile, options: .atomic)
    }

    // MARK: Decks

    /// Loads every deck file. Files that cannot be read are reported and left untouched on disk.
    func loadDecks() -> (decks: [Deck], unreadable: [String]) {
        let files = (try? fileManager.contentsOfDirectory(at: decksFolder, includingPropertiesForKeys: nil)) ?? []
        var decks: [Deck] = []
        var unreadable: [String] = []
        for file in files where file.pathExtension == "json" {
            do {
                let document = try JSONCoding.decoder.decode(DeckDocument.self, from: Data(contentsOf: file))
                decks.append(document.deck)
            } catch {
                unreadable.append(file.lastPathComponent)
            }
        }
        return (decks, unreadable)
    }

    func save(_ deck: Deck) throws {
        try JSONCoding.encoder.encode(DeckDocument(deck: deck)).write(to: deckFile(deck.id), options: .atomic)
    }

    func deleteDeckFile(_ id: UUID) {
        try? fileManager.removeItem(at: deckFile(id))
    }

    // MARK: Media

    /// Copies an image into `media/` under a new unique name and returns that name.
    func importImage(from source: URL) throws -> String {
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        let name = "\(UUID().uuidString.lowercased()).\(ext)"
        try fileManager.copyItem(at: source, to: mediaURL(name))
        return name
    }

    func writeMedia(_ data: Data, named name: String) throws {
        try data.write(to: mediaURL(name), options: .atomic)
    }

    func deleteMedia(_ names: [String]) {
        for name in names { try? fileManager.removeItem(at: mediaURL(name)) }
    }

    // MARK: Backups

    /// Copies `library.json` and `decks/` into `backups/<today>/` once per day.
    func makeDailyBackup(today: Date = .now) {
        let target = backupsFolder.appendingPathComponent(DayKey.string(for: today), isDirectory: true)
        guard !fileManager.fileExists(atPath: target.path), containsLibrary else { return }
        do {
            try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: libraryFile.path) {
                try fileManager.copyItem(at: libraryFile, to: target.appendingPathComponent("library.json"))
            }
            if fileManager.fileExists(atPath: decksFolder.path) {
                try fileManager.copyItem(at: decksFolder, to: target.appendingPathComponent("decks"))
            }
        } catch {
            try? fileManager.removeItem(at: target)
            return
        }
        let backups = ((try? fileManager.contentsOfDirectory(atPath: backupsFolder.path)) ?? [])
            .filter { DayKey.date(from: $0) != nil }
            .sorted()
        for old in backups.dropLast(Self.backupsToKeep) {
            try? fileManager.removeItem(at: backupsFolder.appendingPathComponent(old))
        }
    }

    /// Copies this library's data into another (empty) folder.
    func copyContents(to destination: URL) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in ["library.json", "decks", "media"] {
            let source = root.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try fileManager.copyItem(at: source, to: destination.appendingPathComponent(name))
        }
    }
}

enum JSONCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(fractionalISO8601))
        }
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = (try? Date(text, strategy: fractionalISO8601)) ?? (try? Date(text, strategy: .iso8601)) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(text)")
        }
        return decoder
    }

    /// ISO 8601 with milliseconds, e.g. `2026-11-13T14:05:09.123Z`. Plain ISO 8601 is also read.
    private static let fractionalISO8601 = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
}
