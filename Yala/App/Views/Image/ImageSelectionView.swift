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
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showInbox = false
    @State private var draftsCreated = 0

    // Navigation for drafts
    @State private var createdDrafts: [InboxDraft] = []
    @State private var createdDraft: InboxDraft?
    @State private var draftWasApproved = false

    /// Callback when draft is saved but not approved (user should go to Inbox)
    var onSavedToInbox: (() -> Void)?

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
                if showingResult {
                    resultView
                } else if isProcessing {
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
                InboxDraftEditSheet(draft: draft) {
                    // onApproved callback - mark as approved and dismiss image view
                    draftWasApproved = true
                    dismiss()
                }
            }
            .onChange(of: createdDraft) { oldValue, newValue in
                // Detect when EditSheet is dismissed (draft becomes nil)
                if oldValue != nil && newValue == nil && !draftWasApproved {
                    // Draft was saved but not approved - navigate to Inbox
                    onSavedToInbox?()
                    dismiss()
                }
                // Reset flag for next use
                if newValue == nil {
                    draftWasApproved = false
                }
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

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.green)

            Text("\(draftsCreated)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.orange)

            Text(draftsCreated == 1 ? L10n.Image.transactionDetected : L10n.Image.transactionsDetectedCount)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            // Action button
            if draftsCreated == 1 {
                // Single draft: Review button
                Button {
                    createdDraft = createdDrafts.first
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text(L10n.Image.reviewDraft)
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Color.orange)
                    .cornerRadius(DS.Radius.sm)
                }
                .padding(.horizontal, DS.Spacing.xl)
            } else {
                // Multiple drafts: Go to Inbox button
                Button {
                    onSavedToInbox?()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray")
                        Text(L10n.Image.goToInbox)
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(Color.orange)
                    .cornerRadius(DS.Radius.sm)
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
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
    /// - Stores drafts and shows result view with action button
    private func handleNavigation(drafts: [InboxDraft]) async {
        await MainActor.run {
            createdDrafts = drafts
            withAnimation(.easeOut(duration: 0.3)) {
                showingResult = true
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
