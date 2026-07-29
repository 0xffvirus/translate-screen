import AppIntents
import Foundation
import UniformTypeIdentifiers
import UIKit

extension Notification.Name {
    static let pendingScreenshotReady = Notification.Name("pendingScreenshotReady")
}

enum PendingScreenshotStore {
    nonisolated private static var url: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pending-translate-screen-image")
    }

    nonisolated static func save(_ data: Data) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        Task { @MainActor in
            NotificationCenter.default.post(name: .pendingScreenshotReady, object: nil)
        }
    }

    static func take() -> UIImage? {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return image
    }
}

struct TranslateScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate Screenshot"
    static let description = IntentDescription(
        "Receives the output of Take Screenshot, then opens it in Translate Screen with translated text over the original layout."
    )
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(
        title: "Screenshot",
        description: "Connect this to the Take Screenshot action directly above it",
        supportedContentTypes: [.image],
        requestValueDialog: "Add Take Screenshot above this action, or choose an image.",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Translate \(\.$screenshot)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try PendingScreenshotStore.save(screenshot.data)
        return .result(dialog: "Opening your translated screen…")
    }
}

struct TranslateScreenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateScreenshotIntent(),
            phrases: [
                "Translate a screenshot with \(.applicationName)",
                "Open a screenshot in \(.applicationName)"
            ],
            shortTitle: "Translate Screenshot",
            systemImageName: "camera.viewfinder"
        )
    }
}
