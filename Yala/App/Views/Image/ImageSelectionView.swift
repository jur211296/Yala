//
//  ImageSelectionView.swift
//  Yala
//
//  View for selecting and processing images (screenshots, receipts)
//  Fase 8.4 - Imágenes MVP
//

import SwiftUI
import PhotosUI
import SwiftData

struct ImageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showInbox = false
    @State private var draftsCreated = 0

    // Navigation for single draft (direct edit)
    @State private var createdDraft: InboxDraft?

    // Navigation for multiple drafts (alert)
    @State private var showMultipleDraftsAlert = false
    @State private var multipleDraftsCount = 0

    // Vision API service (online, preferred)
    private let visionService = ImageVisionService.shared

    // Local OCR services (offline fallback)
    private let ocrService = ImageOCRService()
    private let classifier = ImageClassifier()
    private let singleExtractor = ScreenshotSingleExtractor()
    private let listExtractor = ScreenshotListExtractor()

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                if isProcessing {
                    processingView
                } else {
                    selectionView
                }
            }
            .padding(DS.Spacing.xl)
            .navigationTitle(L10n.Image.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                if newValue != nil {
                    Task {
                        await processImage()
                    }
                }
            }
            .alert(L10n.Image.errorTitle, isPresented: $showError) {
                Button(L10n.Common.accept) {
                    showError = false
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showInbox) {
                InboxView()
            }
            .sheet(item: $createdDraft) { draft in
                InboxDraftEditSheet(draft: draft)
            }
            .alert(L10n.Image.transactionsDetected, isPresented: $showMultipleDraftsAlert) {
                Button(L10n.Image.goToInbox) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showInbox = true
                    }
                }
                Button(L10n.Common.cancel, role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(L10n.Image.transactionsDetectedMessage(multipleDraftsCount))
            }
        }
    }

    // MARK: - Selection View

    private var selectionView: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(Color.orange)

            Text(L10n.Image.selectTitle)
                .font(.title2.weight(.semibold))

            Text(L10n.Image.selectSubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text(L10n.Image.selectButton)
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(Color.orange)
                .cornerRadius(DS.Radius.sm)
            }
            .padding(.horizontal, DS.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.orange)

            Text(L10n.Image.processing)
                .font(.title3.weight(.medium))

            Text(L10n.Image.processingSubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    // MARK: - Processing Logic

    private func processImage() async {
        guard let selectedPhoto else { return }

        isProcessing = true
        defer {
            isProcessing = false
        }

        do {
            // 1. Load image data
            guard let imageData = try await selectedPhoto.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: imageData) else {
                throw ImageError.loadFailed
            }

            // 2. Try Vision API first if available
            if visionService.isAvailable {
                do {
                    try await processImageWithVision(uiImage)
                    return
                } catch {
                    // Vision failed, fall through to offline processing
                    print("Vision API failed, falling back to OCR: \(error.localizedDescription)")
                }
            }

            // 3. Fallback to local OCR processing
            try await processImageOffline(uiImage)

        } catch let error as ImageOCRService.OCRError {
            handleError(error.localizedDescription)
        } catch let error as ImageError {
            handleError(error.localizedDescription)
        } catch {
            handleError(L10n.Image.errorGeneric)
        }
    }

    /// Process image using GPT-4o Vision API (online)
    private func processImageWithVision(_ uiImage: UIImage) async throws {
        let response = try await visionService.analyze(image: uiImage)

        // Check if we got valid transactions
        guard !response.transactions.isEmpty,
              response.imageType != "unknown" else {
            throw ImageError.noDataExtracted
        }

        // Create drafts from Vision response
        let drafts = VisionDraftFactory.createDrafts(
            from: response,
            rawText: nil,
            context: modelContext
        )

        guard !drafts.isEmpty else {
            throw ImageError.noDataExtracted
        }

        draftsCreated = drafts.count
        try modelContext.save()
        await handleNavigation(drafts: drafts)
    }

    /// Process image using local OCR pipeline (offline fallback)
    private func processImageOffline(_ uiImage: UIImage) async throws {
        // Extract text with OCR
        let ocrResult = try await ocrService.extractText(from: uiImage)

        // Classify image type
        let imageType = classifier.classify(ocrResult: ocrResult)

        // Extract data based on type
        switch imageType {
        case .screenshotSingle:
            // Single transaction
            if let draft = singleExtractor.extract(from: ocrResult, context: modelContext) {
                draftsCreated = 1
                try modelContext.save()
                await handleNavigation(drafts: [draft])
            } else {
                throw ImageError.noDataExtracted
            }

        case .screenshotList:
            // Multiple transactions
            let drafts = listExtractor.extract(from: ocrResult, context: modelContext)
            if !drafts.isEmpty {
                draftsCreated = drafts.count
                try modelContext.save()
                await handleNavigation(drafts: drafts)
            } else {
                throw ImageError.noDataExtracted
            }

        case .receiptPhoto:
            // Receipt - use single extractor as fallback
            if let draft = singleExtractor.extract(from: ocrResult, context: modelContext) {
                draftsCreated = 1
                try modelContext.save()
                await handleNavigation(drafts: [draft])
            } else {
                throw ImageError.noDataExtracted
            }

        case .unknown:
            throw ImageError.unrecognizedType
        }
    }

    /// Handles navigation after drafts are created
    /// - 1 draft: Opens edit sheet directly
    /// - Multiple: Shows alert with count and option to go to inbox
    private func handleNavigation(drafts: [InboxDraft]) async {
        try? await Task.sleep(for: .milliseconds(300))
        await MainActor.run {
            if drafts.count == 1, let draft = drafts.first {
                // Single draft: open edit sheet directly
                createdDraft = draft
            } else {
                // Multiple drafts: show alert with count
                multipleDraftsCount = drafts.count
                showMultipleDraftsAlert = true
            }
        }
    }

    private func handleError(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Error Types

    enum ImageError: LocalizedError {
        case loadFailed
        case noDataExtracted
        case unrecognizedType

        var errorDescription: String? {
            switch self {
            case .loadFailed:
                return L10n.Image.errorLoad
            case .noDataExtracted:
                return L10n.Image.errorNoData
            case .unrecognizedType:
                return L10n.Image.errorUnrecognized
            }
        }
    }
}

#Preview {
    ImageSelectionView()
        .modelContainer(for: [InboxDraft.self, Account.self, Subcategory.self])
}
