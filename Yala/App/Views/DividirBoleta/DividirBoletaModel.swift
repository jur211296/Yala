//
//  DividirBoletaModel.swift
//  Yala
//
//  El motor de «Dividir una boleta» (maqueta 1A, 26-nov-2026). Las personas son valores escritos al vuelo: nada de
//  `SplitMember` ni de grupo, y nada se guarda salvo, si la persona lo pide, el borrador de su parte. La lectura es la de
//  Grupos (`ReceiptSplitService.readPhoto`, tarea `receipt.photo`, cupo diario de recibos) y se hace UNA vez, al tocar
//  «Repartir», con la frase de quién comió qué en la misma llamada.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class DividirBoletaModel {

    /// Los pasos de la hoja.
    enum Step: Equatable {
        /// Cámara, Fotos o Archivo.
        case source
        /// ¿Entre quiénes?, ¿cómo lo dividimos? y la frase opcional. Aquí se lee la foto.
        case who
        /// Sin lectura (la IA no pudo o no hay cupo): el total escrito a mano.
        case manualTotal
        /// Las líneas, quién comió cada una y los extras.
        case review
        /// Quién pagó, lo que debe cada uno, la imagen y mi parte.
        case result
    }

    /// La lectura de la foto.
    enum ReadPhase: Equatable {
        case idle
        case reading
        case failure(GroupCaptureFailure)
        case read
    }

    let currencyCode: String

    var step: Step = .source
    private(set) var photo: UIImage?
    private(set) var readPhase: ReadPhase = .idle
    private(set) var people: [DividirBoletaPerson]
    var mode: DividirBoletaMode = .byLines
    var phrase = ""
    var lines: [ReceiptSplitLine] = []
    private(set) var unmatchedNames: [String] = []
    private(set) var merchant: String?
    private(set) var readCurrency: String?
    private(set) var printedTotal: Double?
    /// Quién pagó. Por defecto, yo (Jürgen: «no asumamos que siempre pague yo», pero es lo normal).
    var payerID: String
    /// La imagen que se comparte: qué cuenta y con qué diseño.
    var imageKind: DividirBoletaImageKind = .summary
    var imageStyle: DividirBoletaImageStyle = .light

    private var task: Task<Void, Never>?

    init(meName: String, currencyCode: String) {
        let me = DividirBoletaPerson(name: meName, isMe: true)
        self.people = [me]
        self.payerID = me.id
        self.currencyCode = currencyCode
    }

    var me: DividirBoletaPerson? { people.first(where: \.isMe) }
    var effectiveCurrency: String { readCurrency ?? currencyCode }
    var canSplitPeople: Bool { people.count >= 2 }
    var isReading: Bool { readPhase == .reading }

    var summary: DividirBoletaLogic.Summary? {
        DividirBoletaLogic.summary(lines, people: people, mode: mode, payerID: payerID)
    }

    var shareCents: [String: Int] { DividirBoletaLogic.shareCents(lines, people: people, mode: mode) }

    var canContinueFromReview: Bool { DividirBoletaLogic.canSplit(lines, people: people, mode: mode) }

    var payer: DividirBoletaPerson? { people.first { $0.id == payerID } }

    // MARK: - Foto

    /// Una foto nueva vuelve a empezar la lectura (lo leído de la anterior no vale para esta).
    func choosePhoto(_ image: UIImage) {
        cancelReading()
        photo = image
        clearRead()
        step = .who
    }

    func failToOpenFile() {
        readPhase = .failure(.unreadableFile)
        step = .who
    }

    func failCamera() {
        readPhase = .failure(.camera)
        step = .who
    }

    /// «Otra foto»: de vuelta a Cámara, Fotos o Archivo, sin perder los nombres.
    func chooseAnotherPhoto() {
        cancelReading()
        photo = nil
        clearRead()
        step = .source
    }

    // MARK: - Personas

    /// Añade a alguien por su nombre. `false` si el nombre está vacío, repetido o ya no caben más.
    @discardableResult
    func addPerson(named raw: String) -> Bool {
        guard people.count < DividirBoletaLogic.maxPeople,
              let name = DividirBoletaLogic.cleanedName(raw, existing: people) else { return false }
        people.append(DividirBoletaPerson(name: name))
        DS.Haptic.selection()
        return true
    }

    /// Quita a alguien (nunca a mí). Sale también de las líneas y, si había pagado, paga «Yo».
    func removePerson(_ id: String) {
        guard let person = people.first(where: { $0.id == id }), !person.isMe else { return }
        people.removeAll { $0.id == id }
        lines = DividirBoletaLogic.removing(id, from: lines)
        if payerID == id, let me { payerID = me.id }
        DS.Haptic.selection()
    }

    // MARK: - Leer

    /// «Repartir»: si la foto ya se leyó, a la revisión sin volver a leer (no gasta otro recibo); si no, la lee.
    func split() {
        guard canSplitPeople else { return }
        if readPhase == .read {
            step = .review
            return
        }
        guard let photo else { return }
        read(photo)
    }

    private func read(_ image: UIImage) {
        readPhase = .reading
        let currentPhrase = mode == .byLines ? phrase : ""
        let currency = VisionCurrencyContext(mainCurrency: currencyCode, accountCurrencies: [currencyCode])
        task = Task {
            #if DEBUG
            if let profile = UITestHooks.receiptSplitProfile {
                await uiTestReply(profile)
                return
            }
            #endif
            do {
                let response = try await ReceiptSplitService.shared.readPhoto(
                    image: image, phrase: currentPhrase, currency: currency)
                apply(response)
            } catch {
                handle(error)
            }
        }
    }

    func cancelReading() {
        task?.cancel()
        task = nil
        if readPhase == .reading { readPhase = .idle }
    }

    /// Lo leído pasa a líneas con las personas de la boleta (el mismo casado de nombres que Grupos).
    func apply(_ response: ReceiptSplitResponse) {
        guard !Task.isCancelled else { return }
        let draft = ReceiptSplitDraftLogic.draft(from: response, members: DividirBoletaLogic.matcherMembers(people))
        lines = draft.lines
        unmatchedNames = draft.unmatchedNames
        merchant = response.merchant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        readCurrency = response.currency.flatMap { CurrencyCode(rawValue: $0) != nil ? $0 : nil }
        printedTotal = response.printedTotal
        readPhase = .read
        step = .review
        DS.Haptic.success()
    }

    private func handle(_ error: Error) {
        guard !Task.isCancelled else { return }
        #if DEBUG
        print("DividirBoletaModel: Error: \(error)")
        #endif
        readPhase = .failure(GroupCaptureModel.failure(
            for: error,
            source: .photo,
            isConnected: NetworkMonitor.shared.isConnected,
            isPro: FeatureGateService.shared.isProUser
        ))
        DS.Haptic.error()
    }

    private func clearRead() {
        readPhase = .idle
        lines = []
        unmatchedNames = []
        merchant = nil
        readCurrency = nil
        printedTotal = nil
    }

    // MARK: - A mano

    /// «Apuntarlo a mano»: sin lectura, el total escrito se reparte por igual.
    func startManualTotal() {
        cancelReading()
        step = .manualTotal
    }

    func useManualTotal(_ amount: Double) {
        guard amount >= 0.01 else { return }
        lines = [ReceiptSplitLine(description: L10n.DividirBoleta.manualLineName, amount: amount, kind: .item)]
        unmatchedNames = []
        merchant = nil
        readCurrency = nil
        printedTotal = nil
        mode = .equal
        readPhase = .read
        step = .review
    }

    // MARK: - Edición de líneas (la de Grupos)

    func update(_ id: UUID, _ change: (inout ReceiptSplitLine) -> Void) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        change(&lines[index])
        DS.Haptic.selection()
    }

    func setEveryone(for lineID: UUID) {
        update(lineID) { $0.assignees = []; $0.needsReview = false }
    }

    func toggle(_ personID: String, in lineID: UUID) {
        update(lineID) { line in
            line.needsReview = false
            if line.assignees.contains(personID) { line.assignees.remove(personID) } else { line.assignees.insert(personID) }
        }
    }

    func setExtraShare(_ share: ReceiptExtraShare, for lineID: UUID) {
        update(lineID) { $0.extraShare = share; $0.assignees = [] }
    }

    func toggleExtraPerson(_ personID: String, in lineID: UUID) {
        update(lineID) { line in
            if line.extraShare != .people { line.extraShare = .people; line.assignees = [] }
            if line.assignees.contains(personID) { line.assignees.remove(personID) } else { line.assignees.insert(personID) }
            if line.assignees.isEmpty { line.extraShare = .excluded }
        }
    }

    func delete(_ ids: Set<UUID>) {
        lines.removeAll { ids.contains($0.id) }
        DS.Haptic.warning()
    }

    func addSurcharge(_ kind: ReceiptLineKind, percent: Int, share: ReceiptExtraShare) {
        lines.append(ReceiptSplitLogic.surcharge(
            kind: kind,
            percent: percent,
            description: L10n.ReceiptSplit.surchargeTitle(kind: kind, percent: percent),
            share: share,
            lines: lines
        ))
        DS.Haptic.selection()
    }

    // MARK: - UI test

    #if DEBUG
    /// Lo que «lee» la hoja sin red con `-uitest-receipt-split`: la boleta de la maqueta, 7 líneas para Yo, Carla, Martín
    /// y Rocío, con la propina del 10 % aparte. `trial` y `daily` imitan los fallos del gateway.
    private func uiTestReply(_ profile: String) async {
        do {
            try await Task.sleep(for: .milliseconds(900))
        } catch {
            return
        }
        switch profile {
        case "trial": handle(ReceiptSplitError.network(ProxyErrorMapper.trialExhaustedResponse()))
        case "daily": handle(ReceiptSplitError.network(ProxyErrorMapper.quotaResponse(type: "yala_quota_daily")))
        default: apply(Self.uiTestBoletaResponse)
        }
    }

    static let uiTestBoletaResponse = ReceiptSplitResponse(
        merchant: "Cevichería El Muelle",
        currency: "PEN",
        printedTotal: 260.70,
        lines: [
            .init(description: "Ceviche clásico", amount: 42, kind: "item", people: ["@me"]),
            .init(description: "Lomo saltado", amount: 48, kind: "item", people: ["Martín"]),
            .init(description: "Ají de gallina", amount: 36, kind: "item", people: ["Carla"]),
            .init(description: "Arroz con mariscos", amount: 45, kind: "item", people: ["Rocío"]),
            .init(description: "Chicha morada 1 L", amount: 24, kind: "item", people: []),
            .init(description: "Gaseosa 500 ml ×2", amount: 14, kind: "item", people: ["Carla", "Martín"]),
            .init(description: "Leche de tigre para compartir", amount: 28, kind: "item", people: ["Rocío", "@me"]),
            .init(description: "Propina 10 %", amount: 23.70, kind: "tip", people: []),
        ]
    )
    #endif
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
