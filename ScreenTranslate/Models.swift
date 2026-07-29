import Combine
import Foundation
import SwiftUI
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case automatic
    case english = "en"
    case arabic = "ar"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .automatic: "Auto Detect"
        case .english: "English"
        case .arabic: "Arabic"
        case .chinese: "Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .russian: "Russian"
        }
    }

    var nativeName: String {
        switch self {
        case .automatic: "Recommended"
        case .english: "English"
        case .arabic: "العربية"
        case .chinese: "中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .russian: "Русский"
        }
    }

    var symbol: String {
        switch self {
        case .automatic: "sparkles"
        case .english: "character.book.closed"
        case .arabic: "character.textbox"
        case .chinese, .japanese, .korean: "character"
        default: "textformat"
        }
    }

    var localeLanguage: Locale.Language? {
        guard self != .automatic else { return nil }
        return Locale.Language(identifier: rawValue)
    }

    var recognitionCode: String? {
        guard self != .automatic else { return nil }
        return rawValue
    }

    var isRightToLeft: Bool { self == .arabic }

    static var sourceLanguages: [AppLanguage] { allCases }
    static var targetLanguages: [AppLanguage] { allCases.filter { $0 != .automatic } }
}

enum TranslationAppearance: String, CaseIterable, Identifiable {
    case natural = "Natural"
    case readable = "Readable"
    case minimal = "Minimal"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .natural: "Blends into the original screen"
        case .readable: "Strong backgrounds for clarity"
        case .minimal: "Subtle, lightweight overlays"
        }
    }
}

struct RecognizedBlock: Identifiable, Hashable {
    let id: UUID
    let original: String
    var translation: String
    let boundingBox: CGRect
    let confidence: Float
}

struct TranslationDocument: Identifiable {
    let id: UUID
    let image: UIImage
    var blocks: [RecognizedBlock]
    let source: AppLanguage
    let target: AppLanguage
    let createdAt: Date

    var originalText: String { blocks.map(\.original).joined(separator: "\n") }
    var translatedText: String { blocks.map(\.translation).joined(separator: "\n") }
}

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let imageData: Data
    let sourceName: String
    let targetName: String
    let date: Date
    let originalText: String
    let translatedText: String

    var image: UIImage? { UIImage(data: imageData) }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var source: AppLanguage {
        didSet { defaults.set(source.rawValue, forKey: Keys.source) }
    }
    @Published var target: AppLanguage {
        didSet { defaults.set(target.rawValue, forKey: Keys.target) }
    }
    @Published var appearance: TranslationAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    @Published var savesHistory: Bool {
        didSet { defaults.set(savesHistory, forKey: Keys.savesHistory) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        source = AppLanguage(rawValue: defaults.string(forKey: Keys.source) ?? "") ?? .automatic
        target = AppLanguage(rawValue: defaults.string(forKey: Keys.target) ?? "") ?? .english
        appearance = TranslationAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .natural
        savesHistory = defaults.bool(forKey: Keys.savesHistory)
    }

    private enum Keys {
        static let source = "defaultSourceLanguage"
        static let target = "defaultTargetLanguage"
        static let appearance = "translationAppearance"
        static let savesHistory = "saveTranslationHistory"
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []
    private let fileURL: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = folder.appendingPathComponent("translation-history.json")
        load()
    }

    func add(_ document: TranslationDocument) {
        guard let data = document.image.jpegData(compressionQuality: 0.55) else { return }
        let item = HistoryItem(
            id: document.id,
            imageData: data,
            sourceName: document.source.name,
            targetName: document.target.name,
            date: document.createdAt,
            originalText: document.originalText,
            translatedText: document.translatedText
        )
        items.insert(item, at: 0)
        items = Array(items.prefix(20))
        save()
    }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // History is optional; a failed local write must not interrupt translation.
        }
    }
}
