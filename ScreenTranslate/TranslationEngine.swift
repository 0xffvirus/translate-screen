import Foundation
import UIKit
@preconcurrency import Vision
import ImageIO

enum ScreenReadingError: LocalizedError {
    case invalidImage
    case noText

    var errorDescription: String? {
        switch self {
        case .invalidImage: "This image couldn’t be opened."
        case .noText: "No text found on this screen."
        }
    }
}

enum ScreenReader {
    static func recognize(in image: UIImage, source: AppLanguage) async throws -> [RecognizedBlock] {
        guard let cgImage = image.cgImage else { throw ScreenReadingError.invalidImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let blocks = observations.compactMap { observation -> RecognizedBlock? in
                    guard let candidate = observation.topCandidates(1).first,
                          !candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }
                    return RecognizedBlock(
                        id: UUID(),
                        original: candidate.string,
                        translation: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }

                guard !blocks.isEmpty else {
                    continuation.resume(throwing: ScreenReadingError.noText)
                    return
                }
                continuation.resume(returning: blocks)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = source == .automatic
            if let language = source.recognitionCode {
                request.recognitionLanguages = [language]
            }

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(
                        cgImage: cgImage,
                        orientation: orientation,
                        options: [:]
                    ).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
