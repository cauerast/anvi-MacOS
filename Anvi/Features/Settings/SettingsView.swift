import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            StudySettingsView()
                .tabItem { Label("Study", systemImage: "rectangle.stack") }
        }
        .frame(width: 520)
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @State private var language = AppLanguage.current
    @State private var launchedLanguage = AppLanguage.current

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $language) {
                    Text("System").tag(AppLanguage.system)
                    Text(verbatim: "English").tag(AppLanguage.english)
                    Text(verbatim: "Português (Brasil)").tag(AppLanguage.portuguese)
                    Text(verbatim: "日本語").tag(AppLanguage.japanese)
                }
                .onChange(of: language) { _, newValue in AppLanguage.apply(newValue) }
                if language != launchedLanguage {
                    HStack {
                        Text("Relaunch Anvi to use the new language.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Relaunch Now") { AppLanguage.relaunch() }
                    }
                }
            }

            Section {
                LabeledContent("Library folder") {
                    Text(model.store.folderURL.path(percentEncoded: false))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Show in Finder") { model.showLibraryInFinder() }
                    Button("Change…") { model.chooseLibraryFolder() }
                    if model.store.folderURL.standardizedFileURL != LibraryLocation.defaultFolder.standardizedFileURL {
                        Button("Use Default") { model.useDefaultLibraryFolder() }
                    }
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Your decks are plain JSON files in this folder, with a daily backup of the last 7 days. Put the folder in iCloud Drive or Dropbox to use it on another Mac, but open it on one Mac at a time.")
                    .foregroundStyle(.secondary)
            }

            if !model.store.unreadableFiles.isEmpty {
                Section("Files that could not be read") {
                    ForEach(model.store.unreadableFiles, id: \.self) { name in
                        Text(verbatim: "decks/\(name)")
                    }
                    Text("These files were left untouched. Fix or remove them and relaunch Anvi.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct StudySettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.store
        let settings = Binding(get: { store.settings }, set: { store.updateSettings($0) })

        Form {
            Section {
                Stepper(value: settings.newCardsPerDay, in: 0...9_999, step: 5) {
                    LabeledContent("New cards per day", value: store.settings.newCardsPerDay, format: .number)
                }
                Stepper(value: settings.reviewsPerDay, in: 0...99_999, step: 10) {
                    LabeledContent("Maximum reviews per day", value: store.settings.reviewsPerDay, format: .number)
                }
            } footer: {
                Text("Limits apply to each deck. Cards you are still learning are always shown.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Desired retention") {
                    HStack {
                        Slider(value: settings.desiredRetention, in: 0.80...0.97, step: 0.01)
                            .frame(width: 180)
                        Text(store.settings.desiredRetention, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            } footer: {
                Text("How likely you want to be to remember a card when it comes back. Higher means more reviews. Scheduling uses FSRS-6.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
