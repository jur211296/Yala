//
//  RemoteWipeCutTests.swift
//  YalaTests
//
//  El «Vaciar datos» de otro dispositivo, procesado tarde aquí: se va lo que existía al vaciar y se queda lo que se creó
//  después (ticket `late-remote-wipe-signal-also-wipes-rows-created-after-it`).
//

import Foundation
import SwiftData
import Testing
@testable import Yala

// MARK: - La decisión pura

@Suite("Vaciado tardío · el corte: la decisión pura")
struct RemoteWipeCutLogicTests {

    private typealias Logic = RemoteWipeCutLogic
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("sin hora de señal no hay corte: el borrado es entero, como antes")
    func noSignalTime_noCut() {
        #expect(Logic.cut(signaledAt: Date(timeIntervalSince1970: 0), fleetStartedOver: true) == nil)
        #expect(Logic.cut(signaledAt: Date(timeIntervalSince1970: -5), fleetStartedOver: false) == nil)
        #expect(Logic.cut(signaledAt: t0, fleetStartedOver: true) == .init(signaledAt: t0, fleetStartedOver: true))
    }

    @Test("lo fechado se va si existía al vaciar: el mismo instante cuenta como anterior, un milisegundo después no")
    func dated_cutIsInclusive() throws {
        let cut = try #require(Logic.cut(signaledAt: t0, fleetStartedOver: false))
        #expect(Logic.takesDated(createdAt: t0.addingTimeInterval(-3600), cut: cut))
        #expect(Logic.takesDated(createdAt: t0, cut: cut), "la fila del mismo instante que la señal existía al vaciar")
        #expect(!Logic.takesDated(createdAt: t0.addingTimeInterval(0.001), cut: cut),
                "una fila creada después de la señal se borra: es lo que el origen apuntó tras vaciar")
    }

    @Test("un borrador se va por su fecha o por el pago programado del que sale; sin origen, solo por su fecha")
    func draft_goesWithItsScheduledPayment() throws {
        let cut = try #require(Logic.cut(signaledAt: t0, fleetStartedOver: true))
        let after = t0.addingTimeInterval(60)
        #expect(Logic.takesDraft(createdAt: after, sourceScheduledPaymentID: "viejo",
                                 takenScheduledPaymentIDs: ["viejo"], cut: cut),
                "el borrador que el arranque sacó de un pago que se vacía sobrevive a su pago")
        #expect(!Logic.takesDraft(createdAt: after, sourceScheduledPaymentID: "nuevo",
                                  takenScheduledPaymentIDs: ["viejo"], cut: cut))
        #expect(!Logic.takesDraft(createdAt: after, sourceScheduledPaymentID: nil,
                                  takenScheduledPaymentIDs: ["viejo"], cut: cut))
        #expect(Logic.takesDraft(createdAt: t0, sourceScheduledPaymentID: nil, takenScheduledPaymentIDs: [], cut: cut))
    }

    @Test("el parque empezó de nuevo si lo dice la marca o si hay una fila personal posterior a la señal")
    func startedOver_markOrEvidence() throws {
        let marked = try #require(Logic.cut(signaledAt: t0, fleetStartedOver: true))
        let unmarked = try #require(Logic.cut(signaledAt: t0, fleetStartedOver: false))
        #expect(Logic.startedOver(marked, personalRowsCreatedAt: []).fleetStartedOver)
        #expect(Logic.startedOver(unmarked, personalRowsCreatedAt: [t0.addingTimeInterval(1)]).fleetStartedOver,
                "la marca del KV llegó tarde, pero el store ya tiene lo que el origen creó después: empezó de nuevo")
        #expect(!Logic.startedOver(unmarked, personalRowsCreatedAt: [t0, t0.addingTimeInterval(-60)]).fleetStartedOver,
                "lo de antes (o del mismo instante) no prueba que nadie empezara de nuevo")
        #expect(Logic.startedOver(unmarked, personalRowsCreatedAt: [t0.addingTimeInterval(1)]).signaledAt == t0)
    }

    @Test("lo sin fecha, por quién lo usa: lo que se queda manda, luego lo que se va, y sin uso decide el parque")
    func undated_truthTable() throws {
        let restarted = try #require(Logic.cut(signaledAt: t0, fleetStartedOver: true))
        let notRestarted = try #require(Logic.cut(signaledAt: t0, fleetStartedOver: false))
        for cut in [restarted, notRestarted] {
            #expect(!Logic.takesUndated(usedByKept: true, usedByTaken: false, cut: cut))
            #expect(!Logic.takesUndated(usedByKept: true, usedByTaken: true, cut: cut),
                    "una cuenta que usa un gasto que se queda no se va, aunque también la usara uno viejo")
            #expect(!Logic.takesUndated(usedByKept: true, usedByTaken: false, parentTaken: true, cut: cut))
            #expect(Logic.takesUndated(usedByKept: false, usedByTaken: true, cut: cut))
            #expect(Logic.takesUndated(usedByKept: false, usedByTaken: false, parentTaken: true, cut: cut),
                    "la subcategoría sin uso de una categoría que se va se queda suelta")
        }
        #expect(!Logic.takesUndated(usedByKept: false, usedByTaken: false, cut: restarted),
                "con el parque empezado de nuevo, lo no usado es sobre todo la semilla nueva del origen")
        #expect(Logic.takesUndated(usedByKept: false, usedByTaken: false, cut: notRestarted),
                "sin onboarding posterior, lo no usado se va como antes, o la semilla no corre")
    }
}

// MARK: - Contra un store real

@Suite("Vaciado tardío · el corte contra un store real", .serialized, .wipeAppGroupMirrorIsolated)
@MainActor
struct RemoteWipeCutBehaviourTests {

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemoteWipeCut-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("RemoteWipeCutTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "RWC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "RWC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "RWC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        // Sin autosave, como `makeTestContext`: un caso que acaba con cambios sin guardar (un `approveDraft` que lanza
        // deja el borrador tocado) los veía guardar por el temporizador del autosave segundos DESPUÉS, con la carpeta
        // del store ya borrada por `cleanup`, y el fault tumbaba el proceso de tests entero en otra suite (medido el
        // 2026-09-28: `NSCocoaErrorDomain 256` en `GroupsConvergence-…/personal.sqlite` desde `__NSFireTimer`).
        context.autosaveEnabled = false
        return context
    }

    /// El borrado resetea las preferencias de `.standard` (el host de test es la app): se restauran al salir. El App Group
    /// lo cubre el trait de la suite.
    private func withStandardRestored(_ body: () throws -> Void) rethrows {
        let standard = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.yala.app"
        let snapshot = standard.persistentDomain(forName: domain) ?? [:]
        defer { standard.setPersistentDomain(snapshot, forName: domain) }
        try body()
    }

    /// El borrado del receptor, sin tocar el centro de notificaciones ni el contexto de un singleton. Cuenta las veces que
    /// pidió reprogramar los avisos de lo que se queda.
    @discardableResult
    private func receiverWipe(_ context: ModelContext, signaledAt: Date, fleetStartedOver: Bool) throws -> Int {
        var reschedules = 0
        try DataWipeService.wipeLocallyForRemoteWipeSignal(
            in: context, signaledAt: signaledAt, fleetStartedOver: fleetStartedOver,
            rescheduleReminders: { _ in reschedules += 1 })
        return reschedules
    }

    /// La señal, hace una hora. Lo de antes se fecha dos horas atrás; lo de después, hace un minuto.
    private let signaledAt = Date.now.addingTimeInterval(-3600)
    private var before: Date { signaledAt.addingTimeInterval(-3600) }
    private var after: Date { Date.now.addingTimeInterval(-60) }

    private func account(_ context: ModelContext, _ name: String) -> Account {
        let account = Account(name: name, currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash")
        context.insert(account)
        return account
    }

    private func category(_ context: ModelContext, _ name: String, sub subName: String) -> (Yala.Category, Subcategory) {
        let category = Yala.Category(name: name, colorHex: "#222222", isIncome: false)
        context.insert(category)
        let subcategory = Subcategory(name: subName, category: category)
        context.insert(subcategory)
        return (category, subcategory)
    }

    private func tx(_ context: ModelContext, _ amount: Double, createdAt: Date, account: Account?,
                    category: Yala.Category?, subcategory: Subcategory?, tags: [Yala.Tag] = []) -> TransactionItem {
        let tx = TransactionItem(date: createdAt, amount: amount, currencyCode: "USD", note: "gasto \(amount)",
                                 category: category, subcategory: subcategory, account: account, tags: tags)
        tx.createdAt = createdAt
        context.insert(tx)
        return tx
    }

    private func rate(_ context: ModelContext, _ dateKey: String) throws -> ExchangeRate {
        let rate = try ExchangeRate(dateKey: dateKey, base: "USD", ratesDictionary: ["PEN": 3.7])
        context.insert(rate)
        return rate
    }

    private func exists<T: PersistentModel>(_ model: T, in context: ModelContext) throws -> Bool {
        let id = model.persistentModelID
        return try context.fetch(FetchDescriptor<T>()).contains { $0.persistentModelID == id }
    }

    private func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    /// Lo que el History registró después de `mark` sobre esas filas: cualquier cambio, borrado o edición. Es lo que el
    /// espejo exporta, así que «ningún cambio» es «el borrado no viaja al origen».
    private func historyChanges(_ context: ModelContext, after mark: Date,
                                touching ids: Set<PersistentIdentifier>) throws -> Int {
        let transactions = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp > mark }))
        return transactions.flatMap(\.changes).filter { ids.contains($0.changedPersistentIdentifier) }.count
    }

    /// **El caso del ticket.** El iPhone vació sus datos, volvió a empezar —una cuenta nueva, su semilla de categorías— y
    /// apuntó gastos. El iPad, cerrado desde antes, procesa ahora la señal. Tiene lo viejo (lo que el espejo aún no le
    /// borró) y lo nuevo (lo que ya le llegó). Se lleva lo viejo; lo nuevo que se usa se queda entero y sin tocar, así que
    /// su borrado no viaja al iPhone. Con las dos respuestas de la marca «¿alguien terminó el onboarding después?»: con un
    /// gasto nuevo en el store el parque ya empezó de nuevo aunque la marca no haya llegado (viaja por el KV, y las filas
    /// por el espejo), así que la semilla sin usar se queda en las dos.
    @Test("procesada tarde, la señal se lleva lo de antes y deja lo creado después: entero, sin tocarlo",
          arguments: [true, false])
    func lateSignal_keepsWhatWasCreatedAfter_untouched(fleetStartedOver: Bool) throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withStandardRestored {
            // Lo de antes del vaciado.
            let oldAccount = account(context, "Banco viejo")
            let (oldCategory, oldSub) = category(context, "Comida vieja", sub: "Restaurantes viejos")
            let oldTag = Yala.Tag(name: "vieja", createdAt: before)
            context.insert(oldTag)
            let oldTx = tx(context, -10, createdAt: before, account: oldAccount, category: oldCategory, subcategory: oldSub,
                           tags: [oldTag])
            // Una categoría que solo usa un gasto viejo por su campo de categoría, sin subcategoría: con la vida nueva
            // probada, lo no usado se queda, así que solo ese uso la hace irse.
            let oldCategoryOnly = Yala.Category(name: "Solo categoría vieja", colorHex: "#444444", isIncome: false)
            context.insert(oldCategoryOnly)
            _ = tx(context, -3, createdAt: before, account: nil, category: oldCategoryOnly, subcategory: nil)
            // Lo que el origen creó después: una cuenta, su semilla (una categoría con gastos y otra sin usar), una etiqueta.
            let newAccount = account(context, "Banco nuevo")
            let (newCategory, newSub) = category(context, "Comida", sub: "Restaurantes")
            let (seedCategory, seedSub) = category(context, "Ocio", sub: "Cine")
            let newTag = Yala.Tag(name: "viaje", createdAt: after)
            context.insert(newTag)
            let newTx = tx(context, -25, createdAt: after, account: newAccount, category: newCategory,
                           subcategory: newSub, tags: [newTag])
            // Un borrador nuevo con su cuenta y su subcategoría: la limpieza de relaciones del borrado no puede tocarlo.
            let newDraft = InboxDraft(note: "Apple Pay", account: newAccount, subcategory: newSub, sourceType: .applePay)
            newDraft.createdAt = after
            context.insert(newDraft)
            let unusedRate = try rate(context, "2026-09-01")
            try context.save()
            let survivors: [any PersistentModel] = [newAccount, newCategory, newSub, newTag, newTx, newDraft]
            let mark = Date.now

            let reschedules = try receiverWipe(context, signaledAt: signaledAt, fleetStartedOver: fleetStartedOver)

            #expect(try !exists(oldTx, in: context) && !exists(oldTag, in: context),
                    "el gasto o la etiqueta de antes del vaciado siguen: el vaciado no llegó")
            #expect(try !exists(oldAccount, in: context) && !exists(oldCategory, in: context) && !exists(oldSub, in: context)
                    && !exists(oldCategoryOnly, in: context),
                    "lo que solo usaba el gasto de antes sigue aquí")
            #expect(try exists(newTx, in: context), """
                el receptor tardío se llevó el gasto que el origen apuntó DESPUÉS de vaciar: su borrado viaja por el espejo \
                y el origen lo pierde
                """)
            #expect(newTx.account?.persistentModelID == newAccount.persistentModelID
                    && newTx.category?.persistentModelID == newCategory.persistentModelID
                    && newTx.subcategory?.persistentModelID == newSub.persistentModelID,
                    "el gasto nuevo se quedó sin su cuenta o su categoría: el saldo del origen deja de cuadrar")
            #expect((newTx.tags ?? []).map(\.persistentModelID) == [newTag.persistentModelID], "el gasto nuevo perdió su etiqueta")
            #expect(try exists(newDraft, in: context) && newDraft.account?.persistentModelID == newAccount.persistentModelID
                    && newDraft.subcategory?.persistentModelID == newSub.persistentModelID,
                    "el borrador nuevo perdió su cuenta o su subcategoría, o se lo llevó el borrado")
            // Lo que no usa nadie: la semilla nueva y un tipo de cambio. El gasto nuevo prueba que el parque empezó de nuevo.
            #expect(try exists(seedCategory, in: context) && exists(seedSub, in: context) && exists(unusedRate, in: context),
                    """
                el receptor se llevó lo que el origen sembró después y aún no usa: el origen lo pierde y su semilla no vuelve \
                (marca del KV: \(fleetStartedOver))
                """)
            #expect(try historyChanges(context, after: mark,
                                       touching: Set(survivors.map(\.persistentModelID))) == 0, """
                el borrado escribió en filas que se quedan: esa escritura viaja al origen como una edición suya
                """)
            // Control: el History sí ve el borrado de lo viejo, así que el cero de arriba mide algo.
            #expect(try historyChanges(context, after: mark, touching: [oldTx.persistentModelID]) > 0,
                    "el History no registra el borrado de lo viejo: la aserción de cero cambios no mide nada")
            #expect(reschedules == 1, "el receptor no reprogramó los avisos de lo que se queda: quedan mudos")
        }
    }

    /// Las demás filas fechadas, con el mismo corte: presupuestos, favoritos, pagos programados, planes, notificaciones,
    /// memoria de comercios. Y un borrador que el arranque sacó de un pago viejo se va con él aunque sea posterior. Lo que
    /// se queda conserva sus relaciones y no se escribe.
    @Test("el corte vale para cada modelo con fecha, y el borrador derivado de un pago viejo se va con su pago")
    func everyDatedModel_followsTheCut() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withStandardRestored {
            let cash = account(context, "Efectivo")
            let (_, sub) = category(context, "Casa", sub: "Luz")
            let tag = Yala.Tag(name: "casa", createdAt: after)
            context.insert(tag)

            let oldBudget = Budget(currencyCode: "USD", limitAmount: 100, createdAt: before)
            let newBudget = Budget(currencyCode: "USD", limitAmount: 200, accounts: [cash], subcategories: [sub],
                                   tags: [tag], createdAt: after, accountIDs: CSVMirrorCodec.encode([cash.shortcutID]))
            let oldFavorite = FavoritePayment(name: "Café viejo")
            oldFavorite.createdAt = before
            let newFavorite = FavoritePayment(name: "Café", account: cash, subcategory: sub, tags: [tag])
            newFavorite.createdAt = after
            let oldScheduled = ScheduledPayment(name: "Gimnasio viejo", amount: 30, currencyCode: "USD", nextDueDate: .now)
            oldScheduled.createdAt = before
            let newScheduled = ScheduledPayment(name: "Gimnasio", amount: 30, currencyCode: "USD", account: cash,
                                                subcategory: sub, nextDueDate: .now)
            newScheduled.createdAt = after
            let oldPlan = CashFlowPlan(name: "Plan viejo")
            oldPlan.createdAt = before
            let newPlan = CashFlowPlan(name: "Plan")
            newPlan.createdAt = after
            let oldNotification = NotificationItem(name: "Vieja", text: "", hour: 9, minute: 0, type: .endOfDay)
            oldNotification.createdAt = before
            let newNotification = NotificationItem(name: "Nueva", text: "", hour: 9, minute: 0, type: .endOfDay)
            newNotification.createdAt = after
            let oldMemory = MerchantMemory(merchantCanonical: "viejo", lastApprovedAt: before)
            let newMemory = MerchantMemory(merchantCanonical: "nuevo", subcategory: sub, lastApprovedAt: after)
            let oldDraft = InboxDraft(note: "viejo")
            oldDraft.createdAt = before
            let derivedDraft = InboxDraft(note: "Gimnasio viejo", sourceType: .scheduledPayment)
            derivedDraft.createdAt = after
            derivedDraft.sourceScheduledPaymentID = oldScheduled.id.uuidString
            let newDraft = InboxDraft(note: "Apple Pay", account: cash, subcategory: sub, tags: [tag], sourceType: .applePay)
            newDraft.createdAt = after
            let newScheduledDraft = InboxDraft(note: "Gimnasio", sourceType: .scheduledPayment)
            newScheduledDraft.createdAt = after
            newScheduledDraft.sourceScheduledPaymentID = newScheduled.id.uuidString
            let taken: [any PersistentModel] = [oldBudget, oldFavorite, oldScheduled, oldPlan, oldNotification, oldMemory,
                                                oldDraft, derivedDraft]
            let kept: [any PersistentModel] = [newBudget, newFavorite, newScheduled, newPlan, newNotification, newMemory,
                                               newDraft, newScheduledDraft]
            for model in taken + kept { context.insert(model) }
            try context.save()
            let mark = Date.now

            try receiverWipe(context, signaledAt: signaledAt, fleetStartedOver: true)

            for model in taken {
                #expect(try !exists(model, in: context), "\(type(of: model)) de antes del vaciado sigue aquí")
            }
            for model in kept {
                #expect(try exists(model, in: context),
                        "\(type(of: model)) creado después del vaciado se lo llevó el receptor tardío")
            }
            #expect(newFavorite.account != nil && newFavorite.subcategory != nil && (newFavorite.tags ?? []).count == 1,
                    "el favorito nuevo perdió sus relaciones")
            #expect(newDraft.account != nil && newDraft.subcategory != nil && (newDraft.tags ?? []).count == 1,
                    "el borrador nuevo perdió sus relaciones")
            #expect(newMemory.subcategory != nil, "la memoria del comercio nuevo perdió su subcategoría")
            #expect((newBudget.accounts ?? []).count == 1 && (newBudget.subcategories ?? []).count == 1
                    && (newBudget.tags ?? []).count == 1 && newBudget.accountIDs != nil,
                    "el presupuesto nuevo perdió sus filtros")
            #expect(try historyChanges(context, after: mark,
                                       touching: Set((kept + [cash, sub, tag]).map(\.persistentModelID))) == 0,
                    "el borrado escribió en filas que se quedan: esa escritura viaja al origen")
        }
    }

    /// **Lo que usa algo que se queda se queda, aunque también lo use algo que se va**, por cada camino por el que se
    /// puede usar. Cada fila sin fecha la usan a la vez un gasto viejo y una fila nueva por UNA relación distinta: si el
    /// corte olvida esa relación, solo ve el uso viejo y se la lleva.
    @Test("lo que usa algo que se queda se conserva por cada relación, aunque también lo use algo que se va")
    func usedByKept_wins_throughEveryRelation() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withStandardRestored {
            // Un gasto viejo por cada fila sin fecha, en el hueco que le toca.
            @MainActor func oldUse(account: Account? = nil, category: Yala.Category? = nil, subcategory: Subcategory? = nil) {
                _ = tx(context, -1, createdAt: before, account: account, category: category, subcategory: subcategory)
            }
            let groups = Account(name: "Grupos", currencyCode: "USD", colorHex: "#333333", iconName: "person.3",
                                 type: "cash", isSystemAccount: true)
            context.insert(groups)
            oldUse(account: groups)
            let bridged = tx(context, -30, createdAt: after, account: groups, category: nil, subcategory: nil)
            bridged.splitExpenseID = UUID().uuidString

            let (txCategory, _) = category(context, "Solo categoría", sub: "Sin uso aquí")
            oldUse(category: txCategory)
            _ = tx(context, -1, createdAt: after, account: nil, category: txCategory, subcategory: nil)
            let (viaSubCategory, viaSub) = category(context, "Por la subcategoría", sub: "Usada")
            oldUse(category: viaSubCategory)
            oldUse(subcategory: viaSub)
            _ = tx(context, -8, createdAt: after, account: nil, category: nil, subcategory: viaSub)

            let favoriteAccount = account(context, "Del favorito")
            let (_, favoriteSub) = category(context, "Del favorito", sub: "Del favorito")
            oldUse(account: favoriteAccount, subcategory: favoriteSub)
            let favorite = FavoritePayment(name: "Café", account: favoriteAccount, subcategory: favoriteSub)
            favorite.createdAt = after
            let scheduledAccount = account(context, "Del pago")
            let (_, scheduledSub) = category(context, "Del pago", sub: "Del pago")
            oldUse(account: scheduledAccount, subcategory: scheduledSub)
            let scheduled = ScheduledPayment(name: "Gimnasio", amount: 30, currencyCode: "USD", account: scheduledAccount,
                                             subcategory: scheduledSub, nextDueDate: .now)
            scheduled.createdAt = after
            // Un presupuesto que filtra por categoría, y por cuenta y subcategoría SOLO por el espejo CSV: la M2M puede
            // llegar sin hidratar, y el corte tiene que verla igual.
            let (budgetCategory, _) = category(context, "Del presupuesto", sub: "Sin uso aquí")
            oldUse(category: budgetCategory)
            let budgetAccount = account(context, "Del presupuesto")
            let (_, budgetSub) = category(context, "Del presupuesto CSV", sub: "Del presupuesto CSV")
            oldUse(account: budgetAccount, subcategory: budgetSub)
            let budget = Budget(currencyCode: "USD", limitAmount: 50, category: budgetCategory, createdAt: after)
            budget.accountIDs = CSVMirrorCodec.encode([budgetAccount.shortcutID])
            budget.subcategoryIDs = CSVMirrorCodec.encode([budgetSub.shortcutID])
            // Un plan con una línea por categoría y otra por subcategoría.
            let (lineCategory, _) = category(context, "De la línea", sub: "Sin uso aquí")
            oldUse(category: lineCategory)
            let (_, lineSub) = category(context, "De la línea sub", sub: "De la línea sub")
            oldUse(subcategory: lineSub)
            let plan = CashFlowPlan(name: "Plan")
            plan.createdAt = after
            for model in [favorite, scheduled, budget, plan] as [any PersistentModel] { context.insert(model) }
            let lineA = CashFlowLine(name: "A", category: lineCategory)
            let lineB = CashFlowLine(name: "B", subcategory: lineSub)
            context.insert(lineA)
            context.insert(lineB)
            lineA.plan = plan
            lineB.plan = plan
            try context.save()

            try receiverWipe(context, signaledAt: signaledAt, fleetStartedOver: false)

            let used: [(String, any PersistentModel)] = [
                ("la cuenta de grupos de la reposición", groups), ("la categoría de una transacción", txCategory),
                ("la categoría por la subcategoría", viaSubCategory), ("la subcategoría de una transacción", viaSub),
                ("la cuenta del favorito", favoriteAccount), ("la subcategoría del favorito", favoriteSub),
                ("la cuenta del pago programado", scheduledAccount), ("la subcategoría del pago programado", scheduledSub),
                ("la categoría del presupuesto", budgetCategory),
                ("la cuenta del presupuesto (CSV)", budgetAccount), ("la subcategoría del presupuesto (CSV)", budgetSub),
                ("la categoría de la línea del plan", lineCategory), ("la subcategoría de la línea del plan", lineSub),
            ]
            for (what, model) in used {
                #expect(try exists(model, in: context), "el corte se llevó \(what), que usa una fila que se queda")
            }
            #expect(bridged.account?.persistentModelID == groups.persistentModelID,
                    "la reposición de grupos del origen se quedó sin su cuenta de grupos")
        }
    }

    /// **Sin nada que pruebe una vida nueva** —ni la marca ni una fila personal posterior; solo lo que crea el arranque de
    /// este dispositivo: un borrador de Apple Pay, una memoria reaprobada, una fila de grupo— lo que no usa nadie se va
    /// como antes, y lo que solo usan un borrador o una memoria también. Si se quedara, la categoría vieja impediría la
    /// semilla del onboarding de este dispositivo y el espejo se la llevaría después: sin ninguna categoría.
    @Test("sin vida nueva se va lo no usado y lo que solo usan un borrador o una memoria; lo de grupos se queda")
    func withoutANewLife_unusedAndWeaklyUsedGo() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withStandardRestored {
            let unusedAccount = account(context, "Sin uso")
            let (unusedCategory, unusedSub) = category(context, "Sin uso", sub: "Sin uso")
            let unusedRate = try rate(context, "2026-09-02")
            let oldCard = account(context, "Tarjeta vieja")
            let (oldCategory, oldSub) = category(context, "Comida vieja", sub: "Restaurantes viejos")
            let applePay = InboxDraft(note: "Apple Pay", account: oldCard, subcategory: oldSub, sourceType: .applePay)
            applePay.createdAt = after
            let memory = MerchantMemory(merchantCanonical: "restaurante", subcategory: oldSub, lastApprovedAt: after)
            let groups = Account(name: "Grupos", currencyCode: "USD", colorHex: "#333333", iconName: "person.3",
                                 type: "cash", isSystemAccount: true)
            context.insert(groups)
            let bridged = tx(context, -30, createdAt: after, account: groups, category: nil, subcategory: nil)
            bridged.splitExpenseID = UUID().uuidString
            context.insert(applePay)
            context.insert(memory)
            try context.save()

            try receiverWipe(context, signaledAt: signaledAt, fleetStartedOver: false)

            #expect(try !exists(unusedAccount, in: context) && !exists(unusedCategory, in: context)
                    && !exists(unusedSub, in: context) && !exists(unusedRate, in: context),
                    "sin vida nueva se conservó lo que no usa nadie: la semilla de este dispositivo no correría")
            #expect(try !exists(oldCard, in: context) && !exists(oldCategory, in: context) && !exists(oldSub, in: context),
                    """
                un borrador o una memoria creados al arrancar protegieron una cuenta o una categoría vieja: la semilla no \
                corre y el espejo se la lleva después
                """)
            #expect(try exists(applePay, in: context) && exists(memory, in: context),
                    "el borrador y la memoria nuevos se fueron: son posteriores a la señal")
            #expect(try exists(bridged, in: context) && exists(groups, in: context),
                    "la fila de grupo nueva o su cuenta de grupos se fueron")
        }
    }

    /// Una notificación posterior a la señal (el onboarding del origen crea las suyas) también prueba la vida nueva: lo
    /// que no usa nadie se queda aunque la marca del KV no haya llegado.
    @Test("una notificación posterior prueba la vida nueva: lo no usado se queda aunque falte la marca")
    func aLaterNotification_provesANewLife() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withStandardRestored {
            let (seedCategory, seedSub) = category(context, "Ocio", sub: "Cine")
            let notification = NotificationItem(name: "Resumen", text: "", hour: 21, minute: 0, type: .endOfDay)
            notification.createdAt = after
            context.insert(notification)
            try context.save()

            try receiverWipe(context, signaledAt: signaledAt, fleetStartedOver: false)

            #expect(try exists(seedCategory, in: context) && exists(seedSub, in: context),
                    "con una notificación nueva en el store, el receptor se llevó la semilla sin usar del origen")
        }
    }

    /// Una subcategoría sin uso de una categoría que se va, se va con ella: si no, queda suelta, sin categoría.
    @Test("la subcategoría sin uso de una categoría vieja se va con ella")
    func unusedSubcategory_followsItsCategory() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withStandardRestored {
            let (oldCategory, usedSub) = category(context, "Vieja", sub: "Usada")
            let loose = Subcategory(name: "Sin uso", category: oldCategory)
            context.insert(loose)
            _ = tx(context, -10, createdAt: before, account: nil, category: oldCategory, subcategory: usedSub)
            try context.save()

            try receiverWipe(context, signaledAt: signaledAt, fleetStartedOver: true)

            #expect(try !exists(oldCategory, in: context) && !exists(usedSub, in: context))
            #expect(try !exists(loose, in: context), "la subcategoría sin uso de una categoría borrada quedó suelta")
        }
    }

    /// Sin hora de señal no hay con qué separar: el borrado es entero, como antes del ticket, y no hay nada que reprogramar.
    @Test("sin hora de señal el borrado se lo lleva todo, como antes")
    func noSignalTime_wipesEverything() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withStandardRestored {
            let cash = account(context, "Efectivo")
            let recent = tx(context, -10, createdAt: after, account: cash, category: nil, subcategory: nil)
            try context.save()

            let reschedules = try receiverWipe(context, signaledAt: Date(timeIntervalSince1970: 0), fleetStartedOver: true)

            #expect(try !exists(recent, in: context) && !exists(cash, in: context),
                    "sin hora de señal el receptor conservó filas: el vaciado queda a medias")
            #expect(reschedules == 0, "sin corte no queda nada que reprogramar")
        }
    }

    /// «Vaciar datos» en el propio dispositivo no tiene corte: se lo lleva todo, de cada modelo, lo reciente también.
    @Test("el «Vaciar datos» propio sigue borrándolo todo, de cada modelo")
    func ownWipe_hasNoCut() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withStandardRestored {
            let cash = account(context, "Efectivo")
            let (_, sub) = category(context, "Semilla", sub: "Sin uso")
            let tag = Yala.Tag(name: "etiqueta")
            context.insert(tag)
            _ = tx(context, -10, createdAt: .now, account: cash, category: nil, subcategory: sub, tags: [tag])
            _ = try rate(context, "2026-09-03")
            let draft = InboxDraft(note: "borrador", account: cash)
            let budget = Budget(currencyCode: "USD", limitAmount: 10, accounts: [cash])
            let favorite = FavoritePayment(name: "Café", account: cash)
            let scheduled = ScheduledPayment(name: "Gimnasio", amount: 30, currencyCode: "USD", nextDueDate: .now)
            let plan = CashFlowPlan(name: "Plan")
            let memory = MerchantMemory(merchantCanonical: "comercio", subcategory: sub)
            let notification = NotificationItem(name: "Aviso", text: "", hour: 9, minute: 0, type: .endOfDay)
            for model in [draft, budget, favorite, scheduled, plan, memory, notification] as [any PersistentModel] {
                context.insert(model)
            }
            try context.save()

            try DataWipeService.wipeAllUserData(in: context, broadcastSignal: false)

            let counts = [
                ("TransactionItem", try count(TransactionItem.self, in: context)),
                ("Account", try count(Account.self, in: context)),
                ("Category", try count(Yala.Category.self, in: context)),
                ("Subcategory", try count(Subcategory.self, in: context)),
                ("Tag", try count(Yala.Tag.self, in: context)),
                ("ExchangeRate", try count(ExchangeRate.self, in: context)),
                ("InboxDraft", try count(InboxDraft.self, in: context)),
                ("Budget", try count(Budget.self, in: context)),
                ("FavoritePayment", try count(FavoritePayment.self, in: context)),
                ("ScheduledPayment", try count(ScheduledPayment.self, in: context)),
                ("CashFlowPlan", try count(CashFlowPlan.self, in: context)),
                ("MerchantMemory", try count(MerchantMemory.self, in: context)),
                ("NotificationItem", try count(NotificationItem.self, in: context)),
            ]
            for (model, n) in counts {
                #expect(n == 0, "«Vaciar datos» dejó \(n) filas de \(model)")
            }
        }
    }
}
