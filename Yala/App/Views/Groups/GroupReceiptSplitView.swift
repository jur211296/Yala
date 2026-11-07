//
//  GroupReceiptSplitView.swift
//  Yala
//
//  «Desde un recibo», dentro de Nuevo gasto de un grupo (card «Grupos: repartir un recibo con IA», 2.3).
//
//  Foto del recibo (con una frase opcional de quién comió qué) o una nota de voz con las dos cosas. La IA lee las
//  líneas; la revisión deja cambiar quién paga cada una, incluir propina, servicio o impuestos con un atajo y quitar
//  líneas. «Usar este reparto» devuelve una plantilla con importes exactos por persona y el formulario de siempre la
//  aplica: el gasto se guarda como cualquier otro, sin líneas ni foto.
//
//  Propina, servicio e impuestos NO se reparten solos (Jürgen, 2026-11-05): llegan «sin incluir».
//

import PhotosUI
import SwiftUI

struct GroupReceiptSplitView: View {

    let members: [SplitMember]
    /// El miembro de quien usa la app, RESUELTO como lo resuelve el formulario (`currentUserMemberID`): el flag
    /// `isCurrentUser` llega apagado a quien entró por enlace hasta el siguiente arranque, y «yo» no casaría.
    let currentMemberID: String?
    let currencyCode: String
    let onUse: (GroupExpensePrefillTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    enum Phase: Equatable {
        case capture
        case recording
        case reading
        case review
        case failure(Failure)
    }

    enum Failure: Equatable {
        case read, noLines, noConnection, trialPhotos, trialVoice, busy, dailyLimit, camera, microphone, noVoice
    }

    @State private var phase: Phase = .capture
    @State private var photo: UIImage?
    @State private var phrase = ""
    @State private var lines: [ReceiptSplitLine] = []
    @State private var unmatchedNames: [String] = []
    @State private var merchant: String?
    @State private var readCurrency: String?
    @State private var printedTotal: Double?
    @State private var lastSource: PendingAIInput = .image
    @State private var readTask: Task<Void, Never>?
    @State private var recordTask: Task<Void, Never>?

    @State private var showCamera = false
    @State private var showPhotosPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var showUpgrade = false
    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .image

    @FocusState private var phraseFocused: Bool

    private var memberIDs: [String] { members.map(\.id.uuidString) }
    private var effectiveCurrency: String { readCurrency ?? currencyCode }

    var body: some View {
        NavigationStack {
            content
                .yalaScreenBackground(.subtle)
                .navigationTitle(phase == .review ? L10n.ReceiptSplit.reviewTitle : L10n.ReceiptSplit.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                            cancelAll()
                            dismiss()
                        }
                        .accessibilityIdentifier("receipt_split_close")
                    }
                }
        }
        .interactiveDismissDisabled(phase == .reading || phase == .recording)
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in loadPicked(item) }
        .fullScreenCover(isPresented: $showCamera) {
            ImageCameraPicker(onFinish: cameraFinished)
                .ignoresSafeArea()
        }
        .proUpgradeSheet(
            isPresented: $showUpgrade,
            feature: lastSource == .voice ? .voiceInput : .imageInput,
            context: .proFeature,
            // «Apuntarlo a mano» vuelve al formulario del gasto, que sigue con lo escrito (mejoras necesarias 2.3 · V3).
            onManualEntry: { dismiss() }
        ) {
            phase = .capture
        }
        .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { input in
            start(input)
        }
        .onDisappear { cancelAll() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .capture: captureView
        case .recording: recordingView
        case .reading: readingView
        case .review: reviewView
        case .failure(let failure): failureView(failure)
        }
    }

    // MARK: - Captura

    private var captureView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Label(L10n.ReceiptSplit.photoTitle, systemImage: "doc.text.viewfinder")
                        .font(DS.Typography.headline)
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("receipt_split_photo_preview")
                        sourceButtons(changing: true)
                    } else {
                        sourceButtons(changing: false)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L10n.ReceiptSplit.phraseLabel)
                            .font(DS.Typography.subheadlineEmphasized)
                        TextField(L10n.ReceiptSplit.phrasePlaceholder, text: $phrase, axis: .vertical)
                            .lineLimit(1...4)
                            .focused($phraseFocused)
                            .padding(DS.Spacing.md)
                            .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                            .accessibilityIdentifier("receipt_split_phrase")
                        Text(L10n.ReceiptSplit.phraseFooter)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    if photo != nil {
                        YalaPrimaryButton(L10n.ReceiptSplit.splitButton, icon: "sparkles") {
                            phraseFocused = false
                            requestRead(.image)
                        }
                        .accessibilityIdentifier("receipt_split_split")
                    }
                }
                .padding(DS.Spacing.lg)
                .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.lg))

                Button {
                    phraseFocused = false
                    requestRead(.voice)
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "mic.fill")
                            .font(DS.Typography.title3)
                            .foregroundStyle(theme.onAccent)
                            .frame(width: 44, height: 44)
                            .background(theme.accent, in: Circle())
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(L10n.ReceiptSplit.voiceTitle)
                                .font(DS.Typography.headline)
                                .foregroundStyle(.primary)
                            Text(L10n.ReceiptSplit.voiceHint)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: DS.Spacing.sm)
                    }
                    .padding(DS.Spacing.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                .accessibilityIdentifier("receipt_split_voice")
            }
            .padding(DS.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }

    private func sourceButtons(changing: Bool) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            if ImageCameraPicker.isAvailable {
                RecordPillButton(icon: "camera", text: L10n.ReceiptSplit.camera) {
                    Task { await openCamera() }
                }
                .accessibilityIdentifier("receipt_split_camera")
            }
            RecordPillButton(
                icon: "photo.on.rectangle",
                text: changing ? L10n.ReceiptSplit.changePhoto : L10n.ReceiptSplit.library
            ) {
                openPhotos()
            }
            .accessibilityIdentifier("receipt_split_library")
            Spacer(minLength: 0)
        }
    }

    // MARK: - Voz y lectura

    private var recordingView: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 48)) // A11Y-DT: icono decorativo
                .foregroundStyle(theme.accentText)
                .symbolEffect(.variableColor.iterative)
            Text(L10n.ReceiptSplit.listening)
                .font(DS.Typography.title3)
            Text(L10n.ReceiptSplit.voiceExample)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
            YalaPrimaryButton(L10n.ReceiptSplit.stopRecording, icon: "stop.fill") {
                finishRecording()
            }
            .accessibilityIdentifier("receipt_split_stop")
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    private var readingView: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
            Text(L10n.ReceiptSplit.reading)
                .font(DS.Typography.headline)
                .accessibilityIdentifier("receipt_split_reading")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Revisión

    private var items: [ReceiptSplitLine] { lines.filter { !$0.kind.isExtra } }
    private var extras: [ReceiptSplitLine] { lines.filter(\.kind.isExtra) }
    private var shares: [(memberID: String, amount: Double)] { ReceiptSplitLogic.shares(lines, memberIDs: memberIDs) }
    private var hasNegativeShare: Bool { shares.contains { $0.amount < 0 } }

    private var reviewView: some View {
        List {
            if !unmatchedNames.isEmpty {
                Section {
                    Label(
                        L10n.ReceiptSplit.unmatchedNames(unmatchedNames.formatted(.list(type: .and))),
                        systemImage: "person.fill.questionmark"
                    )
                    .font(DS.Typography.subheadline)
                    .accessibilityIdentifier("receipt_split_unmatched")
                }
            }

            Section {
                ForEach(items) { line in itemRow(line) }
                    .onDelete { offsets in delete(offsets, in: items) }
            } header: {
                Text(L10n.ReceiptSplit.linesSection)
            } footer: {
                Text(L10n.ReceiptSplit.linesFooter)
            }

            Section {
                ForEach(extras) { line in extraRow(line) }
                    .onDelete { offsets in delete(offsets, in: extras) }
                surchargeMenu
            } header: {
                Text(L10n.ReceiptSplit.extrasSection)
            } footer: {
                Text(L10n.ReceiptSplit.extrasFooter)
            }

            Section {
                ForEach(shares, id: \.memberID) { share in
                    HStack {
                        Text(memberName(share.memberID))
                        Spacer()
                        Text(money(share.amount))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("receipt_split_share_\(memberName(share.memberID))")
                }
                HStack {
                    Text(L10n.ReceiptSplit.total)
                        .font(DS.Typography.headline)
                    Spacer()
                    Text(money(ReceiptSplitLogic.total(lines)))
                        .font(DS.Typography.headline)
                        .monospacedDigit()
                        .accessibilityIdentifier("receipt_split_total")
                }
            } header: {
                Text(L10n.ReceiptSplit.perPersonSection)
            } footer: {
                if let mismatch = totalMismatch {
                    Text(mismatch)
                        .accessibilityIdentifier("receipt_split_total_mismatch")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            YalaPrimaryButton(
                L10n.ReceiptSplit.useSplit,
                isDisabled: shares.isEmpty || hasNegativeShare,
                disabledHint: hasNegativeShare ? L10n.ReceiptSplit.negativeShare : L10n.ReceiptSplit.nothingToSplit
            ) {
                use()
            }
            .accessibilityIdentifier("receipt_split_use")
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(.thBackground)
        }
    }

    private func itemRow(_ line: ReceiptSplitLine) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.description)
                    .font(DS.Typography.body)
                Spacer(minLength: DS.Spacing.sm)
                Text(money(line.amount))
                    .monospacedDigit()
            }
            Menu {
                Button {
                    setAssignees([], for: line.id)
                } label: {
                    if line.assignees.isEmpty {
                        Label(L10n.ReceiptSplit.everyone, systemImage: "checkmark")
                    } else {
                        Text(L10n.ReceiptSplit.everyone)
                    }
                }
                Section(L10n.ReceiptSplit.whoHadIt) {
                    ForEach(members, id: \.id) { member in
                        Button { toggle(member.id.uuidString, in: line.id) } label: {
                            if line.assignees.contains(member.id.uuidString) {
                                Label(member.displayName, systemImage: "checkmark")
                            } else {
                                Text(member.displayName)
                            }
                        }
                    }
                }
            } label: {
                peopleChip(
                    line.assignees.isEmpty ? L10n.ReceiptSplit.everyone : names(line.assignees),
                    flagged: line.needsReview
                )
            }
            .accessibilityIdentifier("receipt_split_people_\(line.description)")
        }
        .accessibilityIdentifier("receipt_split_line_\(line.description)")
    }

    private func extraRow(_ line: ReceiptSplitLine) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(line.description)
                        .font(DS.Typography.body)
                    Text(L10n.ReceiptSplit.kindLabel(line.kind))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text((line.kind == .discount ? "−" : "") + money(line.amount))
                    .monospacedDigit()
                    .foregroundStyle(line.isIncluded ? .primary : .secondary)
            }
            Menu {
                shareButton(.excluded, title: L10n.ReceiptSplit.shareExcluded, line: line)
                shareButton(.proportional, title: L10n.ReceiptSplit.shareProportional, line: line)
                shareButton(.equal, title: L10n.ReceiptSplit.shareEqual, line: line)
                Section(L10n.ReceiptSplit.sharePeople) {
                    ForEach(members, id: \.id) { member in
                        Button { toggleExtraPerson(member.id.uuidString, in: line.id) } label: {
                            if line.extraShare == .people, line.assignees.contains(member.id.uuidString) {
                                Label(member.displayName, systemImage: "checkmark")
                            } else {
                                Text(member.displayName)
                            }
                        }
                    }
                }
            } label: {
                peopleChip(extraChipText(line), muted: !line.isIncluded)
            }
            .accessibilityIdentifier("receipt_split_extra_\(line.description)")
        }
    }

    private func shareButton(_ share: ReceiptExtraShare, title: String, line: ReceiptSplitLine) -> some View {
        Button {
            update(line.id) { $0.extraShare = share; $0.assignees = [] }
        } label: {
            if line.extraShare == share {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    /// Atajos para lo que no venía en el recibo: propina o servicio a un porcentaje del consumo, eligiendo cómo se
    /// reparte (nunca uno por defecto).
    private var surchargeMenu: some View {
        Menu {
            surchargeOption(.tip, percent: 10)
            surchargeOption(.tip, percent: 15)
            surchargeOption(.service, percent: 10)
        } label: {
            Label(L10n.ReceiptSplit.addSurcharge, systemImage: "plus.circle")
        }
        .accessibilityIdentifier("receipt_split_add_surcharge")
    }

    private func surchargeOption(_ kind: ReceiptLineKind, percent: Int) -> some View {
        Menu(L10n.ReceiptSplit.surchargeTitle(kind: kind, percent: percent)) {
            Button(L10n.ReceiptSplit.shareProportional) { addSurcharge(kind, percent: percent, share: .proportional) }
            Button(L10n.ReceiptSplit.shareEqual) { addSurcharge(kind, percent: percent, share: .equal) }
        }
    }

    private func peopleChip(_ text: String, muted: Bool = false, flagged: Bool = false) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: flagged ? "person.fill.questionmark" : "person.2")
            Text(text)
                .lineLimit(2)
            Image(systemName: "chevron.up.chevron.down")
                .font(DS.Typography.caption)
        }
        .font(DS.Typography.caption)
        .foregroundStyle(muted ? Color.secondary : theme.accentText)
        .padding(.vertical, DS.Spacing.xxs)
        .contentShape(Rectangle())
    }

    private func extraChipText(_ line: ReceiptSplitLine) -> String {
        switch line.extraShare {
        case .excluded: L10n.ReceiptSplit.shareExcluded
        case .proportional: L10n.ReceiptSplit.shareProportional
        case .equal: L10n.ReceiptSplit.shareEqual
        case .people: line.assignees.isEmpty ? L10n.ReceiptSplit.shareExcluded : names(line.assignees)
        }
    }

    private var totalMismatch: String? {
        guard let printedTotal else { return nil }
        let read = ReceiptSplitLogic.readTotal(lines)
        guard abs(read - printedTotal) >= 0.01 else { return nil }
        return L10n.ReceiptSplit.printedTotalMismatch(printed: money(printedTotal), lines: money(read))
    }

    // MARK: - Fallos

    private func failureView(_ failure: Failure) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: failureIcon(failure))
                .font(.system(size: 44)) // A11Y-DT: icono decorativo
                .foregroundStyle(.secondary)
            Text(failureTitle(failure))
                .font(DS.Typography.title3)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("receipt_split_failure")
            Text(failureMessage(failure))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            if failure == .trialPhotos || failure == .trialVoice {
                YalaPrimaryButton(L10n.Voice.trialSeePro) { showUpgrade = true }
                    .accessibilityIdentifier("receipt_split_see_pro")
            } else {
                YalaPrimaryButton(L10n.Action.retry) { phase = .capture }
                    .accessibilityIdentifier("receipt_split_retry")
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
    }

    private func failureIcon(_ failure: Failure) -> String {
        switch failure {
        case .trialPhotos, .trialVoice: "sparkles"
        case .noConnection: "wifi.slash"
        case .camera: "camera"
        case .microphone, .noVoice: "mic.slash"
        default: "doc.text.magnifyingglass"
        }
    }

    private func failureTitle(_ failure: Failure) -> String {
        switch failure {
        case .read: L10n.ReceiptSplit.failureReadTitle
        case .noLines: L10n.ReceiptSplit.failureNoLinesTitle
        case .noConnection: L10n.Voice.failureNoConnectionTitle
        case .trialPhotos: L10n.Image.Entry.failureTrialUsedUpTitle
        case .trialVoice: L10n.Voice.failureTrialUsedUpTitle
        case .busy: L10n.Image.Entry.failureBusyTitle
        case .dailyLimit: lastSource == .voice ? L10n.Voice.failureDailyLimitTitle : L10n.Image.Entry.failureDailyLimitTitle
        case .camera: L10n.Image.Entry.failureCameraTitle
        case .microphone: L10n.Voice.failureMicTitle
        case .noVoice: L10n.Voice.failureNoVoiceTitle
        }
    }

    private func failureMessage(_ failure: Failure) -> String {
        switch failure {
        case .read: L10n.ReceiptSplit.failureReadMessage
        case .noLines: L10n.ReceiptSplit.failureNoLinesMessage
        case .noConnection: L10n.ReceiptSplit.failureNoConnectionMessage
        case .trialPhotos: L10n.Image.Entry.failureTrialUsedUpMessage
        case .trialVoice: L10n.Voice.failureTrialUsedUpMessage
        case .busy: L10n.Image.Entry.failureBusyMessage
        case .dailyLimit: lastSource == .voice ? L10n.Voice.failureDailyLimitMessage : L10n.Image.Entry.failureDailyLimitMessage
        case .camera: L10n.Image.Entry.failureCameraMessage
        case .microphone: L10n.ReceiptSplit.failureMicMessage
        case .noVoice: L10n.Voice.failureNoVoiceMessage
        }
    }

    // MARK: - Acciones

    private func openPhotos() {
        #if DEBUG
        if UITestHooks.receiptSplitProfile != nil {
            photo = UIImage(named: "ExampleImages/example-receipt-es")
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
            phase = .failure(.camera)
        }
    }

    private func cameraFinished(_ image: UIImage?) {
        showCamera = false
        if let image { photo = image }
    }

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = image
                }
            } catch {
                #if DEBUG
                print("GroupReceiptSplitView: Error loading picked photo: \(error)")
                #endif
            }
        }
    }

    /// El consentimiento de datos de IA es el mismo de foto y voz: sin él, se pide antes de la primera llamada.
    private func requestRead(_ input: PendingAIInput) {
        guard appPreferences.aiDataConsentAccepted else {
            pendingAIInput = input
            showAIConsentAlert = true
            return
        }
        start(input)
    }

    private func start(_ input: PendingAIInput) {
        lastSource = input
        switch input {
        case .image: readPhoto()
        case .voice: recordTask = Task { await startRecording() }
        }
    }

    private func startRecording() async {
        #if DEBUG
        if UITestHooks.receiptSplitProfile != nil {
            phase = .recording
            return
        }
        #endif
        guard await AudioRecorderService.shared.requestMicrophonePermission() else {
            phase = .failure(.microphone)
            return
        }
        do {
            try await AudioRecorderService.shared.startRecording()
            // Cerrada la hoja mientras arrancaba el audio: el micrófono no se queda abierto sin pantalla.
            guard !Task.isCancelled else {
                AudioRecorderService.shared.cancelRecording()
                return
            }
            phase = .recording
        } catch {
            #if DEBUG
            print("GroupReceiptSplitView: Error starting recording: \(error)")
            #endif
            phase = .failure(.microphone)
        }
    }

    private func finishRecording() {
        phase = .reading
        readTask = Task {
            #if DEBUG
            if let profile = UITestHooks.receiptSplitProfile {
                await applyUITestReply(profile, source: .voice)
                return
            }
            #endif
            do {
                let audio = try await AudioRecorderService.shared.stopRecording()
                let transcription = try await VoiceTranscriptionService.shared.transcribe(
                    audioData: audio,
                    language: appPreferences.voiceLanguage
                )
                let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Un audio vacío que el modelo «transcribe» con relleno no trae importes: lo para `noLines` del servicio.
                guard !text.isEmpty else {
                    phase = .failure(.noVoice)
                    return
                }
                let response = try await ReceiptSplitService.shared.readNote(text: text, currency: currencyContext)
                apply(response)
            } catch {
                handle(error, source: .voice)
            }
        }
    }

    private func readPhoto() {
        guard let photo else { return }
        phase = .reading
        let currentPhrase = phrase
        readTask = Task {
            #if DEBUG
            if let profile = UITestHooks.receiptSplitProfile {
                await applyUITestReply(profile, source: .image)
                return
            }
            #endif
            do {
                let response = try await ReceiptSplitService.shared.readPhoto(
                    image: photo,
                    phrase: currentPhrase,
                    currency: currencyContext
                )
                apply(response)
            } catch {
                handle(error, source: .image)
            }
        }
    }

    private var currencyContext: VisionCurrencyContext {
        VisionCurrencyContext(mainCurrency: currencyCode, accountCurrencies: [currencyCode])
    }

    private func apply(_ response: ReceiptSplitResponse) {
        guard !Task.isCancelled else { return }
        let draft = ReceiptSplitDraftLogic.draft(from: response, members: matcherMembers)
        lines = draft.lines
        unmatchedNames = draft.unmatchedNames
        merchant = response.merchant
        readCurrency = response.currency.flatMap { CurrencyCode(rawValue: $0) != nil ? $0 : nil }
        printedTotal = response.printedTotal
        phase = .review
        DS.Haptic.success()
    }

    private func handle(_ error: Error, source: PendingAIInput) {
        guard !Task.isCancelled else { return }
        #if DEBUG
        print("GroupReceiptSplitView: Error: \(error)")
        #endif
        phase = .failure(Self.failure(for: error, source: source, isConnected: NetworkMonitor.shared.isConnected))
        DS.Haptic.error()
    }

    /// Qué fallo enseñar: lo que el gateway contestó con nombre propio va con su texto (el de foto o el de voz).
    static func failure(for error: Error, source: PendingAIInput, isConnected: Bool) -> Failure {
        let inner: Error
        switch error {
        case ReceiptSplitError.noLines: return .noLines
        case ReceiptSplitError.emptyNote: return .noVoice
        case ReceiptSplitError.network(let wrapped): inner = wrapped
        case TranscriptionError.networkError(let wrapped): inner = wrapped
        case TranscriptionError.emptyAudio: return .noVoice
        default: return isConnected ? .read : .noConnection
        }
        if ProxyErrorMapper.isTrialExhausted(inner) { return source == .voice ? .trialVoice : .trialPhotos }
        if ProxyErrorMapper.isDailyLimitReached(inner) { return .dailyLimit }
        if ProxyErrorMapper.isBurstLimited(inner) { return .busy }
        return isConnected ? .read : .noConnection
    }

    private var matcherMembers: [ReceiptPeopleMatcher.Member] {
        members.map {
            ReceiptPeopleMatcher.Member(id: $0.id.uuidString, name: $0.displayName, isCurrentUser: $0.id.uuidString == currentMemberID)
        }
    }

    private func use() {
        let description = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let template = ReceiptSplitLogic.template(
            lines: lines,
            memberIDs: memberIDs,
            currencyCode: effectiveCurrency,
            description: description,
            date: .now
        ) else { return }
        DS.Haptic.success()
        onUse(template)
        dismiss()
    }

    private func cancelAll() {
        readTask?.cancel()
        recordTask?.cancel()
        if AudioRecorderService.shared.state == .recording { AudioRecorderService.shared.cancelRecording() }
    }

    // MARK: - Edición de líneas

    private func update(_ id: UUID, _ change: (inout ReceiptSplitLine) -> Void) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        change(&lines[index])
        DS.Haptic.selection()
    }

    private func setAssignees(_ ids: Set<String>, for lineID: UUID) {
        update(lineID) { $0.assignees = ids; $0.needsReview = false }
    }

    private func toggle(_ memberID: String, in lineID: UUID) {
        update(lineID) { line in
            line.needsReview = false
            if line.assignees.contains(memberID) { line.assignees.remove(memberID) } else { line.assignees.insert(memberID) }
        }
    }

    private func toggleExtraPerson(_ memberID: String, in lineID: UUID) {
        update(lineID) { line in
            if line.extraShare != .people { line.extraShare = .people; line.assignees = [] }
            if line.assignees.contains(memberID) { line.assignees.remove(memberID) } else { line.assignees.insert(memberID) }
        }
    }

    private func delete(_ offsets: IndexSet, in section: [ReceiptSplitLine]) {
        let ids = Set(offsets.map { section[$0].id })
        lines.removeAll { ids.contains($0.id) }
        DS.Haptic.warning()
    }

    private func addSurcharge(_ kind: ReceiptLineKind, percent: Int, share: ReceiptExtraShare) {
        let line = ReceiptSplitLogic.surcharge(
            kind: kind,
            percent: percent,
            description: L10n.ReceiptSplit.surchargeTitle(kind: kind, percent: percent),
            share: share,
            lines: lines
        )
        lines.append(line)
        DS.Haptic.selection()
    }

    // MARK: - Formato

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: effectiveCurrency, forceFullPrecision: true)
    }

    private func memberName(_ id: String) -> String {
        members.first { $0.id.uuidString == id }?.displayName ?? ""
    }

    private func names(_ ids: Set<String>) -> String {
        members.filter { ids.contains($0.id.uuidString) }.map(\.displayName).formatted(.list(type: .and))
    }

    // MARK: - UI test

    #if DEBUG
    /// Lo que «lee» la hoja sin red con `-uitest-receipt-split`: una cena de cinco platos con «Tú», Ana y Beto.
    private func applyUITestReply(_ profile: String, source: PendingAIInput) async {
        do {
            try await Task.sleep(for: .milliseconds(1500))
        } catch {
            return
        }
        if profile == "trial" {
            handle(ReceiptSplitError.network(ProxyErrorMapper.trialExhaustedResponse()), source: source)
            return
        }
        apply(Self.uiTestCuscoResponse)
    }

    static let uiTestCuscoResponse = ReceiptSplitResponse(
        merchant: "Cusco Grill",
        currency: "PEN",
        printedTotal: 180.30,
        lines: [
            .init(description: "Lomo saltado", amount: 38, kind: "item", people: ["Ana"]),
            .init(description: "Ají de gallina", amount: 32, kind: "item", people: ["Beto"]),
            .init(description: "Pizza familiar", amount: 48, kind: "item", people: ["@me", "Ana"]),
            .init(description: "Jarra de chicha", amount: 18, kind: "item", people: []),
            .init(description: "Cuy al horno", amount: 28, kind: "item", people: ["Carla"]),
            .init(description: "Servicio 10 %", amount: 16.30, kind: "service", people: []),
        ]
    )
    #endif
}
