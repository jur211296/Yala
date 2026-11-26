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
//  La reconciliación no puede ocupar el hilo principal de una vez (lote 3 de eficiencia, 26-nov-2026): con 16.004
//  movimientos en el iPhone 14 leerlos con sus relaciones costaba ~1,8 s seguidos, y uno de los dos cierres del vigilante
//  de iOS en segundo plano (`0x8BADF00D`) cayó ahí dentro. Ahora lee por tramos, cada uno en un contexto propio que se
//  suelta al terminarlo (sus filas no se quedan vivas en el contexto de la app), y cede el hilo entre tramo y tramo;
//  las entradas, el plan y el estado guardado se calculan fuera del hilo principal. Al pasar a segundo plano se corta lo
//  que esté en vuelo y se olvida su firma, así que la vuelta siguiente reconcilia.
//  Leer los modelos FUERA del hilo principal no se puede: son del main actor (`SWIFT_DEFAULT_ACTOR_ISOLATION`).
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData
import UIKit
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
    /// Movimientos por tramo de lectura. Un tramo de 1.000 con sus relaciones cuesta del orden de 0,1 s en un iPhone 14.
    nonisolated static let readSliceSize = 1_000

    /// Las operaciones con el índice van en fila: un vaciado nunca se cruza con una reconciliación a medias.
    private static var tail: Task<Void, Never>?
    private static var pendingReconcile: Task<Void, Never>?
    /// Sube con cada vaciado: una reconciliación que empezó antes no escribe nada después.
    private static var generation = 0
    /// La reconciliación que está leyendo o calculando (lote 3 de eficiencia). Se cancela con una petición nueva, con
    /// el vaciado y al pasar a segundo plano.
    private static var reconcileTask: Task<Void, Never>?
    /// La app está en segundo plano: no se escribe en el índice hasta volver (`ReconcileSuspension`).
    private(set) static var isSuspendedInBackground = false
    private static var lifecycleObservers: [NSObjectProtocol] = []

    // MARK: - Embudos

    /// Pide una reconciliación. Varias peticiones seguidas se funden en una.
    static func scheduleReconcile(context: ModelContext, delay: Duration = .seconds(2)) {
        guard isEnabled else { return }
        observeLifecycleOnce()
        pendingReconcile?.cancel()
        reconcileTask?.cancel()
        let requestedGeneration = generation
        pendingReconcile = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard requestedGeneration == generation else { return }
            // La petición ya no espera: lo que corre ahora es la reconciliación (`reconcileTask`).
            pendingReconcile = nil
            reconcile(context: context)
        }
    }

    /// Vacía el índice de Yala y olvida lo indexado. Sin guarda: retirar siempre es seguro.
    static func clear() {
        guard isEnabled else { return }
        generation += 1
        pendingReconcile?.cancel()
        pendingReconcile = nil
        reconcileTask?.cancel()
        reconcileTask = nil
        SpotlightIndexState.remove()
        SpotlightAlVolver.olvidar()
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

    // MARK: - Segundo plano (lote 3 de eficiencia)

    /// Al pasar a segundo plano se corta la reconciliación en vuelo y se deja de escribir en el índice; al volver, se
    /// reanuda. Lo cortado olvida su firma (`SpotlightAlVolver`), así que la vuelta reconcilia otra vez.
    private static func observeLifecycleOnce() {
        guard lifecycleObservers.isEmpty else { return }
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { enterBackground() }
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { leaveBackground() }
            }
        ]
    }

    static func enterBackground() {
        isSuspendedInBackground = true
        let decision = ReconcileSuspension.onBackground(
            hasPendingRequest: pendingReconcile != nil, hasReconcileInFlight: reconcileTask != nil)
        if decision.cancels {
            pendingReconcile?.cancel()
            pendingReconcile = nil
            reconcileTask?.cancel()
            reconcileTask = nil
        }
        if decision.forgetsFirma { SpotlightAlVolver.olvidar() }
        #if DEBUG
        if decision.cancels { print("SpotlightIndexService: segundo plano — se corta la reconciliación en vuelo") }
        #endif
    }

    static func leaveBackground() {
        isSuspendedInBackground = false
    }

    // MARK: - Reconciliación

    private static func reconcile(context: ModelContext) {
        guard !WidgetDataCache.isWipeArmed else { return }
        // Lo que lee esta reconciliación: la vuelta a primer plano no repite si nada cambió desde aquí (lote 1 de
        // eficiencia, `SpotlightAlVolver`). Se toma antes de leer: un guardado durante la lectura cuenta como cambio.
        SpotlightAlVolver.anotarReconciliacion(currentFirma())
        let startedGeneration = generation
        reconcileTask?.cancel()
        reconcileTask = Task { @MainActor in
            defer { if startedGeneration == generation, !Task.isCancelled { reconcileTask = nil } }
            let plan: SpotlightIndexLogic.Plan
            do {
                // Por tramos y fuera del hilo principal lo que se puede (lote 3 de eficiencia). Cortada (otra petición,
                // el vaciado, segundo plano), lanza `CancellationError` y olvida la firma como cualquier lectura fallida.
                let desired = try await desiredEntries(context: context)
                try ReconcileSuspension.check(cancelled: Task.isCancelled, generationChanged: startedGeneration != generation)
                plan = await Task.detached(priority: .utility) {
                    SpotlightIndexLogic.plan(desired: desired, indexed: SpotlightIndexState.read())
                }.value
                try ReconcileSuspension.check(cancelled: Task.isCancelled, generationChanged: startedGeneration != generation)
            } catch {
                SpotlightAlVolver.olvidar()
                #if DEBUG
                print("SpotlightIndexService: Error: \(error)")
                #endif
                return
            }
            guard !plan.isEmpty, !WidgetDataCache.isWipeArmed else { return }
            enqueue {
                guard startedGeneration == generation else { return }
                do {
                    if plan.deletesEverythingFirst {
                        try await index.deleteAllSearchableItems()
                    }
                    for chunk in stride(from: 0, to: plan.toDelete.count, by: batchSize) {
                        try ReconcileSuspension.check(suspended: isSuspendedInBackground)
                        try await index.deleteSearchableItems(
                            withIdentifiers: Array(plan.toDelete[chunk..<min(chunk + batchSize, plan.toDelete.count)]))
                    }
                    for chunk in stride(from: 0, to: plan.toIndex.count, by: batchSize) {
                        guard startedGeneration == generation else { return }
                        try ReconcileSuspension.check(suspended: isSuspendedInBackground)
                        // Los elementos de Core Spotlight se arman por tramo, no los 16 mil de una vez.
                        let items = plan.toIndex[chunk..<min(chunk + batchSize, plan.toIndex.count)].map(searchableItem)
                        try await index.indexSearchableItems(items)
                    }
                    guard startedGeneration == generation else { return }
                    SpotlightIndexState.write(plan.resulting)
                } catch {
                    // Sin estado guardado, la próxima vez se vacía y se indexa entero: un índice a medias no se queda.
                    // También si se cortó al pasar a segundo plano.
                    SpotlightIndexState.remove()
                    SpotlightAlVolver.olvidar()
                    #if DEBUG
                    print("SpotlightIndexService: Error: \(error)")
                    #endif
                }
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
    ///
    /// Lee los movimientos por tramos de `readSliceSize`, cada tramo en un contexto propio sobre el mismo almacén (sus
    /// filas se sueltan al terminar el tramo) y cediendo el hilo principal entre uno y otro; lanza `CancellationError`
    /// si la tarea se cancela entre dos tramos. Las entradas se arman fuera del hilo principal. Lo que el contexto de la
    /// app tenga sin guardar no se ve aquí: entra con su guardado, que vuelve a pedir reconciliar (`updateCache`).
    static func desiredEntries(
        context: ModelContext, spotlightContext fixedContext: SpotlightIndexLogic.Context? = nil
    ) async throws -> [SpotlightEntry] {
        // Lo que decide la sesión: el de ahora, salvo que el llamador (un test) fije uno.
        let spotlightContext = fixedContext ?? currentContext()
        guard !spotlightContext.isGroupsFocusedShell else { return [] }
        let accounts = SiriFinanceSnapshotStore.read(from: SiriFinanceSnapshotStore.sharedDefaults)?.accounts ?? []
        let container = context.container
        var inputs: [SpotlightIndexLogic.TransactionInput] = []
        var seen = Set<PersistentIdentifier>()
        var offset = 0
        while true {
            let slice = try readSlice(container: container, offset: offset, seen: &seen)
            inputs.append(contentsOf: slice.inputs)
            guard slice.fetched >= readSliceSize else { break }
            offset += slice.fetched
            // Un milisegundo y no `Task.yield()`: el run loop tiene que atender el paso a segundo plano y los toques
            // entre tramo y tramo (molde de `PanelViewModel.fetchTransactionsInSlices`).
            try await Task.sleep(for: .milliseconds(1))
        }
        let transactions = inputs
        return await Task.detached(priority: .utility) {
            SpotlightIndexLogic.entries(
                accounts: accounts, transactions: transactions, context: spotlightContext, presentation: makePresentation())
        }.value
    }

    /// Un tramo: los movimientos en el orden de siempre desde `offset`, leídos en un contexto que muere al salir. Lo ya
    /// visto en un tramo anterior (un guardado entre dos tramos desplaza las posiciones) se descarta por su identidad.
    private static func readSlice(
        container: ModelContainer, offset: Int, seen: inout Set<PersistentIdentifier>
    ) throws -> (inputs: [SpotlightIndexLogic.TransactionInput], fetched: Int) {
        let sliceContext = ModelContext(container)
        sliceContext.autosaveEnabled = false
        var descriptor = FetchDescriptor<TransactionItem>(sortBy: [
            SortDescriptor(\.date, order: .reverse),
            SortDescriptor(\.createdAt, order: .reverse)
        ])
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = readSliceSize
        descriptor.relationshipKeyPathsForPrefetching = [\.category, \.subcategory, \.account]
        let transactions = try sliceContext.fetch(descriptor)
        let pendingDeletion = RecordPendingDeletion.shared
        var inputs: [SpotlightIndexLogic.TransactionInput] = []
        inputs.reserveCapacity(transactions.count)
        for tx in transactions where seen.insert(tx.persistentModelID).inserted {
            inputs.append(SpotlightIndexLogic.TransactionInput(
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
                // «Oculta su historial» (`Account.keepsHistory`): una cuenta archivada sigue enseñando sus registros.
                accountExcludedFromStatistics: tx.account.map { !$0.keepsHistory } ?? false,
                isGroupBridged: tx.splitExpenseID != nil || tx.splitSettlementID != nil,
                isPendingDeletion: pendingDeletion.hides(tx.persistentModelID, transferPairID: tx.transferPairID)
            ))
        }
        return (inputs, transactions.count)
    }

    /// Lo que decide si la vuelta a primer plano reconcilia (`SpotlightAlVolver`): lo que puede cambiar el índice.
    static func currentFirma() -> SpotlightFirma {
        let context = currentContext()
        return SpotlightFirma(
            dataVersion: SessionState.shared.dataVersion,
            storeSaves: StoreSaveCounter.shared.count,
            isGroupsFocusedShell: context.isGroupsFocusedShell,
            isExpensesOnlyMode: context.isExpensesOnlyMode,
            includeGroupTransactions: context.includeGroupTransactions
        )
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

    /// Los textos del índice. `nonisolated`: se arman en la tarea de fondo que calcula las entradas.
    nonisolated private static func makePresentation() -> SpotlightIndexLogic.Presentation {
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
    nonisolated private struct Stored: Codable {
        let version: Int
        let entries: [String: String]
    }

    nonisolated static var fileURL: URL? {
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

    /// `nonisolated`: la reconciliación lo lee fuera del hilo principal (lote 3 de eficiencia).
    nonisolated static func read() -> [String: String]? {
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

// MARK: - Cortar al pasar a segundo plano (lote 3 de eficiencia)

/// Qué hace la reconciliación de Spotlight con la app en segundo plano. Lógica pura, para los tests.
nonisolated enum ReconcileSuspension {

    struct Decision: Equatable {
        /// Se cancela la petición que espera y la reconciliación que lee o calcula.
        let cancels: Bool
        /// Se olvida la firma de la última reconciliación: la vuelta reconcilia aunque nada haya cambiado.
        let forgetsFirma: Bool
    }

    /// Al pasar a segundo plano: con algo en vuelo, se corta y se olvida la firma; sin nada, no se toca.
    static func onBackground(hasPendingRequest: Bool, hasReconcileInFlight: Bool) -> Decision {
        let inFlight = hasPendingRequest || hasReconcileInFlight
        return Decision(cancels: inFlight, forgetsFirma: inFlight)
    }

    /// Lanza `CancellationError` si la reconciliación tiene que parar.
    static func check(cancelled: Bool = false, generationChanged: Bool = false, suspended: Bool = false) throws {
        if cancelled || generationChanged || suspended { throw CancellationError() }
    }
}
