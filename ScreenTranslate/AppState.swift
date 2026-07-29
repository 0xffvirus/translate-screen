import Combine
import Foundation
import SwiftUI
import Translation
import UIKit

@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case reading
        case translating
        case preparing
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var document: TranslationDocument?
    @Published var translationConfiguration: TranslationSession.Configuration?
    @Published var presentsResult = false

    let settings: AppSettings
    let history: HistoryStore

    init(settings: AppSettings, history: HistoryStore) {
        self.settings = settings
        self.history = history
    }

    func process(_ image: UIImage) {
        phase = .reading
        document = nil
        presentsResult = true

        Task {
            do {
                let blocks = try await ScreenReader.recognize(in: image, source: settings.source)
                document = TranslationDocument(
                    id: UUID(),
                    image: image,
                    blocks: blocks,
                    source: settings.source,
                    target: settings.target,
                    createdAt: Date()
                )
                phase = .translating
                translationConfiguration = TranslationSession.Configuration(
                    source: settings.source.localeLanguage,
                    target: settings.target.localeLanguage
                )
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func translate(using session: TranslationSession) async {
        guard var current = document else { return }

        do {
            let requests = current.blocks.map {
                TranslationSession.Request(
                    sourceText: $0.original,
                    clientIdentifier: $0.id.uuidString
                )
            }
            let responses = try await session.translations(from: requests)
            let translated = Dictionary(
                uniqueKeysWithValues: responses.compactMap { response in
                    response.clientIdentifier.map { ($0, response.targetText) }
                }
            )

            for index in current.blocks.indices {
                let key = current.blocks[index].id.uuidString
                if let value = translated[key] {
                    current.blocks[index].translation = value
                }
            }

            document = current
            phase = .preparing
            try? await Task.sleep(for: .milliseconds(180))
            phase = .ready
            if settings.savesHistory {
                history.add(current)
            }
        } catch {
            // OCR remains useful even if individual language packs are unavailable.
            document = current
            phase = .failed("Translation couldn’t be completed.")
        }
    }

    func retry() {
        guard let image = document?.image else { return }
        process(image)
    }

    func closeResult() {
        presentsResult = false
        phase = .idle
        document = nil
        translationConfiguration = nil
    }
}
