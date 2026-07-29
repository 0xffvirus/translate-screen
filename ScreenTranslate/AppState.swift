import Combine
import Foundation
import OSLog
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
    @Published private(set) var translatedBlockCount = 0
    @Published private(set) var totalBlockCount = 0

    let settings: AppSettings
    let history: HistoryStore

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate",
        category: "TranslationPerformance"
    )
    private var activeProcessID: UUID?
    private var recognitionTask: Task<Void, Never>?

    init(settings: AppSettings, history: HistoryStore) {
        self.settings = settings
        self.history = history
    }

    func process(_ image: UIImage) {
        cancelCurrentWork()

        let processID = UUID()
        let source = settings.source
        let target = settings.target
        let startedAt = ContinuousClock.now

        activeProcessID = processID
        phase = .reading
        document = nil
        translationConfiguration = nil
        translatedBlockCount = 0
        totalBlockCount = 0
        presentsResult = true

        logger.info(
            "Processing started; source: \(source.rawValue), target: \(target.rawValue)"
        )

        recognitionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if activeProcessID == processID {
                    recognitionTask = nil
                }
            }

            do {
                let ocrStartedAt = ContinuousClock.now
                let blocks = try await ScreenReader.recognize(in: image, source: source)
                guard !Task.isCancelled, activeProcessID == processID else {
                    logger.info("Discarded stale OCR result")
                    return
                }

                let ocrMilliseconds = Self.milliseconds(
                    from: ocrStartedAt.duration(to: .now)
                )
                logger.info(
                    "OCR finished in \(ocrMilliseconds) ms; blocks: \(blocks.count)"
                )

                document = TranslationDocument(
                    id: processID,
                    image: image,
                    blocks: blocks,
                    source: source,
                    target: target,
                    createdAt: Date()
                )
                totalBlockCount = blocks.count
                phase = .translating
                translationConfiguration = TranslationSession.Configuration(
                    source: source.localeLanguage,
                    target: target.localeLanguage,
                    preferredStrategy: .lowLatency
                )
            } catch {
                guard !Task.isCancelled, activeProcessID == processID else { return }
                let elapsedMilliseconds = Self.milliseconds(
                    from: startedAt.duration(to: .now)
                )
                logger.error(
                    "Processing failed after \(elapsedMilliseconds) ms: \(error.localizedDescription)"
                )
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func translate(using session: TranslationSession) async {
        guard phase == .translating,
              var current = document,
              activeProcessID == current.id else {
            logger.info("Ignored translation session without an active document")
            return
        }

        let processID = current.id
        let startedAt = ContinuousClock.now
        let characterCount = current.blocks.reduce(0) { $0 + $1.original.count }

        let modelsReady = await session.isReady
        guard !Task.isCancelled, activeProcessID == processID else { return }
        logger.info(
            "Translation started; blocks: \(current.blocks.count), characters: \(characterCount), models ready: \(modelsReady)"
        )

        do {
            let requests = current.blocks.map {
                TranslationSession.Request(
                    sourceText: $0.original,
                    clientIdentifier: $0.id.uuidString
                )
            }
            let blockIndices = Dictionary(
                uniqueKeysWithValues: current.blocks.indices.map {
                    (current.blocks[$0].id.uuidString, $0)
                }
            )

            for try await response in session.translate(batch: requests) {
                guard !Task.isCancelled, activeProcessID == processID else {
                    session.cancel()
                    return
                }
                guard let key = response.clientIdentifier,
                      let index = blockIndices[key] else { continue }

                current.blocks[index].translation = response.targetText
                translatedBlockCount += 1
                document = current
            }

            guard !Task.isCancelled, activeProcessID == processID else { return }
            document = current
            phase = .ready
            let translationMilliseconds = Self.milliseconds(
                from: startedAt.duration(to: .now)
            )
            logger.info(
                "Translation finished in \(translationMilliseconds) ms; translated blocks: \(self.translatedBlockCount)"
            )

            if settings.savesHistory {
                history.add(current)
            }
        } catch {
            guard !Task.isCancelled, activeProcessID == processID else {
                logger.info("Translation cancelled")
                return
            }
            let translationMilliseconds = Self.milliseconds(
                from: startedAt.duration(to: .now)
            )
            logger.error(
                "Translation failed after \(translationMilliseconds) ms: \(error.localizedDescription)"
            )
            // OCR remains useful even if individual language packs are unavailable.
            document = current
            phase = .failed(
                "Translation couldn’t be completed: \(error.localizedDescription)"
            )
        }
    }

    func retry() {
        guard let image = document?.image else { return }
        process(image)
    }

    func closeResult() {
        cancelCurrentWork()
        activeProcessID = nil
        presentsResult = false
        phase = .idle
        document = nil
        translationConfiguration = nil
        translatedBlockCount = 0
        totalBlockCount = 0
    }

    private func cancelCurrentWork() {
        recognitionTask?.cancel()
        recognitionTask = nil
        // Changing the configuration cancels the task and its view-bound session.
        translationConfiguration = nil
    }

    private static func milliseconds(from duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
