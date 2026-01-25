//
//  ImageOCRService.swift
//  Yala
//
//  Service for extracting text from images using Vision framework
//

import UIKit
import Vision

/// Service for performing OCR on images using Apple's Vision framework
@Observable
final class ImageOCRService {

    /// Errors that can occur during OCR processing
    enum OCRError: Error, LocalizedError {
        case noTextDetected
        case visionRequestFailed
        case imageProcessingFailed

        var errorDescription: String? {
            switch self {
            case .noTextDetected:
                return "No se detectó texto en la imagen"
            case .visionRequestFailed:
                return "Error al procesar la imagen"
            case .imageProcessingFailed:
                return "No se pudo procesar la imagen"
            }
        }
    }

    /// Extract text from an image using Vision framework
    /// - Parameter image: UIImage to extract text from
    /// - Returns: OCRResult with extracted text and observations
    /// - Throws: OCRError if extraction fails
    func extractText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageProcessingFailed
        }

        // Create Vision text recognition request
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Perform request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw OCRError.visionRequestFailed
        }

        // Extract results
        guard let observations = request.results,
              !observations.isEmpty else {
            throw OCRError.noTextDetected
        }

        // Build full text by concatenating all observations
        let fullText = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        return OCRResult(fullText: fullText, observations: observations)
    }
}
