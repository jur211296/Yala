//
//  GroupPhotoCaptureView.swift
//  Yala
//
//  Foto dentro de un grupo, igual que la foto de personal (`ImageSelectionView`): la hoja a media altura con el título,
//  las tres fichas Cámara · Fotos · Archivo, la foto que se lee nada más elegirla con su línea de luz, y la misma
//  pantalla de fallo. Lo propio del grupo: el «¿Quién comió qué?» opcional antes de elegir, y «lo entendido», que es el
//  reparto entre la gente del grupo y lleva a Nuevo gasto relleno (encargo del 2026-11-16).
//
//  Un recibo por vez: el reparto es de un gasto. De un PDF se lee la primera página.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct GroupPhotoCaptureView: View {
    @State private var model: GroupCaptureModel
    let onUse: (GroupExpensePrefillTemplate) -> Void
    let onManualEntry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var phrase = ""
    @FocusState private var phraseFocused: Bool
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var pickedItem: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var showUpgrade = false
    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .image
    /// La foto elegida mientras se pide el consentimiento de datos de IA.
    @State private var awaitingConsent: UIImage?
    @State private var showOtherPhotoConfirmation = false

    init(
        members: [SplitMember],
        currentMemberID: String?,
        currencyCode: String,
        onUse: @escaping (GroupExpensePrefillTemplate) -> Void,
        onManualEntry: (() -> Void)?
    ) {
        _model = State(initialValue: GroupCaptureModel(
            members: members, currentMemberID: currentMemberID, currencyCode: currencyCode))
        self.onUse = onUse
        self.onManualEntry = onManualEntry
    }

    private var isReview: Bool { model.phase == .review }

    private var sheetDetents: Set<PresentationDetent> {
        ImageEntrySheetHeightLogic.detents(showsSeveralToReview: isReview, dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            GroupCaptureHeader(showsClose: model.phase != .processing, closeIdentifier: "receipt_split_close") { dismiss() }
            content
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .dsAnimation(.easeInOut(duration: 0.25), value: model.phase, reduceMotion: reduceMotion)
        .yalaScreenBackground(
            ImageEntrySheetHeightLogic.background(
                detents: sheetDetents,
                selectedDetent: selectedDetent,
                usesLargeSheets: usesLargeSheets
            )
        )
        // El reparto no cabe a media altura: la hoja pasa a grande sola (decisión 80 de la revisión 2.3, como varios
        // registros en la foto de personal).
        .yalaSheetDetents(sheetDetents, selection: $selectedDetent)
        .onChange(of: isReview) { _, review in if review { selectedDetent = .large } }
        .growsSheetToLarge(when: isReview)
        .interactiveDismissDisabled(model.phase == .processing)
        .announcesEntryPhase(phaseAnnouncement)
        .asksBeforeDiscardingEntry(
            title: L10n.EntryDiscard.photoTitle,
            message: L10n.GruposCaptura.discardSplitMessage,
            isPresented: $showOtherPhotoConfirmation,
            onDiscard: chooseAnother
        )
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in loadPicked(item) }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false,
            onCompletion: importFile
        )
        .fullScreenCover(isPresented: $showCamera) {
            ImageCameraPicker(onFinish: cameraFinished)
                .ignoresSafeArea()
        }
        .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { _ in
            guard let image = awaitingConsent else { return }
            awaitingConsent = nil
            read(image)
        }
        .proUpgradeSheet(
            isPresented: $showUpgrade, feature: .imageInput, context: .proFeature,
            onManualEntry: { manualEntry() }
        ) {
            chooseAnother()
        }
        .onDisappear { model.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .starting, .listening:
            chooseContent
        case .processing:
            readingContent
        case .review:
            GroupReceiptReviewContent(
                model: model,
                againTitle: L10n.Image.Entry.otherPhoto,
                againIdentifier: "receipt_split_other_photo",
                onAgain: { showOtherPhotoConfirmation = true },
                onUse: use
            )
        case .failure(let failure):
            GroupCaptureFailureView(
                failure: failure,
                source: model.source,
                actions: GroupCaptureFailureActions(
                    tryAgainTitle: L10n.Image.Entry.otherPhoto,
                    onTryAgain: chooseAnother,
                    onClose: { dismiss() },
                    onManualEntry: manualEntry,
                    onSeePro: { showUpgrade = true },
                    onOpenSettings: GroupCaptureSystemSettings.open
                )
            )
        }
    }

    // MARK: - Elegir

    private var chooseContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.GruposCaptura.photoTitle)
                        .font(DS.Typography.title3)
                        .foregroundStyle(.thPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("group_photo_title")
                    Text(L10n.GruposCaptura.photoSubtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                sourceTiles

                // Lo propio del grupo: quién comió qué, antes de elegir, porque la foto se lee nada más elegirla.
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.ReceiptSplit.phraseLabel)
                        .font(DS.Typography.label)
                        .foregroundStyle(.thPrimaryText)
                    TextField(L10n.ReceiptSplit.phrasePlaceholder, text: $phrase, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($phraseFocused)
                        .padding(DS.Spacing.md)
                        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .accessibilityIdentifier("receipt_split_phrase")
                    Text(L10n.ReceiptSplit.phraseFooter)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DS.Spacing.xs)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_photo_choose")
    }

    /// Con texto de accesibilidad, una debajo de otra: tres en fila no caben (como personal).
    private var sourceTiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        let hasCamera = ImageCameraPicker.isAvailable
        return layout {
            if hasCamera {
                sourceTile(L10n.Image.Entry.camera, icon: "camera", isPrimary: true, identifier: "group_photo_source_camera") {
                    Task { await openCamera() }
                }
            }
            sourceTile(L10n.Image.Entry.photos, icon: "photo.on.rectangle", isPrimary: !hasCamera,
                       identifier: "group_photo_source_photos") {
                openPhotos()
            }
            sourceTile(L10n.Image.Entry.file, icon: "doc", isPrimary: false, identifier: "group_photo_source_file") {
                phraseFocused = false
                showFileImporter = true
            }
        }
    }

    /// La ficha de personal (`ImageSelectionView.sourceTile`).
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
                    .foregroundStyle(isPrimary ? theme.onAccent : theme.accentText)
                    .frame(width: 48, height: 48) // A11Y-DT: disco del icono de la fuente
                    .background(
                        Circle().fill(isPrimary ? theme.onAccent.opacity(0.18) : theme.accent.opacity(0.15))
                    )
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(isPrimary ? theme.onAccent : Color.primary)
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

    // MARK: - Leyendo

    private var readingContent: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xs) {
                Text(L10n.Image.Entry.readingOne)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.GruposCaptura.readingStep)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            if let image = model.readingPhoto {
                GroupCaptureReadingPhoto(image: image, accent: theme.accent, reduceMotion: reduceMotion)
                    .padding(.top, DS.Spacing.xs)
            }

            Spacer(minLength: DS.Spacing.lg)

            Button(L10n.Action.cancel) {
                model.reset()
            }
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .frame(minHeight: 48) // A11Y-DT: tap target de los botones de la hoja
            .accessibilityLabel(L10n.Image.Entry.cancelReading)
            .accessibilityIdentifier("receipt_split_cancel_reading")
        }
        .padding(.top, DS.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("receipt_split_reading")
    }

    private var phaseAnnouncement: String {
        switch model.phase {
        case .idle, .starting, .listening:
            return EntryPhaseFeedbackLogic.announcement(title: L10n.GruposCaptura.photoTitle)
        case .processing:
            return EntryPhaseFeedbackLogic.announcement(title: L10n.Image.Entry.readingOne)
        case .review:
            return EntryPhaseFeedbackLogic.announcement(title: L10n.ReceiptSplit.reviewTitle)
        case .failure(let failure):
            return GroupCaptureFailureText.announcement(failure, source: model.source)
        }
    }

    // MARK: - Fuentes

    private func openPhotos() {
        phraseFocused = false
        #if DEBUG
        if UITestHooks.receiptSplitProfile != nil, let example = UIImage(named: "ExampleImages/example-receipt-es") {
            requestRead(example)
            return
        }
        #endif
        pickedItem = nil
        showPhotosPicker = true
    }

    private func openCamera() async {
        phraseFocused = false
        if await ImageCameraPicker.requestAccess() {
            showCamera = true
        } else {
            model.failCamera()
        }
    }

    private func cameraFinished(_ image: UIImage?) {
        showCamera = false
        guard let image else { return }
        requestRead(PhotoIntake.image(reducing: image, maxEdge: PhotoIntake.currentIntakeMaxEdge()))
    }

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = PhotoIntake.image(from: data, maxEdge: PhotoIntake.currentIntakeMaxEdge()) {
                    requestRead(image)
                }
            } catch {
                #if DEBUG
                print("GroupPhotoCaptureView: Error loading picked photo: \(error)")
                #endif
            }
        }
    }

    /// Una imagen o la primera página de un PDF, como la ficha Archivo de personal.
    private func importFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard let image = Self.image(from: url) else {
                model.failToOpenFile()
                return
            }
            requestRead(image)
        case .failure(let error):
            #if DEBUG
            print("GroupPhotoCaptureView: Error importing file: \(error)")
            #endif
            model.failToOpenFile()
        }
    }

    private static func image(from url: URL) -> UIImage? {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            #if DEBUG
            print("GroupPhotoCaptureView: Error reading file: \(error)")
            #endif
            return nil
        }
        let maxEdge = PhotoIntake.currentIntakeMaxEdge()
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) == true {
            guard case .pages(let pages, _) = PDFPageImport.open(data, password: nil, room: 1),
                  let first = pages.first else { return nil }
            return PhotoIntake.image(reducing: first, maxEdge: maxEdge)
        }
        return PhotoIntake.image(from: data, maxEdge: maxEdge)
    }

    // MARK: - Leer

    /// El consentimiento de datos de IA es el mismo de foto y voz: sin él, se pide antes de la primera llamada.
    private func requestRead(_ image: UIImage) {
        guard appPreferences.aiDataConsentAccepted else {
            awaitingConsent = image
            pendingAIInput = .image
            showAIConsentAlert = true
            return
        }
        read(image)
    }

    private func read(_ image: UIImage) {
        phraseFocused = false
        model.readPhoto(image, phrase: phrase)
    }

    private func chooseAnother() {
        model.reset()
    }

    private func use() {
        guard let template = model.template() else { return }
        DS.Haptic.success()
        onUse(template)
        dismiss()
    }

    private func manualEntry() {
        onManualEntry?()
        dismiss()
    }
}
