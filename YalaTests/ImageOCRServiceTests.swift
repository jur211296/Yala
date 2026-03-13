// Tests generated for: ImageOCRService (OCRError only)
// Cobertura estimada: 100% of OCRError, ~15% of full service

import Foundation
import Testing

@testable import Yala

struct ImageOCRServiceTests {

    // MARK: - OCRError descriptions

    @Test func ocrError_noTextDetected_hasSpanishDescription() {
        let error = ImageOCRService.OCRError.noTextDetected
        #expect(error.errorDescription == "No se detectó texto en la imagen")
    }

    @Test func ocrError_visionRequestFailed_hasSpanishDescription() {
        let error = ImageOCRService.OCRError.visionRequestFailed
        #expect(error.errorDescription == "Error al procesar la imagen")
    }

    @Test func ocrError_imageProcessingFailed_hasSpanishDescription() {
        let error = ImageOCRService.OCRError.imageProcessingFailed
        #expect(error.errorDescription == "No se pudo procesar la imagen")
    }

    @Test func ocrError_conformsToLocalizedError() {
        let error: any LocalizedError = ImageOCRService.OCRError.noTextDetected
        #expect(error.errorDescription != nil)
    }

    @Test func ocrError_allCasesHaveDescriptions() {
        let cases: [ImageOCRService.OCRError] = [
            .noTextDetected,
            .visionRequestFailed,
            .imageProcessingFailed
        ]
        for errorCase in cases {
            #expect(errorCase.errorDescription != nil)
            #expect(!errorCase.errorDescription!.isEmpty)
        }
    }
}

/*
Tests generated:
1. ocrError_noTextDetected_hasSpanishDescription - Correct error message
2. ocrError_visionRequestFailed_hasSpanishDescription - Correct error message
3. ocrError_imageProcessingFailed_hasSpanishDescription - Correct error message
4. ocrError_conformsToLocalizedError - Protocol conformance
5. ocrError_allCasesHaveDescriptions - All cases have non-empty descriptions

Cases NOT covered (require real UIImage + Vision framework):
- extractText(from:) happy path (needs real image with text)
- extractText with no-text image (needs UIImage that Vision can process)
- extractText with invalid cgImage
- Full OCR pipeline integration
*/
