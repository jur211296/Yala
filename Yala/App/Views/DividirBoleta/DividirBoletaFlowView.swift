//
//  DividirBoletaFlowView.swift
//  Yala
//
//  La hoja de «Dividir una boleta» (maqueta 1A, decisión de Jürgen del 26-nov-2026): foto → ¿entre quiénes? → revisión →
//  resultado con quién pagó, la imagen para compartir y mi parte. Una sola hoja con pasos, sin presentaciones
//  encadenadas. Se abre desde la hoja de foto personal y desde Grupos; ninguno de los dos crea un grupo ni guarda personas.
//
//  Mi parte (solo en Yala completo) es un borrador de la Bandeja: «Registrar mi parte» abre su editor empujado dentro de
//  esta misma hoja (el molde de «Ver todo» de la foto personal) y aprobarlo lo registra; «o mándala a la Bandeja» lo deja
//  ahí. Un borrador por boleta: tocar los dos no lo duplica.
//

import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DividirBoletaFlowView: View {
    /// Yala completo: se puede registrar mi parte. En «solo grupos», solo ver y compartir.
    let allowsRegistering: Bool
    /// «Listo»: la persona terminó. Quien abrió la hoja puede cerrar también la suya.
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    @State private var model: DividirBoletaModel

    @State private var pickedItem: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var showUpgrade = false
    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .image

    @State private var shareItem: DividirBoletaShareItem?

    @State private var myDraft: InboxDraft?
    @State private var editingDraft: InboxDraft?
    @State private var registration: DividirBoletaRegistration = .none

    init(currencyCode: String, allowsRegistering: Bool, onFinished: @escaping () -> Void) {
        _model = State(initialValue: DividirBoletaModel(meName: L10n.DividirBoleta.whoMe, currencyCode: currencyCode))
        self.allowsRegistering = allowsRegistering
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            NavigationStack {
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent }
                    .yalaScreenBackground(.subtle)
            }
            .opacity(editingDraft == nil ? 1 : 0)
            .allowsHitTesting(editingDraft == nil)
            .accessibilityHidden(editingDraft != nil)

            if let editingDraft {
                InboxDraftEditSheet(draft: editingDraft, onBack: closeEditor)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .dsAnimation(DS.Animation.appear, value: model.step, reduceMotion: reduceMotion)
        .interactiveDismissDisabled(model.isReading || editingDraft != nil)
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
            model.split()
        }
        .proUpgradeSheet(isPresented: $showUpgrade, feature: .imageInput, context: .proFeature)
        .sheet(item: $shareItem, onDismiss: { shareItem = nil }) { item in
            ActivityView(activityItems: [item.image], completion: { _ in shareItem = nil })
        }
        .onChange(of: model.summary?.myShareCents) { _, cents in keepDraftInStep(with: cents) }
        .onDisappear { model.cancelReading() }
    }

    // MARK: - Pasos

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .source:
            DividirBoletaSourceStep(
                onCamera: { Task { await openCamera() } },
                onPhotos: openPhotos,
                onFile: { showFileImporter = true }
            )
        case .who:
            switch model.readPhase {
            case .reading:
                DividirBoletaReadingStep(photo: model.photo, onCancel: model.cancelReading)
            case .failure(let failure):
                GroupCaptureFailureView(
                    failure: failure,
                    source: .photo,
                    actions: failureActions(failure)
                )
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)
            case .idle, .read:
                DividirBoletaWhoStep(model: model, onSplit: requestRead)
            }
        case .manualTotal:
            DividirBoletaManualTotalStep(currencyCode: model.effectiveCurrency) { model.useManualTotal($0) }
        case .review:
            DividirBoletaReviewStep(model: model) { model.step = .result }
        case .result:
            DividirBoletaResultStep(
                model: model,
                allowsRegistering: allowsRegistering,
                registration: registration,
                onShare: { shareItem = DividirBoletaShareItem(image: $0) },
                onRegister: register,
                onSendToInbox: sendToInbox
            )
        }
    }

    private var title: String {
        switch model.step {
        case .source, .who, .manualTotal: L10n.DividirBoleta.entryTitle
        case .review: L10n.DividirBoleta.reviewTitle
        case .result: L10n.DividirBoleta.resultTitle
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if model.step == .source || model.isReading {
                YalaToolbarButton(systemName: "xmark", label: L10n.DividirBoleta.close) { dismiss() }
                    .accessibilityIdentifier("dividir_boleta_close")
            } else {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.DividirBoleta.back) { goBack() }
                    .accessibilityIdentifier("dividir_boleta_back")
            }
        }
        if model.step == .result {
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarTextButton(L10n.DividirBoleta.resultDone) { finish() }
                    .accessibilityIdentifier("dividir_boleta_done")
            }
        }
    }

    private func goBack() {
        switch model.step {
        case .source: dismiss()
        case .who: model.chooseAnotherPhoto()
        case .manualTotal: model.step = .who
        case .review: model.step = model.photo == nil ? .manualTotal : .who
        case .result: model.step = .review
        }
    }

    private func finish() {
        DS.Haptic.success()
        onFinished()
        dismiss()
    }

    // MARK: - Fallo

    private func failureActions(_ failure: GroupCaptureFailure) -> GroupCaptureFailureActions {
        let retriesSamePhoto = failure == .noConnection || failure == .busy
        return GroupCaptureFailureActions(
            tryAgainTitle: retriesSamePhoto ? L10n.Action.retry : L10n.Image.Entry.otherPhoto,
            onTryAgain: { retriesSamePhoto ? model.split() : model.chooseAnotherPhoto() },
            onClose: { dismiss() },
            onManualEntry: { model.startManualTotal() },
            onSeePro: { showUpgrade = true },
            onOpenSettings: GroupCaptureSystemSettings.open
        )
    }

    // MARK: - Leer

    /// El permiso de datos de IA es el de foto y voz: sin él, se pide antes de la primera lectura.
    private func requestRead() {
        guard appPreferences.aiDataConsentAccepted || model.readPhase == .read else {
            pendingAIInput = .image
            showAIConsentAlert = true
            return
        }
        model.split()
    }

    // MARK: - Fuentes

    private func openPhotos() {
        #if DEBUG
        if UITestHooks.receiptSplitProfile != nil, let example = UIImage(named: "ExampleImages/example-receipt-es") {
            model.choosePhoto(example)
            return
        }
        #endif
        pickedItem = nil
        showPhotosPicker = true
    }

    private func openCamera() async {
        if await ImageCameraPicker.requestAccess() {
            showCamera = true
        } else {
            model.failCamera()
        }
    }

    private func cameraFinished(_ image: UIImage?) {
        showCamera = false
        guard let image else { return }
        model.choosePhoto(PhotoIntake.image(reducing: image, maxEdge: PhotoIntake.currentIntakeMaxEdge()))
    }

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = PhotoIntake.image(from: data, maxEdge: PhotoIntake.currentIntakeMaxEdge()) {
                    model.choosePhoto(image)
                }
            } catch {
                #if DEBUG
                print("DividirBoletaFlowView: Error loading picked photo: \(error)")
                #endif
            }
        }
    }

    /// Una imagen o la primera página de un PDF, como la ficha Archivo de personal.
    private func importFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, let image = Self.image(from: url) else {
                model.failToOpenFile()
                return
            }
            model.choosePhoto(image)
        case .failure(let error):
            #if DEBUG
            print("DividirBoletaFlowView: Error importing file: \(error)")
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
            print("DividirBoletaFlowView: Error reading file: \(error)")
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

    // MARK: - Mi parte

    /// El borrador de mi parte: el mismo si ya se creó y sigue pendiente; si no, uno nuevo. `nil` si no se pudo guardar.
    private func draftForMyShare() -> InboxDraft? {
        if let myDraft, !myDraft.isDeleted, myDraft.modelContext != nil, myDraft.status == .pending { return myDraft }
        guard let cents = model.summary?.myShareCents,
              let draft = DividirBoletaLogic.myShareDraft(
                myShareCents: cents,
                merchant: model.merchant,
                fallbackNote: L10n.DividirBoleta.resultMerchantFallback,
                currencyCode: model.effectiveCurrency,
                date: .now
              ) else { return nil }
        modelContext.insert(draft)
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("DividirBoletaFlowView: Error saving my share draft: \(error)")
            #endif
            modelContext.delete(draft)
            return nil
        }
        myDraft = draft
        return draft
    }

    private func register() {
        guard let draft = draftForMyShare() else {
            registration = .failed
            DS.Haptic.error()
            return
        }
        dsWithAnimation(reduceMotion) { editingDraft = draft }
    }

    private func sendToInbox() {
        guard draftForMyShare() != nil else {
            registration = .failed
            DS.Haptic.error()
            return
        }
        registration = .inInbox
        DS.Haptic.success()
    }

    /// ‹ del editor (o lo que lo cierra: aprobar, descartar). Aprobado o borrado ⇒ registrada; pendiente ⇒ en la Bandeja.
    private func closeEditor() {
        let draft = editingDraft
        let gone = draft.map { $0.isDeleted || $0.modelContext == nil } ?? true
        if gone || reduceMotion {
            editingDraft = nil
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { editingDraft = nil }
        }
        if gone {
            // Borrarlo desde el editor es descartarlo: mi parte ya no está en ninguna parte.
            registration = draft?.status == .approved ? .registered : .none
            myDraft = nil
        } else if draft?.status == .approved {
            registration = .registered
        } else {
            registration = .inInbox
        }
    }

    /// Si se vuelve a la revisión y cambia mi parte, el borrador que sigue pendiente se corrige: la Bandeja no puede
    /// guardar un importe que ya no es el de la boleta.
    private func keepDraftInStep(with cents: Int?) {
        guard let myDraft, !myDraft.isDeleted, myDraft.modelContext != nil, myDraft.status == .pending,
              let cents, let amount = DividirBoletaLogic.draftAmount(myShareCents: cents) else { return }
        myDraft.amount = amount
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("DividirBoletaFlowView: Error updating my share draft: \(error)")
            #endif
        }
    }
}

/// La imagen que se manda al menú de compartir.
struct DividirBoletaShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}
