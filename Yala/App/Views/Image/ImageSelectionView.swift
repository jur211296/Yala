//
//  ImageSelectionView.swift
//  Yala
//
//  El registro por imagen (propuesta C, elegida por Jürgen el 2026-10-04): una hoja a media altura que elige la foto,
//  la lee con la foto a la vista y enseña lo leído como la fila del registro para guardarlo ahí mismo. Es el gemelo de
//  la hoja de voz (`VoiceRecordingView`) y reusa su fila (`VoiceDraftReviewCard`).
//
//  Cuatro fases en la misma hoja, sin presentaciones encadenadas ni alerts:
//  1. **Elegir** — Cámara · Fotos · Archivo (imagen o PDF). En la práctica guiada, también los recibos de ejemplo.
//  2. **Leyendo** — la foto con una línea que la recorre, el paso y Cancelar. Sin cuenta atrás.
//  3. **Lo leído** — una `VoiceDraftReviewCard` por borrador. «Guardar» los aprueba por el camino de la Bandeja
//     (`DraftService.approveDraft`); cerrar sin guardar los deja en la Bandeja. Las fotos que no se pudieron leer se
//     avisan aparte y se reintentan sin perder lo leído.
//  4. **Fallo** — qué pasó en lenguaje de usuario y una salida (`ImageEntryFailure`).
//

import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SceneNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.yalaTheme) private var theme
    @Environment(ImageVisionService.self) private var imageVisionService
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(AppPreferences.self) private var appPreferences

    @State private var networkMonitor = NetworkMonitor.shared

    @State private var phase: Phase = .choose
    /// Todas las fotos de esta vez, para las miniaturas de «Lo leído».
    @State private var images: [UIImage] = []
    /// Las que se están leyendo ahora (todas, o solo las que fallaron al reintentar).
    @State private var readingImages: [UIImage] = []
    @State private var readingIndex = 0
    @State private var failedImages: [UIImage] = []
    @State private var readTask: Task<Void, Never>?
    @State private var drafts: [InboxDraft] = []
    @State private var detailDraft: InboxDraft?
    @State private var saveFailed = false
    @State private var trialReported = false
    @State private var selectedDetent: PresentationDetent = .medium

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false

    /// Práctica guiada: recibos de ejemplo que se pueden leer sin tener uno a mano.
    var exampleImages: [UIImage]?

    /// Práctica guiada: se llama cuando el paso se cumple, con el ID del registro, su nombre, su tipo (`.transaction`
    /// si se guardó, `.draft` si quedó en la Bandeja) y los IDs de los demás borradores para limpiarlos con él.
    var onSetupTrialCompleted: ((PersistentIdentifier, String, PracticeItemKind, [PersistentIdentifier]) -> Void)?

    /// Práctica guiada: «Ahora no».
    var onSetupTrialSkipped: (() -> Void)?

    private enum Phase: Equatable {
        case choose
        case reading
        case review
        case failure(ImageEntryFailure)
    }

    private let buttonHeight: CGFloat = 48 // A11Y-DT: tap target de los botones de la hoja
    private let maxPhotos = 10

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            header
            content
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .dsAnimation(.easeInOut(duration: 0.25), value: phase, reduceMotion: reduceMotion)
        .yalaScreenBackground(
            SelectorSheetSizing.mediumFirst.background(
                selectedDetent: selectedDetent,
                usesLargeSheets: usesLargeSheets,
                dynamicTypeSize: dynamicTypeSize
            )
        )
        .selectorSheetSizing(.mediumFirst, selectedDetent: $selectedDetent)
        .interactiveDismissDisabled(phase == .reading)
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPhotos,
            maxSelectionCount: isSetupTrial ? 1 : maxPhotos,
            matching: .images
        )
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: !isSetupTrial,
            onCompletion: importFiles
        )
        .fullScreenCover(isPresented: $showCamera) {
            ImageCameraPicker(onFinish: cameraFinished)
                .ignoresSafeArea()
        }
        .sheet(item: $detailDraft, onDismiss: afterDetails) { draft in
            InboxDraftEditSheet(draft: draft)
        }
        .onChange(of: selectedPhotos) { _, newValue in
            loadPickedPhotos(newValue)
        }
        .onAppear(perform: checkForSharedImage)
        .onDisappear(perform: tearDown)
    }

    private var isSetupTrial: Bool { onSetupTrialCompleted != nil }

    // MARK: - Cabecera

    /// Cerrar solo cuando no hay un Cancelar abajo; «Ahora no» de la práctica, mientras no haya nada que revisar.
    private var header: some View {
        HStack {
            if let skip = onSetupTrialSkipped, phase != .review, phase != .reading {
                Button(L10n.SetupChecklist.skipStep) {
                    skip()
                    dismiss()
                }
                .font(DS.Typography.label)
                .frame(minHeight: 44)
            }
            Spacer()
            if phase != .reading {
                YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                    dismiss()
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("image_close")
            }
        }
        .frame(minHeight: 44)
        .padding(.top, DS.Spacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .choose:
            chooseContent
        case .reading:
            readingContent
        case .review:
            reviewContent
        case .failure(let failure):
            failureContent(failure)
        }
    }

    // MARK: - Elegir

    private var chooseContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L10n.Image.Entry.title)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("image_choose_title")
                Text(L10n.Image.Entry.subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let examples = exampleImages, !examples.isEmpty {
                exampleRow(examples)
            }

            sourceTiles

            if !isSetupTrial {
                Text(L10n.Image.Entry.multipleHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DS.Spacing.none)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("image_choose")
    }

    /// Con texto de accesibilidad, una debajo de otra: tres en fila no caben.
    private var sourceTiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        let hasCamera = ImageCameraPicker.isAvailable
        return layout {
            if hasCamera {
                sourceTile(L10n.Image.Entry.camera, icon: "camera", isPrimary: true, identifier: "image_source_camera") {
                    Task { await openCamera() }
                }
            }
            sourceTile(L10n.Image.Entry.photos, icon: "photo.on.rectangle", isPrimary: !hasCamera, identifier: "image_source_photos") {
                openPhotos()
            }
            sourceTile(L10n.Image.Entry.file, icon: "doc", isPrimary: false, identifier: "image_source_file") {
                showFileImporter = true
            }
        }
    }

    private func sourceTile(
        _ title: String,
        icon: String,
        isPrimary: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(isPrimary ? Color.contrastingText(for: theme.accent) : theme.accent)
                    .frame(width: 48, height: 48) // A11Y-DT: disco del icono de la fuente
                    .background(
                        Circle().fill(isPrimary ? Color.contrastingText(for: theme.accent).opacity(0.18) : theme.accent.opacity(0.15))
                    )
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(isPrimary ? Color.contrastingText(for: theme.accent) : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isPrimary ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thCard))
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func exampleRow(_ examples: [UIImage]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.SetupChecklist.ImageTrial.pickExample)
                .font(DS.Typography.label)
                .foregroundStyle(.thPrimaryText)
            HStack(spacing: DS.Spacing.sm) {
                ForEach(examples.indices, id: \.self) { index in
                    Button {
                        startReading([examples[index]])
                    } label: {
                        Image(uiImage: examples[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 92) // A11Y-DT: miniatura del recibo de ejemplo
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(exampleLabel(index))
                    .accessibilityIdentifier("image_example_\(index)")
                }
            }
        }
    }

    private func exampleLabel(_ index: Int) -> String {
        let labels = [
            L10n.SetupChecklist.ImageTrial.exampleReceipt,
            L10n.SetupChecklist.ImageTrial.exampleBankAlert,
            L10n.SetupChecklist.ImageTrial.exampleTransactionList
        ]
        return index < labels.count ? labels[index] : ""
    }

    // MARK: - Leyendo

    private var readingContent: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xs) {
                Text(readingImages.count > 1 ? L10n.Image.Entry.readingMany : L10n.Image.Entry.readingOne)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(readingStepText)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
            }
            .accessibilityElement(children: .combine)

            if let image = currentReadingImage {
                ImageReadingPhoto(image: image, accent: theme.accent, reduceMotion: reduceMotion)
                    .id(readingIndex)
                    .padding(.top, DS.Spacing.xs)
            }

            Spacer(minLength: DS.Spacing.lg)

            Button(L10n.Action.cancel, action: cancelReading)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: buttonHeight)
                .accessibilityLabel(L10n.Image.Entry.cancelReading)
                .accessibilityIdentifier("image_cancel_reading")
        }
        .padding(.top, DS.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("image_reading")
    }

    private var currentReadingImage: UIImage? {
        guard !readingImages.isEmpty else { return nil }
        return readingImages[min(readingIndex, readingImages.count - 1)]
    }

    private var readingStepText: String {
        readingImages.count > 1
            ? L10n.Image.Entry.readingProgress(readingIndex + 1, readingImages.count)
            : L10n.Image.Entry.readingStep
    }

    // MARK: - Lo leído

    private var pendingDrafts: [InboxDraft] {
        drafts.filter { $0.status == .pending }
    }

    private var allSaved: Bool {
        !drafts.isEmpty && pendingDrafts.isEmpty
    }

    private var canSave: Bool {
        VoiceEntryFlowLogic.canSave(pendingDrafts.map(readiness))
    }

    private var reviewContent: some View {
        VStack(spacing: DS.Spacing.md) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.md) {
                        Text(reviewTitle)
                            .font(DS.Typography.title3)
                            .foregroundStyle(.thPrimaryText)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("image_review_title")
                        Spacer(minLength: DS.Spacing.sm)
                        thumbnails
                    }

                    ForEach(drafts, id: \.persistentModelID) { draft in
                        VoiceDraftReviewCard(draft: draft) {
                            detailDraft = draft
                        }
                    }

                    if !failedImages.isEmpty {
                        failedPhotosBanner
                    }

                    if !allSaved {
                        Text(L10n.Voice.reviewInboxNote)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            if saveFailed {
                Text(L10n.Chat.Draft.saveFailedGeneric)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.errorForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: DS.Spacing.md) {
                if allSaved {
                    primaryButton(L10n.Action.done, isEnabled: true, identifier: "image_finish") {
                        dismiss()
                    }
                } else {
                    secondaryButton(L10n.Image.Entry.otherPhoto, identifier: "image_other_photo", action: chooseAnother)
                    primaryButton(saveTitle, isEnabled: canSave, identifier: "image_save", action: saveAll)
                }
            }
        }
        .padding(.top, DS.Spacing.xs)
    }

    /// Las fotos de esta vez, en pequeño; las que no se leyeron, atenuadas y con aviso.
    private var thumbnails: some View {
        HStack(spacing: -DS.Spacing.md) {
            ForEach(images.indices.prefix(4), id: \.self) { index in
                let image = images[index]
                let failed = failedImages.contains { $0 === image }
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 44) // A11Y-DT: miniatura decorativa de la foto
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .strokeBorder(.thCard, lineWidth: 2)
                    )
                    .opacity(failed ? 0.45 : 1)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -4 : 4))
            }
        }
        .accessibilityHidden(true)
    }

    private var failedPhotosBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Semantic.warningForeground)
                .accessibilityHidden(true)
            Text(L10n.Image.Entry.photosFailed(failedImages.count))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Spacing.sm)
            Button(L10n.Action.retry, action: retryFailedPhotos)
                .font(DS.Typography.label)
                .foregroundStyle(DS.Semantic.warningForeground)
                .frame(minHeight: 44)
                .accessibilityIdentifier("image_retry_failed")
        }
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Semantic.warningBackground)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("image_failed_photos")
    }

    private var reviewTitle: String {
        if allSaved { return L10n.Chat.Draft.savedBadge }
        return drafts.count > 1 ? L10n.Image.Entry.reviewTitleMany(drafts.count) : L10n.Image.Entry.reviewTitle
    }

    private var saveTitle: String {
        pendingDrafts.count > 1 ? L10n.Voice.saveMany(pendingDrafts.count) : L10n.Chat.Draft.saveButton
    }

    private func readiness(_ draft: InboxDraft) -> VoiceDraftReadiness {
        VoiceDraftReadiness(
            hasAmount: draft.amount != nil,
            hasAccount: draft.account != nil,
            accountIsArchived: draft.account?.isArchived ?? false,
            hasSubcategory: draft.subcategory != nil,
            isFutureDate: draft.effectiveDate > Date.now
        )
    }

    // MARK: - Fallo

    private func failureContent(_ failure: ImageEntryFailure) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: failureIcon(failure))
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.warningForeground)
                .frame(width: 72, height: 72) // A11Y-DT: disco del icono del fallo
                .background(Circle().fill(DS.Semantic.warningBackground))
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.xs) {
                Text(failureTitle(failure))
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("image_failure_title")
                Text(failureMessage(failure))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: DS.Spacing.lg)

            HStack(spacing: DS.Spacing.md) {
                failureActions(failure)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("image_failure")
    }

    @ViewBuilder
    private func failureActions(_ failure: ImageEntryFailure) -> some View {
        switch failure {
        case .cameraPermission:
            secondaryButton(L10n.Image.Entry.otherPhoto, identifier: "image_other_photo", action: chooseAnother)
            primaryButton(L10n.Image.openSettings, isEnabled: true, identifier: "image_open_settings", action: openSystemSettings)
        case .serviceUnavailable:
            primaryButton(L10n.Action.close, isEnabled: true, identifier: "image_failure_close") { dismiss() }
        case .noAmount, .unreadable, .unreadableFile:
            primaryButton(L10n.Image.Entry.otherPhoto, isEnabled: true, identifier: "image_other_photo", action: chooseAnother)
        case .noConnection, .generic, .saveFailed:
            if failure.retriesSamePhotos, !readingImages.isEmpty {
                secondaryButton(L10n.Image.Entry.otherPhoto, identifier: "image_other_photo", action: chooseAnother)
                primaryButton(L10n.Action.retry, isEnabled: true, identifier: "image_retry") {
                    startReading(readingImages)
                }
            } else {
                primaryButton(L10n.Image.Entry.otherPhoto, isEnabled: true, identifier: "image_other_photo", action: chooseAnother)
            }
        }
    }

    private func failureIcon(_ failure: ImageEntryFailure) -> String {
        switch failure {
        case .noConnection: "wifi.slash"
        case .cameraPermission: "camera"
        case .noAmount: "questionmark"
        case .unreadable: "photo"
        case .unreadableFile: "doc"
        case .serviceUnavailable, .saveFailed, .generic: "exclamationmark"
        }
    }

    private func failureTitle(_ failure: ImageEntryFailure) -> String {
        switch failure {
        case .noConnection: L10n.Voice.failureNoConnectionTitle
        case .cameraPermission: L10n.Image.Entry.failureCameraTitle
        case .noAmount: L10n.Image.Entry.failureNoAmountTitle
        case .unreadable: L10n.Image.Entry.failureUnreadableTitle
        case .unreadableFile: L10n.Image.Entry.failureUnreadableFileTitle
        case .serviceUnavailable, .saveFailed, .generic: L10n.Image.Entry.failureGenericTitle
        }
    }

    private func failureMessage(_ failure: ImageEntryFailure) -> String {
        switch failure {
        case .noConnection: L10n.Image.errorNoConnection
        case .cameraPermission: L10n.Image.Entry.failureCameraMessage
        case .noAmount: L10n.Image.Entry.failureNoAmountMessage
        case .unreadable: L10n.Image.errorCorrupted
        case .unreadableFile: L10n.Image.Entry.failureUnreadableFileMessage
        case .serviceUnavailable: L10n.Image.errorNoApiKey
        case .saveFailed: L10n.Image.errorSaveFailed
        case .generic: L10n.Image.Entry.failureGenericMessage
        }
    }

    private func openSystemSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    // MARK: - Botones

    private func primaryButton(
        _ title: String,
        isEnabled: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.body.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                // Apagado se VE apagado: con fondo explícito, `.disabled` no atenúa nada (#348).
                .foregroundStyle(isEnabled ? Color.contrastingText(for: theme.accent) : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: buttonHeight)
                .padding(.horizontal, DS.Spacing.sm)
                .background(
                    Capsule().fill(isEnabled ? theme.accent : DS.Semantic.disabledForeground.opacity(0.35))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(identifier)
    }

    private func secondaryButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.body.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.thPrimaryText)
                .frame(maxWidth: .infinity, minHeight: buttonHeight)
                .padding(.horizontal, DS.Spacing.sm)
                .background(Capsule().fill(Color(.tertiarySystemFill)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Fuentes

    private func openPhotos() {
        #if DEBUG
        if UITestHooks.imageResult != nil {
            startReading(uiTestImages())
            return
        }
        #endif
        selectedPhotos = []
        showPhotosPicker = true
    }

    private func openCamera() async {
        if await ImageCameraPicker.requestAccess() {
            showCamera = true
        } else {
            phase = .failure(.cameraPermission)
        }
    }

    private func cameraFinished(_ image: UIImage?) {
        showCamera = false
        guard let image else { return }
        startReading([image])
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var loaded: [UIImage] = []
            for item in items {
                do {
                    if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        loaded.append(image)
                    }
                } catch {
                    #if DEBUG
                    print("ImageSelectionView: Error loading picked photo: \(error)")
                    #endif
                }
            }
            selectedPhotos = []
            guard !loaded.isEmpty else {
                phase = .failure(.unreadable)
                return
            }
            startReading(loaded)
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            let loaded = urls.prefix(maxPhotos).compactMap(loadImage(from:))
            guard !loaded.isEmpty else {
                phase = .failure(.unreadableFile)
                return
            }
            startReading(loaded)
        case .failure(let error):
            #if DEBUG
            print("ImageSelectionView: Error importing files: \(error)")
            #endif
            phase = .failure(.unreadableFile)
        }
    }

    /// Una imagen, o la primera página de un PDF (el mismo render que soltar un recibo en el iPad).
    private func loadImage(from url: URL) -> UIImage? {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
                return ReceiptDropHandler.firstPageJPEG(pdfData: data).flatMap { UIImage(data: $0) }
            }
            return UIImage(data: data)
        } catch {
            #if DEBUG
            print("ImageSelectionView: Error reading file: \(error)")
            #endif
            return nil
        }
    }

    /// Una foto compartida desde otra app (o soltada en el iPad) llega ya elegida: se lee directamente. Lo soltado que no
    /// se pudo abrir llega como su fallo (`ReceiptDropHandler`) y se enseña sin pasar por elegir.
    private func checkForSharedImage() {
        if let failure = navigation.pendingImageEntryFailure {
            navigation.pendingImageEntryFailure = nil
            phase = .failure(failure)
            return
        }
        guard let url = navigation.pendingSharedImageURL else { return }
        navigation.pendingSharedImageURL = nil
        do {
            let data = try Data(contentsOf: url)
            SharedContainerService.removePendingImage(at: url)
            guard let image = UIImage(data: data) else {
                phase = .failure(.unreadable)
                return
            }
            startReading([image])
        } catch {
            SharedContainerService.removePendingImage(at: url)
            #if DEBUG
            print("ImageSelectionView: Error loading shared image: \(error)")
            #endif
            phase = .failure(.unreadable)
        }
    }

    // MARK: - Leer

    private func startReading(_ batch: [UIImage]) {
        guard !batch.isEmpty else { return }
        images = batch
        failedImages = []
        drafts = []
        saveFailed = false
        guard networkMonitor.isConnected else {
            readingImages = batch
            phase = .failure(.noConnection)
            return
        }
        beginReading(batch, appending: false)
    }

    /// Reintenta solo las que fallaron, sin perder lo ya leído.
    private func retryFailedPhotos() {
        guard !failedImages.isEmpty else { return }
        // Sin red no se calla: la lectura falla igual y vuelve a lo leído con las mismas fotos avisadas.
        beginReading(failedImages, appending: true)
    }

    private func beginReading(_ batch: [UIImage], appending: Bool) {
        readingImages = batch
        readingIndex = 0
        phase = .reading
        readTask?.cancel()
        readTask = Task {
            await read(batch, appending: appending)
        }
    }

    /// Cancelar la primera lectura cierra la hoja; cancelar un reintento vuelve a lo ya leído.
    private func cancelReading() {
        readTask?.cancel()
        readTask = nil
        if drafts.isEmpty {
            dismiss()
        } else {
            phase = .review
        }
    }

    private func read(_ batch: [UIImage], appending: Bool) async {
        // Foto de los pendientes ANTES de crear los nuevos, para que el auto-insert de SwiftData no se cuele en la
        // deduplicación.
        let existingDrafts = fetchPendingDrafts()
        var outcomes: [ImageReadOutcome] = []
        var readDrafts: [InboxDraft] = []
        var failed: [UIImage] = []

        for (index, image) in batch.enumerated() {
            readingIndex = index
            do {
                let found = try await analyze(image, index: index)
                guard !Task.isCancelled else { return }
                if found.isEmpty {
                    outcomes.append(.failed(.noAmount))
                    failed.append(image)
                } else {
                    outcomes.append(.read)
                    readDrafts.append(contentsOf: found)
                }
            } catch let error as VisionError {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("ImageSelectionView: Error reading photo \(index + 1): \(error)")
                #endif
                outcomes.append(.failed(ImageEntryFlowLogic.failure(for: error, isConnected: networkMonitor.isConnected)))
                failed.append(image)
            } catch {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("ImageSelectionView: Error reading photo \(index + 1): \(error)")
                #endif
                outcomes.append(.failed(ImageEntryFlowLogic.failure(forUnknownErrorWhenConnected: networkMonitor.isConnected)))
                failed.append(image)
            }
        }

        switch ImageEntryFlowLogic.result(for: outcomes) {
        case .failure(let failure):
            if appending {
                // El reintento volvió a fallar: lo leído sigue ahí, con las mismas fotos avisadas.
                failedImages = failed
                phase = .review
            } else {
                phase = .failure(failure)
            }
        case .review:
            guard let shown = insert(readDrafts, existing: existingDrafts) else {
                phase = appending ? .review : .failure(.saveFailed)
                saveFailed = appending
                return
            }
            let combined = appending ? drafts + shown : shown
            // La práctica guiada es de UN registro: se revisa el primero; los demás quedan en la Bandeja.
            drafts = isSetupTrial ? Array(combined.prefix(1)) : combined
            failedImages = failed
            phase = .review
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Inserta los nuevos y devuelve lo que se enseña. Si todos parecen duplicados de borradores que ya esperaban en la
    /// Bandeja, se enseñan ESOS (ya insertados): aprobar uno transitorio dejaría un registro duplicado. `nil` si no se
    /// pudo guardar.
    private func insert(_ newDrafts: [InboxDraft], existing: [InboxDraft]) -> [InboxDraft]? {
        let unique = DraftDeduplicationService.deduplicate(newDrafts: newDrafts, existingDrafts: existing)
        if unique.isEmpty {
            return existing.filter { old in newDrafts.contains { DraftDeduplicationService.isDuplicate($0, old) } }
        }
        for draft in unique {
            modelContext.insert(draft)
        }
        do {
            try modelContext.save()
            return unique
        } catch {
            #if DEBUG
            print("ImageSelectionView: Error saving drafts: \(error)")
            #endif
            return nil
        }
    }

    /// Lee una foto con el servicio de imagen: los borradores que trae, sin insertar. Vacío si no trae importes.
    private func analyze(_ image: UIImage, index: Int) async throws -> [InboxDraft] {
        #if DEBUG
        if let profile = UITestHooks.imageResult {
            return try await uiTestDrafts(profile, index: index)
        }
        #endif
        let response = try await imageVisionService.analyze(image: image)
        guard !response.transactions.isEmpty, response.imageType != "unknown" else { return [] }
        return VisionDraftFactory.makeDrafts(from: response, rawText: nil, context: modelContext)
    }

    /// «Otra foto»: lo pendiente de esta vez se descarta —si se quedara, la Bandeja acabaría con el mismo gasto dos
    /// veces— y se vuelve a elegir. Lo ya guardado no se toca.
    private func chooseAnother() {
        let pending = pendingDrafts
        for draft in pending {
            modelContext.delete(draft)
        }
        if !pending.isEmpty {
            do {
                try modelContext.save()
            } catch {
                #if DEBUG
                print("ImageSelectionView: Error discarding drafts: \(error)")
                #endif
            }
        }
        drafts = []
        images = []
        readingImages = []
        failedImages = []
        saveFailed = false
        phase = .choose
    }

    // MARK: - Guardar

    /// Aprueba los pendientes por el mismo camino que la Bandeja: transacción, memoria del comercio, widgets y avisos de
    /// presupuesto. Si uno falla, los anteriores ya quedaron guardados y el resto sigue pendiente.
    private func saveAll() {
        saveFailed = false
        DraftService.shared.setContext(modelContext)
        for draft in pendingDrafts {
            do {
                let transaction = try DraftService.shared.approveDraft(draft, currencyConverter: currencyConverter)
                reportTrial(id: transaction.persistentModelID, name: draft.note, kind: .transaction)
            } catch {
                #if DEBUG
                print("ImageSelectionView: Error approving draft: \(error)")
                #endif
                saveFailed = true
                break
            }
        }
        if !saveFailed {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Al volver del formulario completo: si allí se aprobó, la fila ya sale guardada. Si se rechazó o se borró, sale
    /// de la lista; y si no queda ninguno, la hoja ya no tiene nada que enseñar.
    private func afterDetails() {
        drafts.removeAll { $0.isDeleted || $0.status == .rejected }
        if let approved = drafts.first(where: { $0.status == .approved }), let transaction = approved.approvedTransaction {
            reportTrial(id: transaction.persistentModelID, name: approved.note, kind: .transaction)
        }
        if drafts.isEmpty, phase == .review {
            dismiss()
        }
    }

    // MARK: - Práctica guiada y cierre

    private func reportTrial(id: PersistentIdentifier, name: String, kind: PracticeItemKind, others: [PersistentIdentifier] = []) {
        guard let callback = onSetupTrialCompleted, !trialReported else { return }
        trialReported = true
        callback(id, name, kind, others)
    }

    /// Al cerrar: corta lo que se estuviera leyendo y, en la práctica guiada, da el paso por cumplido con el borrador
    /// que quedó en la Bandeja.
    private func tearDown() {
        readTask?.cancel()
        readTask = nil
        let pending = pendingDrafts
        if let first = pending.first {
            reportTrial(
                id: first.persistentModelID,
                name: first.note,
                kind: .draft,
                others: pending.dropFirst().map(\.persistentModelID)
            )
        }
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

    // MARK: - Seam de XCUITest

    #if DEBUG
    /// `-uitest-image-result`: las fotos que «elige» Fotos son los recibos de ejemplo de la práctica guiada.
    private func uiTestImages() -> [UIImage] {
        let names = ["ExampleImages/example-receipt-es", "ExampleImages/example-bank-alert-es"]
        let count = ["two", "partial"].contains(UITestHooks.imageResult ?? "") ? 2 : 1
        return names.prefix(count).compactMap { UIImage(named: $0) }
    }

    /// Lo que la hoja «lee» sin red, resuelto contra los datos sembrados para que la cuenta y la subcategoría casen.
    private func uiTestDrafts(_ profile: String, index: Int) async throws -> [InboxDraft] {
        // Lo bastante para que la fase «Leyendo» se vea y XCUITest, que sondea a ~1 s, la alcance.
        try await Task.sleep(for: .milliseconds(2500))
        switch profile {
        case "none":
            return []
        case "partial" where index == 1:
            throw VisionError.invalidResponse
        default:
            break
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let today = formatter.string(from: Date.now)
        let isFirst = index == 0
        let transaction = VisionTransaction(
            amount: isFirst ? -251.81 : -22,
            date: today,
            merchant: isFirst ? "Restaurante El Buen Gusto" : "Taxi",
            note: nil,
            currency: uiTestAccountCurrency()
        )
        let response = VisionResponse(
            imageType: "receipt",
            transactions: [transaction],
            confidence: VisionConfidence(overall: 1, imageType: 1)
        )
        let made = VisionDraftFactory.makeDrafts(from: response, rawText: nil, context: modelContext)
        if profile != "incomplete" {
            let subcategory = uiTestExpenseSubcategory()
            for draft in made where draft.subcategory == nil {
                draft.subcategory = subcategory
                draft.needsUserInput.removeAll { $0 == DraftInputRequirement.subcategory }
            }
        }
        return made
    }

    private func uiTestAccountCurrency() -> String? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { account in account.isArchived == false && account.isSystemAccount == false },
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            let codes = try modelContext.fetch(descriptor).map(\.currencyCode)
            let preferred = appPreferences.defaultCurrencyCode.rawValue
            return codes.contains(preferred) ? preferred : codes.first
        } catch {
            print("ImageSelectionView: Error fetching accounts for the UI-test seam: \(error)")
            return nil
        }
    }

    private func uiTestExpenseSubcategory() -> Subcategory? {
        let descriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\.name)])
        do {
            let expense = try modelContext.fetch(descriptor).filter { $0.isVisible && !$0.safeCategory.isIncome }
            return expense.first { $0.name.hasPrefix("Restaurant") } ?? expense.first
        } catch {
            print("ImageSelectionView: Error fetching subcategories for the UI-test seam: \(error)")
            return nil
        }
    }
    #endif
}

/// La foto mientras se lee: una línea del color del tema la recorre de arriba abajo. Sin movimiento si el usuario lo
/// pidió reducido.
private struct ImageReadingPhoto: View {
    let image: UIImage
    let accent: Color
    let reduceMotion: Bool

    @State private var sweepDown = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 190) // A11Y-DT: la foto que se está leyendo
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(accent)
                            .frame(height: 3)
                            .shadow(color: accent.opacity(0.8), radius: 8)
                            .offset(y: sweepDown ? proxy.size.height - 3 : 0)
                    }
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    sweepDown = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    ImageSelectionView()
        .environment(SceneNavigation())
        .modelContainer(for: [InboxDraft.self, Account.self, Subcategory.self])
}
