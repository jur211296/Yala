//
//  GroupCaptureModel.swift
//  Yala
//
//  El motor de Voz, Foto y Yala IA dentro de un grupo (encargo «Grupos: voz, foto y Yala IA idénticos a personal»,
//  2026-11-16). Las tres hojas de Grupos se ven como las de personal y comparten este motor: lo que oyen, ven o leen va
//  al reparto por líneas del recibo (`ReceiptSplitService`, tareas `receipt.*`, cupo diario de Grupos sin candado) y
//  termina en Nuevo gasto relleno. Antes vivía dentro de `GroupReceiptSplitView`.
//

import Observation
import SwiftUI

/// Lo que sale mal al leer un recibo de grupo, en lenguaje de usuario.
enum GroupCaptureFailure: Equatable {
    case read, noLines, noConnection, trialPhotos, trialVoice, busy, dailyLimit, camera, microphone, noVoice
    /// Los recibos del día de Free, gastados: mañana vuelven y Yala Pro da más.
    case dailyLimitFree
    /// El archivo elegido no se pudo abrir (PDF dañado, con contraseña o sin páginas).
    case unreadableFile
}

/// Qué está haciendo la hoja. Las mismas fases que la voz y la foto de personal.
enum GroupCapturePhase: Equatable {
    case idle
    /// Pidiendo el micrófono: se ve como escuchando, con Listo apagado.
    case starting
    case listening
    case processing
    case review
    case failure(GroupCaptureFailure)
}

/// Cómo llegó lo que se leyó: decide el texto de algunos fallos y el «Volver a…» de la revisión.
enum GroupCaptureSource: Equatable {
    case voice, photo, text
}

@MainActor
@Observable
final class GroupCaptureModel {
    let members: [SplitMember]
    /// El miembro de quien usa la app, RESUELTO como lo resuelve el formulario (`currentUserMemberID`).
    let currentMemberID: String?
    let currencyCode: String

    private(set) var phase: GroupCapturePhase = .idle
    /// 0 transcribiendo · 1 entendiendo · 2 preparando, como la voz de personal.
    private(set) var processingStep = 0
    private(set) var source: GroupCaptureSource = .voice
    /// Lo que se oyó o se escribió, para enseñarlo en la revisión como en personal.
    private(set) var heard = ""
    /// La foto que se está leyendo.
    private(set) var readingPhoto: UIImage?
    private(set) var recordedDuration: TimeInterval = 0

    var lines: [ReceiptSplitLine] = []
    private(set) var unmatchedNames: [String] = []
    private(set) var merchant: String?
    private(set) var readCurrency: String?
    private(set) var printedTotal: Double?

    private var task: Task<Void, Never>?

    init(members: [SplitMember], currentMemberID: String?, currencyCode: String) {
        self.members = members
        self.currentMemberID = currentMemberID
        self.currencyCode = currencyCode
    }

    var memberIDs: [String] { members.map(\.id.uuidString) }
    var effectiveCurrency: String { readCurrency ?? currencyCode }
    var isBusy: Bool { phase == .starting || phase == .listening || phase == .processing }

    // MARK: - Voz

    /// Empieza a escuchar. Sin conexión no graba: lo dice antes, como personal.
    func startListening(isConnected: Bool) async {
        source = .voice
        guard isConnected else {
            fail(.noConnection)
            return
        }
        phase = .starting
        #if DEBUG
        if UITestHooks.receiptSplitProfile != nil {
            phase = .listening
            return
        }
        #endif
        guard await AudioRecorderService.shared.requestMicrophonePermission() else {
            fail(.microphone)
            return
        }
        do {
            try await AudioRecorderService.shared.startRecording()
            phase = .listening
            DS.Haptic.medium()
        } catch {
            #if DEBUG
            print("GroupCaptureModel: Error starting recording: \(error)")
            #endif
            fail(.microphone)
        }
    }

    /// «Listo»: para la grabación, la transcribe con la tarea de recibos y la lee.
    func finishListening(duration: TimeInterval, language: VoiceLanguage) {
        recordedDuration = duration
        processingStep = 0
        phase = .processing
        task = Task {
            #if DEBUG
            if let profile = UITestHooks.receiptSplitProfile {
                heard = Self.uiTestHeard
                await uiTestReply(profile)
                return
            }
            #endif
            do {
                let audio = try await AudioRecorderService.shared.stopRecording()
                DS.Haptic.light()
                let transcription = try await VoiceTranscriptionService.shared.transcribe(
                    audioData: audio,
                    language: language,
                    task: .receiptTranscribe
                )
                let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Un audio vacío que el modelo «transcribe» con relleno no trae importes: lo para `noLines` del servicio.
                guard !text.isEmpty else {
                    fail(.noVoice)
                    return
                }
                heard = text
                processingStep = 1
                let response = try await ReceiptSplitService.shared.readNote(text: text, currency: currencyContext)
                apply(response)
            } catch {
                handle(error)
            }
        }
    }

    /// Cancelar mientras escucha: se descarta sin transcribir.
    func cancelListening() {
        if AudioRecorderService.shared.state == .recording { AudioRecorderService.shared.cancelRecording() }
        phase = .idle
    }

    // MARK: - Foto

    /// Lee la foto nada más elegirla, como personal. `phrase` es el «¿quién comió qué?» opcional.
    func readPhoto(_ image: UIImage, phrase: String) {
        source = .photo
        readingPhoto = image
        heard = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        processingStep = 1
        phase = .processing
        let currentPhrase = phrase
        task = Task {
            #if DEBUG
            if let profile = UITestHooks.receiptSplitProfile {
                await uiTestReply(profile)
                return
            }
            #endif
            do {
                let response = try await ReceiptSplitService.shared.readPhoto(
                    image: image,
                    phrase: currentPhrase,
                    currency: currencyContext
                )
                apply(response)
            } catch {
                handle(error)
            }
        }
    }

    /// El archivo no se pudo abrir: sin llamada a la IA.
    func failToOpenFile() {
        source = .photo
        fail(.unreadableFile)
    }

    /// La cámara no tiene permiso.
    func failCamera() {
        source = .photo
        fail(.camera)
    }

    // MARK: - Escrito (Yala IA)

    /// Lo escrito va como una nota ya transcrita (`receipt.voice`): gasta un recibo del día, como la foto o la voz.
    func readText(_ text: String, fromVoice: Bool = false) {
        source = fromVoice ? .voice : .text
        heard = text.trimmingCharacters(in: .whitespacesAndNewlines)
        processingStep = 1
        phase = .processing
        let note = heard
        task = Task {
            #if DEBUG
            if let profile = UITestHooks.receiptSplitProfile {
                await uiTestReply(profile)
                return
            }
            #endif
            do {
                let response = try await ReceiptSplitService.shared.readNote(text: note, currency: currencyContext)
                apply(response)
            } catch {
                handle(error)
            }
        }
    }

    /// Transcribe un audio del chat y lo lee (el micro de la barra de Yala IA). Devuelve lo oído para pintar la burbuja.
    func transcribeAndRead(_ audio: Data, language: VoiceLanguage, onHeard: @escaping (String) -> Void) {
        source = .voice
        processingStep = 0
        phase = .processing
        task = Task {
            #if DEBUG
            if let profile = UITestHooks.receiptSplitProfile {
                heard = Self.uiTestHeard
                onHeard(heard)
                await uiTestReply(profile)
                return
            }
            #endif
            do {
                let transcription = try await VoiceTranscriptionService.shared.transcribe(
                    audioData: audio,
                    language: language,
                    task: .receiptTranscribe
                )
                let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    fail(.noVoice)
                    return
                }
                heard = text
                onHeard(text)
                processingStep = 1
                let response = try await ReceiptSplitService.shared.readNote(text: text, currency: currencyContext)
                apply(response)
            } catch {
                handle(error)
            }
        }
    }

    // MARK: - Común

    /// Cierra o vuelve a empezar: nada se queda escuchando ni leyendo sin pantalla.
    func cancel() {
        task?.cancel()
        task = nil
        if AudioRecorderService.shared.state == .recording { AudioRecorderService.shared.cancelRecording() }
        phase = .idle
    }

    /// Vuelve al principio para otra foto, otra nota u otro texto.
    func reset() {
        cancel()
        lines = []
        unmatchedNames = []
        merchant = nil
        readCurrency = nil
        printedTotal = nil
        heard = ""
        readingPhoto = nil
    }

    /// La plantilla para Nuevo gasto con el reparto de la revisión; `nil` si no hay nada que repartir.
    func template(date: Date = .now) -> GroupExpensePrefillTemplate? {
        let description = ReceiptSplitLogic.expenseDescription(merchant: merchant, lines: lines)
        return ReceiptSplitLogic.template(
            lines: lines,
            memberIDs: memberIDs,
            currencyCode: effectiveCurrency,
            description: description,
            date: date
        )
    }

    private var currencyContext: VisionCurrencyContext {
        VisionCurrencyContext(mainCurrency: currencyCode, accountCurrencies: [currencyCode])
    }

    private var matcherMembers: [ReceiptPeopleMatcher.Member] {
        members.map {
            ReceiptPeopleMatcher.Member(id: $0.id.uuidString, name: $0.displayName, isCurrentUser: $0.id.uuidString == currentMemberID)
        }
    }

    private func apply(_ response: ReceiptSplitResponse) {
        guard !Task.isCancelled else { return }
        let draft = ReceiptSplitDraftLogic.draft(from: response, members: matcherMembers)
        lines = draft.lines
        unmatchedNames = draft.unmatchedNames
        merchant = response.merchant
        readCurrency = response.currency.flatMap { CurrencyCode(rawValue: $0) != nil ? $0 : nil }
        printedTotal = response.printedTotal
        processingStep = 2
        phase = .review
        DS.Haptic.success()
    }

    private func handle(_ error: Error) {
        guard !Task.isCancelled else { return }
        #if DEBUG
        print("GroupCaptureModel: Error: \(error)")
        #endif
        fail(Self.failure(
            for: error,
            source: source,
            isConnected: NetworkMonitor.shared.isConnected,
            isPro: FeatureGateService.shared.isProUser
        ))
    }

    private func fail(_ failure: GroupCaptureFailure) {
        phase = .failure(failure)
        DS.Haptic.error()
    }

    /// Qué fallo enseñar: lo que el gateway contestó con nombre propio va con su texto (el de foto o el de voz).
    /// El cupo diario de recibos es de los dos planes: a Free se le ofrece Pro, a Pro solo se le dice que vuelva mañana.
    /// La prueba agotada (`trial*`) solo la contesta un gateway anterior al cubo `receipt`.
    static func failure(for error: Error, source: GroupCaptureSource, isConnected: Bool, isPro: Bool) -> GroupCaptureFailure {
        let inner: Error
        switch error {
        case ReceiptSplitError.noLines: return .noLines
        case ReceiptSplitError.emptyNote: return .noVoice
        case ReceiptSplitError.network(let wrapped): inner = wrapped
        case TranscriptionError.networkError(let wrapped): inner = wrapped
        case TranscriptionError.emptyAudio: return .noVoice
        default: return isConnected ? .read : .noConnection
        }
        if ProxyErrorMapper.isTrialExhausted(inner) { return source == .photo ? .trialPhotos : .trialVoice }
        if ProxyErrorMapper.isDailyLimitReached(inner) { return isPro ? .dailyLimit : .dailyLimitFree }
        if ProxyErrorMapper.isBurstLimited(inner) { return .busy }
        return isConnected ? .read : .noConnection
    }

    // MARK: - Edición de líneas

    func update(_ id: UUID, _ change: (inout ReceiptSplitLine) -> Void) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        change(&lines[index])
        DS.Haptic.selection()
    }

    func setAssignees(_ ids: Set<String>, for lineID: UUID) {
        update(lineID) { $0.assignees = ids; $0.needsReview = false }
    }

    func toggle(_ memberID: String, in lineID: UUID) {
        update(lineID) { line in
            line.needsReview = false
            if line.assignees.contains(memberID) { line.assignees.remove(memberID) } else { line.assignees.insert(memberID) }
        }
    }

    func toggleExtraPerson(_ memberID: String, in lineID: UUID) {
        update(lineID) { line in
            if line.extraShare != .people { line.extraShare = .people; line.assignees = [] }
            if line.assignees.contains(memberID) { line.assignees.remove(memberID) } else { line.assignees.insert(memberID) }
        }
    }

    func delete(_ ids: Set<UUID>) {
        lines.removeAll { ids.contains($0.id) }
        DS.Haptic.warning()
    }

    func addSurcharge(_ kind: ReceiptLineKind, percent: Int, share: ReceiptExtraShare) {
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

    // MARK: - UI test

    #if DEBUG
    /// Lo que «oye» la voz con `-uitest-receipt-split`: la misma cena que la foto de ejemplo.
    static let uiTestHeard = "Lomo 38 Ana, ají 32 Beto, pizza 48 Ana y yo, chicha 18 entre todos"

    /// Lo que «lee» la hoja sin red con `-uitest-receipt-split`: una cena de cinco platos con «Tú», Ana y Beto.
    private func uiTestReply(_ profile: String) async {
        do {
            try await Task.sleep(for: .milliseconds(700))
            processingStep = 1
            try await Task.sleep(for: .milliseconds(800))
        } catch {
            return
        }
        if profile == "trial" {
            handle(ReceiptSplitError.network(ProxyErrorMapper.trialExhaustedResponse()))
            return
        }
        if profile == "daily" {
            handle(ReceiptSplitError.network(ProxyErrorMapper.quotaResponse(type: "yala_quota_daily")))
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
