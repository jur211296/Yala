//
//  VoiceRecordingView.swift
//  Yala
//
//  El registro por voz (propuesta C, elegida por Jürgen el 2026-10-04): una hoja que ya escucha al abrirse y que, al
//  terminar, enseña lo entendido como la fila del registro para guardarlo ahí mismo.
//
//  Cuatro fases en la misma hoja, sin presentaciones encadenadas:
//  1. **Escuchando** — el orbe del dictado de Yala IA (`VoiceListeningOrb`), el tiempo y Cancelar / Listo.
//  2. **Procesando** — el orbe gira y dice el paso; Cancelar cierra.
//  3. **Lo entendido** — una `VoiceDraftReviewCard` por borrador. «Guardar» los aprueba por el camino de la Bandeja
//     (`DraftService.approveDraft`); cerrar sin guardar los deja en la Bandeja, como siempre.
//  4. **Fallo** — qué pasó en lenguaje de usuario y una salida (`VoiceEntryFailure`).
//
//  Sin pantalla de reposo ni cuenta atrás: Cancelar hace lo que hacía la cuenta atrás (arrepentirse antes de procesar).
//

import SwiftData
import SwiftUI

struct VoiceRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.yalaTheme) private var theme
    @Environment(VoiceTranscriptionService.self) private var voiceTranscriptionService
    @Environment(TranscriptionParserService.self) private var transcriptionParserService
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(CurrencyConverter.self) private var currencyConverter

    @State private var recorder = AudioRecorderService.shared
    @State private var networkMonitor = NetworkMonitor.shared

    @State private var phase: Phase = .starting
    @State private var processingStep = 0
    @State private var recordedDuration: TimeInterval = 0
    @State private var pendingAudioData: Data?
    @State private var processingTask: Task<Void, Never>?
    @State private var drafts: [InboxDraft] = []
    @State private var transcription = ""
    @State private var detailDraft: InboxDraft?
    @State private var saveFailed = false
    @State private var trialReported = false
    @State private var selectedDetent: PresentationDetent = .medium

    /// Para cambiar a la entrada por imagen cuando no hay conexión.
    var onSwitchToImage: (() -> Void)?

    /// Práctica guiada: se llama cuando el paso se cumple (borrador creado o aprobado), con el ID del registro, su
    /// nombre y su tipo (`.transaction` si se aprobó, `.draft` si quedó en la Bandeja).
    var onSetupTrialCompleted: ((PersistentIdentifier, String, PracticeItemKind) -> Void)?

    /// Práctica guiada: «Ahora no».
    var onSetupTrialSkipped: (() -> Void)?

    private enum Phase: Equatable {
        /// Pidiendo el micro: se ve como escuchando, con Listo apagado.
        case starting
        case listening
        case processing
        case review
        case failure(VoiceEntryFailure)
    }

    private let buttonHeight: CGFloat = 48 // A11Y-DT: tap target de los botones de la hoja

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
        .interactiveDismissDisabled(isBusy)
        .task { await startListening() }
        .onDisappear(perform: tearDown)
        .sheet(item: $detailDraft, onDismiss: afterDetails) { draft in
            InboxDraftEditSheet(draft: draft)
        }
    }

    private var isBusy: Bool {
        phase == .starting || phase == .listening || phase == .processing
    }

    private var isSetupTrial: Bool { onSetupTrialCompleted != nil }

    // MARK: - Cabecera

    /// Cerrar solo cuando no hay un Cancelar abajo; «Ahora no» de la práctica, mientras no haya nada que revisar.
    private var header: some View {
        HStack {
            if let skip = onSetupTrialSkipped, phase != .review, phase != .processing {
                Button(L10n.SetupChecklist.skipStep) {
                    recorder.cancelRecording()
                    skip()
                    dismiss()
                }
                .font(DS.Typography.label)
                .frame(minHeight: 44)
            }
            Spacer()
            if phase == .review || isFailure {
                YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                    dismiss()
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("voice_close")
            }
        }
        .frame(minHeight: 44)
        .padding(.top, DS.Spacing.md)
    }

    private var isFailure: Bool {
        if case .failure = phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .starting, .listening:
            listeningContent
        case .processing:
            processingContent
        case .review:
            reviewContent
        case .failure(let failure):
            failureContent(failure)
        }
    }

    // MARK: - Escuchando

    private var listeningContent: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xs) {
                Text(L10n.Chat.listening)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                Text(L10n.Chat.voiceHint)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            VoiceListeningOrb(
                isTranscribing: false,
                duration: recorder.recordingDuration,
                level: recorder.audioLevel,
                accent: theme.accent,
                reduceMotion: reduceMotion
            )
            .padding(.top, DS.Spacing.sm)

            Spacer(minLength: DS.Spacing.lg)

            HStack(spacing: DS.Spacing.md) {
                secondaryButton(L10n.Action.cancel, identifier: "voice_cancel", action: cancelListening)
                    .accessibilityLabel(L10n.Accessibility.discardRecording)
                primaryButton(L10n.Action.done, isEnabled: phase == .listening, identifier: "voice_done") {
                    Task { await finishListening() }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice_listening_panel")
    }

    // MARK: - Procesando

    private var processingContent: some View {
        VStack(spacing: DS.Spacing.md) {
            Text(processingTitle)
                .font(DS.Typography.title3)
                .foregroundStyle(.thPrimaryText)
                .contentTransition(.opacity)

            VoiceListeningOrb(
                isTranscribing: true,
                duration: recordedDuration,
                level: 0,
                accent: theme.accent,
                reduceMotion: reduceMotion
            )
            .padding(.top, DS.Spacing.sm)

            Spacer(minLength: DS.Spacing.lg)

            Button(L10n.Action.cancel, action: cancelProcessing)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: buttonHeight)
                .accessibilityLabel(L10n.Accessibility.cancelProcessing)
                .accessibilityIdentifier("voice_cancel_processing")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice_processing")
    }

    private var processingTitle: String {
        switch processingStep {
        case 0: L10n.Chat.transcribing
        case 1: L10n.Voice.understanding
        default: L10n.Voice.preparing
        }
    }

    // MARK: - Lo entendido

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
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(reviewTitle)
                            .font(DS.Typography.title3)
                            .foregroundStyle(.thPrimaryText)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("voice_review_title")
                        if !transcription.isEmpty {
                            Text(transcription)
                                .font(DS.Typography.subheadline)
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(drafts, id: \.persistentModelID) { draft in
                        VoiceDraftReviewCard(draft: draft) {
                            detailDraft = draft
                        }
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
                    primaryButton(L10n.Action.done, isEnabled: true, identifier: "voice_finish") {
                        dismiss()
                    }
                } else {
                    secondaryButton(L10n.Voice.recordAgain, identifier: "voice_record_again", action: recordAgain)
                    primaryButton(saveTitle, isEnabled: canSave, identifier: "voice_save", action: saveAll)
                }
            }
        }
        .padding(.top, DS.Spacing.xs)
    }

    private var reviewTitle: String {
        if allSaved { return L10n.Chat.Draft.savedBadge }
        return drafts.count > 1 ? L10n.Voice.reviewTitleMany(drafts.count) : L10n.Voice.reviewTitle
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

    private func failureContent(_ failure: VoiceEntryFailure) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: failureIcon(failure))
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.warningForeground)
                .frame(width: 72, height: 72) // A11Y-DT: disco del icono del fallo
                .background(Circle().fill(DS.Semantic.warningBackground))
                .accessibilityHidden(true)
                .padding(.top, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.xs) {
                Text(failureTitle(failure))
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("voice_failure_title")
                Text(failureMessage(failure))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: DS.Spacing.lg)

            HStack(spacing: DS.Spacing.md) {
                failureActions(failure)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("voice_failure")
    }

    @ViewBuilder
    private func failureActions(_ failure: VoiceEntryFailure) -> some View {
        switch failure {
        case .micPermission:
            primaryButton(L10n.Voice.openSettings, isEnabled: true, identifier: "voice_open_settings", action: openSystemSettings)
        case .serviceUnavailable:
            primaryButton(L10n.Action.close, isEnabled: true, identifier: "voice_failure_close") { dismiss() }
        case .noConnection:
            if let switchToImage = onSwitchToImage {
                secondaryButton(L10n.Voice.tryImage, identifier: "voice_try_image") {
                    dismiss()
                    switchToImage()
                }
            }
            primaryButton(L10n.Voice.recordAgain, isEnabled: true, identifier: "voice_record_again", action: recordAgain)
        case .noVoice, .noAmount:
            primaryButton(L10n.Voice.recordAgain, isEnabled: true, identifier: "voice_record_again", action: recordAgain)
        case .generic, .saveFailed:
            if failure.retriesSameAudio, pendingAudioData != nil {
                secondaryButton(L10n.Voice.recordAgain, identifier: "voice_record_again", action: recordAgain)
                primaryButton(L10n.Action.retry, isEnabled: true, identifier: "voice_retry", action: retryProcessing)
            } else {
                primaryButton(L10n.Voice.recordAgain, isEnabled: true, identifier: "voice_record_again", action: recordAgain)
            }
        }
    }

    private func failureIcon(_ failure: VoiceEntryFailure) -> String {
        switch failure {
        case .noConnection: "wifi.slash"
        case .micPermission: "mic.slash"
        case .noVoice: "waveform.slash"
        case .noAmount: "questionmark"
        case .serviceUnavailable, .saveFailed, .generic: "exclamationmark"
        }
    }

    private func failureTitle(_ failure: VoiceEntryFailure) -> String {
        switch failure {
        case .noConnection: L10n.Voice.failureNoConnectionTitle
        case .micPermission: L10n.Voice.failureMicTitle
        case .noVoice: L10n.Voice.failureNoVoiceTitle
        case .noAmount: L10n.Voice.failureNoAmountTitle
        case .serviceUnavailable, .saveFailed, .generic: L10n.Voice.failureGenericTitle
        }
    }

    private func failureMessage(_ failure: VoiceEntryFailure) -> String {
        switch failure {
        case .noConnection: L10n.Voice.errorNoConnection
        case .micPermission: L10n.Voice.errorMicPermission
        case .noVoice: L10n.Voice.failureNoVoiceMessage
        case .noAmount: L10n.Voice.failureNoAmountMessage
        case .serviceUnavailable: L10n.Voice.errorNoApiKey
        case .saveFailed: L10n.Voice.errorSaveFailed
        case .generic: L10n.Voice.failureGenericMessage
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

    // MARK: - Grabar

    private func startListening() async {
        saveFailed = false
        guard networkMonitor.isConnected else {
            phase = .failure(.noConnection)
            return
        }
        phase = .starting
        #if DEBUG
        if UITestHooks.voiceResult != nil {
            phase = .listening
            return
        }
        #endif
        do {
            try await recorder.startRecording()
            phase = .listening
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch let error as RecordingError {
            phase = .failure(VoiceEntryFlowLogic.failure(for: error))
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error starting recording: \(error)")
            #endif
            phase = .failure(.generic)
        }
    }

    private func finishListening() async {
        recordedDuration = recorder.recordingDuration
        #if DEBUG
        if UITestHooks.voiceResult != nil {
            startProcessing(Data())
            return
        }
        #endif
        do {
            let audioData = try await recorder.stopRecording()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            pendingAudioData = audioData
            startProcessing(audioData)
        } catch let error as RecordingError {
            phase = .failure(VoiceEntryFlowLogic.failure(for: error))
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error stopping recording: \(error)")
            #endif
            phase = .failure(.generic)
        }
    }

    /// Cancelar mientras escucha descarta sin transcribir y cierra: no hay otra cosa que hacer en esta hoja.
    private func cancelListening() {
        recorder.cancelRecording()
        dismiss()
    }

    /// Lo que se borra al grabar otra vez son los borradores pendientes de ESTA grabación: si se quedaran, la Bandeja
    /// acabaría con el mismo gasto dos veces. Los ya guardados no se tocan.
    private func recordAgain() {
        for draft in pendingDrafts {
            modelContext.delete(draft)
        }
        if !pendingDrafts.isEmpty {
            do {
                try modelContext.save()
            } catch {
                #if DEBUG
                print("VoiceRecordingView: Error discarding drafts to record again: \(error)")
                #endif
            }
        }
        drafts = []
        transcription = ""
        pendingAudioData = nil
        Task { await startListening() }
    }

    // MARK: - Procesar

    private func startProcessing(_ audioData: Data) {
        processingStep = 0
        phase = .processing
        processingTask = Task {
            await processAudio(audioData)
        }
    }

    private func retryProcessing() {
        guard let audioData = pendingAudioData else { return }
        startProcessing(audioData)
    }

    /// Cancelar a media transcripción cierra la hoja: la petición en curso termina sola y su resultado se ignora.
    private func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
        dismiss()
    }

    private func processAudio(_ audioData: Data) async {
        do {
            let (text, parsedTransactions) = try await understand(audioData)
            guard !Task.isCancelled else { return }

            let validTransactions = parsedTransactions.filter { $0.amount != nil }
            guard !validTransactions.isEmpty else {
                phase = .failure(.noAmount)
                return
            }

            // Foto de los pendientes ANTES de crear los nuevos, para que el auto-insert de SwiftData no se cuele en la
            // deduplicación.
            let existingDrafts = fetchPendingDrafts()

            processingStep = 2
            let newDrafts = validTransactions.map { parsed in
                createInboxDraft(from: parsed, transcription: text, insertInContext: false)
            }
            let uniqueDrafts = DraftDeduplicationService.deduplicate(newDrafts: newDrafts, existingDrafts: existingDrafts)
            // Si todos parecen duplicados, son los propios (SwiftData pudo insertarlos ya).
            let created = uniqueDrafts.isEmpty ? newDrafts : uniqueDrafts
            for draft in created {
                modelContext.insert(draft)
            }
            do {
                try modelContext.save()
            } catch {
                #if DEBUG
                print("VoiceRecordingView: Error saving drafts: \(error)")
                #endif
                phase = .failure(.saveFailed)
                return
            }

            pendingAudioData = nil
            // La práctica guiada es de UN registro: se revisa el primero; los demás quedan en la Bandeja, como antes.
            drafts = isSetupTrial ? Array(created.prefix(1)) : created
            transcription = text
            phase = .review
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let error as TranscriptionError {
            phase = .failure(VoiceEntryFlowLogic.failure(for: error, isConnected: networkMonitor.isConnected))
        } catch let error as ParserError {
            phase = .failure(VoiceEntryFlowLogic.failure(for: error, isConnected: networkMonitor.isConnected))
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error processing audio: \(error)")
            #endif
            phase = .failure(VoiceEntryFlowLogic.failure(forUnknownErrorWhenConnected: networkMonitor.isConnected))
        }
    }

    /// Transcribe y lee el audio: el texto dicho y los registros que contiene.
    private func understand(_ audioData: Data) async throws -> (text: String, parsed: [ParsedTransaction]) {
        #if DEBUG
        if let profile = UITestHooks.voiceResult {
            return uiTestResult(profile)
        }
        #endif
        processingStep = 0
        let result = try await voiceTranscriptionService.transcribe(
            audioData: audioData,
            language: appPreferences.voiceLanguage
        )
        guard !Task.isCancelled else { return (result.text, []) }

        processingStep = 1
        let (expenseSubcategories, incomeSubcategories) = fetchSubcategoryNames()
        let parsed = try await transcriptionParserService.parseMultiple(
            text: result.text,
            expenseSubcategories: expenseSubcategories,
            incomeSubcategories: incomeSubcategories
        )
        return (result.text, parsed)
    }

    #if DEBUG
    /// `-uitest-voice-result`: lo que la hoja «entiende» sin red, resuelto contra los datos sembrados para que la
    /// cuenta y la subcategoría casen (la divisa principal si hay una cuenta en ella; Restaurantes si existe).
    private func uiTestResult(_ profile: String) -> (text: String, parsed: [ParsedTransaction]) {
        let currency = fetchFirstActiveAccountCurrency()
        let expenseNames = fetchSubcategoryNames().expense.sorted()
        let subcategory = expenseNames.first { $0.hasPrefix("Restaurant") } ?? expenseNames.first
        let confidence = ParsedTransaction.TransactionConfidence(amount: 1, date: 1, merchant: 1, subcategory: 1, tags: 1)
        func expense(_ note: String, _ amount: Decimal, subcategory: String?) -> ParsedTransaction {
            ParsedTransaction(
                amount: amount, date: Date.now, note: note, isExpense: true, subcategoryHint: subcategory,
                tagHints: [], currencyHint: currency, confidence: confidence
            )
        }
        switch profile {
        case "incomplete":
            return ("Almuerzo 25 con la tarjeta", [expense("Almuerzo", 25, subcategory: nil)])
        case "two":
            return (
                "Taxi 12 y café 8 con la tarjeta",
                [expense("Taxi", 12, subcategory: subcategory), expense("Café", 8, subcategory: subcategory)]
            )
        default:
            return ("Almuerzo 25 con la tarjeta", [expense("Almuerzo", 25, subcategory: subcategory)])
        }
    }

    private func fetchFirstActiveAccountCurrency() -> String? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { account in account.isArchived == false && account.isSystemAccount == false },
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            let codes = try modelContext.fetch(descriptor).map(\.currencyCode)
            let preferred = appPreferences.defaultCurrencyCode.rawValue
            return codes.contains(preferred) ? preferred : codes.first
        } catch {
            print("VoiceRecordingView: Error fetching accounts for the UI-test seam: \(error)")
            return nil
        }
    }
    #endif

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
                print("VoiceRecordingView: Error approving draft: \(error)")
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
        if drafts.isEmpty {
            dismiss()
        }
    }

    // MARK: - Práctica guiada y cierre

    private func reportTrial(id: PersistentIdentifier, name: String, kind: PracticeItemKind) {
        guard let callback = onSetupTrialCompleted, !trialReported else { return }
        trialReported = true
        callback(id, name, kind)
    }

    /// Al cerrar: suelta el micro si seguía abierto, corta lo que se estuviera procesando y, en la práctica guiada, da
    /// el paso por cumplido con el borrador que quedó en la Bandeja.
    private func tearDown() {
        if recorder.state == .recording {
            recorder.cancelRecording()
        }
        processingTask?.cancel()
        processingTask = nil
        if let pending = pendingDrafts.first {
            reportTrial(id: pending.persistentModelID, name: pending.note, kind: .draft)
        }
    }

    // MARK: - Borradores

    private func createInboxDraft(from parsed: ParsedTransaction, transcription: String, insertInContext: Bool = true) -> InboxDraft {
        // Importe con signo: negativo es gasto.
        var amountDouble: Double?
        if let amount = parsed.amount {
            let value = NSDecimalNumber(decimal: amount).doubleValue
            amountDouble = parsed.isExpense ? -abs(value) : abs(value)
        }

        var matchedAccount: Account?
        var needsUserInputFields = ["account", "subcategory"]

        if let currencyHint = parsed.currencyHint, !currencyHint.isEmpty {
            matchedAccount = findAccount(byCurrency: currencyHint)
            if matchedAccount != nil {
                needsUserInputFields.removeAll { $0 == "account" }
            }
        }

        var matchedSubcategory: Subcategory?
        if let hint = parsed.subcategoryHint, !hint.isEmpty {
            matchedSubcategory = findSubcategory(matching: hint, isExpense: parsed.isExpense)
            if matchedSubcategory != nil {
                needsUserInputFields.removeAll { $0 == "subcategory" }
            }
        }

        // Memoria del comercio: sugiere la subcategoría si el modelo no la encontró.
        if matchedSubcategory == nil && !parsed.note.trimmingCharacters(in: .whitespaces).isEmpty {
            let merchantService = MerchantMemoryService(modelContext: modelContext)
            switch merchantService.suggest(for: parsed.note) {
            case .suggest(let sub), .autoAssign(let sub):
                matchedSubcategory = sub
                needsUserInputFields.removeAll { $0 == "subcategory" }
            case .none:
                break
            }
        }

        var matchedTags: [Tag] = []
        var newlyCreatedTagNames: [String] = []
        if !parsed.tagHints.isEmpty {
            let result = findTags(matching: parsed.tagHints)
            matchedTags = result.tags
            newlyCreatedTagNames = result.newlyCreatedNames
        }

        let draft = InboxDraft(
            note: parsed.note,
            amount: amountDouble,
            date: parsed.date,
            account: matchedAccount,
            subcategory: matchedSubcategory,
            tags: matchedTags,
            sourceType: .voice,
            rawText: transcription,
            confidenceAmount: parsed.confidence.amount,
            confidenceDate: parsed.confidence.date,
            confidenceMerchant: parsed.confidence.merchant,
            confidenceSubcategory: matchedSubcategory != nil ? parsed.confidence.subcategory : nil,
            needsUserInput: needsUserInputFields,
            newlyCreatedTagNames: newlyCreatedTagNames
        )
        if insertInContext {
            modelContext.insert(draft)
        }
        return draft
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
            print("VoiceRecordingView: Error fetching pending drafts: \(error)")
            #endif
            return []
        }
    }

    /// Los nombres de las subcategorías visibles, separados en gasto e ingreso, para que el modelo elija entre ellas.
    private func fetchSubcategoryNames() -> (expense: [String], income: [String]) {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { subcategory in
                subcategory.isVisible == true
            }
        )
        let subcategories: [Subcategory]
        do {
            subcategories = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching subcategory names: \(error)")
            #endif
            return ([], [])
        }
        let expenseNames = subcategories.filter { !$0.safeCategory.isIncome }.map(\.name)
        let incomeNames = subcategories.filter { $0.safeCategory.isIncome }.map(\.name)
        return (expenseNames, incomeNames)
    }

    // MARK: - Emparejar con lo que ya existe

    /// Minúsculas, sin espacios a los lados y sin tildes.
    private func normalizeForMatching(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    /// La subcategoría que coincide con la pista (exacta, luego parcial en los dos sentidos). Si hay más de una, nil:
    /// que elija el usuario.
    private func findSubcategory(matching hint: String, isExpense: Bool) -> Subcategory? {
        let normalizedHint = normalizeForMatching(hint)
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { subcategory in
                subcategory.isVisible == true
            }
        )
        let subcategories: [Subcategory]
        do {
            subcategories = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching subcategories for matching: \(error)")
            #endif
            return nil
        }

        let filtered = subcategories.filter { sub in
            isExpense ? !sub.safeCategory.isIncome : sub.safeCategory.isIncome
        }

        let exactMatches = filtered.filter { normalizeForMatching($0.name) == normalizedHint }
        if exactMatches.count == 1 { return exactMatches.first }
        if exactMatches.count > 1 { return nil }

        let partialMatches = filtered.filter { normalizeForMatching($0.name).contains(normalizedHint) }
        if partialMatches.count == 1 { return partialMatches.first }
        if partialMatches.count > 1 { return nil }

        let reverseMatches = filtered.filter { normalizedHint.contains(normalizeForMatching($0.name)) }
        if reverseMatches.count == 1 { return reverseMatches.first }
        return nil
    }

    /// Las etiquetas que coinciden con las pistas; las que no existen se crean.
    private func findTags(matching hints: [String]) -> (tags: [Tag], newlyCreatedNames: [String]) {
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { tag in
                tag.isActive == true
            }
        )
        let allTags: [Tag]
        do {
            allTags = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching tags: \(error)")
            #endif
            return ([], [])
        }

        var matched: [Tag] = []
        var newlyCreatedNames: [String] = []
        var usedColors = allTags.map { $0.colorHex }

        for hint in hints {
            let normalizedHint = normalizeForMatching(hint)
            guard !normalizedHint.isEmpty else { continue }

            if let exact = allTags.first(where: { normalizeForMatching($0.name) == normalizedHint }) {
                if !matched.contains(where: { $0.persistentModelID == exact.persistentModelID }) {
                    matched.append(exact)
                }
                continue
            }
            if let partial = allTags.first(where: { normalizeForMatching($0.name).contains(normalizedHint) }) {
                if !matched.contains(where: { $0.persistentModelID == partial.persistentModelID }) {
                    matched.append(partial)
                }
                continue
            }

            let capitalizedName = hint.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
            let nextColor = Tag.nextAvailableColor(excluding: usedColors)
            let newTag = Tag(name: capitalizedName, colorHex: nextColor)
            usedColors.append(nextColor)
            modelContext.insert(newTag)
            matched.append(newTag)
            newlyCreatedNames.append(capitalizedName)
        }

        return (matched, newlyCreatedNames)
    }

    /// La cuenta de esa divisa, solo si hay exactamente una.
    private func findAccount(byCurrency currencyCode: String) -> Account? {
        let normalizedCode = currencyCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { account in
                account.isArchived == false
            }
        )
        let accounts: [Account]
        do {
            accounts = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("VoiceRecordingView: Error fetching accounts: \(error)")
            #endif
            return nil
        }
        let matches = accounts.filter { $0.currencyCode.uppercased() == normalizedCode }
        return matches.count == 1 ? matches.first : nil
    }
}

#Preview {
    VoiceRecordingView()
        .previewAppPreferences()
}
