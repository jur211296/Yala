//
//  ChatUnsignedExpenseRepairTests.swift
//  YalaTests
//
//  Que el barrido le devuelva el signo a los gastos que el chat guardó sin firmar, y que no toque
//  nada más. Ticket `chat-rows-with-unsigned-amount-have-no-repair-path`.
//
//  **La aserción del caso que cura es sobre el SALDO, no sobre `tx.amount`.** Es la misma vara que
//  usó el arreglo hacia delante (`ChatDraftSignedAmountTests`) y por el mismo motivo: entre el campo
//  y el número que el usuario ve hay un filtro de cuentas contables, una agrupación por divisa nativa
//  y una conversión. Un test que solo mirase el signo del campo se quedaría verde el día que el saldo
//  dejara de leer ese campo. El campo se comprueba además, como diagnóstico.
//
//  **Los casos de SUPERVIVENCIA sí afirman sobre los campos, y es deliberado.** Ahí la pregunta no es
//  «¿cuánto ve el usuario?» sino «¿tocó el barrido esta fila?», y el saldo no la responde: un saldo
//  correcto es compatible con que el barrido haya reescrito la fila con el mismo valor.
//
//  Los casos que montan una fila en la divisa preferida comprueban las DOS columnas; los que solo
//  necesitan demostrar que un filtro excluye —los cuatro marcadores, el ingreso, la fila huérfana—
//  afirman sobre `amount`, que es la columna que el barrido decide primero. La cabecera decía «se
//  comprueban las DOS columnas» de todos, y no era cierto.
//
//  **Las cuentas van en la divisa preferida a propósito.** Aquí se mide el SIGNO, así que la
//  conversión tiene que ser la identidad y un rojo solo puede venir de lo que se está probando.
//
//  **El flag vive en un `UserDefaults` propio de cada caso.** El barrido es one-shot y lo recuerda en
//  defaults: con `.standard` el primer test que corriera dejaría a los demás sin barrido, y el orden
//  dentro de una suite `.serialized` no está garantizado. Cada caso trae un suite con nombre único; no
//  se borra al salir, igual que en el resto del repo, así que quedan dominios huérfanos en el runner.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("El barrido devuelve el signo a los gastos del chat", .serialized)
struct ChatUnsignedExpenseRepairTests {

    // MARK: - Helpers

    /// Un `UserDefaults` limpio y propio del caso, para que el flag one-shot no viaje entre tests.
    private func makeIsolatedDefaults() throws -> UserDefaults {
        let name = "ChatUnsignedExpenseRepairTests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    /// Una fecha dentro de la ventana en la que el chat guardaba sin firmar.
    private var insideWindow: Date {
        ChatUnsignedExpenseRepairLogic.windowStart.addingTimeInterval(60 * 60 * 24 * 30)
    }

    /// Una fecha ANTERIOR a que `saveDraft` existiera: nada de aquí pudo salir del chat.
    private var beforeWindow: Date {
        ChatUnsignedExpenseRepairLogic.windowStart.addingTimeInterval(-60 * 60 * 24)
    }

    /// El instante en que se dice que corre el barrido. Fijo, para que el caso no dependa del reloj.
    private var sweepRunAt: Date {
        ChatUnsignedExpenseRepairLogic.windowStart.addingTimeInterval(60 * 60 * 24 * 120)
    }

    /// Monta una transacción ya persistida con el signo y los marcadores que pida el caso.
    ///
    /// `amountInPreferredCurrency` se pasa igual que `amount` porque la cuenta va en la divisa
    /// preferida: es lo que el converter habría escrito, no una simplificación.
    @discardableResult
    private func insertTransaction(
        amount: Double,
        categoryIsIncome: Bool,
        createdAt: Date,
        date: Date? = nil,
        balanceAdjustmentType: String? = nil,
        transferPairID: String? = nil,
        splitExpenseID: String? = nil,
        splitSettlementID: String? = nil,
        scheduledPaymentID: String? = nil,
        withoutCategory: Bool = false,
        context: ModelContext,
        preferred: String
    ) throws -> TransactionItem {
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        let category = makeTestCategory(
            context: context,
            name: categoryIsIncome ? "Sueldo" : "Comida",
            isIncome: categoryIsIncome
        )
        let subcategory = makeTestSubcategory(
            context: context,
            name: categoryIsIncome ? "Nómina" : "Almuerzo",
            category: category
        )

        let transaction = TransactionItem(
            date: date ?? createdAt,
            amount: amount,
            currencyCode: preferred,
            note: "caso",
            category: withoutCategory ? nil : category,
            subcategory: withoutCategory ? nil : subcategory,
            account: account,
            exchangeRate: 1.0,
            amountInPreferredCurrency: amount,
            preferredCurrencyCode: preferred
        )
        transaction.createdAt = createdAt
        transaction.balanceAdjustmentType = balanceAdjustmentType
        transaction.transferPairID = transferPairID
        transaction.splitExpenseID = splitExpenseID
        transaction.splitSettlementID = splitSettlementID
        transaction.scheduledPaymentID = scheduledPaymentID
        context.insert(transaction)
        try context.save()
        return transaction
    }

    /// El saldo que vería el usuario, leyendo del store.
    private func liveBalance(in context: ModelContext, preferred: String) throws -> Double {
        LiveBalanceCalculator.liveBalance(
            accounts: try context.fetch(FetchDescriptor<Account>()),
            transactions: try context.fetch(FetchDescriptor<TransactionItem>()),
            preferredCurrencyCode: preferred
        )
    }

    // MARK: - El corpus que hay que curar

    /// El caso del ticket: un gasto que el chat guardó positivo deja de inflar el saldo.
    ///
    /// El saldo esperado es `-30` y no `+30`: la cuenta de test arranca sin saldo inicial, así que el
    /// único movimiento es el gasto. Antes del barrido el mismo store daba `+30` — ese es el daño.
    @Test func unsignedChatExpense_stopsInflatingTheBalance() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let transaction = try insertTransaction(
            amount: 30, categoryIsIncome: false, createdAt: insideWindow,
            context: context, preferred: preferred)

        // Control del escenario: sin esto, un cambio en el montaje podría dejar el caso midiendo otra
        // cosa y el rojo señalaría al barrido.
        #expect(try liveBalance(in: context, preferred: preferred) == 30.0,
                "el escenario debe partir del daño: el gasto SUMANDO al saldo")

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 1)
        #expect(try liveBalance(in: context, preferred: preferred) == -30.0,
                "tras el barrido el gasto debe RESTAR del saldo")
        // Diagnóstico: las dos columnas quedan firmadas, no solo la del saldo.
        #expect(transaction.amount == -30.0)
        #expect(transaction.amountInPreferredCurrency == -30.0)
    }

    // MARK: - Lo que tiene que sobrevivir

    /// **AC del ticket.** Un reembolso legítimo —categoría de gasto con monto positivo, la forma que
    /// `TransactionClassificationLogic` documenta como intencionada— registrado FUERA de la ventana
    /// no se toca. Es lo que separa este barrido de uno que destruye datos buenos.
    @Test func legitimateRefundBeforeTheWindow_survives() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let refund = try insertTransaction(
            amount: 45, categoryIsIncome: false, createdAt: beforeWindow,
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(refund.amount == 45.0, "el reembolso anterior a la ventana debe quedar POSITIVO")
        #expect(refund.amountInPreferredCurrency == 45.0)
    }

    /// El otro borde: un reembolso registrado DESPUÉS del cierre de la ventana tampoco se toca.
    @Test func legitimateRefundAfterTheWindow_survives() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let refund = try insertTransaction(
            amount: 45, categoryIsIncome: false,
            createdAt: sweepRunAt.addingTimeInterval(60 * 60 * 24),
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(refund.amount == 45.0)
        #expect(refund.amountInPreferredCurrency == 45.0)
    }

    /// El saldo inicial de una cuenta creada DENTRO de la ventana sobrevive.
    ///
    /// Este es el caso que obligó a filtrar por marcadores de sistema y no solo por la forma:
    /// `InitialBalanceService` guarda el saldo inicial con el monto tal cual —uno de +500 es
    /// `amount: 500`— y con la subcategoría «Ajuste de saldo», que cuelga de la categoría «Otros», y
    /// «Otros» es `isIncome: false`. Con el criterio literal del ticket, toda cuenta abierta en la
    /// ventana habría visto su saldo inicial volteado a `-500` en silencio.
    @Test func initialBalanceInsideTheWindow_survives() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let initialBalance = try insertTransaction(
            amount: 500, categoryIsIncome: false, createdAt: insideWindow,
            balanceAdjustmentType: InitialBalanceService.typeInitialBalance,
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(initialBalance.amount == 500.0, "el saldo inicial debe seguir siendo POSITIVO")
        #expect(initialBalance.amountInPreferredCurrency == 500.0)
        #expect(try liveBalance(in: context, preferred: preferred) == 500.0)
    }

    /// Los otros cuatro marcadores de sistema, por el mismo motivo: ninguno lo escribe `saveDraft`,
    /// así que una fila que lleve uno tiene un origen conocido que no es el chat.
    ///
    /// Van juntos y no en cuatro casos porque la afirmación es UNA —«llevar marcador excluye»— y
    /// cada fila trae el suyo, de modo que un rojo dice cuál falló por su valor.
    @Test func rowsWithSystemMarkersInsideTheWindow_survive() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let transfer = try insertTransaction(
            amount: 100, categoryIsIncome: false, createdAt: insideWindow,
            transferPairID: UUID().uuidString, context: context, preferred: preferred)
        let split = try insertTransaction(
            amount: 200, categoryIsIncome: false, createdAt: insideWindow,
            splitExpenseID: UUID().uuidString, context: context, preferred: preferred)
        let settlement = try insertTransaction(
            amount: 300, categoryIsIncome: false, createdAt: insideWindow,
            splitSettlementID: UUID().uuidString, context: context, preferred: preferred)
        let scheduled = try insertTransaction(
            amount: 400, categoryIsIncome: false, createdAt: insideWindow,
            scheduledPaymentID: UUID().uuidString, context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(transfer.amount == 100.0)
        #expect(split.amount == 200.0)
        #expect(settlement.amount == 300.0)
        #expect(scheduled.amount == 400.0)
    }

    /// Un ingreso guardado dentro de la ventana no se toca: el bug solo afectaba a los gastos, porque
    /// el signo salía de `draft.isExpense` y un ingreso ya se guardaba positivo, que es lo correcto.
    @Test func incomeInsideTheWindow_survives() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let income = try insertTransaction(
            amount: 1200, categoryIsIncome: true, createdAt: insideWindow,
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(income.amount == 1200.0)
        #expect(try liveBalance(in: context, preferred: preferred) == 1200.0)
    }

    /// Una fila SIN categoría no se toca: el chat siempre asigna una, así que no pudo salir de ahí y
    /// no hay nada que permita afirmar que su signo esté mal.
    @Test func rowWithoutCategoryInsideTheWindow_survives() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let orphan = try insertTransaction(
            amount: 70, categoryIsIncome: false, createdAt: insideWindow,
            withoutCategory: true, context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(orphan.amount == 70.0)
    }

    /// Un gasto que YA está firmado no se vuelve a voltear. Es lo que impide que el barrido, si
    /// alguna vez corriera dos veces, deshaga su propio trabajo.
    @Test func alreadySignedExpense_isNotFlippedBack() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let expense = try insertTransaction(
            amount: -30, categoryIsIncome: false, createdAt: insideWindow,
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(expense.amount == -30.0)
        #expect(try liveBalance(in: context, preferred: preferred) == -30.0)
    }

    // MARK: - One-shot

    /// El barrido corre UNA vez por dispositivo: una fila con la forma del bug que apareciera después
    /// (por ejemplo, llegada por sync desde un teléfono que sigue con el build viejo) ya no se cura.
    /// Es el residual conocido del one-shot, y este caso lo deja fijado en vez de que sorprenda.
    @Test func sweepRunsOnlyOnce() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        try insertTransaction(
            amount: 30, categoryIsIncome: false, createdAt: insideWindow,
            context: context, preferred: preferred)

        let first = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)
        #expect(first == 1)
        #expect(defaults.bool(forKey: ChatUnsignedExpenseRepairService.repairSweepKey))

        let late = try insertTransaction(
            amount: 55, categoryIsIncome: false, createdAt: insideWindow,
            context: context, preferred: preferred)

        let second = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(second == 0, "el flag debe cortar la segunda corrida")
        #expect(late.amount == 55.0)
    }

    /// Con corpus presente y nada que curar, el flag SÍ se marca: el barrido hizo su trabajo, y sin
    /// esto recorrería todas las transacciones en cada arranque para siempre a cambio de nada.
    @Test func sweepMarksTheFlagWhenThereIsCorpusButNothingToRepair() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        // Una transacción cualquiera que NO es candidata: basta para probar que el store tiene datos.
        try insertTransaction(
            amount: 1200, categoryIsIncome: true, createdAt: insideWindow,
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(defaults.bool(forKey: ChatUnsignedExpenseRepairService.repairSweepKey))
    }

    /// **Un store vacío NO quema el flag.**
    ///
    /// Es el caso que cazó la review adversarial y que habría dejado el corpus roto para siempre:
    /// `awaitPersonalStoreReady()` contesta «¿es seguro guardar?», no «¿ya llegaron los datos?», y su
    /// rama `runNoAccount` abre de inmediato en cuanto no hay cuenta de iCloud en ese instante. Un
    /// primer arranque tras reinstalar, con la sesión aún no lista, barría cero filas y marcaba el
    /// flag; el corpus bajaba en el arranque siguiente y ya no lo curaba nadie.
    @Test func emptyStoreDoesNotBurnTheFlag() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(
            !defaults.bool(forKey: ChatUnsignedExpenseRepairService.repairSweepKey),
            "sin transacciones el barrido no ha podido hacer su trabajo: debe reintentarse")
    }

    /// Y el reintento del arranque siguiente SÍ cura, una vez que el corpus ha bajado. Es la mitad
    /// que demuestra que el caso anterior no solo evita el daño, sino que deja la puerta abierta.
    @Test func sweepRepairsOnTheNextLaunchAfterTheCorpusArrives() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        // Arranque 1: el restore aún no ha bajado nada.
        _ = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        // Llega el corpus.
        let expense = try insertTransaction(
            amount: 30, categoryIsIncome: false, createdAt: insideWindow,
            context: context, preferred: preferred)

        // Arranque 2.
        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 1)
        #expect(expense.amount == -30.0)
        #expect(try liveBalance(in: context, preferred: preferred) == -30.0)
        #expect(defaults.bool(forKey: ChatUnsignedExpenseRepairService.repairSweepKey))
    }

    // MARK: - Lo importado no se toca (decisión de Jürgen, 2026-09-08)

    /// **Un lote de importación sobrevive entero.**
    ///
    /// Jürgen aceptó perder reembolsos, no lo importado por CSV. Como esas filas son indistinguibles
    /// campo a campo de las del chat, lo que las separa es que **nacen a la vez**: el importador crea
    /// el lote sin `save()` intermedio, mientras el chat exige un toque humano por fila.
    ///
    /// El escenario es el que de verdad se colaba: un CSV con años de historia importado DENTRO de la
    /// ventana, cuyas filas toman como `createdAt` el instante del import.
    @Test func importedBatchInsideTheWindow_survives() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        // Ocho filas creadas en 40 ms, con fechas de transacción repartidas por años — la firma de un
        // import histórico. Tres son «gasto positivo», que es la forma que el barrido busca.
        var imported: [TransactionItem] = []
        for index in 0..<8 {
            imported.append(
                try insertTransaction(
                    amount: index % 3 == 0 ? 45 : -20,
                    categoryIsIncome: false,
                    createdAt: insideWindow.addingTimeInterval(Double(index) * 0.005),
                    date: beforeWindow.addingTimeInterval(-Double(index) * 60 * 60 * 24 * 200),
                    context: context, preferred: preferred))
        }

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0, "ninguna fila de un lote de importación debe tocarse")
        for (index, row) in imported.enumerated() where index % 3 == 0 {
            #expect(row.amount == 45.0)
            #expect(row.amountInPreferredCurrency == 45.0)
        }
    }

    /// **Y el gasto del chat que cae en medio de la ventana sí se cura**, que es la mitad que impide
    /// satisfacer el filtro anterior no reparando nunca nada.
    ///
    /// Aquí conviven las dos poblaciones en el mismo store: un lote importado y un gasto dictado un
    /// rato después. Solo el segundo se voltea.
    @Test func chatExpenseIsStillRepairedAlongsideAnImportedBatch() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        for index in 0..<5 {
            try insertTransaction(
                amount: 45, categoryIsIncome: false,
                createdAt: insideWindow.addingTimeInterval(Double(index) * 0.005),
                context: context, preferred: preferred)
        }
        // Media hora después, un gasto dictado al chat: nace solo.
        let dictated = try insertTransaction(
            amount: 30, categoryIsIncome: false,
            createdAt: insideWindow.addingTimeInterval(1800),
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 1, "solo el gasto dictado; el lote se queda como está")
        #expect(dictated.amount == -30.0)
        #expect(try liveBalance(in: context, preferred: preferred) == 45.0 * 5 - 30.0)
    }

    /// El lote se detecta con TODAS las filas del store, no solo con las candidatas.
    ///
    /// Un import real mezcla gastos e ingresos, y el vecino que delata el lote puede ser cualquiera:
    /// si el barrido mirase solo las positivas, un import con **una sola** candidata entre muchas
    /// filas parecería un gasto suelto y se colaría. Aquí la candidata está rodeada de ingresos.
    @Test func aLoneCandidateInsideAnImportedBatch_isStillProtected() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        for index in 0..<6 {
            try insertTransaction(
                amount: 900, categoryIsIncome: true,
                createdAt: insideWindow.addingTimeInterval(Double(index) * 0.005),
                context: context, preferred: preferred)
        }
        let lone = try insertTransaction(
            amount: 45, categoryIsIncome: false,
            createdAt: insideWindow.addingTimeInterval(0.030),
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(lone.amount == 45.0, "la rodean ingresos del mismo lote: sigue siendo importada")
    }

    /// La detección de lotes, contra la lógica pura: qué agrupa y qué no.
    @Test func batchFlagsGroupsByChainedGaps() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

        // Una sola fila nunca es lote: no hay con quién nacer a la vez.
        #expect(ChatUnsignedExpenseRepairLogic.batchFlags(createdAts: [at(0)]) == [false])

        // Dos separadas por más de la tolerancia son dos filas solitarias.
        #expect(
            ChatUnsignedExpenseRepairLogic.batchFlags(createdAts: [at(0), at(60)]) == [false, false])

        // Encadenadas: cada hueco es menor que la tolerancia, así que las cinco son UN lote aunque
        // entre la primera y la última pasen más de dos segundos. Es lo que hace un import grande.
        #expect(
            ChatUnsignedExpenseRepairLogic.batchFlags(
                createdAts: [at(0), at(1.5), at(3), at(4.5), at(6)]) == [true, true, true, true, true])

        // El orden de entrada no importa: el resultado va emparejado a la posición de cada fecha.
        #expect(
            ChatUnsignedExpenseRepairLogic.batchFlags(
                createdAts: [at(100), at(0), at(0.1)]) == [false, true, true])

        // Dos lotes separados por una pausa humana, con una fila suelta entre medias.
        #expect(
            ChatUnsignedExpenseRepairLogic.batchFlags(
                createdAts: [at(0), at(0.2), at(600), at(1200), at(1200.3)])
                == [true, true, false, true, true])
    }

    // MARK: - Lo que el pre-filtro tapaba

    /// **El criterio, por separado del `#Predicate`.**
    ///
    /// `alreadySignedExpense_isNotFlippedBack` monta una fila negativa, y esa el fetch ni la devuelve:
    /// prueba el pre-filtro, no el criterio. Borrar el `guard row.amount > 0` de `isCandidate` dejaba
    /// los quince casos VERDES. Es el mismo defecto que ya se corrigió para la ventana —dos sitios
    /// comprobando lo mismo y ninguna prueba capaz de distinguirlos— sobreviviendo en la condición
    /// hermana, así que aquí se llama a la lógica a pelo.
    @Test func nonPositiveAmountsAreNeverCandidates() {
        func facts(_ amount: Double) -> ChatUnsignedExpenseRepairLogic.RowFacts {
            .init(amount: amount, categoryIsIncome: false, createdAt: insideWindow)
        }

        #expect(ChatUnsignedExpenseRepairLogic.isCandidate(facts(30), sweepRunAt: sweepRunAt))
        #expect(!ChatUnsignedExpenseRepairLogic.isCandidate(facts(-30), sweepRunAt: sweepRunAt))
        #expect(
            !ChatUnsignedExpenseRepairLogic.isCandidate(facts(0), sweepRunAt: sweepRunAt),
            "el cero no tiene signo que corregir")
    }

    // MARK: - La ventana se mide sobre createdAt, no sobre date

    /// **Una fila creada FUERA de la ventana no se toca aunque su `date` caiga dentro.**
    ///
    /// Es la distinción más argumentada del criterio y no tenía un solo caso: el helper montaba las
    /// dos fechas con el mismo valor, así que cambiar `createdAt` por `date` en el servicio dejaba la
    /// suite entera verde. Aquí se separan a propósito.
    @Test func rowCreatedOutsideTheWindowSurvivesEvenIfItsDateIsInside() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let refund = try insertTransaction(
            amount: 45, categoryIsIncome: false,
            createdAt: beforeWindow,   // se guardó ANTES de que el chat existiera
            date: insideWindow,        // pero el usuario la fechó dentro de la ventana
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 0)
        #expect(refund.amount == 45.0)
        #expect(refund.amountInPreferredCurrency == 45.0)
    }

    /// Y su recíproco: una fila creada DENTRO sí se cura aunque el usuario la fechara años atrás —
    /// «gasté 30 soles en marzo» dictado al chat es exactamente eso.
    @Test func rowCreatedInsideTheWindowIsRepairedEvenIfItsDateIsOld() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let expense = try insertTransaction(
            amount: 30, categoryIsIncome: false,
            createdAt: insideWindow,
            date: beforeWindow.addingTimeInterval(-60 * 60 * 24 * 365),
            context: context, preferred: preferred)

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 1)
        #expect(expense.amount == -30.0)
        #expect(expense.amountInPreferredCurrency == -30.0)
    }

    /// **Las dos columnas se firman por separado y no se cruzan.**
    ///
    /// En todos los demás casos la cuenta va en la divisa preferida, así que las dos columnas llevan
    /// el MISMO número y permutar las dos asignaciones del servicio quedaría verde. Aquí llevan
    /// valores distintos, que es lo único que distingue «firma cada una» de «escribe cualquiera».
    @Test func bothColumnsAreSignedIndependently() async throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let preferred = CurrencyDefaults.currentPreferred

        let account = makeTestAccount(context: context, name: "Dólares", currencyCode: preferred)
        let category = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let subcategory = makeTestSubcategory(context: context, name: "Almuerzo", category: category)
        let transaction = TransactionItem(
            date: insideWindow,
            amount: 30,                          // magnitud en la divisa de la fila
            currencyCode: preferred,
            note: "columnas distintas",
            category: category,
            subcategory: subcategory,
            account: account,
            exchangeRate: 3.7,
            amountInPreferredCurrency: 111,      // ...y su conversión, distinta a propósito
            preferredCurrencyCode: preferred
        )
        transaction.createdAt = insideWindow
        context.insert(transaction)
        try context.save()

        let repaired = ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded(
            context: context, defaults: defaults, now: sweepRunAt)

        #expect(repaired == 1)
        #expect(transaction.amount == -30.0)
        #expect(transaction.amountInPreferredCurrency == -111.0)
    }

    // MARK: - La ventana, sin store

    /// Los bordes exactos, contra la lógica pura: el arranque del día en que nació `saveDraft` entra,
    /// y el instante anterior no. Un `>=` que se convirtiera en `>` dejaría fuera el primer día.
    @Test func windowBoundariesAreInclusive() {
        let start = ChatUnsignedExpenseRepairLogic.windowStart
        let end = sweepRunAt

        #expect(ChatUnsignedExpenseRepairLogic.isWithinWindow(createdAt: start, sweepRunAt: end))
        #expect(ChatUnsignedExpenseRepairLogic.isWithinWindow(createdAt: end, sweepRunAt: end))
        #expect(
            !ChatUnsignedExpenseRepairLogic.isWithinWindow(
                createdAt: start.addingTimeInterval(-1), sweepRunAt: end))
        #expect(
            !ChatUnsignedExpenseRepairLogic.isWithinWindow(
                createdAt: end.addingTimeInterval(1), sweepRunAt: end))
    }

    /// La ventana arranca el 2026-04-27 en UTC, que es el día del commit que trajo `saveDraft`
    /// (`52d2ad6b`). El valor se fija aquí para que un cambio accidental de la constante salga en
    /// rojo con su fecha, y no como un barrido que de pronto cura de más o de menos.
    @Test func windowStartsTheDaySaveDraftWasBorn() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: ChatUnsignedExpenseRepairLogic.windowStart)

        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 27)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    /// La reparación firma la MAGNITUD en vez de negar el valor guardado. Da lo mismo en el corpus
    /// —el criterio ya garantiza que el monto es positivo— pero no en una fila que llegara con la
    /// columna convertida ya en negativo: negarla a ciegas la dejaría positiva, peor de como estaba.
    @Test func repairSignsTheMagnitudeInsteadOfNegating() {
        let fromPositive = ChatUnsignedExpenseRepairLogic.repairedAmounts(
            amount: 30, amountInPreferredCurrency: 111)
        #expect(fromPositive.amount == -30)
        #expect(fromPositive.amountInPreferredCurrency == -111)

        // Los dos de arriba no distinguen firmar de negar: con entrada positiva dan lo mismo. Esta es
        // la mitad que sí, y la que da nombre al test.
        let fromMixed = ChatUnsignedExpenseRepairLogic.repairedAmounts(
            amount: -30, amountInPreferredCurrency: -111)
        #expect(fromMixed.amount == -30, "no debe volver a positivo")
        #expect(fromMixed.amountInPreferredCurrency == -111, "no debe volver a positivo")
    }
}
