//
//  ChatDraftSignedAmountTests.swift
//  YalaTests
//
//  Que un gasto guardado desde el chat RESTE del saldo de la cuenta.
//  Ticket `chat-draft-drops-the-expense-sign`.
//
//  **Por qué las aserciones son sobre el SALDO y no sobre `tx.amount`.** El campo era el síntoma
//  legible, pero el daño estaba en el número que el usuario ve, y las dos cosas no son la misma
//  afirmación: entre el campo y el saldo hay un filtro de cuentas contables, una agrupación por
//  divisa nativa y una conversión. Un test que solo mirase el signo del campo se quedaría verde el
//  día que el saldo dejara de leer ese campo. Por eso cada caso llama a
//  `LiveBalanceCalculator.liveBalance` y afirma sobre su resultado; el signo del campo se comprueba
//  además, como diagnóstico, no como criterio.
//
//  Es el mismo CALCULADOR que alimenta el Panel, no la misma LLAMADA: el Panel le pasa las cuentas
//  ya filtradas por `PanelTotalAccountsLogic` más `selectedAccountIDs`/`isExcludeMode`. Aquí se le
//  llama con los filtros por defecto a propósito, que es lo que mantiene el caso independiente de
//  `SessionState.shared`.
//
//  **Por qué la cuenta va en la divisa PREFERIDA.** Aquí se mide el SIGNO, así que la conversión
//  tiene que ser la identidad: `liveBalanceBreakdown` entra por la rama misma-divisa y no toca el
//  converter, de modo que un rojo solo puede venir del signo. La otra mitad —que el monto convertido
//  y la tasa sean correctos— la cubre el fichero hermano `ChatDraftExchangeRateTests`, que monta el
//  escenario opuesto. Separarlos es lo que hace que cada rojo apunte a un sitio.
//
//  **La divisa preferida se lee UNA vez y se pasa a mano.** Sale de `UserDefaults.standard`, que es
//  compartido: `InitialBalanceServiceTests` escribe esa misma clave (`defaultCurrencyCode`), y
//  `.serialized` ordena dentro de una suite pero no entre suites. Leerla tres veces —al montar, al
//  guardar y al medir— abría la puerta a que cambiase a media prueba, y entonces el rojo saldría con
//  un mensaje culpando al signo. De ahí también el guard estructural de divisa de cada caso: si el
//  escenario deja de ser el de la rama identidad, se dice en vez de disfrazarse de fallo del cálculo.
//
//  Fichero aparte a propósito: `makeTestContext()` reusa el container por `#fileID`, así que el
//  STORE es propio y llega vacío a cada caso (hace `rollback` + wipe de todos los modelos). Ojo: eso
//  vale para SwiftData y NO para el resto — `setContext` toca `SessionState.shared` y consume
//  `chat_draft_saved_signal` de los defaults compartidos, igual que `ChatAssistantViewModelTests`.
//  El aislamiento aquí es del store, no del proceso. `.serialized` es obligatorio.
//
//  **Aviso para quien diagnostique un flake:** guardar de verdad pasa por `TransactionService.create`,
//  que escribe en el App Group real (`WidgetDataCache.updateCache`) y suelta una Task hacia
//  `BudgetAlertService` — la combinación documentada como R8. Y `saveDraft` deja
//  `TransactionService.shared` apuntando al store de este fichero (lo inyecta él por dentro). Si
//  aparece un crash-loop intermitente del runner, mirar aquí antes que al container.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Un gasto guardado desde el chat resta del saldo", .serialized)
struct ChatDraftSignedAmountTests {

    // MARK: - Helpers

    /// El montaje completo: cuenta contable en la divisa preferida, categoría de la naturaleza
    /// pedida y un borrador pendiente ya adjunto a un mensaje del assistant.
    ///
    /// `messages` es `private(set)`, así que la única vía de entrada desde fuera es la que usa la
    /// app al reabrirse: el blob de sesión del día en `UserDefaults`, que `setContext` rehidrata.
    /// Es además el camino real — un borrador del chat vive exactamente ahí hasta que se pulsa Save.
    private func makeScenario(
        amount: Decimal,
        isExpense: Bool,
        context: ModelContext
    ) throws -> (vm: ChatAssistantViewModel, messageID: UUID, draftID: UUID, preferred: String) {
        let preferred = CurrencyDefaults.currentPreferred
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        // La categoría casa con la naturaleza del borrador: un gasto cuelga de una categoría de
        // gasto. No es decorado — es lo que hace que el escenario sea el real, y lo que deja ver que
        // el RENDER de la fila sí salía bien (el tipo se decide por categoría) mientras el saldo y
        // los totales estaban mal.
        let category = makeTestCategory(
            context: context,
            name: isExpense ? "Comida" : "Sueldo",
            isIncome: !isExpense
        )
        let subcategory = makeTestSubcategory(
            context: context,
            name: isExpense ? "Almuerzo" : "Nómina",
            category: category
        )
        try context.save()

        let draft = ChatTransactionDraft(
            amount: amount,
            currencyCode: preferred,
            isExpense: isExpense,
            note: isExpense ? "Almuerzo" : "Sueldo",
            date: Date.now,
            accountID: account.persistentModelID,
            subcategoryID: subcategory.persistentModelID
        )
        let message = ChatMessage(
            role: .assistant,
            text: "Te propongo esto",
            timestamp: Date.now,
            attachments: [.drafts([draft])]
        )
        let defaults = makeIsolatedDefaults()
        let blob = ChatPersistedSession(messages: [message], allTurns: [])
        let key = "chat_session_" + DayKeyFormatter.string(from: Date.now)
        defaults.set(try JSONEncoder().encode(blob), forKey: key)

        let vm = ChatAssistantViewModel(defaults: defaults)
        // `autoLoadSuggestions: false` evita el `Task { loadSuggestions }` que sobrevive al test.
        vm.setContext(context, autoLoadSuggestions: false)
        return (vm, message.id, draft.id, preferred)
    }

    /// El saldo que vería el usuario, leyendo del store.
    private func liveBalance(in context: ModelContext, preferred: String) throws -> Double {
        LiveBalanceCalculator.liveBalance(
            accounts: try context.fetch(FetchDescriptor<Account>()),
            transactions: try context.fetch(FetchDescriptor<TransactionItem>()),
            preferredCurrencyCode: preferred
        )
    }

    /// La transacción guardada, exigiendo que sea EXACTAMENTE una.
    ///
    /// Aborta con `#require` en vez de avisar con `#expect` y seguir: `.first` sobre un fetch sin
    /// `sortBy` no tiene orden definido, así que con residuo en el store las aserciones siguientes
    /// medirían una fila arbitraria y enterrarían el diagnóstico bajo fallos secundarios. Un solo
    /// punto de fallo por causa, y el mensaje cubre los dos motivos: cero (no se guardó) y más de una
    /// (residuo).
    private func singleSavedTransaction(
        in context: ModelContext,
        errorMessage: String?
    ) throws -> TransactionItem {
        let all = try context.fetch(FetchDescriptor<TransactionItem>())
        try #require(
            all.count == 1,
            """
            Se esperaba 1 transacción en el store y hay \(all.count). Si es 0, el borrador no llegó a
            guardarse y no hay nada que medir: revisa en qué guard cortó `saveDraft` \
            (errorMessage: \(errorMessage ?? "ninguno")). Si es más de 1, hay residuo y la medición
            iría sobre la fila equivocada.
            """
        )
        return all[0]
    }

    // MARK: - El caso del ticket

    @Test("Guardar un gasto desde el chat BAJA el saldo de la cuenta")
    func savingExpenseDraftDecreasesBalance() async throws {
        let context = try makeTestContext()
        let (vm, messageID, draftID, preferred) = try makeScenario(
            amount: 30, isExpense: true, context: context)

        // El saldo de partida se MIDE, no se asume cero.
        let balanceBefore = try liveBalance(in: context, preferred: preferred)

        await vm.saveDraft(messageID: messageID, draftID: draftID)

        let tx = try singleSavedTransaction(in: context, errorMessage: vm.errorMessage)

        // Guard estructural, ANTES de medir: si la divisa preferida se movió bajo nuestros pies, el
        // cálculo deja de ir por la rama identidad y el rojo de abajo culparía al signo de algo que
        // no es suyo. Esto lo dice en vez de disfrazarlo.
        #expect(
            tx.currencyCode == tx.preferredCurrencyCode,
            """
            La fila quedó en \(tx.currencyCode) con preferida \(tx.preferredCurrencyCode): el
            escenario ya no es el de conversión identidad que este fichero necesita. Alguien movió
            `defaultCurrencyCode` en los defaults compartidos a mitad del test.
            """
        )

        let balanceAfter = try liveBalance(in: context, preferred: preferred)

        #expect(
            balanceAfter == balanceBefore - 30,
            """
            Un gasto de 30 dictado al chat dejó el saldo en \(balanceAfter) partiendo de \
            \(balanceBefore): tenía que RESTAR. Con el bug de \
            `chat-draft-drops-the-expense-sign` el saldo subía a \(balanceBefore + 30), porque \
            `saveDraft` persistía la magnitud sin firmar y `LiveBalanceCalculator` acumula \
            `tx.amount` sin mirar la categoría.
            """
        )

        #expect(tx.amount == -30, "El monto persistido es \(tx.amount); se esperaba -30.")

        // La OTRA columna de dinero, y no es redundante: los totales históricos de Registros y
        // Estadísticas suman `amountInPreferredCurrency` con signo, así que un gasto positivo aquí
        // RESTA del bucket de gastos aunque el saldo ya esté bien. Es además el único centinela
        // contra firmar una sola de las dos columnas: la tasa no lo delataría, porque se guarda con
        // `abs()` y saldría positiva y plausible.
        #expect(
            tx.amountInPreferredCurrency < 0,
            """
            El monto en divisa preferida es \(tx.amountInPreferredCurrency) para un GASTO: tiene que \
            ir firmado igual que el nativo (\(tx.amount)). Las cuatro columnas viajan juntas en el \
            grupo de coherencia `money`.
            """
        )
    }

    // MARK: - Pareja de control

    @Test("Guardar un ingreso desde el chat SUBE el saldo (pareja de control)")
    func savingIncomeDraftIncreasesBalance() async throws {
        let context = try makeTestContext()
        let (vm, messageID, draftID, preferred) = try makeScenario(
            amount: 30, isExpense: false, context: context)

        let balanceBefore = try liveBalance(in: context, preferred: preferred)

        await vm.saveDraft(messageID: messageID, draftID: draftID)

        let tx = try singleSavedTransaction(in: context, errorMessage: vm.errorMessage)
        #expect(tx.currencyCode == tx.preferredCurrencyCode)

        let balanceAfter = try liveBalance(in: context, preferred: preferred)

        #expect(
            balanceAfter == balanceBefore + 30,
            """
            Un ingreso de 30 dejó el saldo en \(balanceAfter) partiendo de \(balanceBefore): tenía \
            que SUMAR. Esta pareja existe para que el arreglo del caso de arriba no se pueda \
            satisfacer negando el monto siempre — el signo tiene que salir de `draft.isExpense`. \
            Verificado por mutación: con el código anterior al fix, este caso se queda en VERDE.
            """
        )
        #expect(tx.amount == 30, "El monto persistido es \(tx.amount); se esperaba 30.")
        #expect(tx.amountInPreferredCurrency > 0)
    }
}
