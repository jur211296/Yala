//
//  SpotlightIndexService.swift
//  Yala
//
//  Mantiene al día el índice de Spotlight con tus cuentas y movimientos (opción C de `docs/siri-ios-27-2026-10.md`).
//  Lo que entra lo decide `SpotlightIndexLogic`; aquí se lee SwiftData y se habla con Core Spotlight.
//
//  Vive y muere con la foto de Siri y los widgets, en los mismos dos embudos:
//  - `WidgetDataCache.updateCache` (todo cambio de datos de la app) pide una reconciliación, y la vuelta a primer plano
//    otra, que recoge lo que llegó sincronizado. Las dos esperan un momento y se funden en una.
//  - `WidgetDataCache.clearCache()` (cierre de sesión, «Vaciar datos», purgas de frontera) vacía el índice entero.
//  Con un borrado armado no se reindexa nada: el store está a punto de dejar de ser de nadie (`WidgetDataCache.isWipeArmed`).
//
//  El índice va con protección `complete`: con el iPhone bloqueado no se lee. Y si la persona protege Yala con
//  «Requerir Face ID», iOS deja de enseñar su contenido en las búsquedas.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData
import UniformTypeIdentifiers

@MainActor
enum SpotlightIndexService {

    /// Nombre del índice propio de Yala.
    static let indexName = "yala-content"
    static let accountsDomain = "accounts"
    static let transactionsDomain = "transactions"

    /// Fuera de los tests: el host de los unit tests llama a `updateCache` y no debe tocar el índice del simulador.
    static var isEnabled: Bool { !SwiftDataConfiguration.isRunningTests }

    private static let index = CSSearchableIndex(name: indexName, protectionClass: .complete)
    private static let batchSize = 500

    /// Las operaciones con el índice van en fila: un vaciado nunca se cruza con una reconciliación a medias.
    private static var tail: Task<Void, Never>?
    private static var pendingReconcile: Task<Void, Never>?
    /// Sube con cada vaciado: una reconciliación que empezó antes no escribe nada después.
    private static var generation = 0

    // MARK: - Embudos

    /// Pide una reconciliación. Varias peticiones seguidas se funden en una.
    static func scheduleReconcile(context: ModelContext, delay: Duration = .seconds(2)) {
        guard isEnabled else { return }
        pendingReconcile?.cancel()
        let requestedGeneration = generation
        pendingReconcile = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard requestedGeneration == generation else { return }
            reconcile(context: context)
        }
    }

    /// Vacía el índice de Yala y olvida lo indexado. Sin guarda: retirar siempre es seguro.
    static func clear() {
        guard isEnabled else { return }
        generation += 1
        pendingReconcile?.cancel()
        pendingReconcile = nil
        SpotlightIndexState.remove()
        enqueue {
            do {
                try await index.deleteAllSearchableItems()
            } catch {
                #if DEBUG
                print("SpotlightIndexService: Error: \(error)")
                #endif
            }
        }
    }

    // MARK: - Reconciliación

    private static func reconcile(context: ModelContext) {
        guard !WidgetDataCache.isWipeArmed else { return }
        let desired: [SpotlightEntry]
        do {
            desired = try desiredEntries(context: context)
        } catch {
            #if DEBUG
            print("SpotlightIndexService: Error: \(error)")
            #endif
            return
        }
        let plan = SpotlightIndexLogic.plan(desired: desired, indexed: SpotlightIndexState.read())
        guard !plan.isEmpty else { return }
        let startedGeneration = generation
        let items = plan.toIndex.map(searchableItem)
        enqueue {
            guard startedGeneration == generation else { return }
            do {
                if plan.deletesEverythingFirst {
                    try await index.deleteAllSearchableItems()
                }
                for chunk in stride(from: 0, to: plan.toDelete.count, by: batchSize) {
                    try await index.deleteSearchableItems(
                        withIdentifiers: Array(plan.toDelete[chunk..<min(chunk + batchSize, plan.toDelete.count)]))
                }
                for chunk in stride(from: 0, to: items.count, by: batchSize) {
                    guard startedGeneration == generation else { return }
                    try await index.indexSearchableItems(Array(items[chunk..<min(chunk + batchSize, items.count)]))
                }
                guard startedGeneration == generation else { return }
                SpotlightIndexState.write(plan.resulting)
            } catch {
                // Sin estado guardado, la próxima vez se vacía y se indexa entero: un índice a medias no se queda.
                SpotlightIndexState.remove()
                #if DEBUG
                print("SpotlightIndexService: Error: \(error)")
                #endif
            }
        }
    }

    private static func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = tail
        tail = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    /// Lo que tiene que haber en el índice según el store de ahora.
    static func desiredEntries(context: ModelContext) throws -> [SpotlightEntry] {
        let spotlightContext = currentContext()
        guard !spotlightContext.isGroupsFocusedShell else { return [] }
        let accounts = SiriFinanceSnapshotStore.read(from: SiriFinanceSnapshotStore.sharedDefaults)?.accounts ?? []
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        let pendingDeletion = RecordPendingDeletion.shared
        let inputs = transactions.map { tx in
            SpotlightIndexLogic.TransactionInput(
                recordToken: SpotlightRecordLink.token(for: tx.persistentModelID),
                date: tx.date,
                amount: tx.amount,
                currencyCode: tx.currencyCode,
                note: tx.note,
                categoryName: tx.category?.name,
                subcategoryName: tx.subcategory?.name,
                accountName: tx.account?.name,
                tagNames: (tx.tags ?? []).map(\.name),
                isIncome: TransactionClassificationLogic.isIncome(tx),
                isTransfer: tx.transferPairID != nil,
                isBalanceAdjustment: tx.balanceAdjustmentType != nil,
                accountExcludedFromStatistics: tx.account?.excludeFromStatistics ?? false,
                isGroupBridged: tx.splitExpenseID != nil || tx.splitSettlementID != nil,
                isPendingDeletion: pendingDeletion.hides(tx.persistentModelID, transferPairID: tx.transferPairID)
            )
        }
        return SpotlightIndexLogic.entries(
            accounts: accounts, transactions: inputs, context: spotlightContext, presentation: presentation())
    }

    static func currentContext() -> SpotlightIndexLogic.Context {
        SpotlightIndexLogic.Context(
            // Un gate de visibilidad lee la shell, no el eje (`swiftui-ds.md`, «Solo grupos» tiene dos orígenes).
            isGroupsFocusedShell: SessionState.shared.isGroupsFocusedShell,
            isExpensesOnlyMode: SessionState.shared.isExpensesOnlyMode,
            includeGroupTransactions: UserDefaults.standard.object(
                forKey: AppPreferences.Keys.includeGroupTransactionsInFeed) as? Bool ?? true
        )
    }

    private static func presentation() -> SpotlightIndexLogic.Presentation {
        SpotlightIndexLogic.Presentation(
            untitledTransaction: String(localized: "spotlight.transaction.untitled"),
            accountKind: String(localized: "spotlight.account.kind"),
            formatAmount: { amount, code in amount.formatted(.currency(code: code)) },
            formatDate: { $0.formatted(date: .abbreviated, time: .omitted) }
        )
    }

    private static func searchableItem(_ entry: SpotlightEntry) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = entry.title
        attributes.contentDescription = entry.detail
        attributes.keywords = entry.keywords
        if let date = entry.date {
            attributes.contentCreationDate = date
        }
        let item = CSSearchableItem(
            uniqueIdentifier: entry.identifier,
            domainIdentifier: entry.kind == .account ? accountsDomain : transactionsDomain,
            attributeSet: attributes)
        // Sin caducidad: el índice lo mantiene la app, no el reloj.
        item.expirationDate = .distantFuture
        // La cuenta es la misma entidad que Siri ya conoce («¿cuánto tengo en mi BCP?», «abre mi BCP»).
        if let accountID = entry.accountID {
            item.associateAppEntity(
                YalaAccountEntity(id: accountID, name: entry.title, currencyCodes: entry.accountCurrencyCodes))
        }
        return item
    }
}

// MARK: - Lo que la app dejó en el índice

/// Identificador → huella de lo que la app indexó la última vez, en un fichero de Application Support. Sin fichero, la
/// app no sabe qué hay en el índice y lo rehace entero.
@MainActor
enum SpotlightIndexState {
    private struct Stored: Codable {
        let version: Int
        let entries: [String: String]
    }

    static var fileURL: URL? {
        do {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return base.appending(path: "spotlight-index-state.json")
        } catch {
            #if DEBUG
            print("SpotlightIndexState: Error: \(error)")
            #endif
            return nil
        }
    }

    static func read() -> [String: String]? {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let stored = try JSONDecoder().decode(Stored.self, from: Data(contentsOf: url))
            return stored.version == 1 ? stored.entries : nil
        } catch {
            #if DEBUG
            print("SpotlightIndexState: Error: \(error)")
            #endif
            return nil
        }
    }

    static func write(_ entries: [String: String]) {
        guard let url = fileURL else { return }
        do {
            try JSONEncoder().encode(Stored(version: 1, entries: entries)).write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("SpotlightIndexState: Error: \(error)")
            #endif
        }
    }

    static func remove() {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("SpotlightIndexState: Error: \(error)")
            #endif
        }
    }
}
