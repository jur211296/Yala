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
    @State private var selectedImage: UIImage?
    @State private var isCountingDown = false
    @State private var countdownValue = 3
    @State private var countdownTask: Task<Void, Never>?
    @State private var isProcessing = false
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var errorType: ImageErrorType = .generic
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
                } else if isCountingDown {
                    countdownView
                } else if isProcessing {
                    processingView
                } else {
                    selectionView
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.yalaBackground)
            .navigationTitle(L10n.Image.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .disabled(isProcessing || isCountingDown)
                }
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                if let photo = newValue {
                    Task {
                        await loadImageAndStartCountdown(from: photo)
                    }
                }
            }
            .alert(L10n.Image.errorTitle, isPresented: $showError) {
                switch errorType {
                case .photoPermission:
                    Button(L10n.Image.openSettings) {
                        openSystemSettings()
                    }
                    Button(L10n.Common.cancel, role: .cancel) {
                        showError = false
                    }
                case .corrupted, .loadFailed:
                    Button(L10n.Action.retry) {
                        showError = false
                        resetForRetry()
                    }
                    Button(L10n.Common.cancel, role: .cancel) {
                        showError = false
                    }
                case .generic, .noData, .unrecognized:
                    Button(L10n.Common.accept) {
                        showError = false
                    }
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
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Main circle with gradient (matching VoiceRecordingView style)
            ZStack {
                // Main circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.teal, Color.teal.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.teal.opacity(0.4), radius: 20, x: 0, y: 8)

                // Glass overlay
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                // Icon
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }

            // Status text
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Image.selectTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(L10n.Image.selectSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Select button (circle style like Voice)
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Image(systemName: "photo.badge.plus")
                    .font(.title.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(
                        LinearGradient(
                            colors: [Color.teal, Color.teal.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.teal.opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Image preview with subtle styling
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            }

            // Countdown display
            VStack(spacing: DS.Spacing.sm) {
                Text("\(countdownValue)")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(Color.teal)
                    .contentTransition(.numericText())

                Text(L10n.Image.analyzingIn(countdownValue))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Cancel button (circle style)
            Button {
                cancelCountdown()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Processing circle (matching Voice style)
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.teal.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 10)

                // Main circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.teal.opacity(0.8), Color.teal.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.teal.opacity(0.4), radius: 20, x: 0, y: 8)

                // Glass overlay
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                // Spinner
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // Status text
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Image.processing)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(L10n.Image.processingSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Result View (only shown for multiple drafts)

    private var resultView: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Success circle
            ZStack {
                // Main circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.green.opacity(0.4), radius: 16, x: 0, y: 8)

                // Glass overlay
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                // Checkmark icon
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }

            // Count and label
            VStack(spacing: DS.Spacing.sm) {
                Text("\(draftsCreated)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.electricIndigo)

                Text(L10n.Image.transactionsDetectedCount)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Go to Inbox button (capsule style)
            YalaPrimaryButton(L10n.Image.goToInbox, icon: "tray") {
                onSavedToInbox?()
                dismiss()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Countdown Logic

    /// Loads the image and starts 2-second countdown before processing
    private func loadImageAndStartCountdown(from photo: PhotosPickerItem) async {
        do {
            // Load image data
            guard let imageData = try await photo.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: imageData) else {
                throw ImageError.loadFailed
            }

            // Show preview and start countdown
            await MainActor.run {
                selectedImage = uiImage
                countdownValue = 3
                isCountingDown = true
            }

            // Start countdown task
            countdownTask = Task {
                for i in (1...3).reversed() {
                    await MainActor.run {
                        countdownValue = i
                    }
                    try? await Task.sleep(for: .seconds(1))

                    // Check if cancelled
                    if Task.isCancelled { return }
                }

                // Countdown finished - start processing
                await MainActor.run {
                    isCountingDown = false
                }
                await processImage()
            }

        } catch {
            handleError(L10n.Image.errorLoad, type: .loadFailed)
        }
    }

    /// Cancels the countdown and returns to selection view
    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        isCountingDown = false
        selectedImage = nil
        selectedPhoto = nil
        countdownValue = 3
    }

    // MARK: - Processing Logic

    private func processImage() async {
        guard let uiImage = selectedImage else { return }

        await MainActor.run {
            isProcessing = true
        }

        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        do {
            // Try Vision API first if available
            if visionService.isAvailable {
                do {
                    try await processImageWithVision(uiImage)
                    return
                } catch {
                    // Vision failed, fall through to offline processing
                    print("Vision API failed, falling back to OCR: \(error.localizedDescription)")
                }
            }

            // Fallback to local OCR processing
            try await processImageOffline(uiImage)

        } catch let error as ImageOCRService.OCRError {
            handleError(error.localizedDescription, type: .corrupted)
        } catch let error as ImageError {
            let errorType: ImageErrorType
            switch error {
            case .loadFailed:
                errorType = .loadFailed
            case .noDataExtracted:
                errorType = .noData
            case .unrecognizedType:
                errorType = .unrecognized
            case .corrupted:
                errorType = .corrupted
            }
            handleError(error.localizedDescription, type: errorType)
        } catch {
            handleError(L10n.Image.errorGeneric, type: .generic)
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
    /// Handles navigation after drafts are created
    /// - 1 draft: Opens edit sheet directly (like Voice)
    /// - Multiple drafts: Shows result view with "Go to Inbox" button
    private func handleNavigation(drafts: [InboxDraft]) async {
        await MainActor.run {
            createdDrafts = drafts
            if drafts.count == 1 {
                // Single draft: open edit sheet directly
                createdDraft = drafts.first
            } else {
                // Multiple drafts: show result view
                withAnimation(.easeOut(duration: 0.3)) {
                    showingResult = true
                }
            }
        }
    }

    private func handleError(_ message: String, type: ImageErrorType = .generic) {
        errorMessage = message
        errorType = type
        showError = true
    }

    private func openSystemSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    private func resetForRetry() {
        selectedPhoto = nil
        selectedImage = nil
        isCountingDown = false
        isProcessing = false
        showingResult = false
        countdownValue = 3
    }

    // MARK: - Error Types

    /// Types of errors that need special handling
    enum ImageErrorType {
        case photoPermission
        case corrupted
        case loadFailed
        case noData
        case unrecognized
        case generic
    }

    enum ImageError: LocalizedError {
        case loadFailed
        case noDataExtracted
        case unrecognizedType
        case corrupted

        var errorDescription: String? {
            switch self {
            case .loadFailed:
                return L10n.Image.errorLoad
            case .noDataExtracted:
                return L10n.Image.errorNoData
            case .unrecognizedType:
                return L10n.Image.errorUnrecognized
            case .corrupted:
                return L10n.Image.errorCorrupted
            }
        }
    }
}

#Preview {
    ImageSelectionView()
        .modelContainer(for: [InboxDraft.self, Account.self, Subcategory.self])
}
