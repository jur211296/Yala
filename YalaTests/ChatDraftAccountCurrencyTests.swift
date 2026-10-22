//
//  ChatDraftAccountCurrencyTests.swift
//  YalaTests
//
//  Que un borrador del chat se guarde en la divisa de su CUENTA, no en la que dictó el usuario.
//  Ticket `chat-draft-stamps-its-own-currency-not-the-account`.
//
//  **El escenario no es de laboratorio.** `DraftBuilder.build` elige cuenta con
//  `findAccount(byCurrency:)`, que devuelve cuenta solo si hay **exactamente una** viva en esa
//  divisa (`matches.count == 1 ? matches.first : nil` — o sea, `0 ó 2+ → nil`). Cuando devuelve
//  `nil` el borrador nace con `accountID == nil`, la tarjeta le pide cuenta al usuario y el menú le
//  ofrece todas **sin filtrar por divisa** (`ForEach(allAccounts)`, que sí filtra archivadas). El
//  desemparejamiento era la salida natural de que ese match fallara — y no solo por «dicté una
//  divisa en la que no tengo cuenta»: con DOS cuentas en la divisa dictada también falla, y ahí las
//  divisas ni siquiera difieren.
//
//  **Por qué cada test monta la cuenta en la divisa PREFERIDA o en una extranjera, y no dos
//  extranjeras cualesquiera.** Hace falta que el par (divisa dictada, divisa de la cuenta) produzca
//  tasas DISTINTAS, porque es lo único que separa el arreglo completo del medio-arreglo. Si alguien
//  corrige el `currencyCode:` del `TransactionItem` pero deja el `from:` del `convertChecked`
//  apuntando a `draft.currencyCode`, la fila queda diciendo una divisa y convertida desde otra —peor
//  que el bug original, porque entonces ni el reparador reproduce el número— y una aserción que solo
//  mirase `tx.currencyCode` pasaría VERDE. Anclando un lado en la preferida, la conversión correcta
//  es la identidad (tasa 1.0) y la incorrecta no, así que las dos se distinguen numéricamente.
//
//  Los dos escenarios van en ESPEJO (cuenta preferida / cuenta extranjera) a propósito: con uno solo,
//  un fix que devolviera siempre la preferida —en vez de la de la cuenta— también pasaría.
//
//  Fichero aparte: `makeTestContext()` reusa el container por `#fileID`, así que el STORE es propio.
//  Eso vale para SwiftData y NO para el resto — `setContext` toca `SessionState.shared` y los
//  defaults compartidos, igual que `ChatAssistantViewModelTests`; de ahí el `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("El borrador del chat se guarda en la divisa de su cuenta", .serialized)
struct ChatDraftAccountCurrencyTests {

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
    /// simulador — que estos tests no pueden dar por conocido. Se compara NORMALIZADO porque el
    /// pipeline de conversión normaliza los dos lados: con la preferida guardada como `"jpy"`, un
    /// `foreignCode` de `"JPY"` entraría por la rama misma-divisa, la tasa saldría 1.0 y el test se
    /// caería CON el fix puesto. Molde tomado de `ChatDraftExchangeRateTests`.
    private var foreignCode: String {
        normalizeCurrencyCode(CurrencyDefaults.currentPreferred) == "JPY" ? "CHF" : "JPY"
    }

    private var pastDate: Date {
        Calendar.current.date(byAdding: .day, value: -10, to: Date.now) ?? Date.now
    }

    /// La fila del día con TODAS las divisas: la conversión sale `.exact` y la tasa es determinista.
    private func completeRates() -> [String: Double] {
        Dictionary(
            uniqueKeysWithValues: CurrencyCode.allRawValues.map {
                ($0, CurrencyCode.fallbackRates[$0] ?? 1.0)
            }
        )
    }

    private func seedRates(on date: Date, in context: ModelContext) throws {
        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: date),
            base: "USD",
            ratesDictionary: completeRates()
        )
        context.insert(row)
        try context.save()
    }

    /// Monta el VM con un borrador pendiente ya adjunto a un mensaje del assistant.
    ///
    /// `messages` es `private(set)`, así que la única vía de entrada desde fuera es la que usa la app
    /// al reabrirse: el blob de sesión del día en `UserDefaults`, que `setContext` rehidrata. Es
    /// además el camino real — un borrador del chat vive exactamente ahí hasta que se pulsa Save.
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

    /// El borrador tal y como lo tiene el VM AHORA. Es lo que la tarjeta pinta, así que es la única
    /// forma de afirmar sobre lo que el usuario ve sin montar la vista.
    private func liveDraft(
        in vm: ChatAssistantViewModel, messageID: UUID, draftID: UUID
    ) -> ChatTransactionDraft? {
        for message in vm.messages where message.id == messageID {
            for attachment in message.attachments ?? [] {
                if case .drafts(let drafts) = attachment {
                    if let found = drafts.first(where: { $0.id == draftID }) { return found }
                }
            }
        }
        return nil
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

    @Test("Dictar en otra divisa y elegir una cuenta local guarda la divisa de la CUENTA")
    func savingDraftDictatedInForeignCurrencyStampsTheAccountCurrency() async throws {
        let context = try makeTestContext()
        let date = pastDate
        try seedRates(on: date, in: context)

        let preferred = CurrencyDefaults.currentPreferred
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(
            context: context, name: "Restaurantes", category: category)
        try context.save()

        // El borrador nace en la divisa DICTADA (lo que devuelve el parseo), y el usuario elige una
        // cuenta que no es de esa divisa. Ésa es la combinación que el ticket describe.
        let draft = ChatTransactionDraft(
            amount: 50,
            currencyCode: foreignCode,
            isExpense: true,
            note: "Cena",
            date: date,
            accountID: account.persistentModelID,
            subcategoryID: subcategory.persistentModelID
        )
        let (vm, messageID) = try makeViewModelWithDraft(draft, context: context)

        // CONTROL POSITIVO del escenario: si esto no se cumple, el test no está midiendo lo que cree
        // y cualquier verde de abajo sería vacío.
        #expect(
            normalizeCurrencyCode(draft.currencyCode) != normalizeCurrencyCode(account.currencyCode),
            """
            El borrador y la cuenta comparten divisa (\(draft.currencyCode)): no hay desemparejamiento \
            que medir. Revisa `foreignCode` contra la preferida del entorno.
            """
        )

        await vm.saveDraft(messageID: messageID, draftID: draft.id)

        let tx = try #require(
            try singleSavedTransaction(in: context),
            """
            El borrador no llegó a guardarse: sin transacción no hay nada que medir y el test sería \
            verde por vacío. Revisa si `saveDraft` cortó en alguna guard \
            (errorMessage: \(vm.errorMessage ?? "ninguno")).
            """
        )

        #expect(
            normalizeCurrencyCode(tx.currencyCode) == normalizeCurrencyCode(account.currencyCode),
            """
            La transacción quedó en \(tx.currencyCode) dentro de una cuenta en \
            \(account.currencyCode). `LiveBalanceCalculator` agrupa por `tx.currencyCode` y convierte \
            cada grupo con la tasa de HOY, así que esa cuenta enseñaría un saldo que no cuadra y que \
            además cambia solo al moverse el tipo de cambio.
            """
        )

        // GUARD ESTRUCTURAL, antes de medir la tasa. Las aserciones de abajo dan por hecho que la
        // cuenta está en la divisa preferida; si otra suite moviera `defaultCurrencyCode` en los
        // defaults COMPARTIDOS entre el montaje y el save (`.serialized` ordena dentro de una suite,
        // no entre suites), el escenario dejaría de ser el que este test cree medir y el rojo saldría
        // en `exchangeRate == 1.0` con un mensaje que culpa al código bajo prueba. Molde tomado de
        // `ChatDraftSignedAmountTests`.
        #expect(
            tx.currencyCode == tx.preferredCurrencyCode,
            """
            La fila quedó en \(tx.currencyCode) con preferida \(tx.preferredCurrencyCode), y este \
            caso monta la cuenta EN la preferida: alguien movió `defaultCurrencyCode` en los defaults \
            compartidos a mitad del test. El fallo no es del código bajo prueba.
            """
        )

        // Y la otra mitad, que es la que separa el arreglo del MEDIO-arreglo: la conversión tiene que
        // partir de la divisa que se estampó. Aquí la cuenta está en la preferida, así que la
        // conversión correcta es la identidad. Si el `from:` siguiera en `draft.currencyCode`, estas
        // dos aserciones caen mientras la de arriba pasa.
        #expect(
            tx.exchangeRate == 1.0,
            """
            Tasa \(tx.exchangeRate) para una transacción en \(tx.currencyCode) con preferida \
            \(tx.preferredCurrencyCode): la conversión no partió de la divisa que se estampó. La fila \
            dice una divisa y está convertida desde otra — las cuatro columnas del grupo `money` \
            dejan de ser coherentes y el reparador reescribiría otro número al pasar por ella.
            """
        )
        #expect(
            abs(tx.amountInPreferredCurrency - tx.amount) < 0.000_001,
            """
            Monto convertido \(tx.amountInPreferredCurrency) frente a monto \(tx.amount) en la misma \
            divisa: se convirtió desde \(draft.currencyCode) en vez de desde \(account.currencyCode).
            """
        )

        // Y lo que el borrador ENSEÑA tras guardar es lo que se guardó. La tarjeta formatea el monto
        // con `draft.currencyCode`, así que sin esto seguiría siendo posible que el usuario viera una
        // divisa y la fila tuviera otra — el bug original, movido al estado `.saved`.
        let saved = try #require(liveDraft(in: vm, messageID: messageID, draftID: draft.id))
        #expect(
            normalizeCurrencyCode(saved.currencyCode) == normalizeCurrencyCode(tx.currencyCode),
            """
            La tarjeta enseñaría \(saved.currencyCode) y la fila guardada dice \(tx.currencyCode).
            """
        )
    }

    @Test("El espejo: cuenta extranjera y dictado en la preferida guarda la de la cuenta")
    func savingDraftDictatedInPreferredCurrencyStampsTheForeignAccountCurrency() async throws {
        let context = try makeTestContext()
        let date = pastDate
        try seedRates(on: date, in: context)

        let preferred = CurrencyDefaults.currentPreferred
        let account = makeTestAccount(
            context: context, name: "Extranjera", currencyCode: foreignCode)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(
            context: context, name: "Restaurantes", category: category)
        try context.save()

        let draft = ChatTransactionDraft(
            amount: 50,
            currencyCode: preferred,
            isExpense: true,
            note: "Cena",
            date: date,
            accountID: account.persistentModelID,
            subcategoryID: subcategory.persistentModelID
        )
        let (vm, messageID) = try makeViewModelWithDraft(draft, context: context)

        #expect(
            normalizeCurrencyCode(draft.currencyCode) != normalizeCurrencyCode(account.currencyCode),
            "El borrador y la cuenta comparten divisa: no hay desemparejamiento que medir."
        )

        await vm.saveDraft(messageID: messageID, draftID: draft.id)

        let tx = try #require(
            try singleSavedTransaction(in: context),
            "El borrador no llegó a guardarse (errorMessage: \(vm.errorMessage ?? "ninguno"))."
        )

        // Este es el espejo del anterior, y está por una razón concreta: con SOLO el test de arriba,
        // un fix que estampara siempre la divisa PREFERIDA —en vez de la de la cuenta— también
        // pasaría en verde. Aquí la cuenta no es la preferida, así que ese fix falso se cae.
        #expect(
            normalizeCurrencyCode(tx.currencyCode) == normalizeCurrencyCode(account.currencyCode),
            """
            La transacción quedó en \(tx.currencyCode) dentro de una cuenta en \
            \(account.currencyCode).
            """
        )
        // El guard estructural del espejo: aquí la cuenta NO es la preferida, y si lo fuera la
        // aserción de la tasa de abajo sería imposible de cumplir por razones del entorno.
        #expect(
            tx.currencyCode != tx.preferredCurrencyCode,
            """
            La fila quedó en \(tx.currencyCode) y la preferida es \(tx.preferredCurrencyCode): este \
            caso monta la cuenta en una divisa EXTRANJERA, así que alguien movió \
            `defaultCurrencyCode` en los defaults compartidos a mitad del test.
            """
        )
        #expect(
            tx.exchangeRate != 1.0,
            """
            Tasa 1.0 para una transacción en \(tx.currencyCode) con preferida \
            \(tx.preferredCurrencyCode): o no hubo conversión, o partió de la divisa equivocada.
            """
        )

        // Hace que la siembra de tasas sea LOAD-BEARING. `completeRates()` reproduce exactamente
        // `CurrencyCode.fallbackRates`, y el escalón 3 de `resolveRates` rellena lo que falte desde
        // esa misma tabla: sin esta línea se puede borrar el `seedRates` y los números salen
        // idénticos, con lo que la fila sembrada sería andamiaje muerto. Lo único que cambia al
        // quitarla es la CALIDAD (`.exact` → `.staticFallback`), y es justo lo que se mide aquí.
        #expect(
            !tx.isExchangeRateProvisional,
            """
            La conversión salió provisional pese a la fila de tasas completa del día: o no se sembró, \
            o no se usó y el converter cayó a la tabla estática.
            """
        )

        // Coherencia interna del grupo `money`. Dicho con precisión, porque es fácil pedirle de más:
        // esta aserción NO discrimina ninguno de los mutantes de este ticket —`exchangeRate` se
        // persiste como ese mismo cociente, así que es una identidad aritmética para cualquier par de
        // divisas— y tampoco garantiza que el reparador reproduzca la fila:
        // `recalculatePreferredCurrency` reconvierte desde `currencyCode` en `date`, no desde el
        // cociente, de modo que una fila del medio-arreglo es coherente consigo misma y aun así se
        // reescribiría. Está como pin de la derivación de la tasa, que es de otro ticket
        // (`chat-assistant-plants-exchange-rate-one`), no como red de éste.
        let derived = tx.amountInPreferredCurrency / tx.amount
        #expect(
            abs(tx.exchangeRate - abs(derived)) < 0.000_001,
            """
            La tasa persistida (\(tx.exchangeRate)) no cuadra con los montos que la acompañan \
            (\(tx.amountInPreferredCurrency) / \(tx.amount) = \(derived)).
            """
        )
    }

    @Test("Cambiar de cuenta antes de guardar cambia la divisa con la que se guarda")
    func changingTheAccountBeforeSavingChangesTheStampedCurrency() async throws {
        let context = try makeTestContext()
        let date = pastDate
        try seedRates(on: date, in: context)

        let preferred = CurrencyDefaults.currentPreferred
        let foreignAccount = makeTestAccount(
            context: context, name: "Extranjera", currencyCode: foreignCode)
        let localAccount = makeTestAccount(
            context: context, name: "Diaria", currencyCode: preferred)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(
            context: context, name: "Restaurantes", category: category)
        try context.save()

        // El camino REAL del usuario: el borrador nace emparejado (dictó en la divisa de una cuenta
        // que sí tiene) y luego cambia de cuenta en el menú, que ofrece todas sin filtrar por divisa.
        // Es el segundo camino al desemparejamiento, y el que `updateDraft` deja abierto: acepta
        // `accountID` y no acepta `currencyCode`, de modo que la pareja se rompía sin que nada
        // avisara. Al derivar la divisa de la cuenta deja de haber nada que corregir a mano.
        let draft = ChatTransactionDraft(
            amount: 50,
            currencyCode: foreignCode,
            isExpense: true,
            note: "Cena",
            date: date,
            accountID: foreignAccount.persistentModelID,
            subcategoryID: subcategory.persistentModelID
        )
        let (vm, messageID) = try makeViewModelWithDraft(draft, context: context)

        vm.updateDraft(
            messageID: messageID,
            draftID: draft.id,
            accountID: .some(localAccount.persistentModelID)
        )
        await vm.saveDraft(messageID: messageID, draftID: draft.id)

        let tx = try #require(
            try singleSavedTransaction(in: context),
            "El borrador no llegó a guardarse (errorMessage: \(vm.errorMessage ?? "ninguno"))."
        )

        #expect(
            normalizeCurrencyCode(tx.currencyCode) == normalizeCurrencyCode(preferred),
            """
            Se guardó en \(tx.currencyCode) tras mover el borrador a una cuenta en \(preferred). El \
            `currencyCode` del borrador sigue siendo el dictado (\(foreignCode)) porque `updateDraft` \
            no lo toca: es la divisa EFECTIVA la que tiene que seguir a la cuenta.
            """
        )
        #expect(
            tx.exchangeRate == 1.0,
            "Tasa \(tx.exchangeRate) tras mover el borrador a una cuenta en la divisa preferida."
        )
    }

    // MARK: - El borrador lleva la divisa efectiva, y por eso nadie tiene que deducirla

    @Test("Elegir cuenta sincroniza la divisa del borrador con la de esa cuenta")
    func choosingAnAccountSyncsTheDraftCurrency() async throws {
        let context = try makeTestContext()
        let preferred = CurrencyDefaults.currentPreferred
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(
            context: context, name: "Restaurantes", category: category)
        try context.save()

        // El borrador nace SIN cuenta, que es lo que pasa cuando `findAccount` no da match único.
        let draft = ChatTransactionDraft(
            amount: 50,
            currencyCode: foreignCode,
            isExpense: true,
            note: "Cena",
            date: pastDate,
            accountID: nil,
            subcategoryID: subcategory.persistentModelID,
            needsUserInput: ["account"]
        )
        let (vm, messageID) = try makeViewModelWithDraft(draft, context: context)

        vm.updateDraft(
            messageID: messageID, draftID: draft.id,
            accountID: .some(account.persistentModelID))

        let updated = try #require(liveDraft(in: vm, messageID: messageID, draftID: draft.id))
        #expect(
            normalizeCurrencyCode(updated.currencyCode) == normalizeCurrencyCode(preferred),
            """
            El borrador sigue en \(updated.currencyCode) tras elegir una cuenta en \(preferred). Es \
            el valor que la tarjeta enseña junto al monto: si no sigue a la cuenta, el usuario \
            confirma una divisa y se guarda otra.
            """
        )
    }

    @Test("Con la cuenta archivada entre elegir y guardar, lo que se ve es lo que se guarda")
    func archivingTheAccountAfterChoosingItDoesNotSplitTheDisplayedAndSavedCurrency() async throws {
        let context = try makeTestContext()
        let date = pastDate
        try seedRates(on: date, in: context)

        let preferred = CurrencyDefaults.currentPreferred
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        let category = makeTestCategory(context: context, name: "Comida")
        let subcategory = makeTestSubcategory(
            context: context, name: "Restaurantes", category: category)
        try context.save()

        let draft = ChatTransactionDraft(
            amount: 50,
            currencyCode: foreignCode,
            isExpense: true,
            note: "Cena",
            date: date,
            accountID: nil,
            subcategoryID: subcategory.persistentModelID,
            needsUserInput: ["account"]
        )
        let (vm, messageID) = try makeViewModelWithDraft(draft, context: context)
        vm.updateDraft(
            messageID: messageID, draftID: draft.id,
            accountID: .some(account.persistentModelID))

        // Y AHORA se archiva, con el borrador ya apuntando a ella. Es alcanzable de verdad: la
        // sesión del chat vive el día entero, y la bajada de plan archiva cuentas en LOTE
        // (`DowngradeResolutionSheet`). Éste es el borde que se llevó por delante el primer intento
        // de arreglo de este ticket: la tarjeta resolvía la cuenta con un `@Query` que filtra
        // `!isArchived` y `saveDraft` la resuelve con `context.model(for:)`, que NO filtra, así que
        // los dos lados daban divisas distintas y el usuario confirmaba «$ 50» para guardar «S/ 50».
        account.isArchived = true
        try context.save()

        // LO QUE VE EL USUARIO EN ESE INSTANTE, medido ANTES de guardar. Aquí está el bug: la
        // tarjeta pinta esto y el botón Guardar sigue activo (`canSave` mira `accountID != nil`, no
        // el lookup). Medirlo solo DESPUÉS del save no serviría — el congelado de `saveDraft` ya
        // habría alineado los dos lados y el test pasaría con la divergencia puesta.
        let beforeSaving = try #require(liveDraft(in: vm, messageID: messageID, draftID: draft.id))
        #expect(
            normalizeCurrencyCode(beforeSaving.currencyCode) == normalizeCurrencyCode(preferred),
            """
            Con la cuenta archivada, la tarjeta enseñaría \(beforeSaving.currencyCode) mientras el \
            guardado estampará \(preferred): el usuario confirma una divisa y se guarda otra.
            """
        )

        await vm.saveDraft(messageID: messageID, draftID: draft.id)

        let tx = try #require(
            try singleSavedTransaction(in: context),
            "El borrador no llegó a guardarse (errorMessage: \(vm.errorMessage ?? "ninguno"))."
        )
        let shown = try #require(liveDraft(in: vm, messageID: messageID, draftID: draft.id))

        // La invariante que hace imposible la divergencia: la divisa vive en el BORRADOR, así que no
        // hay dos criterios que puedan discrepar. Nadie deduce nada resolviendo la cuenta por su
        // cuenta — ni la tarjeta, ni ningún consumidor futuro del blob.
        #expect(
            normalizeCurrencyCode(shown.currencyCode) == normalizeCurrencyCode(tx.currencyCode),
            """
            La tarjeta enseñaría \(shown.currencyCode) y la transacción guardada dice \
            \(tx.currencyCode). Con la cuenta archivada, los dos lados volvieron a discrepar.
            """
        )
        #expect(
            normalizeCurrencyCode(tx.currencyCode) == normalizeCurrencyCode(preferred),
            "Se guardó en \(tx.currencyCode) con la cuenta en \(preferred)."
        )
    }

    // MARK: - El helper, en aislamiento

    @Test("Sin cuenta elegida, la divisa efectiva es la que dictó el usuario")
    func effectiveCurrencyFallsBackToTheDictatedOneWhenThereIsNoAccount() throws {
        let draft = ChatTransactionDraft(
            amount: 50,
            currencyCode: "USD",
            isExpense: true,
            note: "Cena",
            date: Date.now
        )

        // Es la rama que ejerce la TARJETA, no el guardado: `saveDraft` exige `accountID` y aborta
        // sin él, así que un borrador sin cuenta no puede llegar a persistirse con esta divisa. Lo
        // que se fija aquí es que mientras el usuario no ha elegido cuenta se le siga enseñando lo
        // que dictó, en vez de un hueco o la divisa preferida.
        #expect(draft.effectiveCurrencyCode(account: nil) == "USD")
    }
}
