import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: HistoryStore
    @State private var showsShortcutSetup = false
    @State private var showsPrivacy = false
    @State private var showsAbout = false

    var body: some View {
        Form {
            Section("Languages") {
                Picker("Default Source", selection: $settings.source) {
                    ForEach(AppLanguage.sourceLanguages) { Text($0.name).tag($0) }
                }
                Picker("Default Target", selection: $settings.target) {
                    ForEach(AppLanguage.targetLanguages) { Text($0.name).tag($0) }
                }
            }

            Section {
                Picker("Translation Appearance", selection: $settings.appearance) {
                    ForEach(TranslationAppearance.allCases) { Text($0.rawValue).tag($0) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.appearance.rawValue).font(.subheadline.weight(.medium))
                    Text(settings.appearance.detail).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle("Save Translation History", isOn: $settings.savesHistory)
                if settings.savesHistory, !history.items.isEmpty {
                    Button("Clear Saved History", role: .destructive) { history.clear() }
                }
            } header: {
                Text("History")
            } footer: {
                Text(settings.savesHistory
                     ? "Up to 20 recent translations are stored only on this device."
                     : "History is off. Screenshots are not kept after you close a translation.")
            }

            Section("Action Button") {
                Button {
                    showsShortcutSetup = true
                } label: {
                    Label("Shortcut Setup", systemImage: "button.programmable")
                }
            }

            Section("Information") {
                Button {
                    showsPrivacy = true
                } label: {
                    Label("Privacy", systemImage: "hand.raised")
                }
                Button {
                    showsAbout = true
                } label: {
                    Label("About Translate Screen", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showsShortcutSetup) { ShortcutSetupView() }
        .sheet(isPresented: $showsPrivacy) { PrivacyView() }
        .sheet(isPresented: $showsAbout) { AboutView() }
    }
}

private struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("Your screen stays yours", systemImage: "lock.shield.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.blue)

                    privacySection(
                        "On-device processing",
                        "Text recognition and translation use Apple frameworks on your iPhone. Translate Screen does not upload screenshots to its own servers."
                    )
                    privacySection(
                        "Temporary by default",
                        "When history is off, the selected screenshot is held only while you view the translation and is released when you close it."
                    )
                    privacySection(
                        "History is your choice",
                        "If you enable history, recent screenshots and recognized text are stored in the app’s private local storage. You can delete them at any time."
                    )
                }
                .padding(24)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func privacySection(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            Text(detail).foregroundStyle(.secondary)
        }
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.blue.gradient)
                        .frame(width: 104, height: 104)
                    Image(systemName: "viewfinder")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text("Translate Screen").font(.title2.bold())
                Text("See it. Press. Understand.")
                    .foregroundStyle(.secondary)
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, 50)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
