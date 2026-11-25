//
//  BankEmailDraftService.swift
//  Yala
//
//  Trae a la Bandeja los movimientos que el gateway leyó de los avisos del banco reenviados (2.3). El gateway no escribe
//  en los datos de la nube de nadie: guarda lo leído en una cola de la cuenta, y la app lo convierte aquí en borradores
//  locales —que sincronizan como cualquier otro— y le confirma al gateway cuáles ya tiene (`ack`), que los borra.
//
//  Orden: crear → guardar → apuntar los ids → `ack`. Si el `ack` no llega, la próxima vuelta los vuelve a traer y los ids
//  apuntados impiden duplicarlos (y se vuelven a confirmar).
//
//  Corre al volver a primer plano, solo si: la persona preparó su dirección (`BankEmailSetupStore`), tiene sesiones de
//  Yala web abiertas (la web apunta por esta misma cola, lote 1) o han pasado 2 minutos desde la última pregunta (la IA
//  de la persona también apunta aquí, con `source: "ai"`, y la app no sabe si hay una conectada: `AIConnectorDraftLogic`);
//  los datos viven en la nube con sesión, no hay un borrado de cierre armado y el import está asentado (el gate de
//  `ApplePayDraftService`). Si lo único que faltaba era el import, se reintenta cuando se asienta
//  (`syncIfDeferredByImport`, desde el borde final del cambio remoto de `AppBootstrapper`).
//

import Foundation
import SwiftData

@MainActor
enum BankEmailDraftService {

    static func makeClient() -> BankEmailClient {
        BankEmailClient(attestProvider: AttestSessionProvider.live)
    }

    /// ¿Toca preguntar al gateway? Pura, para los tests. `webConnected`: hay sesiones de Yala web (`ConnectedBrowsersPresence`).
    /// `aiPollDue`: pasaron 2 minutos desde la última pregunta, por si la IA de la persona dejó algo (`AIConnectorDraftLogic`).
    nonisolated static func shouldSync(isSetUp: Bool, webConnected: Bool = false, aiPollDue: Bool = false, storageIsCloud: Bool, hasSession: Bool, wipeArmed: Bool, importQuiescent: Bool) -> Bool {
        (isSetUp || webConnected || aiPollDue) && storageIsCloud && hasSession && !wipeArmed && importQuiescent
    }

    private static var inFlight = false
    /// La última vez que se preguntó a la cola (cualquier pregunta trae también lo de la IA). En memoria: un arranque en
    /// frío pregunta una vez.
    private static var lastQueuePoll: Date?
    /// La última vuelta no preguntó solo porque el import seguía activo: al asentarse se reintenta.
    private static var deferredByImport = false

    /// Trae, crea y confirma. Devuelve cuántos borradores creó (0 si no tocaba o falló: se reintenta en la próxima vuelta).
    @discardableResult
    static func syncIfNeeded(context: ModelContext, webConnected: Bool = ConnectedBrowsersPresence.cachedHasSessions(), now: Date = .now) async -> Int {
        let isSetUp = BankEmailSetupStore.isSetUp()
        let aiPollDue = AIConnectorDraftLogic.isPollDue(lastPoll: lastQueuePoll, now: now)
        let storageIsCloud = CloudSyncFlags.storageMode == .cloud
        let hasSession = CloudAuthService.shared.hasSession
        let wipeArmed = StorageModePersistence.isSignOutWipeArmed()
        let importQuiescent = iCloudSyncService.shared.isImportQuiescent
        guard shouldSync(
            isSetUp: isSetUp,
            webConnected: webConnected,
            aiPollDue: aiPollDue,
            storageIsCloud: storageIsCloud,
            hasSession: hasSession,
            wipeArmed: wipeArmed,
            importQuiescent: importQuiescent
        ), !inFlight else {
            if !importQuiescent {
                deferredByImport = shouldSync(
                    isSetUp: isSetUp, webConnected: webConnected, aiPollDue: aiPollDue, storageIsCloud: storageIsCloud,
                    hasSession: hasSession, wipeArmed: wipeArmed, importQuiescent: true)
            }
            return 0
        }
        deferredByImport = false
        lastQueuePoll = now
        inFlight = true
        defer { inFlight = false }

        let client = makeClient()
        let drafts: [BankEmailDraftDTO]
        do {
            drafts = try await client.drafts()
        } catch {
            #if DEBUG
            print("BankEmailDraftService: Error: \(error)")
            #endif
            return 0
        }
        guard !drafts.isEmpty else { return 0 }

        let fresh = drafts.filter { !BankEmailCreatedIDsStore.contains($0.id) }
        let created = materialize(fresh, context: context)
        guard created != nil else { return 0 }
        BankEmailCreatedIDsStore.add(fresh.map(\.id))

        do {
            try await client.ack(ids: drafts.map(\.id))
        } catch {
            #if DEBUG
            print("BankEmailDraftService: Error: \(error)")
            #endif
        }
        return created ?? 0
    }

    /// Lo que no entró al volver a primer plano porque el import seguía activo, ahora que se asentó. No hace nada si la
    /// última vuelta no se saltó por eso.
    @discardableResult
    static func syncIfDeferredByImport(context: ModelContext) async -> Int {
        guard deferredByImport else { return 0 }
        return await syncIfNeeded(context: context)
    }

    /// Crea los borradores y guarda. `nil` si el guardado falló (se deshacen solo los de aquí y no se confirma nada).
    static func materialize(_ dtos: [BankEmailDraftDTO], context: ModelContext) -> Int? {
        guard !dtos.isEmpty else { return 0 }
        let accounts = DraftBuilder.fetchActiveAccounts(context: context)
        var inserted: [InboxDraft] = []
        var arrivals: [InboxArrivalJoin.Arrival] = []

        // Lo que apuntó la IA tiene su propio paso (cuenta y subcategoría por id o por nombre, y el freno contra el
        // duplicado de otro aparato). Si sus lecturas fallan, no se crea nada de la vuelta y no se confirma nada.
        let aiDTOs = dtos.filter { AIConnectorDraftLogic.isAI(source: $0.source) }
        if !aiDTOs.isEmpty {
            guard let aiDrafts = aiConnectorDrafts(aiDTOs, accounts: accounts, context: context) else { return nil }
            aiDrafts.forEach { context.insert($0) }
            inserted.append(contentsOf: aiDrafts)
            arrivals.append(contentsOf: aiDrafts.map { InboxArrivalJoin.Arrival(draft: $0, currencyCode: $0.cachedCurrencyCode) })
        }

        for dto in dtos where !AIConnectorDraftLogic.isAI(source: dto.source) {
            let fields = BankEmailDraftLogic.fields(from: dto)
            // Lo apuntado en Yala web trae la cuenta y la subcategoría elegidas (lote 1, `WebDraftLogic`).
            let fromWeb = WebDraftLogic.isWeb(source: dto.source)
            let chosenAccount = fromWeb ? WebDraftLogic.account(ref: dto.accountRef, in: accounts, id: \.shortcutID) : nil
            let account = chosenAccount
                ?? DraftBuilder.findAccount(
                    paymentMention: fields.accountMention, last4: dto.accountLast4, dictatedCurrency: fields.currencyCode,
                    in: accounts)
                ?? fields.currencyCode.flatMap { DraftBuilder.findAccount(byCurrency: $0, in: accounts) }

            var subcategory: Subcategory?
            var subcategoryConfidence: Double?
            if fromWeb, let wanted = WebDraftLogic.uuid(dto.subcategoryRef) {
                do {
                    subcategory = try EntityApplyMap.findSubcategory(byShortcutID: wanted, context: context)
                } catch {
                    #if DEBUG
                    print("BankEmailDraftService: Error: \(error)")
                    #endif
                }
                if let chosen = subcategory,
                   !WebDraftLogic.acceptsSubcategory(isVisible: chosen.isVisible, isIncomeCategory: chosen.category?.isIncome, amount: fields.amount) {
                    subcategory = nil
                }
                if subcategory != nil { subcategoryConfidence = 1.0 }
            }
            if subcategory == nil, !fields.note.isEmpty {
                switch MerchantMemoryService(modelContext: context).suggest(for: fields.note, isExpense: fields.amount < 0) {
                case .autoAssign(let sub):
                    subcategory = sub
                    subcategoryConfidence = 0.95
                case .suggest(let sub):
                    subcategory = sub
                    subcategoryConfidence = 0.8
                case .none:
                    break
                }
            }

            let draft = InboxDraft(
                note: fields.note,
                amount: fields.amount,
                date: fields.date,
                account: account,
                subcategory: subcategory,
                sourceType: fromWeb ? .automation : .emailAlert,
                rawText: fromWeb ? WebDraftLogic.evidence : fields.evidence,
                evidence: fromWeb ? WebDraftLogic.evidence : fields.evidence,
                confidenceAmount: 0.9,
                confidenceDate: 0.9,
                confidenceMerchant: fields.note.isEmpty ? nil : (fromWeb ? 1.0 : 0.9),
                confidenceSubcategory: subcategoryConfidence,
                needsUserInput: DraftBuilder.computeNeedsUserInput(
                    hasAmount: true, hasAccount: account != nil, hasSubcategory: subcategory != nil)
            )
            // Sin cuenta, la Bandeja enseña el importe en la divisa del aviso (un aviso en dólares no sale en soles).
            draft.cachedCurrencyCode = account?.currencyCode ?? fields.currencyCode
            context.insert(draft)
            inserted.append(draft)
            arrivals.append(InboxArrivalJoin.Arrival(draft: draft, currencyCode: fields.currencyCode, last4: dto.accountLast4))
        }

        // Bandeja sin duplicados (lote 2): el mismo consumo que ya llegó por otra fuente (Apple Pay, el aviso del banco, o
        // el correo y la IA de esta misma tanda) se une al pendiente que lo tiene, en este mismo guardado.
        let joined = InboxArrivalJoin.joinBeforeSave(arrivals, context: context)

        do {
            SaveBreadcrumb.willSave("BankEmailDraftService.materialize")
            try context.save()
            SaveBreadcrumb.didSave("BankEmailDraftService.materialize")
        } catch {
            #if DEBUG
            print("BankEmailDraftService: Error saving drafts: \(error)")
            #endif
            inserted.filter { !joined.isAbsorbed($0) }.forEach { context.delete($0) }
            InboxArrivalJoin.revert(joined)
            return nil
        }
        return inserted.count
    }

    /// Tu IA registra en Yala (2.3): los borradores de lo que Claude, ChatGPT o Grok apuntó por el conector, sin insertar.
    /// `nil` si no se pudieron leer las subcategorías o los borradores `.aiConnector` que ya hay.
    ///
    /// Los ids creados (`BankEmailCreatedIDsStore`) son de cada aparato: si el que trae la cola es OTRO (iPad tras iPhone),
    /// lo que lo frena es el borrador que ya le llegó por el sync, reconocido por el instante en que la IA lo apuntó
    /// (`createdAt`), el importe y la nota. Residual aceptado: dos aparatos que traen la cola a la vez, antes de que el sync
    /// lleve el borrador del uno al otro, crean dos; la persona descarta uno.
    private static func aiConnectorDrafts(_ dtos: [BankEmailDraftDTO], accounts: [Account], context: ModelContext) -> [InboxDraft]? {
        let subcategories: [Subcategory]
        let existing: [InboxDraft]
        do {
            subcategories = try context.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate<Subcategory> { $0.isVisible == true }))
            // También los que tienen algo unido: un borrador de la IA puede vivir dentro de otro (`InboxArrivalJoin`).
            let raw = DraftSourceType.aiConnector.rawValue
            existing = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate<InboxDraft> {
                $0.sourceTypeRaw == raw || $0.joinRecordRaw != nil
            }))
        } catch {
            #if DEBUG
            print("BankEmailDraftService: Error reading for AI drafts: \(error)")
            #endif
            return nil
        }
        let known = InboxArrivalJoin.aiMaterializations(in: existing)

        var drafts: [InboxDraft] = []
        for dto in dtos {
            let fields = AIConnectorDraftLogic.fields(from: dto)
            let receivedAt = Date(timeIntervalSince1970: dto.receivedAtMs / 1000)
            if AIConnectorDraftLogic.alreadyMaterialized(receivedAt: receivedAt, fields: fields, among: known) { continue }
            let account = AIConnectorDraftLogic.account(for: fields, in: accounts)
            let subcategory = AIConnectorDraftLogic.subcategory(for: fields, in: subcategories)

            let draft = InboxDraft(
                note: fields.note,
                amount: fields.amount,
                date: fields.date,
                account: account,
                subcategory: subcategory,
                sourceType: .aiConnector,
                rawText: fields.evidence,
                evidence: fields.evidence,
                confidenceAmount: 0.95,
                confidenceDate: 0.95,
                confidenceMerchant: fields.note.isEmpty ? nil : 0.95,
                confidenceSubcategory: subcategory == nil ? nil : 0.95,
                needsUserInput: DraftBuilder.computeNeedsUserInput(
                    hasAmount: true, hasAccount: account != nil, hasSubcategory: subcategory != nil)
            )
            // Sin cuenta, la Bandeja enseña el importe en la divisa que dijo la IA (un gasto en dólares no sale en soles).
            draft.cachedCurrencyCode = account?.currencyCode ?? fields.currencyCode
            // El instante en que la IA lo apuntó, que es el mismo en todos los aparatos: con él, otro aparato reconoce este
            // borrador cuando le llega por el sync (`alreadyMaterialized`).
            draft.createdAt = receivedAt
            drafts.append(draft)
        }
        return drafts
    }

    #if DEBUG
    /// Solo tests: olvida la última pregunta, la que se saltó por el import y la petición en vuelo.
    static func _testReset() {
        inFlight = false
        lastQueuePoll = nil
        deferredByImport = false
    }
    #endif
}
