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
//  Corre al volver a primer plano, solo si: la persona preparó su dirección (`BankEmailSetupStore`) o tiene sesiones de
//  Yala web abiertas (la web apunta por esta misma cola, lote 1), los datos viven en la nube con sesión, no hay un
//  borrado de cierre armado y el import está asentado (el gate de `ApplePayDraftService`).
//

import Foundation
import SwiftData

@MainActor
enum BankEmailDraftService {

    static func makeClient() -> BankEmailClient {
        BankEmailClient(attestProvider: AttestSessionProvider.live)
    }

    /// ¿Toca preguntar al gateway? Pura, para los tests. `webConnected`: hay sesiones de Yala web (`ConnectedBrowsersPresence`).
    nonisolated static func shouldSync(isSetUp: Bool, webConnected: Bool = false, storageIsCloud: Bool, hasSession: Bool, wipeArmed: Bool, importQuiescent: Bool) -> Bool {
        (isSetUp || webConnected) && storageIsCloud && hasSession && !wipeArmed && importQuiescent
    }

    private static var inFlight = false

    /// Trae, crea y confirma. Devuelve cuántos borradores creó (0 si no tocaba o falló: se reintenta en la próxima vuelta).
    @discardableResult
    static func syncIfNeeded(context: ModelContext, webConnected: Bool = ConnectedBrowsersPresence.cachedHasSessions()) async -> Int {
        guard shouldSync(
            isSetUp: BankEmailSetupStore.isSetUp(),
            webConnected: webConnected,
            storageIsCloud: CloudSyncFlags.storageMode == .cloud,
            hasSession: CloudAuthService.shared.hasSession,
            wipeArmed: StorageModePersistence.isSignOutWipeArmed(),
            importQuiescent: iCloudSyncService.shared.isImportQuiescent
        ), !inFlight else { return 0 }
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

    /// Crea los borradores y guarda. `nil` si el guardado falló (se deshacen solo los de aquí y no se confirma nada).
    static func materialize(_ dtos: [BankEmailDraftDTO], context: ModelContext) -> Int? {
        guard !dtos.isEmpty else { return 0 }
        let accounts = DraftBuilder.fetchActiveAccounts(context: context)
        var inserted: [InboxDraft] = []

        for dto in dtos {
            let fields = BankEmailDraftLogic.fields(from: dto)
            // Lo apuntado en Yala web trae la cuenta y la subcategoría elegidas (lote 1, `WebDraftLogic`).
            let fromWeb = WebDraftLogic.isWeb(source: dto.source)
            let chosenAccount = fromWeb ? WebDraftLogic.account(ref: dto.accountRef, in: accounts, id: \.shortcutID) : nil
            let account = chosenAccount
                ?? DraftBuilder.findAccount(paymentMention: fields.accountMention, dictatedCurrency: fields.currencyCode, in: accounts)
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
        }

        do {
            SaveBreadcrumb.willSave("BankEmailDraftService.materialize")
            try context.save()
            SaveBreadcrumb.didSave("BankEmailDraftService.materialize")
        } catch {
            #if DEBUG
            print("BankEmailDraftService: Error saving drafts: \(error)")
            #endif
            inserted.forEach { context.delete($0) }
            return nil
        }
        return inserted.count
    }
}
