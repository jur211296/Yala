//
//  InboxViewModel.swift
//  Yala
//
//  ViewModel para InboxView - maneja drafts de transacciones.
//  Refactor D.8: @Query → ViewModel
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Filter Type

enum InboxFilter: String, CaseIterable {
    case pending
    /// «De tu IA» («Conecta tu IA», decisión D9): los pendientes que apuntó una IA. Se comporta como «Pendientes».
    case fromAI
    case archived

    /// Pendientes y su subconjunto: deslizar, guardar los listos y las acciones de pendientes valen en los dos.
    var isPendingList: Bool { self != .archived }

    var displayName: String {
        switch self {
        case .pending:
            return L10n.Inbox.pending
        case .fromAI:
            return L10n.ConectaTuIA.filterFromAI
        case .archived:
            return L10n.Inbox.archived
        }
    }

    var icon: String {
        switch self {
        case .pending:
            return "tray.full"
        case .fromAI:
            return "sparkles"
        case .archived:
            return "archivebox"
        }
    }
}

@MainActor
@Observable
final class InboxViewModel {
    /// Cuántos borradores ya resueltos (archivados y descartados) lee la lista como mucho. Los pendientes no tienen tope.
    static let resolvedDraftsLimit = 500


    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allDrafts: [InboxDraft] = []
    private(set) var pendingDrafts: [InboxDraft] = []
    /// Gastos de grupo pendientes sin su grupo en este teléfono: se les ofrece «Quitar de aquí»
    /// (`InboxGroupDraftsHiddenHere`).
    private(set) var hideableHereIDs: Set<PersistentIdentifier> = []
    /// Divisa del gasto de grupo de cada borrador que no tiene cuenta, por `splitExpenseID` (`InboxDraftDisplayCurrencyLogic`).
    private(set) var groupExpenseCurrencies: [String: String] = [:]
    /// Gastos de grupo a los que les sobra un borrador «Elige cuenta» o un «Préstamo a grupos» repetido
    /// (`GroupBridgeLeftoversNotice`, bug del 2026-11-09).
    private(set) var groupLeftoverCount = 0
    /// Borradores que la Bandeja ya quitó de la lista y que se borran o descartan después de la animación
    /// (`InboxView.removeDraftWithAnimation`). Una recarga en esa espera —la del borrado anterior, un `dataVersion`— no
    /// los devuelve: su fila volvería a montarse y leería el `InboxDraft` cuando se borre (crash de TestFlight 2.2 (2),
    /// card f8rj). Registros y Pagos planificados esconden igual lo que espera (`RecordPendingDeletion`).
    @ObservationIgnored private var pendingRemovalIDs: Set<PersistentIdentifier> = []
    /// «¿Es el mismo gasto?» (Bandeja sin duplicados, lote 3): las parejas de pendientes que pueden ser el mismo consumo.
    private(set) var sameExpensePairs: [InboxSameExpensePair] = []
    /// «Ya registrado» (lote 3): por pendiente, el registro ya guardado que se le parece, con el criterio que frena al
    /// guardar (`InboxDuplicateCheck`).
    private(set) var alreadyRecorded: [PersistentIdentifier: InboxAlreadyRecorded] = [:]
    /// «¿Es tu pago X?» (lote 4): los pendientes que pueden ser un pago planificado y no se unieron solos al llegar.
    private(set) var plannedQuestions: [InboxPlannedQuestion] = []
    /// Dónde vive lo marcado como «Son distintos» (`InboxSameExpenseDistinct`) y «No es ese pago»
    /// (`InboxPlannedDistinct`). Las pruebas pasan uno aislado.
    @ObservationIgnored var distinctDefaults: UserDefaults = .standard

    // MARK: - Setup

    func setContext(_ context: ModelContext) {
        let isNewContext = self.modelContext !== context
        self.modelContext = context
        // Puente síncrono para que la capa de servicio pode filas antes de borrar (crash iOS 27,
        // ver InboxRowPruneCoordinator). weak: se libera solo al cerrarse el Inbox.
        InboxRowPruneCoordinator.shared.viewModel = self
        if isNewContext { loadData() }
    }

    func loadData() {
        loadAllDrafts()
        loadPendingDrafts()
        loadHideableHere()
        loadGroupExpenseCurrencies()
        loadGroupLeftovers()
        loadSameExpensePairs()
        loadPlannedQuestions()
        loadAlreadyRecorded()
        LoadTimeMarks.ready(.inbox)
    }

    // MARK: - Bandeja sin duplicados, lote 3

    /// Las parejas «¿Es el mismo gasto?» de los pendientes de ahora. Sin leer nada más: el emparejador trabaja sobre lo
    /// que cada borrador ya guarda.
    private func loadSameExpensePairs(calendar: Calendar = .current) {
        var drafts: [InboxDraft] = []
        var entries: [InboxSameExpensePairing.Entry] = []
        for draft in pendingDrafts where draft.isReadableInInbox {
            guard let consumption = InboxArrivalJoin.consumption(of: draft) else { continue }
            let isPlain: Bool
            if case .none = InboxJoinRecord.read(draft.joinRecordRaw) { isPlain = true } else { isPlain = false }
            entries.append(InboxSameExpensePairing.Entry(
                consumption: consumption, isPlain: isPlain, createdAt: draft.createdAt,
                key: InboxSameExpenseDistinct.draftKey(of: draft)))
            drafts.append(draft)
        }
        let pairs = InboxSameExpensePairing.pairs(
            entries, distinct: InboxSameExpenseDistinct.pairs(distinctDefaults), calendar: calendar
        ).map { InboxSameExpensePair(holder: drafts[$0.holder], arriving: drafts[$0.arriving]) }
        if pairs != sameExpensePairs { sameExpensePairs = pairs }
    }

    /// «¿Es tu pago X?» (lote 4): cada pendiente de una fuente que avisa de un cargo, solo o con lo que ya tiene unido, frente
    /// a los pagos planificados. Lo que casa fuerte se unió al llegar; aquí queda lo dudoso (la primera vez que un comercio
    /// casa, un fijo con otro importe) y lo fuerte de antes de esta función. Uno a uno, sin lo que ya va en «¿Es el mismo
    /// gasto?» ni lo contestado con «No». Una lectura que falla no pregunta nada.
    private func loadPlannedQuestions(calendar: Calendar = .current) {
        guard let context = modelContext else { return }
        let paired = Set(sameExpensePairs.flatMap { [$0.holder.persistentModelID, $0.arriving.persistentModelID] })
        let readable = pendingDrafts.filter(\.isReadableInInbox)
        var drafts: [InboxDraft] = []
        var arrivals: [BandejaPlanificadoMatchLogic.Arrival] = []
        for draft in readable where !paired.contains(draft.persistentModelID) {
            guard InboxArrivalJoin.matchSource(of: draft) != nil,
                  let consumption = InboxArrivalJoin.consumption(of: draft) else { continue }
            drafts.append(draft)
            arrivals.append(BandejaPlanificadoMatchLogic.Arrival(consumption))
        }
        var found: [InboxPlannedQuestion] = []
        if !arrivals.isEmpty {
            var targets = InboxPlannedTargets(pending: readable, context: context, calendar: calendar)
            let all = targets.all()
            let answered = InboxPlannedDistinct.pairs(distinctDefaults)
            let questions = BandejaPlanificadoMatchLogic.questions(
                arrivals: arrivals, planned: all.map(\.planned),
                excluded: { index, paymentID in
                    answered.contains(InboxPlannedDistinct.pairKey(
                        draftKey: InboxSameExpenseDistinct.draftKey(of: drafts[index]), paymentID: paymentID))
                },
                calendar: calendar)
            for question in questions {
                guard let target = all.first(where: { $0.planned.paymentID == question.paymentID }) else { continue }
                let plannedDraft = target.draft.flatMap { paired.contains($0.persistentModelID) ? nil : $0 }
                found.append(InboxPlannedQuestion(arriving: drafts[question.arrival], target: target,
                                                  plannedDraft: plannedDraft))
            }
        }
        if found != plannedQuestions { plannedQuestions = found }
    }

    /// «Ya registrado»: lo que «Guardar los listos» dejaría pendiente por posible duplicado, dicho en la fila. Una lectura
    /// que falla no avisa de nada, como deslizar para guardar.
    private func loadAlreadyRecorded() {
        guard let context = modelContext else { return }
        var found: [PersistentIdentifier: InboxAlreadyRecorded] = [:]
        for draft in pendingDrafts where draft.isReadableInInbox && !draft.isFromGroup && !draft.requiresApprovalForm
            && !draft.isSettlementAmountChangeNotice {
            do {
                guard let twin = try InboxDuplicateCheck.possibleDuplicate(of: draft, in: context) else { continue }
                found[draft.persistentModelID] = InboxAlreadyRecorded(
                    dateText: InboxDuplicateCheck.twinDateText(twin.date),
                    summary: InboxDuplicateCheck.twinSummary(twin))
            } catch {
                #if DEBUG
                print("InboxViewModel: Error checking already recorded: \(error)")
                #endif
            }
        }
        if found != alreadyRecorded { alreadyRecorded = found }
    }

    func alreadyRecorded(for draft: InboxDraft) -> InboxAlreadyRecorded? {
        alreadyRecorded[draft.persistentModelID]
    }

    /// La lista por días, con las parejas «¿Es el mismo gasto?» juntas en una tarjeta si `pairsSameExpense` (filtro
    /// «Pendientes», fuera del modo selección). La tarjeta va en el día del más reciente; un borrador que ya no está en la
    /// lista (podado, borrado) deshace su pareja.
    func listSections(for filter: InboxFilter, pairsSameExpense: Bool) -> [InboxListSection] {
        let filtered = filteredDrafts(for: filter)
        let present = Set(filtered.map(\.persistentModelID))
        var paired: Set<PersistentIdentifier> = []
        var items: [InboxListItem] = []
        if pairsSameExpense {
            for pair in sameExpensePairs where pair.holder.isReadableInInbox && pair.arriving.isReadableInInbox
                && present.contains(pair.holder.persistentModelID) && present.contains(pair.arriving.persistentModelID) {
                paired.insert(pair.holder.persistentModelID)
                paired.insert(pair.arriving.persistentModelID)
                items.append(.pair(pair))
            }
        }
        if pairsSameExpense {
            for question in plannedQuestions where question.arriving.isReadableInInbox
                && present.contains(question.arriving.persistentModelID)
                && !paired.contains(question.arriving.persistentModelID) {
                paired.insert(question.arriving.persistentModelID)
                var shown = question
                if let planned = question.plannedDraft {
                    if planned.isReadableInInbox, present.contains(planned.persistentModelID),
                       !paired.contains(planned.persistentModelID) {
                        paired.insert(planned.persistentModelID)
                    } else {
                        shown = question.withoutPlannedDraft
                    }
                }
                items.append(.planned(shown))
            }
        }
        items += filtered.filter { !paired.contains($0.persistentModelID) }.map(InboxListItem.draft)
        return InboxListSection.grouped(items)
    }

    private func loadGroupLeftovers() {
        guard let context = modelContext else { return }
        do {
            let count = try GroupBridgeRaceCleaner.leftovers(in: context, since: nil).plan.expenseIDs.count
            if count != groupLeftoverCount { groupLeftoverCount = count }
        } catch {
            #if DEBUG
            print("InboxViewModel: Error loading group leftovers: \(error)")
            #endif
        }
    }

    /// La divisa con la que se pinta el importe de un borrador en la Bandeja.
    func displayCurrencyCode(for draft: InboxDraft, fallback: String) -> String {
        InboxDraftDisplayCurrencyLogic.currency(
            draftCurrency: draft.displayCurrencyCode,
            groupExpenseCurrency: draft.splitExpenseID.flatMap { groupExpenseCurrencies[$0] },
            fallback: fallback)
    }

    /// Un borrador de gasto de grupo sin cuenta no sabe su divisa: la del gasto del que viene (bug del 2026-11-09).
    private func loadGroupExpenseCurrencies() {
        guard let context = modelContext else { return }
        let ids = InboxDraftDisplayCurrencyLogic.groupExpenseIDsNeedingCurrency(
            allDrafts.map { ($0.splitExpenseID, $0.displayCurrencyCode) })
        guard !ids.isEmpty else {
            if !groupExpenseCurrencies.isEmpty { groupExpenseCurrencies = [:] }
            return
        }
        do {
            let expenses = try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { ids.contains($0.id) }))
            var map: [String: String] = [:]
            for expense in expenses { map[expense.id.uuidString] = expense.currencyCode }
            if map != groupExpenseCurrencies { groupExpenseCurrencies = map }
        } catch {
            #if DEBUG
            print("InboxViewModel: Error loading group expense currencies: \(error)")
            #endif
        }
    }

    /// Qué borradores pendientes se pueden quitar de la Bandeja solo aquí.
    private func loadHideableHere() {
        guard let context = modelContext else { return }
        let ids = InboxGroupDraftsHiddenHere.hideableIDs(in: pendingDrafts, context: context)
        if ids != hideableHereIDs { hideableHereIDs = ids }
    }

    func canHideHere(_ draft: InboxDraft) -> Bool {
        hideableHereIDs.contains(draft.persistentModelID)
    }

    private func loadAllDrafts() {
        guard let context = modelContext else { return }

        // Los pendientes, TODOS; el tope de 500 es solo para lo ya resuelto (archivados y descartados). Con un tope
        // común, un pendiente creado antes de los 500 más recientes no salía en la lista ni en su contador mientras la
        // app seguía creyendo que había pendientes (lote 03 de las necesarias 2.3).
        let pendingRaw = DraftStatus.pending.rawValue
        let pendingDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.statusRaw == pendingRaw },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        var resolvedDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.statusRaw != pendingRaw },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        resolvedDescriptor.fetchLimit = Self.resolvedDraftsLimit

        do {
            let merged = InboxDraftListMerge.newestFirst(
                pending: try context.fetch(pendingDescriptor),
                resolved: try context.fetch(resolvedDescriptor)
            )
            // Sin los gastos de grupo quitados de la Bandeja en este teléfono (`InboxGroupDraftsHiddenHere`).
            let fetched = withoutPendingRemovals(
                InboxGroupDraftsHiddenHere.visible(merged, context: context)
            )
            if fetched != allDrafts { allDrafts = fetched }
        } catch {
            #if DEBUG
            print("InboxViewModel: Error loading all drafts: \(error)")
            #endif
        }
    }

    private func loadPendingDrafts() {
        guard let context = modelContext else { return }

        var descriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.statusRaw == "pending" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200

        do {
            let fetched = withoutPendingRemovals(
                InboxGroupDraftsHiddenHere.visible(try context.fetch(descriptor), context: context)
            )
            if fetched != pendingDrafts { pendingDrafts = fetched }
        } catch {
            #if DEBUG
            print("InboxViewModel: Error loading pending drafts: \(error)")
            #endif
        }
    }

    private func withoutPendingRemovals(_ drafts: [InboxDraft]) -> [InboxDraft] {
        guard !pendingRemovalIDs.isEmpty else { return drafts }
        return drafts.filter { !pendingRemovalIDs.contains($0.persistentModelID) }
    }

    /// Lo que la lista puede leer: un borrador borrado por otro camino (sincronización, un servicio en segundo plano)
    /// sigue en el array cacheado hasta la próxima recarga, y leer cualquiera de sus propiedades tumba la app.
    private var readableDrafts: [InboxDraft] {
        allDrafts.filter(\.isReadableInInbox)
    }

    // MARK: - Computed Properties

    func filteredDrafts(for filter: InboxFilter) -> [InboxDraft] {
        switch filter {
        case .pending:
            return readableDrafts.filter { $0.status == .pending }
        case .fromAI:
            return readableDrafts.filter { $0.status == .pending && $0.sourceType == .aiConnector }
        case .archived:
            // Only show archived drafts that have cached values (to avoid crashes from invalid relationships),
            // plus rejected settlement drafts, which never had an account (`InboxDraft.isShownInArchive`).
            return readableDrafts.filter(\.isShownInArchive)
        }
    }

    /// Drafts grouped by transaction date (effectiveDate), sorted newest first
    func groupedDrafts(for filter: InboxFilter) -> [(date: Date, drafts: [InboxDraft])] {
        let filtered = filteredDrafts(for: filter)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { draft in
            calendar.startOfDay(for: draft.effectiveDate)
        }
        return grouped
            .map { (date: $0.key, drafts: $0.value.sorted {
                if $0.effectiveDate == $1.effectiveDate { return $0.createdAt > $1.createdAt }
                return $0.effectiveDate > $1.effectiveDate
            }) }
            .sorted { $0.date > $1.date }
    }

    /// ¿Alguna IA apuntó algo en este teléfono (pendiente o ya resuelto)? Apaga la puerta de «Conecta tu IA».
    var hasAnyAIDraft: Bool {
        readableDrafts.contains { $0.sourceType == .aiConnector }
    }

    func countForFilter(_ filter: InboxFilter) -> Int {
        switch filter {
        case .pending:
            return readableDrafts.count(where: { $0.status == .pending })
        case .fromAI:
            return readableDrafts.count(where: { $0.status == .pending && $0.sourceType == .aiConnector })
        case .archived:
            return readableDrafts.count(where: \.isShownInArchive)
        }
    }

    // MARK: - Draft Lookup

    func findPendingDraft(by id: PersistentIdentifier) -> InboxDraft? {
        pendingDrafts.first { $0.persistentModelID == id }
    }

    /// Returns the oldest pending draft (last in array, sorted newest-first)
    func firstPendingDraft() -> InboxDraft? {
        pendingDrafts.last
    }

    func removeDraft(_ draft: InboxDraft) {
        removeDraft(id: draft.persistentModelID)
    }

    /// Quita la fila de un borrador que se va a borrar o descartar DESPUÉS (tras la animación), y la deja fuera de toda
    /// recarga hasta `endRemoval(id:)`.
    func beginRemoval(_ draft: InboxDraft) {
        pendingRemovalIDs.insert(draft.persistentModelID)
        removeDraft(id: draft.persistentModelID)
    }

    /// El borrado o descarte diferido terminó (con éxito o no): la próxima recarga vuelve a enseñar lo que siga en la
    /// base — un descartado, en Archivados; uno que no se pudo borrar, en su sitio.
    func endRemoval(id: PersistentIdentifier) {
        pendingRemovalIDs.remove(id)
    }

    /// Poda una fila del array cacheado por su id persistente. Usado por el
    /// `InboxRowPruneCoordinator` desde la capa de servicio para desmontar la fila ANTES de que
    /// `context.delete` invalide el @Model (evita el SIGTRAP de SwiftData en iOS 27). Idempotente.
    func removeDraft(id: PersistentIdentifier) {
        allDrafts.removeAll { $0.persistentModelID == id }
        pendingDrafts.removeAll { $0.persistentModelID == id }
    }

    var hasPendingDrafts: Bool {
        !pendingDrafts.isEmpty
    }

    // MARK: - Pure Logic Functions (for testing)

    /// Filter drafts by status (testable without SwiftData)
    func filterDrafts(
        statuses: [DraftStatus],
        cachedAccountNames: [String?],
        for filter: InboxFilter
    ) -> [Int] {
        var result: [Int] = []
        for i in 0..<statuses.count {
            let status = statuses[i]
            let cachedName = cachedAccountNames[i]

            switch filter {
            case .pending, .fromAI:
                if status == .pending {
                    result.append(i)
                }
            case .archived:
                if (status == .approved || status == .rejected) && cachedName != nil {
                    result.append(i)
                }
            }
        }
        return result
    }

    /// Count drafts by filter (testable without SwiftData)
    func countDrafts(statuses: [DraftStatus], for filter: InboxFilter) -> Int {
        switch filter {
        case .pending, .fromAI:
            return statuses.count(where: { $0 == .pending })
        case .archived:
            return statuses.count(where: { $0 == .approved || $0 == .rejected })
        }
    }

    /// Group drafts by date (testable without SwiftData)
    func groupDraftsByDate(dates: [Date], indices: [Int]) -> [(date: Date, indices: [Int])] {
        guard !dates.isEmpty else { return [] }

        let calendar = Calendar.current
        var grouped: [Date: [Int]] = [:]

        for i in 0..<dates.count {
            let dayStart = calendar.startOfDay(for: dates[i])
            grouped[dayStart, default: []].append(indices[i])
        }

        return grouped
            .map { (date: $0.key, indices: $0.value) }
            .sorted { $0.date > $1.date }
    }
}

extension InboxDraft {
    /// Se puede leer sin tumbar la app: ni marcado para borrar en su contexto ni ya borrado y guardado (sin contexto).
    /// SwiftData aborta (`_assertionFailure`) al leer una propiedad de un modelo borrado, y una fila de la Bandeja puede
    /// volver a pintarse con su borrador ya borrado (card f8rj; mismo molde que `BudgetDetailView.isBudgetValid`).
    var isReadableInInbox: Bool {
        !isDeleted && modelContext != nil
    }
}

/// La lista de la Bandeja junta dos lecturas: todos los pendientes y los resueltos más recientes. Mismo orden que la
/// lectura única de antes: lo más nuevo primero.
enum InboxDraftListMerge {
    static func newestFirst(pending: [InboxDraft], resolved: [InboxDraft]) -> [InboxDraft] {
        (pending + resolved).sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Bandeja sin duplicados, lote 3: lo que pinta la lista

/// Dos pendientes que pueden ser el mismo consumo: «¿Es el mismo gasto?». `holder` es el que se queda con «Es el mismo»
/// (el que llegó primero, o el que ya tenía algo unido) y `arriving` el que se une a él.
struct InboxSameExpensePair: Identifiable, Equatable {
    struct ID: Hashable {
        let holder: PersistentIdentifier
        let arriving: PersistentIdentifier
    }

    let holder: InboxDraft
    let arriving: InboxDraft

    var id: ID { ID(holder: holder.persistentModelID, arriving: arriving.persistentModelID) }

    /// Los dos, del más antiguo al más reciente por su fecha: así se leen en la tarjeta.
    var chronological: [InboxDraft] {
        holder.effectiveDate <= arriving.effectiveDate ? [holder, arriving] : [arriving, holder]
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// «Ya registrado el 15 oct»: el registro guardado que se parece a un pendiente, ya en texto (se lee al cargar: el
/// registro puede borrarse con la lista abierta).
struct InboxAlreadyRecorded: Equatable {
    let dateText: String
    let summary: String
}

enum InboxListItem: Identifiable {
    case draft(InboxDraft)
    case pair(InboxSameExpensePair)
    /// Lote 4: «¿Es tu pago X?».
    case planned(InboxPlannedQuestion)

    enum ID: Hashable {
        case draft(PersistentIdentifier)
        case pair(InboxSameExpensePair.ID)
        case planned(InboxPlannedQuestion.ID)
    }

    var id: ID {
        switch self {
        case .draft(let draft): .draft(draft.persistentModelID)
        case .pair(let pair): .pair(pair.id)
        case .planned(let question): .planned(question.id)
        }
    }

    /// La fecha que decide su día y su orden: la del borrador, o la del más reciente de la pareja.
    var sortDate: Date {
        switch self {
        case .draft(let draft): draft.effectiveDate
        case .pair(let pair): max(pair.holder.effectiveDate, pair.arriving.effectiveDate)
        case .planned(let question): question.drafts.map(\.effectiveDate).max() ?? question.arriving.effectiveDate
        }
    }

    var sortCreatedAt: Date {
        switch self {
        case .draft(let draft): draft.createdAt
        case .pair(let pair): max(pair.holder.createdAt, pair.arriving.createdAt)
        case .planned(let question): question.drafts.map(\.createdAt).max() ?? question.arriving.createdAt
        }
    }
}

struct InboxListSection {
    let date: Date
    let items: [InboxListItem]

    /// Por día, lo más nuevo primero; el mismo orden que `groupedDrafts`.
    static func grouped(_ items: [InboxListItem], calendar: Calendar = .current) -> [InboxListSection] {
        Dictionary(grouping: items) { calendar.startOfDay(for: $0.sortDate) }
            .map { day, items in
                InboxListSection(date: day, items: items.sorted {
                    if $0.sortDate == $1.sortDate { return $0.sortCreatedAt > $1.sortCreatedAt }
                    return $0.sortDate > $1.sortDate
                })
            }
            .sorted { $0.date > $1.date }
    }
}

/// Qué pendientes se preguntan «¿Es el mismo gasto?». Pura: la fijan `BandejaFilaConFuentesTests`.
///
/// Solo entre pendientes de fuentes que avisan de un cargo (las del emparejador), y al menos uno de los dos sin nada unido:
/// ese es el que se une al otro. Con los dos sin unir, se une el más reciente. Lo dudoso y lo fuerte se preguntan (lo
/// fuerte que no se unió al llegar es de antes de la unión, o de dos aparatos a la vez): en la lista nunca se une solo.
/// Uno a uno, la mejor pareja primero: la más fuerte, la más cercana en el tiempo y en el importe.
nonisolated enum InboxSameExpensePairing {
    struct Entry: Sendable {
        let consumption: InboxMatchLogic.Consumption
        /// Sin nada unido: puede unirse a otro con «Es el mismo».
        let isPlain: Bool
        let createdAt: Date
        /// `InboxSameExpenseDistinct.draftKey`.
        let key: String
    }

    struct Pair: Equatable, Sendable {
        /// Índices en las entradas.
        let holder: Int
        let arriving: Int
        let level: InboxMatchLogic.Level
    }

    static func pairs(_ entries: [Entry], distinct: Set<String>, calendar: Calendar = .current) -> [Pair] {
        var options: [(pair: Pair, comparison: InboxMatchLogic.Comparison, createdAt: Date)] = []
        for first in entries.indices {
            for second in entries.indices where second > first {
                let a = entries[first]
                let b = entries[second]
                guard a.isPlain || b.isPlain else { continue }
                guard !distinct.contains(InboxSameExpenseDistinct.pairKey(a.key, b.key)) else { continue }
                // Se une el que no tiene nada unido; si ninguno lo tiene, el más reciente.
                let arriving: Int
                if a.isPlain && b.isPlain {
                    arriving = a.createdAt > b.createdAt ? first : second
                } else {
                    arriving = a.isPlain ? first : second
                }
                let holder = arriving == first ? second : first
                let comparison = InboxMatchLogic.compare(
                    entries[arriving].consumption.holder, with: entries[holder].consumption, calendar: calendar)
                guard comparison.level > .none else { continue }
                options.append((Pair(holder: holder, arriving: arriving, level: comparison.level), comparison,
                                entries[holder].createdAt))
            }
        }
        options.sort { lhs, rhs in
            if lhs.comparison.level != rhs.comparison.level { return lhs.comparison.level > rhs.comparison.level }
            if lhs.comparison.timeGap != rhs.comparison.timeGap { return lhs.comparison.timeGap < rhs.comparison.timeGap }
            if lhs.comparison.amountGap != rhs.comparison.amountGap {
                return lhs.comparison.amountGap < rhs.comparison.amountGap
            }
            return lhs.createdAt < rhs.createdAt
        }
        var used: Set<Int> = []
        var chosen: [Pair] = []
        for option in options where !used.contains(option.pair.holder) && !used.contains(option.pair.arriving) {
            used.insert(option.pair.holder)
            used.insert(option.pair.arriving)
            chosen.append(option.pair)
        }
        return chosen
    }
}

/// «Son distintos» y «Separar»: las parejas que la persona ya dijo que no son el mismo gasto, para no volver a preguntar.
///
/// **Solo en este teléfono, a propósito** (Paso 0, D4): un campo sincronizado pediría otra migración. Vive en
/// `UserDefaults.standard` sin prefijo de preferencias sincronizadas, como «Quitar de aquí»
/// (`InboxGroupDraftsHiddenHere`), y lo retira el borrado de datos (`DataWipeService.removeRowDerivedKeys`). Cada
/// borrador se reconoce por su origen y su instante de llegada: el `syncID` puede llegar después, y «Separar» devuelve a
/// cada fuente su instante de llegada.
@MainActor
enum InboxSameExpenseDistinct {
    nonisolated static let key = "inbox.sameExpenseDistinctPairs"
    /// Las más recientes que se guardan: una pareja vieja ya no está en la Bandeja.
    nonisolated static let limit = 300

    nonisolated static func draftKey(sourceTypeRaw: String, createdAt: Date) -> String {
        "\(sourceTypeRaw)@\(Int64((createdAt.timeIntervalSinceReferenceDate * 1000).rounded()))"
    }

    static func draftKey(of draft: InboxDraft) -> String {
        draftKey(sourceTypeRaw: draft.sourceTypeRaw, createdAt: draft.createdAt)
    }

    nonisolated static func pairKey(_ a: String, _ b: String) -> String {
        a < b ? "\(a)|\(b)" : "\(b)|\(a)"
    }

    static func pairs(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Marca como distintos a todos los de `drafts` entre sí (dos con «Son distintos»; el borrador y lo que se separó de
    /// él con «Separar»).
    static func markDistinct(_ drafts: [InboxDraft], _ defaults: UserDefaults = .standard) {
        let keys = drafts.filter(\.isReadableInInbox).map(draftKey(of:))
        guard keys.count >= 2 else { return }
        var stored = defaults.stringArray(forKey: key) ?? []
        for first in keys.indices {
            for second in keys.indices where second > first {
                let pair = pairKey(keys[first], keys[second])
                stored.removeAll { $0 == pair }
                stored.append(pair)
            }
        }
        defaults.set(Array(stored.suffix(limit)), forKey: key)
    }
}

// MARK: - Bandeja sin duplicados, lote 4: «¿Es tu pago X?»

/// Un pendiente que puede ser un pago planificado: «¿Es tu pago «Luz del Sur»?» con «Sí, es ese pago» y «No es ese pago».
/// Los textos del planificado se leen al cargar (el planificado puede cambiar con la lista abierta).
struct InboxPlannedQuestion: Identifiable, Equatable {
    struct ID: Hashable {
        let arriving: PersistentIdentifier
        let paymentID: UUID
    }

    let arriving: InboxDraft
    /// El borrador pendiente del planificado, si ya lo tiene y no va en otra tarjeta: se enseña junto al que llega.
    let plannedDraft: InboxDraft?
    let paymentID: UUID
    let paymentName: String
    /// «S/ 120.00 estimado · vence el 15 nov», para cuando el planificado aún no tiene borrador.
    let plannedDetail: String

    var id: ID { ID(arriving: arriving.persistentModelID, paymentID: paymentID) }

    /// Los borradores de la tarjeta, del más antiguo al más reciente por su fecha.
    var drafts: [InboxDraft] {
        [arriving, plannedDraft].compactMap { $0 }.sorted { $0.effectiveDate <= $1.effectiveDate }
    }

    var withoutPlannedDraft: InboxPlannedQuestion {
        InboxPlannedQuestion(arriving: arriving, plannedDraft: nil, paymentID: paymentID, paymentName: paymentName,
                             plannedDetail: plannedDetail)
    }

    init(arriving: InboxDraft, plannedDraft: InboxDraft?, paymentID: UUID, paymentName: String, plannedDetail: String) {
        self.arriving = arriving
        self.plannedDraft = plannedDraft
        self.paymentID = paymentID
        self.paymentName = paymentName
        self.plannedDetail = plannedDetail
    }

    @MainActor
    init(arriving: InboxDraft, target: InboxPlannedTargets.Target, plannedDraft: InboxDraft?) {
        let planned = target.planned
        let amount = YalaFormatterStatic.currency(
            value: abs(planned.amount), currencyCode: planned.currencyCode ?? target.payment.currencyCode,
            forceFullPrecision: true)
        self.init(
            arriving: arriving, plannedDraft: plannedDraft, paymentID: planned.paymentID, paymentName: target.payment.name,
            plannedDetail: L10n.BandejaUnir.planificadoDetalle(
                importe: planned.isEstimate ? L10n.BandejaUnir.importeEstimado(amount) : amount,
                fecha: InboxDuplicateCheck.twinDateText(planned.occurrence)))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.plannedDraft?.persistentModelID == rhs.plannedDraft?.persistentModelID
            && lhs.plannedDetail == rhs.plannedDetail && lhs.paymentName == rhs.paymentName
    }
}

/// «No es ese pago» y «Separar» de un planificado: qué pendiente ya se dijo que no es qué pago, para no volver a preguntar.
///
/// **Solo en este teléfono, como «Son distintos»** (`InboxSameExpenseDistinct`, lote 3): un campo sincronizado pediría
/// otra migración. Lo retira el borrado de datos (`DataWipeService.removeRowDerivedKeys`).
@MainActor
enum InboxPlannedDistinct {
    nonisolated static let key = "inbox.plannedDistinctPairs"
    nonisolated static let limit = 300

    nonisolated static func pairKey(draftKey: String, paymentID: UUID) -> String {
        "\(draftKey)|planned:\(paymentID.uuidString)"
    }

    static func pairs(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    static func markDistinct(_ drafts: [InboxDraft], paymentID: UUID, _ defaults: UserDefaults = .standard) {
        let keys = drafts.filter(\.isReadableInInbox).map {
            pairKey(draftKey: InboxSameExpenseDistinct.draftKey(of: $0), paymentID: paymentID)
        }
        guard !keys.isEmpty else { return }
        var stored = defaults.stringArray(forKey: key) ?? []
        for pair in keys {
            stored.removeAll { $0 == pair }
            stored.append(pair)
        }
        defaults.set(Array(stored.suffix(limit)), forKey: key)
    }
}
