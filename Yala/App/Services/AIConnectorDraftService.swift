//
//  AIConnectorDraftService.swift
//  Yala
//
//  Tu IA registra en Yala (2.3): trae a la Bandeja lo que Claude, ChatGPT o Grok apuntó por el conector de Yala. El
//  conector no escribe en los datos de la nube de nadie: deja el movimiento en una cola de la cuenta en el gateway, y la
//  app lo convierte aquí en un borrador local —que sincroniza como cualquier otro y la persona confirma o descarta— y le
//  confirma al gateway cuáles ya tiene (`ack`), que los borra. Mismo molde que `BankEmailDraftService`, y el mismo
//  cliente (`BankEmailClient`, que ya lleva App Attest cableado).
//
//  Orden: crear → guardar → apuntar los ids → `ack`. Si el `ack` no llega, la próxima vuelta los vuelve a traer y los ids
//  apuntados impiden duplicarlos (y se vuelven a confirmar). Los ids son de cada aparato: si el que los trae es OTRO
//  (iPad tras iPhone), lo que lo frena es el borrador que ya le llegó por el sync, reconocido por el instante en que la
//  IA lo apuntó (`createdAt`), el importe y la nota. Residual aceptado: dos aparatos que traen la cola a la vez, antes de
//  que el sync lleve el borrador del uno al otro, crean dos; la persona descarta uno.
//
//  Corre al volver a primer plano (también en el primer `.active` de un arranque en frío) y cuando el import se asienta,
//  solo si: los datos viven en la nube con sesión, no hay un borrado de cierre armado y el import está asentado. No hay
//  marca de «preparado» como en el correo: la app no sabe si la persona conectó una IA, y la petición es una lectura de
//  una fila por cuenta. Dos llamadas seguidas en menos de `minimumInterval` no repiten la petición.
//

import Foundation
import SwiftData

@MainActor
enum AIConnectorDraftService {

    /// Un cambio de escena dispara `.active` dos o tres veces seguidas: una sola petición por ráfaga.
    static let minimumInterval: TimeInterval = 15

    /// ¿Toca preguntar al gateway? Pura, para los tests.
    nonisolated static func shouldSync(storageIsCloud: Bool, hasSession: Bool, wipeArmed: Bool, importQuiescent: Bool) -> Bool {
        storageIsCloud && hasSession && !wipeArmed && importQuiescent
    }

    private static var inFlight = false
    private static var lastAttempt: Date?

    /// Trae, crea y confirma. Devuelve cuántos borradores creó (0 si no tocaba o falló: se reintenta en la próxima vuelta).
    @discardableResult
    static func syncIfNeeded(context: ModelContext, now: Date = .now) async -> Int {
        guard shouldSync(
            storageIsCloud: CloudSyncFlags.storageMode == .cloud,
            hasSession: CloudAuthService.shared.hasSession,
            wipeArmed: StorageModePersistence.isSignOutWipeArmed(),
            importQuiescent: iCloudSyncService.shared.isImportQuiescent
        ), !inFlight else { return 0 }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < minimumInterval { return 0 }
        lastAttempt = now
        inFlight = true
        defer { inFlight = false }

        let client = BankEmailDraftService.makeClient()
        let drafts: [ConnectorDraftDTO]
        do {
            drafts = try await client.connectorDrafts()
        } catch {
            #if DEBUG
            print("AIConnectorDraftService: Error: \(error)")
            #endif
            return 0
        }
        guard !drafts.isEmpty else { return 0 }

        let fresh = drafts.filter { !AIConnectorCreatedIDsStore.contains($0.id) }
        guard let created = materialize(fresh, context: context) else { return 0 }
        AIConnectorCreatedIDsStore.add(fresh.map(\.id))

        do {
            try await client.ackConnectorDrafts(ids: drafts.map(\.id))
        } catch {
            #if DEBUG
            print("AIConnectorDraftService: Error: \(error)")
            #endif
        }
        return created
    }

    /// Crea los borradores y guarda. `nil` si el guardado falló (se deshacen solo los de aquí y no se confirma nada).
    static func materialize(_ dtos: [ConnectorDraftDTO], context: ModelContext) -> Int? {
        guard !dtos.isEmpty else { return 0 }
        let accounts = DraftBuilder.fetchActiveAccounts(context: context)
        let subcategories: [Subcategory]
        do {
            subcategories = try context.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate<Subcategory> { $0.isVisible == true }))
        } catch {
            #if DEBUG
            print("AIConnectorDraftService: Error fetching subcategories: \(error)")
            #endif
            return nil
        }

        // Los que ya están en la Bandeja porque los creó OTRO aparato de la persona (iPhone e iPad) y llegaron por el sync
        // antes de que la cola se vaciara: la lista de ids creados es de cada aparato y no los ve.
        let existing: [InboxDraft]
        do {
            let raw = DraftSourceType.aiConnector.rawValue
            existing = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate<InboxDraft> { $0.sourceTypeRaw == raw }))
        } catch {
            #if DEBUG
            print("AIConnectorDraftService: Error fetching existing drafts: \(error)")
            #endif
            return nil
        }

        var inserted: [InboxDraft] = []
        for dto in dtos {
            let fields = AIConnectorDraftLogic.fields(from: dto)
            let receivedAt = Date(timeIntervalSince1970: dto.receivedAtMs / 1000)
            if AIConnectorDraftLogic.alreadyMaterialized(receivedAt: receivedAt, fields: fields, among: existing.map(AIConnectorDraftLogic.Existing.init)) {
                continue
            }
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
            context.insert(draft)
            inserted.append(draft)
        }

        do {
            SaveBreadcrumb.willSave("AIConnectorDraftService.materialize")
            try context.save()
            SaveBreadcrumb.didSave("AIConnectorDraftService.materialize")
        } catch {
            #if DEBUG
            print("AIConnectorDraftService: Error saving drafts: \(error)")
            #endif
            inserted.forEach { context.delete($0) }
            return nil
        }
        return inserted.count
    }

    #if DEBUG
    /// Solo tests: olvida la ráfaga y la petición en vuelo.
    static func _testReset() {
        inFlight = false
        lastAttempt = nil
    }
    #endif
}
