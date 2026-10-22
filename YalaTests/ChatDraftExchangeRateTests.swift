//
//  ChatDraftExchangeRateTests.swift
//  YalaTests
//
//  Que guardar un borrador del chat PERSISTA la tasa que se usó, no un 1.0 plantado.
//  Ticket `chat-assistant-plants-exchange-rate-one`.
//
//  **Por qué el escenario es el de tasa EXACTA y no el aproximado.** El fichero hermano
//  (`ManualWriteRateQualityBehaviorTests`) monta una fila de tasas PARCIAL para probar la
//  provisionalidad. Aquí hace falta lo contrario: la fila COMPLETA, que es el caso normal y el único
//  en el que el daño era permanente. Con la tasa aproximada el flag queda `true`, la transacción
//  entra en la cola del reparador y el 1.0 se curaba solo en el arranque siguiente; con la tasa
//  exacta el flag queda `false`, la fila sale del `#Predicate` del reparador (`== true`) y el número
//  falso se sellaba para siempre. Un test con fila parcial habría pasado en verde con el bug puesto.
//
//  Fichero aparte a propósito: `makeTestContext()` reusa el container por `#fileID`, así que el
//  STORE es propio. Ojo: eso vale para SwiftData y NO para el resto — `setContext` toca
//  `SessionState.shared` y consume `chat_draft_saved_signal` de los defaults compartidos, igual que
//  `ChatAssistantViewModelTests`. El aislamiento aquí es del store, no del proceso.
//
//  **Aviso para quien diagnostique un flake:** guardar de verdad pasa por `TransactionService.create`,
//  que dispara `WidgetDataCache.updateCache` (escribe en el App Group real) y una Task suelta hacia
//  `BudgetAlertService`. Ésa es la combinación documentada como R8, que ha llegado a tumbar el runner
//  de Swift Testing y que otras suites esquivan a propósito. Hoy los dos guards de
//  `checkBudgetsAndNotify` cortan (toggle en `false`, sin contexto inyectado), pero leen estado
//  GLOBAL: si aparece un crash-loop intermitente del runner, mirar aquí antes que al container.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("La tasa del borrador del chat se deriva, no se planta", .serialized)
struct ChatDraftExchangeRateTests {

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Una divisa que con seguridad NO es la preferida del entorno.
    ///
    /// La preferida sale de `CurrencyDefaults.currentPreferred`, que lee el `UserDefaults` del
    /// simulador — que estos tests no pueden tocar ni dar por conocido. En vez de fijar el destino se
    /// fija que el ORIGEN sea distinto: así la conversión es real sea cual sea el entorno. Molde
    /// tomado de `ManualWriteRateQualityBehaviorTests`.
    /// El guard compara NORMALIZADO, y no es cosmético: el pipeline de conversión normaliza los dos
    /// lados (`"jpy"`, `"yen"` y `"¥"` son alias válidos de JPY). Comparando el string crudo, un
    /// simulador con la preferida guardada como `"jpy"` haría que este helper devolviera `"JPY"`,
    /// el converter entraría por la rama misma-divisa, la tasa saldría 1.0 y el test se caería
    /// **con el fix puesto** — un rojo que apunta al sitio equivocado.
    private var foreignCode: String {
        normalizeCurrencyCode(CurrencyDefaults.currentPreferred) == "JPY" ? "CHF" : "JPY"
    }

    /// Fecha fija en el pasado, para no depender del momento del día en que se corra.
    private var pastDate: Date {
        Calendar.current.date(byAdding: .day, value: -10, to: Date.now) ?? Date.now
    }

    /// La fila del día con TODAS las divisas: la conversión sale `.exact`.
    private func completeRates() -> [String: Double] {
        Dictionary(
            uniqueKeysWithValues: CurrencyCode.allRawValues.map {
                ($0, CurrencyCode.fallbackRates[$0] ?? 1.0)
            }
        )
    }

    private func seedRates(_ rates: [String: Double], on date: Date, in context: ModelContext) throws
    {
        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: date),
            base: "USD",
            ratesDictionary: rates
        )
        context.insert(row)
        try context.save()
    }

    /// Monta el VM con un borrador pendiente ya adjunto a un mensaje del assistant.
    ///
    /// `messages` es `private(set)`, así que la única vía de entrada desde fuera es la que usa la
    /// app al reabrirse: el blob de sesión del día en `UserDefaults`, que `setContext` rehidrata.
    /// Es además el camino real — un borrador del chat vive exactamente ahí hasta que se pulsa Save.
    private func makeViewModelWithDraft(
        _ draft: ChatTransactionDraft,
        context: ModelContext
    ) throws -> (vm: ChatAssistantViewModel, messageID: UUID) {
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
        return (vm, message.id)
    }

    /// Exige que haya EXACTAMENTE una: `.first` a secas afirma sobre «la fila que salga primero», no
    /// sobre la que acabamos de crear, y convertiría un residuo futuro en una medición silenciosa de
    /// la transacción equivocada en vez de en un rojo.
    private func singleSavedTransaction(in context: ModelContext) throws -> TransactionItem? {
        let all = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(all.count <= 1, "Residuo en el store: \(all.count) transacciones, se esperaba 1.")
        return all.first
    }

    // MARK: - El caso del ticket

    @Test("Guardar un borrador en otra divisa persiste la tasa que se usó, no 1.0")
    func savingForeignCurrencyDraftPersistsTheEffectiveRate() async throws {
        let context = try makeTestContext()
        // NO se toca `TransactionService.shared`: `saveDraft` ya le inyecta el contexto por dentro
        // (defensivamente, con su propio comentario). Ponerlo aquí sería redundante y dejaría el
        // singleton apuntando al store de este fichero para el resto del proceso.
        let date = pastDate
        try seedRates(completeRates(), on: date, in: context)

        let account = makeTestAccount(context: context, name: "Extranjera", currencyCode: foreignCode)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(
            context: context, name: "Restaurantes", category: category)
        try context.save()

        let draft = ChatTransactionDraft(
            amount: 100,
            currencyCode: foreignCode,
            isExpense: true,
            note: "Cena",
            date: date,
            accountID: account.persistentModelID,
            subcategoryID: subcategory.persistentModelID
        )
        let (vm, messageID) = try makeViewModelWithDraft(draft, context: context)

        await vm.saveDraft(messageID: messageID, draftID: draft.id)

        let tx = try #require(
            try singleSavedTransaction(in: context),
            """
            El borrador no llegó a guardarse: sin transacción no hay nada que medir y el test sería
            verde por vacío. Revisa si `saveDraft` cortó en alguna de sus guards \
            (errorMessage: \(vm.errorMessage ?? "ninguno")).
            """
        )

        // Que HUBO conversión se afirma de forma ESTRUCTURAL, no se infiere de que la tasa sea
        // distinta de 1.0. Si otra suite moviera `defaultCurrencyCode` bajo nuestros pies entre el
        // montaje y el save, el escenario dejaría de ser el que el test cree estar midiendo y estas
        // dos líneas lo dicen en vez de disfrazarlo de fallo del cálculo.
        #expect(tx.currencyCode != tx.preferredCurrencyCode)

        #expect(
            tx.exchangeRate != 1.0,
            """
            La transacción se guardó en \(foreignCode) con preferida \
            \(CurrencyDefaults.currentPreferred) y monto convertido \(tx.amountInPreferredCurrency), \
            o sea que HUBO conversión — pero la tasa persistida es 1.0. Es el número que el detalle \
            de la transacción le enseña al usuario, y decía «1,00» para un gasto en otra divisa.
            """
        )

        // Esta igualdad es EXACTA por construcción, no aproximada: la tasa persistida sale de dividir
        // esos mismos dos Double, así que la diferencia es 0.0 y la tolerancia no llega a ejercitarse.
        // Lo que detecta, y por eso está, es que alguien deje de derivar la tasa del monto — con el
        // 1.0 replantado da 0,9752. Lo que NO cubre: que la conversión se haga `on: draft.date` (la
        // otra mitad del arreglo de esta ruta, cerrada en `fx-manual-writes-seal-approximate-as-final`).
        // Convertir en la fecha equivocada deja tasa y monto mutuamente coherentes, así que las tres
        // aserciones seguirían verdes; ese escenario necesita dos filas de tasas y es otro test.
        let derived = tx.amountInPreferredCurrency / tx.amount
        #expect(
            abs(tx.exchangeRate - abs(derived)) < 0.000_001,
            """
            La tasa persistida (\(tx.exchangeRate)) no cuadra con el monto que la acompaña \
            (\(tx.amountInPreferredCurrency) / \(tx.amount) = \(derived)). Las cuatro columnas viajan \
            juntas en el grupo de coherencia `money`: si no son coherentes entre sí, el reparador \
            reescribiría otro número al pasar por la fila.
            """
        )

        #expect(
            !tx.isExchangeRateProvisional,
            """
            Con la fila de tasas completa la conversión es exacta y la transacción NO entra en la cola \
            del reparador (`#Predicate` = `== true`). Ésa es justamente la razón por la que el 1.0 \
            plantado era permanente, y por la que este test usa fila completa: si el flag saliera \
            `true`, el escenario sería el que ya se auto-curaba y no probaría nada.
            """
        )
    }

    // MARK: - Pareja de control

    @Test("Guardar un borrador en la divisa preferida sí deja 1.0 (pareja de control)")
    func savingPreferredCurrencyDraftKeepsRateAtOne() async throws {
        let context = try makeTestContext()
        // NO se toca `TransactionService.shared`: `saveDraft` ya le inyecta el contexto por dentro
        // (defensivamente, con su propio comentario). Ponerlo aquí sería redundante y dejaría el
        // singleton apuntando al store de este fichero para el resto del proceso.
        let date = pastDate
        try seedRates(completeRates(), on: date, in: context)

        let preferred = CurrencyDefaults.currentPreferred
        let account = makeTestAccount(context: context, name: "Local", currencyCode: preferred)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(
            context: context, name: "Restaurantes", category: category)
        try context.save()

        let draft = ChatTransactionDraft(
            amount: 100,
            currencyCode: preferred,
            isExpense: true,
            note: "Cena",
            date: date,
            accountID: account.persistentModelID,
            subcategoryID: subcategory.persistentModelID
        )
        let (vm, messageID) = try makeViewModelWithDraft(draft, context: context)

        await vm.saveDraft(messageID: messageID, draftID: draft.id)

        let tx = try #require(
            try singleSavedTransaction(in: context),
            "El borrador no llegó a guardarse (errorMessage: \(vm.errorMessage ?? "ninguno"))."
        )

        #expect(tx.preferredCurrencyCode == preferred)
        #expect(
            abs(tx.exchangeRate - 1.0) < 0.000_001,
            """
            Origen y destino son la misma divisa (\(preferred)): 1.0 es la tasa CORRECTA aquí, no un \
            valor plantado. Esta pareja existe para que el test de arriba no se pueda satisfacer \
            escribiendo cualquier número distinto de 1.0.
            """
        )
        #expect(abs(tx.amountInPreferredCurrency - tx.amount) < 0.000_001)
    }
}
