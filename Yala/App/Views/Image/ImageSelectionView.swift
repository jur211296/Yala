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
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ImageVisionService.self) private var imageVisionService

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isCountingDown = false
    @State private var countdownValue = 3
    @State private var countdownTask: Task<Void, Never>?
    @State private var isProcessing = false
    @State private var processingProgress: (current: Int, total: Int) = (0, 0)
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

    // Network monitor
    private let networkMonitor = NetworkMonitor.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                if showingResult {
                    resultView
                        .transition(.scale.combined(with: .opacity))
                } else if isCountingDown {
                    countdownView
                        .transition(.scale.combined(with: .opacity))
                } else if isProcessing {
                    processingView
                        .transition(.scale.combined(with: .opacity))
                } else {
                    selectionView
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(DS.Spacing.xl)
            .dsAnimation(.easeInOut(duration: 0.3), value: showingResult, reduceMotion: reduceMotion)
            .dsAnimation(.easeInOut(duration: 0.3), value: isCountingDown, reduceMotion: reduceMotion)
            .dsAnimation(.easeInOut(duration: 0.3), value: isProcessing, reduceMotion: reduceMotion)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.yalaBackground)
            .navigationTitle(L10n.Image.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Only show X in selection view (during countdown/processing, there's an X below)
                if !isCountingDown && !isProcessing && !showingResult {
                    ToolbarItem(placement: .topBarTrailing) {
                        YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                if !newValue.isEmpty {
                    Task {
                        await loadImagesAndStartCountdown(from: newValue)
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
                case .noApiKey, .noConnection:
                    // No action available - feature requires API key and network
                    Button(L10n.Common.accept) {
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
                    // Draft was not approved - just dismiss back to PanelView
                    dismiss()
                }
                // Reset flag for next use
                if newValue == nil {
                    draftWasApproved = false
                }
            }
            .onAppear {
                checkForSharedImage()
            }
        }
    }

    // MARK: - Shared Image Handling

    /// Check for pending shared image from Share Extension
    private func checkForSharedImage() {
        guard let imageURL = sessionState.pendingSharedImageURL else { return }

        // Clear URL immediately to prevent double processing
        // (shouldShowSharedImage was already reset by the one-shot observer)
        sessionState.pendingSharedImageURL = nil

        Task {
            await loadSharedImage(from: imageURL)
        }
    }

    /// Load shared image and start countdown
    private func loadSharedImage(from url: URL) async {
        do {
            let imageData = try Data(contentsOf: url)
            guard let uiImage = UIImage(data: imageData) else {
                // Clean up the file
                SharedContainerService.removePendingImage(at: url)
                return
            }

            // Remove the temporary file
            SharedContainerService.removePendingImage(at: url)

            // Start the countdown flow with the loaded image
            await MainActor.run {
                selectedImages = [uiImage]
                countdownValue = 3
                isCountingDown = true
            }

            // Start countdown task
            countdownTask = Task {
                for i in (1...3).reversed() {
                    await MainActor.run {
                        countdownValue = i
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        return
                    }

                    if Task.isCancelled { return }
                }

                await MainActor.run {
                    isCountingDown = false
                }
                await processAllImages()
            }
        } catch {
            SharedContainerService.removePendingImage(at: url)
            #if DEBUG
            print("ImageSelectionView: Error loading shared image: \(error)")
            #endif
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
                    .fill(DS.Colors.backgroundSubtle)
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
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(.white)
            }

            // Instructions (hints + examples)
            imageInstructionsView

            Spacer()

            // Select button (circle style like Voice)
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            ) {
                Image(systemName: "photo.badge.plus")
                    .font(DS.Typography.title)
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

    // MARK: - Instructions View

    private var imageInstructionsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.lg) {
                Text(L10n.Image.selectTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                // Hints grid
                imageHintsSection

                // Examples
                imageExamplesSection
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private var imageHintsSection: some View {
        VStack(alignment: .center, spacing: DS.Spacing.sm) {
            Text(L10n.Image.youCanUpload)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.sm) {
                imageHintChip(icon: "receipt", text: L10n.Image.hintReceipts)
                imageHintChip(icon: "iphone", text: L10n.Image.hintBankScreenshots)
                imageHintChip(icon: "tag", text: L10n.Image.hintRestaurantTickets)
                imageHintChip(icon: "doc.text", text: L10n.Image.hintStatements)
                imageHintChip(icon: "creditcard", text: L10n.Image.hintPaymentProofs)
                imageHintChip(icon: "photo.on.rectangle", text: L10n.Image.hintMultiple)
            }
        }
        .padding(DS.Spacing.md)
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func imageHintChip(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(Color.teal)

            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var imageExamplesSection: some View {
        VStack(alignment: .center, spacing: DS.Spacing.sm) {
            Text(L10n.Image.exampleLabel)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: DS.Spacing.xs) {
                imageExampleRow(text: L10n.Image.example1)
                imageExampleRow(text: L10n.Image.example2)
                imageExampleRow(text: L10n.Image.example3)
            }
        }
        .padding(DS.Spacing.md)
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func imageExampleRow(text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "photo")
                .font(DS.Typography.caption)
                .foregroundStyle(Color.teal)

            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .italic()

            Spacer()
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(Color.teal.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Image preview(s) with subtle styling
            if selectedImages.count == 1, let image = selectedImages.first {
                // Single image: show large preview with material border
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(.ultraThinMaterial, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            } else if selectedImages.count > 1 {
                // Multiple images: show grid preview with shadows
                VStack(spacing: DS.Spacing.sm) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: DS.Spacing.sm) {
                        ForEach(selectedImages.prefix(6).indices, id: \.self) { index in
                            Image(uiImage: selectedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        if selectedImages.count > 6 {
                            ZStack {
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .fill(Color.teal.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Text("+\(selectedImages.count - 6)")
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(Color.teal)
                            }
                        }
                    }
                    Text(L10n.Image.imagesSelected(selectedImages.count))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Countdown display with ring
            VStack(spacing: DS.Spacing.sm) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.teal.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    // Depleting ring
                    Circle()
                        .trim(from: 0, to: CGFloat(countdownValue) / 3.0)
                        .stroke(Color.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: countdownValue)

                    Text("\(countdownValue)")
                        .font(DS.Typography.amountLarge)
                        .foregroundStyle(Color.teal)
                        .contentTransition(.numericText())
                }

                // Glass label
                Text(L10n.Image.analyzingIn(countdownValue))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .glassEffect()
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
        ProcessingProgressView(
            mode: .determinate(
                current: processingProgress.current,
                total: processingProgress.total
            ),
            accentColor: .teal,
            statusText: L10n.Image.processing
        )
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
                            colors: DS.Gradients.success,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.green.opacity(0.4), radius: 16, x: 0, y: 8)

                // Glass overlay
                Circle()
                    .fill(DS.Colors.backgroundSubtle)
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
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(.white)
            }

            // Count and label
            VStack(spacing: DS.Spacing.sm) {
                Text("\(draftsCreated)")
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(Color.electricIndigo)

                Text(L10n.Image.transactionsDetectedCount)
                    .font(DS.Typography.subheadline)
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

    /// Loads multiple images and starts countdown before processing
    private func loadImagesAndStartCountdown(from photos: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = []

        for photo in photos {
            do {
                guard let imageData = try await photo.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: imageData) else {
                    continue // Skip failed images
                }
                loadedImages.append(uiImage)
            } catch {
                continue // Skip failed images
            }
        }

        guard !loadedImages.isEmpty else {
            handleError(L10n.Image.errorLoad, type: .loadFailed)
            return
        }

        // Show preview and start countdown
        await MainActor.run {
            selectedImages = loadedImages
            countdownValue = 3
            isCountingDown = true
        }

        // Start countdown task
        countdownTask = Task {
            for i in (1...3).reversed() {
                await MainActor.run {
                    countdownValue = i
                    // Haptic feedback on each tick
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }

                // Check if cancelled
                if Task.isCancelled { return }
            }

            // Countdown finished - start processing
            await MainActor.run {
                isCountingDown = false
            }
            await processAllImages()
        }
    }

    /// Cancels the countdown and returns to selection view
    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        isCountingDown = false
        selectedImages = []
        selectedPhotos = []
        countdownValue = 3
    }

    // MARK: - Processing Logic

    /// Process all selected images
    private func processAllImages() async {
        guard !selectedImages.isEmpty else { return }

        // Check for API key first
        guard APIKeyService.hasOpenAIAPIKey else {
            handleError(L10n.Image.errorNoApiKey, type: .noApiKey)
            return
        }

        // Check for network connection
        guard networkMonitor.isConnected else {
            handleError(L10n.Image.errorNoConnection, type: .noConnection)
            return
        }

        await MainActor.run {
            isProcessing = true
            processingProgress = (0, selectedImages.count)
        }

        // Snapshot existing pending drafts BEFORE processing to avoid
        // SwiftData auto-insert interference with deduplication
        let existingDrafts = fetchPendingDrafts()

        var allDrafts: [InboxDraft] = []

        for (index, uiImage) in selectedImages.enumerated() {
            await MainActor.run {
                processingProgress = (index + 1, selectedImages.count)
            }

            do {
                let drafts = try await processSingleImage(uiImage)
                allDrafts.append(contentsOf: drafts)
            } catch {
                // Continue processing other images even if one fails
            }
        }

        await MainActor.run {
            isProcessing = false
        }

        if allDrafts.isEmpty {
            handleError(L10n.Image.errorNoData, type: .noData)
            return
        }

        // Deduplicate against pre-existing pending drafts
        let uniqueDrafts = DraftDeduplicationService.deduplicate(
            newDrafts: allDrafts,
            existingDrafts: existingDrafts
        )

        // If all are duplicates, navigate to what already exists
        let draftsToUse = uniqueDrafts.isEmpty ? allDrafts : uniqueDrafts

        // Insert only unique drafts (no-op if SwiftData already auto-inserted)
        for draft in draftsToUse {
            modelContext.insert(draft)
        }

        draftsCreated = draftsToUse.count
        do {
            try modelContext.save()
        } catch {
            handleError(L10n.Image.errorSaveFailed, type: .generic)
            return
        }
        await handleNavigation(drafts: draftsToUse)
    }

    /// Process a single image and return drafts
    private func processSingleImage(_ uiImage: UIImage) async throws -> [InboxDraft] {
        return try await processImageWithVisionReturning(uiImage)
    }

    /// Process image using GPT-4o Vision API (online) - returns drafts (not yet inserted)
    private func processImageWithVisionReturning(_ uiImage: UIImage) async throws -> [InboxDraft] {
        let response = try await imageVisionService.analyze(image: uiImage)

        // Check if we got valid transactions
        guard !response.transactions.isEmpty,
              response.imageType != "unknown" else {
            throw ImageError.noDataExtracted
        }

        // Create drafts from Vision response without inserting
        let drafts = VisionDraftFactory.makeDrafts(
            from: response,
            rawText: nil,
            context: modelContext
        )

        guard !drafts.isEmpty else {
            throw ImageError.noDataExtracted
        }

        return drafts
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
                dsWithAnimation(reduceMotion) {
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

    private func fetchPendingDrafts() -> [InboxDraft] {
        let descriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { draft in
                draft.statusRaw == "pending"
            }
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ImageSelectionView: Error fetching pending drafts: \(error)")
            #endif
            return []
        }
    }

    private func resetForRetry() {
        selectedPhotos = []
        selectedImages = []
        isCountingDown = false
        isProcessing = false
        showingResult = false
        countdownValue = 3
        processingProgress = (0, 0)
    }

    // MARK: - Error Types

    /// Types of errors that need special handling
    enum ImageErrorType {
        case photoPermission
        case corrupted
        case loadFailed
        case noData
        case unrecognized
        case noApiKey
        case noConnection
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
