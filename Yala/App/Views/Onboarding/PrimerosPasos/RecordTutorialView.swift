//
//  RecordTutorialView.swift
//  Yala
//
//  Y23-08 y Y23-09 · Paso 2 de Primeros pasos, «Aprender a registrar» (prototipo oficial v35, pestaña 4 · Nuevo
//  registro). La página «Cuatro maneras de anotar» (cuatro partes, 3,4 s) y, entre una manera y otra, una pantalla con
//  las cuatro (hecha / omitida / la que sigue), lo ya anotado y «Probar …» / «Omitir». Cada manera abre su pantalla de
//  HOY: el formulario con la guía de foco (`NewTransactionView` + `NewRecordTutorialGuide`), la voz, la foto y Yala IA,
//  estas tres como prueba de cortesía (una vez gratis; después vuelve el candado). Todo se puede omitir. Al terminar se
//  cierra y el Panel pregunta «¿Borramos los de prueba?» (Y23-10).
//

import SwiftData
import SwiftUI

struct RecordTutorialView: View {
    typealias Method = RecordTutorialLogic.Method

    /// Se cerró: terminado (todas resueltas u «Omitir este paso») o solo cerrado para seguir luego.
    let onClose: (_ finished: Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var session = RecordTutorialSession.shared
    @State private var showsIntro = true
    @State private var introPart = 0

    // Las pantallas de cada manera.
    @State private var showsManual = false
    @State private var showsVoice = false
    @State private var showsPhoto = false
    @State private var showsChat = false
    @State private var showsAIConsent = false
    @State private var pendingAIInput: PendingAIInput = .voice
    @State private var showsChatConsent = false
    @State private var exampleImages: [UIImage]?

    private typealias T = L10n.PrimerosPasos23.Record

    var body: some View {
        ZStack {
            if showsIntro && !session.hasStarted {
                introPage.transition(.opacity)
            } else {
                betweenPage.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: showsIntro)
        .yalaScreenBackground(.panel)
        .sheet(isPresented: $showsManual, onDismiss: { settle(.manual) }) {
            NewTransactionView(showsTutorialGuide: true) { ids in
                guard let first = ids.first else { return }
                // Una transferencia guarda dos patas: van juntas, para que «Borrar» no deje una huérfana.
                session.recordSaved(.manual, id: first, additionalIDs: Array(ids.dropFirst()))
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showsVoice, onDismiss: { endTrial(.voice) }) {
            VoiceRecordingView(
                onSwitchToImage: nil,
                onSetupTrialCompleted: { id, _, kind in session.recordSaved(.voice, id: id, isDraft: kind == .draft) },
                onSetupTrialSkipped: { session.skip(.voice) },
                courtesyTrialText: T.trialVoice,
                onCourtesyExtraDrafts: { ids in session.addExtraDrafts(.voice, ids: ids) }
            )
        }
        .sheet(isPresented: $showsPhoto, onDismiss: { endTrial(.photo) }) {
            ImageSelectionView(
                exampleImages: exampleImages,
                onSetupTrialCompleted: { id, _, kind, additional in
                    session.recordSaved(.photo, id: id, isDraft: kind == .draft, additionalIDs: additional)
                },
                onSetupTrialSkipped: { session.skip(.photo) },
                courtesyTrialText: T.trialPhoto,
                onCourtesyExtraDrafts: { ids in session.addExtraDrafts(.photo, ids: ids) }
            )
        }
        .sheet(isPresented: $showsChat, onDismiss: { endTrial(.ai) }) {
            ChatSheetView(courtesyTrial: ChatCourtesyTrial(
                onSkip: {
                    session.skip(.ai)
                    showsChat = false
                },
                onSaved: { id in session.recordSaved(.ai, id: id) }
            ))
        }
        // «Yala lo apunta por ti» antes de voz o foto, una vez (Y23-17). «Ahora no» omite esa manera.
        .aiConsentAlert(isPresented: $showsAIConsent, pendingInput: $pendingAIInput) { input in
            openAfterConsent(input == .voice ? .voice : .photo)
        }
        // Lo aceptado se lee de `UserDefaults`, como el Panel: `AppPreferences` se refresca una vuelta después del aviso
        // y, leído de ahí, una aceptación recién hecha parecía un «Ahora no» (review del lote).
        .onChange(of: showsAIConsent) { _, showing in
            guard !showing, !UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) else { return }
            let method: Method = pendingAIInput == .voice ? .voice : .photo
            FeatureGateService.shared.disableSetupTrial(for: method == .voice ? .voiceInput : .imageInput)
            session.skip(method)
        }
        .chatConsentAlert(isPresented: $showsChatConsent) {
            showsChat = true
        }
        .onChange(of: showsChatConsent) { _, showing in
            guard !showing, !UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiChatConsentAccepted) else { return }
            FeatureGateService.shared.disableSetupTrial(for: .chatAssistant)
            session.skip(.ai)
        }
    }

    // MARK: - Cuatro maneras de anotar

    private var introPage: some View {
        TutorialStoryPage(
            eyebrow: T.introEyebrow,
            count: 4,
            part: $introPart,
            onBack: { closeWithoutFinishing() },
            content: { index in introPart(index) },
            footer: {
                VStack(spacing: DS.Spacing.xs) {
                    YalaPrimaryButton(T.startManual) {
                        showsIntro = false
                        start(.manual)
                    }
                    .accessibilityIdentifier("record_tutorial_start_manual")
                    .primerosPasosButtonText()
                    Button(T.skipStep) {
                        session.skipAll()
                        onClose(true)
                    }
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("record_tutorial_skip_step")
                }
            }
        )
    }

    private func introPart(_ index: Int) -> some View {
        let method = Method.allCases[min(index, 3)]
        return VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.sm) {
                methodIcon(method, size: 44)
                if method.isCourtesyTrial {
                    Text(verbatim: "PRO")
                        .font(DS.Typography.captionSmall.weight(.bold))
                        .foregroundStyle(theme.onAccent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Capsule().fill(theme.accent))
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(Self.title(method))
                    .font(DS.Typography.welcomeHeadline)
                    .accessibilityAddTraits(.isHeader)
                Text(Self.introMessage(method))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if method.isCourtesyTrial {
                    Text(T.tryFreeOnce)
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.thAccentText)
                }
            }
        }
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Entre una manera y la siguiente

    private var betweenPage: some View {
        let next = session.nextMethod
        return VStack(spacing: DS.Spacing.md) {
            HStack {
                YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { closeWithoutFinishing() }
                    .accessibilityIdentifier("record_tutorial_close")
                Spacer()
                Text(L10n.SetupChecklist.Deck.counter(2, SetupStepID.deck.count))
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    methodsRow(next: next)
                    Text(headline)
                        .font(DS.Typography.welcomeHeadline)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("record_tutorial_headline")
                    if !session.records.isEmpty {
                        VStack(spacing: DS.Spacing.sm) {
                            ForEach(session.records) { record in
                                TutorialRecordRow(record: record)
                            }
                        }
                    }
                    if let next {
                        nextCard(next)
                    }
                }
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            VStack(spacing: DS.Spacing.xs) {
                if let next {
                    YalaPrimaryButton(Self.tryTitle(next)) { start(next) }
                        .accessibilityIdentifier("record_tutorial_try")
                    .primerosPasosButtonText()
                    Button(T.skip) { session.skip(next) }
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.thAccentText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("record_tutorial_skip")
                } else {
                    YalaPrimaryButton(T.goToPanel) { onClose(true) }
                        .accessibilityIdentifier("record_tutorial_finish")
                    .primerosPasosButtonText()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private var headline: String {
        switch RecordTutorialLogic.betweenHeadline(recordCount: session.records.count) {
        case .firstRecord: return T.firstRecord
        case .records(let count): return T.records(count)
        case .keepGoing: return T.keepGoing
        }
    }

    private func methodsRow(next: Method?) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(Method.allCases, id: \.self) { method in
                let state = session.state(of: method)
                VStack(spacing: DS.Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(state == .done ? Color(hex: Self.colorHex(method)) : theme.card)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().strokeBorder(
                                method == next ? Color(hex: Self.colorHex(method)) : .clear, lineWidth: 2))
                        Image(systemName: state == .done ? "checkmark" : Self.icon(method))
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(state == .done ? Color.white : Color(hex: Self.colorHex(method)))
                    }
                    .opacity(state == .skipped ? 0.4 : 1)
                    // Sin límite de líneas: con texto grande, partir en dos antes que cortar (ficha).
                    Text(Self.shortName(method))
                        .font(DS.Typography.caption)
                        .foregroundStyle(state == .skipped ? .tertiary : .secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.shortName(method) + ", " + Self.stateLabel(state, isNext: method == next))
            }
        }
    }

    private func nextCard(_ method: Method) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                methodIcon(method, size: 36)
                Text(verbatim: "PRO")
                    .font(DS.Typography.captionSmall.weight(.bold))
                    .foregroundStyle(theme.onAccent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Capsule().fill(theme.accent))
                    .opacity(method.isCourtesyTrial ? 1 : 0)
            }
            Text(Self.nowTitle(method)).font(DS.Typography.headline)
            Text(Self.nextMessage(method))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if method.isCourtesyTrial {
                Text(T.courtesyOnce)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.thAccentText)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(theme.card))
        .accessibilityElement(children: .combine)
    }

    private func methodIcon(_ method: Method, size: CGFloat) -> some View {
        Image(systemName: Self.icon(method))
            .font(DS.Typography.headline)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(Color(hex: Self.colorHex(method))))
            .accessibilityHidden(true)
    }

    // MARK: - Abrir cada manera

    /// Cerrar sin terminar. Si todavía no se probó ninguna manera, el paso 2 no queda retenido: un registro hecho por
    /// otro camino lo cierra como siempre (review del lote: retenerlo desde la página corta dejaba el Panel en la
    /// llegada tranquila para siempre). Si ya se probó alguna, se retoma donde iba.
    private func closeWithoutFinishing() {
        if !session.hasStarted { SetupChecklistManager.shared.cancelRecordTutorial() }
        onClose(false)
    }

    private func start(_ method: Method) {
        DS.Haptic.selection()
        // El paso 2 se retiene desde que se prueba la primera manera (`SetupChecklistManager.isRecordTutorialRunning`).
        session.begin()
        switch method {
        case .manual:
            showsManual = true
        case .voice:
            FeatureGateService.shared.enableSetupTrial(for: .voiceInput)
            if appPreferences.aiDataConsentAccepted {
                showsVoice = true
            } else {
                pendingAIInput = .voice
                showsAIConsent = true
            }
        case .photo:
            FeatureGateService.shared.enableSetupTrial(for: .imageInput)
            exampleImages = Self.loadExampleImages()
            if appPreferences.aiDataConsentAccepted {
                showsPhoto = true
            } else {
                pendingAIInput = .image
                showsAIConsent = true
            }
        case .ai:
            FeatureGateService.shared.enableSetupTrial(for: .chatAssistant)
            if appPreferences.aiChatConsentAccepted {
                showsChat = true
            } else {
                showsChatConsent = true
            }
        }
    }

    private func openAfterConsent(_ method: Method) {
        if method == .voice { showsVoice = true } else { showsPhoto = true }
    }

    /// Al cerrarse una prueba de cortesía vuelve el candado; si no se apuntó nada, la manera queda omitida.
    private func endTrial(_ method: Method) {
        switch method {
        case .voice: FeatureGateService.shared.disableSetupTrial(for: .voiceInput)
        case .photo:
            FeatureGateService.shared.disableSetupTrial(for: .imageInput)
            exampleImages = nil
        case .ai: FeatureGateService.shared.disableSetupTrial(for: .chatAssistant)
        case .manual: break
        }
        settle(method)
    }

    /// Cerrar sin apuntar es omitir esa manera (como la X del prototipo).
    private func settle(_ method: Method) {
        if session.state(of: method) == .pending { session.skip(method) }
    }

    // MARK: - Textos y colores por manera

    static func title(_ method: Method) -> String {
        switch method {
        case .manual: return T.manualTitle
        case .voice: return T.voiceTitle
        case .photo: return T.photoTitle
        case .ai: return T.aiTitle
        }
    }

    static func introMessage(_ method: Method) -> String {
        switch method {
        case .manual: return T.manualMessage
        case .voice: return T.voiceMessage
        case .photo: return T.photoMessage
        case .ai: return T.aiMessage
        }
    }

    static func shortName(_ method: Method) -> String {
        switch method {
        case .manual: return T.manualShort
        case .voice: return T.voiceShort
        case .photo: return T.photoShort
        case .ai: return L10n.Chat.assistantName
        }
    }

    static func nowTitle(_ method: Method) -> String {
        switch method {
        case .manual: return T.manualTitle
        case .voice: return T.nowVoice
        case .photo: return T.nowPhoto
        case .ai: return T.nowAI
        }
    }

    static func nextMessage(_ method: Method) -> String {
        switch method {
        case .manual: return T.manualMessage
        case .voice: return T.nextVoice
        case .photo: return T.nextPhoto
        case .ai: return T.nextAI
        }
    }

    static func tryTitle(_ method: Method) -> String {
        switch method {
        case .manual: return T.startManual
        case .voice: return T.tryVoice
        case .photo: return T.tryPhoto
        case .ai: return T.tryAI
        }
    }

    static func stateLabel(_ state: RecordTutorialLogic.MethodState, isNext: Bool) -> String {
        switch state {
        case .done: return T.stateDone
        case .skipped: return T.stateSkipped
        case .pending: return isNext ? T.stateNext : T.statePending
        }
    }

    static func icon(_ method: Method) -> String {
        switch method {
        case .manual: return "hand.point.up.left.fill"
        case .voice: return "mic.fill"
        case .photo: return "camera.fill"
        case .ai: return "sparkles"
        }
    }

    /// Los colores del prototipo oficial (v35) para cada manera.
    static func colorHex(_ method: Method) -> String {
        switch method {
        case .manual: return "#6063F1"
        case .voice: return "#FF4DA6"
        case .photo: return "#00C2CB"
        case .ai: return "#F59E0B"
        }
    }

    /// El recibo de ejemplo de la app (y los otros dos ejemplos, por si la pantalla de foto los pide), en el idioma de la
    /// app.
    static func loadExampleImages() -> [UIImage]? {
        let supportedLangs: Set<String> = ["de", "en", "es", "fr", "it", "pt"]
        let lang = LanguageManager.baseLanguageCode(of: Bundle.main.preferredLocalizations.first ?? "en")
        let suffix = supportedLangs.contains(lang) ? lang : "en"
        let images = [
            "ExampleImages/example-receipt-\(suffix)",
            "ExampleImages/example-bank-alert-\(suffix)",
            "ExampleImages/example-transaction-list-\(suffix)",
        ].compactMap { UIImage(named: $0) }
        return images.isEmpty ? nil : images
    }
}

// MARK: - Una fila de lo anotado

/// Un registro del tutorial con su categoría, su importe y la manera con que se anotó.
struct TutorialRecordRow: View {
    let record: RecordTutorialRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        let item = TutorialRecordLookup.transaction(record, in: modelContext)
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: item?.subcategory?.iconName ?? RecordTutorialView.icon(record.method))
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(item?.subcategory.map { Color(hex: $0.safeCategory.colorHex) }
                    ?? Color(hex: RecordTutorialView.colorHex(record.method))))
            VStack(alignment: .leading, spacing: 0) {
                Text(TutorialRecordLookup.title(record, item: item, in: modelContext))
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(TutorialRecordLookup.caption(record, item: item))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Spacing.sm)
            if let item {
                Text(appPreferences.currency(abs(item.amount), currencyCode: item.currencyCode))
                    .font(DS.Typography.subheadline.weight(.semibold))
            }
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        .accessibilityElement(children: .combine)
    }
}

/// Lee el registro (o el borrador de la Bandeja) que apunta un registro del tutorial. Por id y con un fetch: un
/// `model(for:)` fabricaría un objeto aunque ya no existiera.
@MainActor
enum TutorialRecordLookup {
    static func transaction(_ record: RecordTutorialRecord, in context: ModelContext) -> TransactionItem? {
        guard !record.isDraft else { return nil }
        let id = record.persistentID
        var descriptor = FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first.flatMap { $0.isDeleted ? nil : $0 }
        } catch {
            #if DEBUG
            print("TutorialRecordLookup: Error: reading the tutorial record: \(error)")
            #endif
            return nil
        }
    }

    static func draft(_ record: RecordTutorialRecord, in context: ModelContext) -> InboxDraft? {
        guard record.isDraft else { return nil }
        let id = record.persistentID
        var descriptor = FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first.flatMap { $0.isDeleted ? nil : $0 }
        } catch {
            #if DEBUG
            print("TutorialRecordLookup: Error: reading the tutorial draft: \(error)")
            #endif
            return nil
        }
    }

    static func title(_ record: RecordTutorialRecord, item: TransactionItem?, in context: ModelContext) -> String {
        if let note = item?.note, !note.isEmpty { return note }
        if let name = item?.subcategory?.name { return name }
        if let draft = draft(record, in: context), !draft.note.isEmpty { return draft.note }
        return RecordTutorialView.title(record.method)
    }

    static func caption(_ record: RecordTutorialRecord, item: TransactionItem?) -> String {
        let via = RecordTutorialView.shortName(record.method)
        guard let sub = item?.subcategory?.name else {
            return record.isDraft ? via + " · " + L10n.PrimerosPasos23.Record.inInbox : via
        }
        return sub + " · " + via
    }
}
