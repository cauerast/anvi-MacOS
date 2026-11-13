import AppKit

/// In-app language override. macOS reads `AppleLanguages` at launch, so a change
/// takes effect after relaunching Anvi.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case portuguese = "pt-BR"
    case japanese = "ja"

    var id: String { rawValue }

    private static let key = "AppleLanguages"

    static var current: AppLanguage {
        guard
            let bundleID = Bundle.main.bundleIdentifier,
            let languages = UserDefaults.standard.persistentDomain(forName: bundleID)?[key] as? [String],
            let first = languages.first
        else { return .system }
        return AppLanguage(rawValue: first) ?? .system
    }

    static func apply(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: key)
        }
    }

    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
