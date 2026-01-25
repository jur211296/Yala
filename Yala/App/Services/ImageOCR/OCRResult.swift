//
//  OCRResult.swift
//  Yala
//
//  Result structure for OCR text extraction
//

import Foundation
import Vision

/// Result of OCR text extraction from an image
struct OCRResult {
    /// Full text extracted from the image (all observations concatenated)
    let fullText: String

    /// Raw Vision observations with bounding boxes
    let observations: [VNRecognizedTextObservation]

    /// Individual text block with position and confidence
    struct TextBlock {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
    }

    /// Parsed text blocks from observations
    var textBlocks: [TextBlock] {
        observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return TextBlock(
                text: candidate.string,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence
            )
        }
    }
}
