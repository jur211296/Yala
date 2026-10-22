//
//  FXOneToOneRepairSweepTests.swift
//  YalaTests
//
//  El barrido que cura las filas selladas con un 1:1 falso.
//  Ticket `chat-rows-sealed-before-the-fix-have-no-repair-path`.
//
//  **Por qué este fichero existe.** Hasta hoy `TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded`
//  no tenía NI UN test, y su único llamador era `AppBootstrapper`. Lo que había en
//  `TransactionUpdateServiceTests` es un espejo —reescribe la aritmética a mano dentro del propio test,
//  con un `// Simulate update` que asigna las cuatro columnas— así que no podía ponerse rojo por nada
//  que le pasara al servicio.
//
//  (El ticket citaba un `grep` que «daba cero». Medido en este árbol: da UNA línea, y es el comentario
//  `// MARK:` de ese fichero espejo. La sustancia se sostiene —ningún test invocaba la función— pero la
//  cifra no era la de este árbol, que es justo lo que las rules mandan re-medir antes de reusar un
//  número ajeno.)
//
//  **Lo que se prueba aquí, y lo que NO.** El criterio de qué fila está envenenada vive en
//  `ExchangeRateRepairLogic.needsRepair` y lo cubre `ExchangeRateRepairLogicTests` (misma divisa,
//  mayúsculas, otras tasas); esa división importa porque el `#Predicate` del servicio ya filtra por
//  `exchangeRate == 1.0`, así que un mutante de esa mitad del criterio saldría VERDE aquí — y rojo
//  allí. Lo de aquí es lo que no tenía dueño: **qué se le hace a cada fila, cuándo corre el barrido y
//  cuándo tiene derecho a sellarse.**
//
//  **El flag vive en un `UserDefaults` propio de cada caso**, como en `ChatUnsignedExpenseRepairTests`:
//  el barrido es one-shot y lo recuerda en defaults, así que con `.standard` el primer caso que
//  corriera dejaría a los demás sin barrido. No se borra al salir —igual que en el resto del repo—, así
//  que cada corrida deja dominios huérfanos en el runner.
//
//  **Casi ningún caso nombra la clave del flag, y es deliberado**: se observa el COMPORTAMIENTO (volver
//  a llamar y ver si repara), que es lo que le importa al usuario y no se rompe cuando la clave suba a
//  `.v3`. Los dos casos del rebobinado sí la escriben literal, porque ahí la clave ES lo que se fija —y
//  el segundo se pondrá rojo con un `.v3`, que es la señal de «ven a mirar esto», no un fallo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("El barrido del 1:1 sellado", .serialized)
struct FXOneToOneRepairSweepTests {

    // MARK: - Helpers

    /// Un `UserDefaults` limpio y propio del caso, para que el one-shot no viaje entre tests.
    private func makeIsolatedDefaults() throws -> UserDefaults {
        let name = "FXOneToOneRepairSweepTests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    /// Una divisa que NO es la preferida del entorno de test.
    ///
    /// Se lee del entorno en vez de fijarse: la preferida sale de `UserDefaults.standard` y otro test
    /// puede haberla movido — fijar `"JPY"` a ciegas haría que estos casos se volvieran triviales en
    /// silencio el día que alguien dejara la preferida en JPY. Es el molde de `FXRepairQueueTests`.
    private var foreignCode: String {
        CurrencyDefaults.currentPreferred == "JPY" ? "PEN" : "JPY"
    }

    /// La tasa de los fixtures. No pretende ser la de ningún par real: lo único que tiene que cumplir
    /// es ser distinta de 1, que es lo que separa «hubo conversión» de «se guardó el monto crudo».
    private static let fixtureRate = 3.72

    /// Una fila ya persistida con la forma que decide el caso.
    ///
    /// **El gasto va NEGATIVO**, que es como lo guarda producción desde el PR #102 (`saveDraft` firma
    /// las dos columnas de monto). Importa aquí y no es cosmética: la tasa se deduce de un cociente, y
    /// con montos negativos ese cociente sale positivo solo si el código toma el valor absoluto — que
    /// es lo que hace, por paridad con el reparador.
    @discardableResult
    private func insertRow(
        currencyCode: String,
        exchangeRate: Double,
        isProvisional: Bool = false,
        amount: Double = -50,
        amountInPreferred: Double? = nil,
        context: ModelContext
    ) throws -> TransactionItem {
        let account = makeTestAccount(context: context, name: "Diaria", currencyCode: currencyCode)
        let category = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let subcategory = makeTestSubcategory(context: context, name: "Almuerzo", category: category)

        let row = TransactionItem(
            date: Date(timeIntervalSince1970: 1_757_000_000),
            amount: amount,
            currencyCode: currencyCode,
            note: "caso",
            category: category,
            subcategory: subcategory,
            account: account,
            exchangeRate: exchangeRate,
            amountInPreferredCurrency: amountInPreferred ?? (amount * Self.fixtureRate),
            preferredCurrencyCode: CurrencyDefaults.currentPreferred,
            isExchangeRateProvisional: isProvisional
        )
        context.insert(row)
        try context.save()
        return row
    }

    // MARK: - Qué se le hace a cada fila

    /// **El caso del ticket.** La fila del chat convirtió de verdad y plantó `1.0` al lado: la tasa se
    /// corrige EN EL SITIO, deducida de los montos que ya están guardados.
    ///
    /// **La aserción que de verdad importa es la del monto convertido**, y es la que refutó el primer
    /// diseño de este arreglo: reabrir la fila para que el reparador la reconvirtiera habría pisado un
    /// `amountInPreferredCurrency` que estaba BIEN con lo que diera la conversión de hoy — tasa
    /// arrastrada, o tabla estática, que es un snapshot congelado. Cambiar un número correcto por uno
    /// peor es un daño mayor que el que el ticket venía a arreglar.
    ///
    /// Y el flag se queda en `false` a propósito: la conversión fue exacta el día que se guardó, y
    /// corregir la tasa no cambia esa verdad. Marcarla encendería el «≈» en el Panel sobre una fila
    /// que nunca fue aproximada.
    @Test("la fila del chat recupera su tasa real sin que le toquen el monto")
    func chatRow_getsItsRealRateWithoutTouchingTheAmount() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let row = try insertRow(currencyCode: foreignCode, exchangeRate: 1.0, context: context)
        let amountBefore = row.amountInPreferredCurrency

        let result = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(result.fixed == 1)
        #expect(result.reopened == 0)
        #expect(abs(row.exchangeRate - Self.fixtureRate) < 0.0001)
        #expect(row.amountInPreferredCurrency == amountBefore)
        #expect(row.isExchangeRateProvisional == false)
    }

    /// La otra población bajo el mismo criterio: la conversión NO ocurrió y se guardó el monto crudo,
    /// así que el cociente vale 1 y no dice nada. Esa sí tiene que volver a la cola del reparador, que
    /// es el único que sabe reconvertirla.
    ///
    /// Es el corpus de `fx-partial-rate-rows-silent-1to1`, y sin este caso el arreglo nuevo curaría el
    /// del chat perdiendo el que la `.v1` ya sabía curar.
    @Test("la fila que tampoco se convirtió vuelve a la cola")
    func unconvertedRow_goesBackToTheQueue() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let row = try insertRow(
            currencyCode: foreignCode, exchangeRate: 1.0, amountInPreferred: -50, context: context)

        let result = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(result.reopened == 1)
        #expect(result.fixed == 0)
        #expect(row.isExchangeRateProvisional == true)
        #expect(row.exchangeRate == 1.0)
    }

    /// **Una tasa `0` es una tasa AUSENTE, y escribirla sería reproducir el bug dentro del arreglo.**
    /// Una fila con el monto convertido en `0` da cociente `0`: si se sellara, el detalle enseñaría
    /// «0,0000» como si fuera un dato y cualquier conversión posterior devolvería cero. Va a la cola.
    @Test("un monto convertido en cero no se sella con una tasa cero")
    func zeroConvertedAmount_isNotSealedWithAZeroRate() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let row = try insertRow(
            currencyCode: foreignCode, exchangeRate: 1.0, amountInPreferred: 0, context: context)

        let result = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(result.fixed == 0)
        #expect(result.reopened == 1)
        #expect(row.exchangeRate == 1.0)
        #expect(row.isExchangeRateProvisional == true)
    }

    /// **Pareja de control, y sin ella los casos de arriba no prueban nada:** un barrido que tocara
    /// TODA fila con tasa `1.0` también los pasaría, y `1.0` es el valor legítimo de la inmensa mayoría
    /// de transacciones de cualquier usuario —las de su propia divisa—.
    @Test("una fila en la divisa preferida con tasa 1:1 no se toca")
    func sameCurrencyRow_isLeftAlone() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let row = try insertRow(
            currencyCode: CurrencyDefaults.currentPreferred,
            exchangeRate: 1.0,
            amountInPreferred: -50,
            context: context
        )

        let result = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(result.fixed == 0)
        #expect(result.reopened == 0)
        #expect(row.exchangeRate == 1.0)
        #expect(row.isExchangeRateProvisional == false)
    }

    /// La fila que YA está en la cola no se toca: la va a arreglar el reparador, con la lógica buena y
    /// en este mismo arranque. El filtro (`needsRepair`) mira la tasa y la divisa, **nunca el flag**,
    /// así que sin este guard recibiría una escritura que ensucia la fila y emite al canal nube.
    @Test("una fila que ya estaba en la cola no se toca")
    func alreadyProvisionalRow_isNotTouched() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let row = try insertRow(
            currencyCode: foreignCode, exchangeRate: 1.0, isProvisional: true, context: context)

        let result = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(result.fixed == 0)
        #expect(result.reopened == 0)
        // Que la tasa siga en 1.0 es lo que demuestra que NO se tocó: si el guard cayera, esta fila
        // tiene cociente deducible y habría salido con 3.72.
        #expect(row.exchangeRate == 1.0)
    }

    // MARK: - One-shot: corre una vez, y una vez de verdad

    /// El barrido no vuelve en el arranque siguiente. La fila nueva se inserta DESPUÉS del primero: si
    /// el one-shot se hubiera perdido, ésta se curaría también.
    @Test("corre una sola vez por dispositivo")
    func sweepRunsOnlyOnce() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        try insertRow(currencyCode: foreignCode, exchangeRate: 1.0, context: context)

        _ = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        let later = try insertRow(currencyCode: foreignCode, exchangeRate: 1.0, context: context)
        let second = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(second.fixed == 0)
        #expect(second.reopened == 0)
        #expect(later.exchangeRate == 1.0)
    }

    /// **El caso del ticket, y el motivo de que la clave suba a `.v2`.** Un dispositivo que ya corrió
    /// el barrido de la `.v1` tiene que volver a barrer una vez: entre aquel barrido y el arreglo del
    /// chat se siguió produciendo exactamente el daño que la `.v1` fue a curar, y esas filas no las
    /// mira nadie más —el reparador de arranque solo busca `isExchangeRateProvisional == true`, y el
    /// caso normal las selló en `false`—.
    @Test("un dispositivo que ya corrió la v1 vuelve a barrer")
    func aDeviceThatAlreadyRanV1_sweepsAgain() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        defaults.set(true, forKey: "fxOneToOneRepairSweep.v1")
        let row = try insertRow(currencyCode: foreignCode, exchangeRate: 1.0, context: context)

        let result = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(result.fixed == 1)
        #expect(abs(row.exchangeRate - Self.fixtureRate) < 0.0001)
    }

    /// La pareja del anterior: con la clave EN CURSO marcada, el barrido no vuelve. Sin este caso,
    /// «rebobinar» sería indistinguible de «haber roto el one-shot».
    @Test("con el flag en curso ya marcado, no vuelve a barrer")
    func aDeviceThatAlreadyRanTheCurrentSweep_staysPut() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        defaults.set(true, forKey: "fxOneToOneRepairSweep.v2")
        let row = try insertRow(currencyCode: foreignCode, exchangeRate: 1.0, context: context)

        let result = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(result.fixed == 0)
        #expect(row.exchangeRate == 1.0)
    }

    // MARK: - Lo que no tiene derecho a sellarse

    /// **Un store vacío no quema el one-shot.** Este barrido no espera a ningún gate de store-ready: en
    /// un primer arranque tras reinstalar barría cero filas, sellaba, y el corpus quedaba fuera de
    /// alcance para siempre al bajar después.
    ///
    /// Se afirma por comportamiento —el arranque siguiente SÍ repara— y no leyendo el flag: es la
    /// consecuencia que le importa al usuario.
    @Test("un store vacío no quema el one-shot, y el arranque siguiente sí repara")
    func emptyStore_doesNotBurnTheFlag() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()

        let first = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)
        #expect(first.fixed == 0)

        // El restore baja el corpus en el arranque siguiente.
        let row = try insertRow(currencyCode: foreignCode, exchangeRate: 1.0, context: context)
        let second = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(second.fixed == 1)
        #expect(abs(row.exchangeRate - Self.fixtureRate) < 0.0001)
    }

    /// **El otro lado del guard de presencia, y hace falta:** con corpus presente y ninguna fila que
    /// encaje, el barrido SÍ hizo su trabajo y se sella. Sin este caso, «no quemar sobre un store
    /// vacío» sería indistinguible de «no quemar nunca», que dejaría el barrido recorriendo la tabla en
    /// cada arranque para siempre — justo el coste que el one-shot existe para evitar.
    ///
    /// Fija además el **residual declarado**: el guard distingue *vacío* de *no vacío*, no *completo* de
    /// *parcial*, así que una fila que llegue después de sellar ya no la mira nadie. Está aquí escrito
    /// como comportamiento esperado para que nadie lo descubra como sorpresa.
    @Test("con corpus y sin candidatas, el barrido sí se sella")
    func corpusWithoutCandidates_burnsTheFlag() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        try insertRow(
            currencyCode: CurrencyDefaults.currentPreferred,
            exchangeRate: 1.0,
            amountInPreferred: -50,
            context: context
        )

        let first = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)
        #expect(first.fixed == 0)

        let later = try insertRow(currencyCode: foreignCode, exchangeRate: 1.0, context: context)
        let second = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(second.fixed == 0)
        #expect(later.exchangeRate == 1.0)
    }

    /// **Con el import en curso, el barrido ni corre ni se sella.** Este barrido vivía en el paso 2 del
    /// bootstrap sin gate de quiescencia, mientras `updateProvisionalTransactions` —tres líneas
    /// después— sí salía por el suyo: en ese arranque se tocaban filas, se quemaba el flag, y el
    /// reparador que debía curar las reabiertas ni siquiera corría.
    @Test("con el import en curso no se sella, y repara cuando el store se queda quieto")
    func nonQuiescentImport_doesNotBurnTheFlag() throws {
        let context = try makeTestContext()
        let defaults = try makeIsolatedDefaults()
        let row = try insertRow(currencyCode: foreignCode, exchangeRate: 1.0, context: context)

        let deferred = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: false)
        #expect(deferred.fixed == 0)
        #expect(row.exchangeRate == 1.0)

        let afterQuiescence = TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(
            context: context, defaults: defaults, isQuiescent: true)

        #expect(afterQuiescence.fixed == 1)
        #expect(abs(row.exchangeRate - Self.fixtureRate) < 0.0001)
    }

    // MARK: - El cableado que producción usa de verdad

    /// **Los once casos de arriba inyectan `isQuiescent` y `defaults`, y producción no pasa ninguno de
    /// los dos.** Sin esto, un mutante que cambiara el default por `isQuiescent ?? true` dejaría la
    /// suite entera verde devolviendo la app exactamente al bug del ticket. La rama de producción se
    /// ejercita llamando **sin** el parámetro, y el barrido de fuente fija de dónde sale el valor.
    ///
    /// Se fija también el **orden** de las dos llamadas del bootstrap, que el propio comentario de
    /// producción declara crítico —el barrido va antes para que lo que reabra se cure en el mismo
    /// arranque— y que hasta hoy no pinneaba nadie.
    @Test("el llamador de producción resuelve la quiescencia del servicio de sync, y en ese orden")
    func productionCallSite_isWiredToTheSyncService() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let service = try String(
            contentsOf: root.appendingPathComponent("Yala/Services/TransactionUpdateService.swift"),
            encoding: .utf8)
        let bootstrapper = try String(
            contentsOf: root.appendingPathComponent("Yala/App/AppBootstrapper.swift"), encoding: .utf8)

        #expect(service.contains("isQuiescent ?? iCloudSyncService.shared.isImportQuiescent"))

        let sweep = try #require(
            bootstrapper.range(of: "TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded("))
        let repairer = try #require(
            bootstrapper.range(of: "TransactionUpdateService.updateProvisionalTransactions("))
        #expect(sweep.lowerBound < repairer.lowerBound)

        // Y que la llamada real no inyecta nada: si algún día pasara `isQuiescent:`, el default deja de
        // ser el camino de producción y este fichero estaría probando otra cosa.
        let callLine = try #require(
            bootstrapper[sweep.lowerBound...].split(separator: "\n").first.map(String.init))
        #expect(!callLine.contains("isQuiescent"))
    }

    // MARK: - La derivación, a pelo

    /// La lógica pura que decide entre curar en el sitio y reabrir. Se prueba aparte del store porque
    /// las bandas de entrada —monto diminuto, cociente 1, tasa inservible— son donde vive la decisión.
    @Test("la tasa solo se deduce cuando los montos dicen que hubo conversión")
    func rateIsOnlyDerivedWhenTheAmountsSayThereWasAConversion() {
        // Hubo conversión: el cociente ES la tasa, y sale positiva aunque los dos montos sean negativos.
        #expect(ExchangeRateRepairLogic.rateFromStoredAmounts(
            amount: -50, amountInPreferredCurrency: -186) .map { abs($0 - 3.72) < 0.0001 } == true)
        // Monto crudo: no hay nada que deducir.
        #expect(ExchangeRateRepairLogic.rateFromStoredAmounts(
            amount: -50, amountInPreferredCurrency: -50) == nil)
        // Tasa inservible.
        #expect(ExchangeRateRepairLogic.rateFromStoredAmounts(
            amount: -50, amountInPreferredCurrency: 0) == nil)
        // Monto diminuto: mismo umbral que el reparador, para no divergir de él.
        #expect(ExchangeRateRepairLogic.rateFromStoredAmounts(
            amount: 0.0001, amountInPreferredCurrency: 0.000372) == nil)
        // Y su pareja de control, justo al otro lado del umbral.
        #expect(ExchangeRateRepairLogic.rateFromStoredAmounts(
            amount: 0.001, amountInPreferredCurrency: 0.00372) != nil)
    }
}
