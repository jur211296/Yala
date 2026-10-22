//
//  RecordsViewModelBulkAccountCurrencyTests.swift
//  YalaTests
//
//  Que mover transacciones a una cuenta de OTRA divisa deje coherentes las cuatro columnas DERIVADAS
//  del grupo `money` —el grupo tiene cinco; la quinta es `amount`, que esta operación no toca—.
//  Ticket `bulk-update-account-leaves-converted-amount-stale`.
//
//  **Por qué la ruta bajo prueba es la del ViewModel y no la del servicio.** El ticket salió de
//  `TransactionService.bulkUpdateAccount`, que reasignaba `currencyCode` sin recomputar las derivadas.
//  Ese método se BORRÓ en vez de parchearse —nunca tuvo un llamador en toda la historia del repo, y
//  divergía de la ruta real en dos cosas, no en una; el porqué completo está donde estaba, en
//  `TransactionService.swift`—. La operación que la app ejecuta de verdad es
//  `RecordsViewModel.bulkUpdateAccount`, que `BulkEditSheet` llama al confirmar la edición masiva, y
//  hasta hoy **no tenía ni un test**.
//
//  **Estos tres casos NO protegen el borrado, y por eso hay una segunda suite al final del fichero.**
//  Es un matiz que costó una lente de review descubrir: ninguno de los tres toca `TransactionService`,
//  así que si alguien repega allí el método malo los tres siguen verdes. Quien vigila esa superficie es
//  el source-scan de `BulkAccountCurrencyRecalcSourceScanTests`; estos miden el comportamiento de la
//  ruta viva, que es lo que el usuario ejecuta.
//
//  **Por qué las tasas se siembran a mano en vez de usar las de la tabla estática.** Hace falta un
//  testigo aritmético que se pueda comprobar de cabeza y que no dependa de cuál sea la divisa
//  preferida del simulador (sale de `UserDefaults` y estos tests no pueden darla por conocida).
//  Sembrando la preferida a `1.0` y la extranjera a `100.0` sobre base USD, la conversión da
//  `amount / 100` **por las dos ramas posibles** de `performConversion` —la cruzada
//  (`amount / fromRate * toRate`) y la directa a base (`amount / fromRate`, que se toma cuando la
//  preferida ES el USD e ignora `toRate`)—, así que el número esperado es el mismo con cualquier
//  preferida. −250,00 se convierte en −2,50 y la tasa efectiva es 0,01.
//
//  **Los dos escenarios van en ESPEJO a propósito.** Con uno solo, un fix que dejara el monto
//  convertido clavado en el importe original también pasaría: en el escenario que mueve a una cuenta
//  en la divisa preferida, la conversión correcta ES la identidad. Es el escenario inverso —mover a
//  una cuenta extranjera— el que exige que el número cambie. Cada uno cubre el punto ciego del otro, y
//  el valor stale de cada uno es exactamente el valor correcto del contrario.
//
//  Fichero aparte: `makeTestContext()` reusa el container por `#fileID`, así que el store es propio.
//  `.serialized` porque la suite hace más de una llamada (regla de `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Mover transacciones a una cuenta de otra divisa recalcula el grupo money", .serialized)
struct RecordsViewModelBulkAccountCurrencyTests {

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Una divisa que con seguridad NO es la preferida del entorno **y que tampoco es el USD**.
    ///
    /// Lo segundo importa tanto como lo primero: el USD es la base de la tabla de tasas y tiene su
    /// propia rama en `performConversion` (`amount * toRate`), así que usarlo como divisa de origen
    /// rompería el testigo aritmético de abajo. Se compara NORMALIZADO porque el pipeline normaliza
    /// los dos lados: con la preferida guardada como `"jpy"`, un `foreignCode` de `"JPY"` entraría por
    /// la rama misma-divisa y la tasa saldría 1.0 con el fix puesto. Molde de
    /// `ChatDraftAccountCurrencyTests`.
    private var foreignCode: String {
        normalizeCurrencyCode(CurrencyDefaults.currentPreferred) == "JPY" ? "CHF" : "JPY"
    }

    private var pastDate: Date {
        Calendar.current.date(byAdding: .day, value: -10, to: Date.now) ?? Date.now
    }

    /// El importe de prueba. Negativo (gasto) y de una magnitud que no se confunde con nada más del
    /// fixture: si una aserción falla, el número del mensaje dice por sí solo de dónde salió.
    private let amount: Double = -250

    /// Lo que vale ese importe en la divisa preferida cuando la transacción está en la extranjera.
    private var convertedAmount: Double { amount / 100 }   // −2,50

    /// La fila del día con TODAS las divisas —para que `resolveRates` la dé por `.exact` y la cuarta
    /// columna (`isExchangeRateProvisional`) tenga un valor afirmable— pero con las dos que este test
    /// usa fijadas a mano.
    private func seedRates(on date: Date, in context: ModelContext) throws {
        var rates = Dictionary(
            uniqueKeysWithValues: CurrencyCode.allRawValues.map {
                ($0, CurrencyCode.fallbackRates[$0] ?? 1.0)
            }
        )
        rates[normalizeCurrencyCode(CurrencyDefaults.currentPreferred)] = 1.0
        rates[foreignCode] = 100.0

        let row = try ExchangeRate(
            dateKey: Self.dateFormatter.string(from: date),
            base: "USD",
            ratesDictionary: rates
        )
        context.insert(row)
        try context.save()
    }

    /// Una transacción ya persistida y CON SUS DERIVADAS AL DÍA, que es el estado del que parte el
    /// caso real: la fila estaba bien antes de la edición masiva y lo que se mide es si sigue bien
    /// después. Sin el `recalculatePreferredCurrency` de aquí, la fila nacería con las derivadas en
    /// su default y el test no podría distinguir «se quedó stale» de «nunca se calculó».
    private func makeTransaction(
        in account: Account, on date: Date, context: ModelContext
    ) throws -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: account.currencyCode,
            note: "Compra",
            account: account
        )
        context.insert(tx)
        tx.recalculatePreferredCurrency(context: context)
        try context.save()
        return tx
    }

    /// Centinelas imposibles en las cuatro derivadas, **justo antes** de la operación que se mide.
    ///
    /// **Sin esto, tres de las cuatro aserciones del grupo `money` no podrían fallar nunca**, y la
    /// suite aparentaría cubrir cuatro columnas mientras cubre una. El motivo es que en este escenario
    /// las otras tres son invariantes: `preferredCurrencyCode` sale de
    /// `CurrencyDefaults.currentPreferred` y vale lo mismo antes y después (además su default de
    /// modelo es `"PEN"`, que es justo la preferida más probable del entorno), e
    /// `isExchangeRateProvisional` ya venía en `false` y en `false` se quedaría. Comparar el valor
    /// final contra el que el fixture dejó no distingue «lo recomputó» de «nunca lo tocó»: las dos
    /// historias dan el mismo verde.
    ///
    /// `exchangeRate` merece mención aparte porque su tautología es más sutil: el recalculador lo
    /// DERIVA como `amountInPreferredCurrency / amount`, así que afirmar los dos es afirmar el mismo
    /// número dos veces. Ensuciarlo con un valor que no cumple esa relación es lo que lo convierte en
    /// una medición independiente.
    ///
    /// Ensuciar es además lo que hace el test hermano de `bulkUpdateAmount`
    /// (`TransactionServiceTests`, con su `-999`), y por la misma razón.
    private func dirtyDerivedColumns(of tx: TransactionItem) throws {
        tx.amountInPreferredCurrency = -999_999
        tx.exchangeRate = 42
        tx.preferredCurrencyCode = "XXX"      // no es una divisa real
        tx.isExchangeRateProvisional = true
    }

    /// El VM con la transacción ya seleccionada, que es lo que `BulkEditSheet` tiene delante cuando el
    /// usuario confirma. El id se captura DESPUÉS del `save()` a propósito: antes de guardar es
    /// temporal y `context.model(for:)` —lo que usa `getSelectedTransactions`— no lo resolvería, así
    /// que la selección saldría vacía y el bulk no tocaría nada. Un test así pasaría en VERDE sin
    /// haber ejecutado una sola línea del código bajo prueba.
    private func makeViewModel(selecting tx: TransactionItem) -> RecordsViewModel {
        let vm = RecordsViewModel()
        vm.selectedRecordIDs = [tx.persistentModelID]
        return vm
    }

    // MARK: - El caso del ticket

    @Test("Mover a una cuenta en otra divisa reconvierte el monto (no deja el de la divisa vieja)")
    func movingToForeignAccountRecomputesTheConvertedAmount() throws {
        let context = try makeTestContext()
        let date = pastDate
        try seedRates(on: date, in: context)

        let preferred = CurrencyDefaults.currentPreferred
        let local = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        let foreign = makeTestAccount(context: context, name: "Viajes", currencyCode: foreignCode)
        try context.save()

        // CONTROL POSITIVO del escenario: si las dos cuentas comparten divisa no hay conversión que
        // cambiar, y cualquier verde de abajo sería vacío.
        #expect(
            normalizeCurrencyCode(local.currencyCode) != normalizeCurrencyCode(foreign.currencyCode),
            """
            Las dos cuentas están en la misma divisa (\(local.currencyCode)): no hay cambio de divisa \
            que medir. Revisa `foreignCode` contra la preferida del entorno.
            """
        )

        let tx = try makeTransaction(in: local, on: date, context: context)

        // Y el estado de PARTIDA, que es la otra mitad del control: la fila entra al bulk con sus
        // derivadas correctas para la divisa preferida (identidad), así que lo que se mida después es
        // el efecto del bulk y no un arrastre de la construcción del fixture.
        #expect(tx.amountInPreferredCurrency == amount, "el fixture no partió de una fila coherente")
        #expect(tx.exchangeRate == 1.0, "el fixture no partió de una fila coherente")

        // Y ahora se ensucian, para que las cuatro aserciones de abajo midan de verdad. Ver
        // `dirtyDerivedColumns`.
        try dirtyDerivedColumns(of: tx)

        let vm = makeViewModel(selecting: tx)
        vm.bulkUpdateAccount(foreign, context: context)

        #expect(
            vm.bulkUpdateError == nil,
            "la edición masiva se rechazó (\(vm.bulkUpdateError ?? "")) y no llegó a mover nada"
        )
        // El SUT se traga un `save()` fallido con un `print` bajo `#if DEBUG` y no lo expone por
        // ningún lado, así que sin esto un guardado que lanza es indistinguible de uno que funciona:
        // todas las aserciones de abajo leen la instancia EN MEMORIA, que el bucle ya mutó antes del
        // `save()`. Los mensajes hablan de lo que ven Panel, Estadísticas e informes —o sea, de lo
        // que quedó en el store— y esta línea es lo que les da derecho a decirlo.
        #expect(
            context.hasChanges == false,
            "el contexto quedó con cambios pendientes: el `save()` del bulk falló y nada de esto llegó a disco"
        )
        #expect(tx.account?.persistentModelID == foreign.persistentModelID, "no cambió de cuenta")

        // Las cuatro columnas DERIVADAS del grupo `money` (que tiene cinco: la quinta es `amount`,
        // que esta operación no toca), más el input que las manda.
        #expect(
            normalizeCurrencyCode(tx.currencyCode) == normalizeCurrencyCode(foreignCode),
            "la transacción no adoptó la divisa de su nueva cuenta"
        )
        #expect(
            abs(tx.amountInPreferredCurrency - convertedAmount) < 0.000_001,
            """
            El monto convertido quedó en \(tx.amountInPreferredCurrency) y debía ser \
            \(convertedAmount). Si vale \(amount) es EXACTAMENTE el bug del ticket: la fila cambió de \
            divisa y se quedó con la conversión de la anterior, así que los 14 calculadores que leen \
            `amountInPreferredCurrency` —Panel, Estadísticas, presupuestos, informes— suman ese \
            número como si fuera bueno y el usuario ve un total inflado 100 veces.
            """
        )
        // La tolerancia va deliberadamente MÁS FLOJA que la del monto: la tasa se deriva de él
        // (`amountInPreferred / amount`), así que un error de 1e-6 en el monto se traduce en 4e-9 en
        // la tasa. Con 1e-9 aquí habría una banda estrecha donde el monto pasa y la tasa falla, y el
        // rojo culparía a «la tasa de la divisa vieja» cuando el problema sería la tolerancia.
        #expect(
            abs(tx.exchangeRate - 0.01) < 0.000_01,
            """
            La tasa quedó en \(tx.exchangeRate) y debía ser 0.01. Un 1.0 aquí es la tasa de la divisa \
            VIEJA sin recomputar; un 42 es el centinela del fixture, o sea que no se tocó nada.
            """
        )
        #expect(
            normalizeCurrencyCode(tx.preferredCurrencyCode) == normalizeCurrencyCode(preferred),
            """
            La columna de divisa preferida quedó en \(tx.preferredCurrencyCode) y debía ser \
            \(preferred). Un "XXX" es el centinela del fixture sin tocar.
            """
        )
        #expect(
            tx.isExchangeRateProvisional == false,
            """
            La fila quedó marcada provisional aunque la tasa del día está sembrada COMPLETA y la \
            conversión es exacta: la mandaría a la cola del reparador sin nada que reparar. Si el \
            centinela del fixture (`true`) sigue puesto, es que no se recomputó nada.
            """
        )
    }

    // MARK: - El espejo

    @Test("Y en el sentido inverso, la conversión vuelve a ser la identidad")
    func movingBackToPreferredAccountRestoresIdentity() throws {
        let context = try makeTestContext()
        let date = pastDate
        try seedRates(on: date, in: context)

        let preferred = CurrencyDefaults.currentPreferred
        let foreign = makeTestAccount(context: context, name: "Viajes", currencyCode: foreignCode)
        let local = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        try context.save()

        let tx = try makeTransaction(in: foreign, on: date, context: context)

        // Control de partida en espejo: aquí la fila entra CONVERTIDA, no en identidad.
        #expect(
            abs(tx.amountInPreferredCurrency - convertedAmount) < 0.000_001,
            "el fixture no partió de una fila coherente (\(tx.amountInPreferredCurrency))"
        )

        try dirtyDerivedColumns(of: tx)

        let vm = makeViewModel(selecting: tx)
        vm.bulkUpdateAccount(local, context: context)

        #expect(vm.bulkUpdateError == nil, "la edición masiva se rechazó y no movió nada")
        #expect(
            context.hasChanges == false,
            "el contexto quedó con cambios pendientes: el `save()` del bulk falló"
        )
        #expect(
            normalizeCurrencyCode(tx.currencyCode) == normalizeCurrencyCode(preferred),
            "la transacción no adoptó la divisa de su nueva cuenta"
        )
        #expect(
            abs(tx.amountInPreferredCurrency - amount) < 0.000_001,
            """
            El monto convertido quedó en \(tx.amountInPreferredCurrency) y debía ser \(amount): la \
            transacción ya está en la divisa preferida, así que la conversión es la identidad. Si \
            vale \(convertedAmount) se quedó con la conversión de la divisa extranjera anterior, y el \
            gasto aparecería 100 veces más pequeño de lo que fue.
            """
        )
        #expect(
            abs(tx.exchangeRate - 1.0) < 0.000_01,
            "la tasa quedó en \(tx.exchangeRate) y en la divisa preferida debía volver a 1.0"
        )
        #expect(
            normalizeCurrencyCode(tx.preferredCurrencyCode) == normalizeCurrencyCode(preferred),
            "la columna de divisa preferida quedó en \(tx.preferredCurrencyCode)"
        )
        // Aquí `convertChecked` sale por el atajo de misma divisa y devuelve `.exact` sin mirar la
        // fila de tasas, así que lo que esta aserción distingue NO es la calidad de la tasa sino que
        // el recálculo haya corrido: con el centinela `true` del fixture sin limpiar, falla.
        #expect(
            tx.isExchangeRateProvisional == false,
            "el centinela `true` del fixture sigue puesto: no se recomputó nada"
        )
    }

    // MARK: - Lo otro que la ruta viva hace y el método borrado no hacía

    @Test("Una transferencia no se puede mover en masa, y ninguna de sus dos patas se toca")
    func transfersAreRejectedAndLeftUntouched() throws {
        let context = try makeTestContext()
        let date = pastDate
        try seedRates(on: date, in: context)

        let preferred = CurrencyDefaults.currentPreferred
        let local = makeTestAccount(context: context, name: "Diaria", currencyCode: preferred)
        let destino = makeTestAccount(context: context, name: "Ahorro", currencyCode: preferred)
        let foreign = makeTestAccount(context: context, name: "Viajes", currencyCode: foreignCode)
        try context.save()

        // Una transferencia de VERDAD: dos patas ligadas por el mismo `transferPairID`, cada una en
        // su cuenta. Con una sola fila el test no podría afirmar lo que dice su nombre —que ninguna
        // de las dos se toca— y el rechazo se mediría contra un par huérfano que no existe en la app.
        let salida = try makeTransaction(in: local, on: date, context: context)
        let entrada = try makeTransaction(in: destino, on: date, context: context)
        for (pata, signo) in [(salida, -1.0), (entrada, 1.0)] {
            pata.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            pata.transferPairID = "par-de-prueba"
            pata.amount = signo * abs(amount)
            pata.recalculatePreferredCurrency(context: context)
        }
        try context.save()

        let vm = makeViewModel(selecting: salida)
        vm.bulkUpdateAccount(foreign, context: context)

        #expect(
            vm.bulkUpdateError != nil,
            """
            La edición masiva aceptó mover la cuenta de una TRANSFERENCIA. Una transferencia tiene dos \
            cuentas inherentes ligadas por `transferPairID`; colapsarlas a una sola parte el par entre \
            cuentas no relacionadas y descuadra los dos saldos. Es la segunda cosa que el \
            `bulkUpdateAccount` del servicio no hacía, y por la que se borró en vez de parchearlo.
            """
        )
        #expect(
            salida.account?.persistentModelID == local.persistentModelID,
            "se rechazó la operación pero la pata seleccionada YA había cambiado de cuenta"
        )
        #expect(
            normalizeCurrencyCode(salida.currencyCode) == normalizeCurrencyCode(preferred),
            "se rechazó la operación pero la divisa de la pata seleccionada YA había cambiado"
        )
        #expect(
            entrada.account?.persistentModelID == destino.persistentModelID,
            """
            La OTRA pata del par cambió de cuenta. Aunque no estaba seleccionada, varias operaciones \
            masivas de esta pantalla propagan al partner por `transferPairID` (nota y tags lo hacen a \
            propósito): la de cuenta no debe, ni siquiera de rebote.
            """
        )
    }
}

// MARK: - El guard del método borrado

/// El source-scan que hace verdadera la nota de `TransactionService.swift`.
///
/// **Existe porque la suite de arriba NO protege el borrado, y conviene decirlo sin rodeos.** Los tres
/// casos ejercitan `RecordsViewModel`; ninguno toca `TransactionService`. Si alguien vuelve a pegar
/// allí el `bulkUpdateAccount` que se borró —sin recomputar las derivadas— los tres siguen en verde,
/// porque el bug volvería a estar en una ruta que nadie llama y que ninguna aserción de comportamiento
/// puede observar. Un guard sobre la superficie equivocada es peor que ninguno: promete algo que no da.
///
/// Lo que se vigila es exactamente el patrón del bug, **por método y no por fichero**: el fichero ya
/// contiene un `recalculatePreferredCurrency` (en `bulkUpdateAmount`), así que un barrido a nivel de
/// fichero pasaría en verde con el método malo dentro. Ese era justo el estado del árbol hasta hoy.
@Suite("Ningún método de servicio reasigna la divisa sin recomputar las derivadas")
struct BulkAccountCurrencyRecalcSourceScanTests {

    /// Los ficheros vigilados: los dos sitios que han tenido una implementación de la edición masiva
    /// de cuenta. `TransactionService` ya no tiene ninguna y este scan es lo que vigila que siga así
    /// (o que, si vuelve, vuelva completa).
    static let watchedFiles = [
        "Yala/Services/TransactionService.swift",
        "Yala/App/ViewModels/RecordsViewModel.swift",
    ]

    static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)          // YalaTests/<este fichero>
            .deletingLastPathComponent()          // YalaTests/
            .deletingLastPathComponent()          // raíz
    }

    /// Devuelve los métodos que asignan `currencyCode` a una transacción **sin** llamar al
    /// recalculador dentro del propio método.
    ///
    /// Se mira el fuente sin comentarios de línea, y no es decorativo: la nota que quedó donde estaba
    /// el método borrado menciona las dos cosas en prosa, así que un barrido sobre el texto crudo se
    /// acusaría a sí mismo. Se reusa el `strippingComments` de `ManualWriteRateQualityTests` —el
    /// mismo problema y la misma solución— en vez de escribir un segundo despiece.
    static func methodsAssigningCurrencyWithoutRecalc(in source: String) -> [String] {
        let clean = ManualWriteRateQualityTests.strippingComments(source)
        // Corte por declaración de método a nivel de tipo (4 espacios de indentación).
        let chunks = clean.components(separatedBy: "\n    func ")
        var offenders: [String] = []
        for chunk in chunks.dropFirst() {
            let name = chunk.prefix(while: { $0 != "(" })
            let assigns = chunk.contains(".currencyCode =") && !chunk.contains(".currencyCode ==")
            guard assigns else { continue }
            if !chunk.contains("recalculatePreferredCurrency") {
                offenders.append(String(name))
            }
        }
        return offenders
    }

    // MARK: - Controles del detector

    @Test("El scan detecta el método que se borró (control positivo)")
    func scanCatchesTheDeletedMethod() {
        // El cuerpo EXACTO que tenía `TransactionService.bulkUpdateAccount` antes del 2026-09-08.
        let bad = """
            final class X {
                func bulkUpdateAccount(_ transactions: [TransactionItem], account: Account) throws {
                    let context = try requireContext()
                    for transaction in transactions {
                        transaction.account = account
                        transaction.currencyCode = account.currencyCode
                    }
                    try context.save()
                }
            }
            """
        #expect(
            Self.methodsAssigningCurrencyWithoutRecalc(in: bad) == ["bulkUpdateAccount"],
            "el detector no ve el bug que existió de verdad: sin esto el scan de abajo no vale nada"
        )
    }

    @Test("Y aprueba el mismo método con el recálculo puesto (control negativo)")
    func scanAcceptsTheFixedMethod() {
        let good = """
            final class X {
                func bulkUpdateAccount(_ transactions: [TransactionItem], account: Account) throws {
                    let context = try requireContext()
                    for transaction in transactions {
                        transaction.account = account
                        transaction.currencyCode = account.currencyCode
                        transaction.recalculatePreferredCurrency(context: context)
                    }
                    try context.save()
                }
            }
            """
        #expect(Self.methodsAssigningCurrencyWithoutRecalc(in: good).isEmpty)
    }

    @Test("Y no se deja engañar por la prosa del comentario que quedó en su lugar")
    func scanIgnoresComments() {
        let commented = """
            final class X {
                func nada() throws {
                    // transaction.currencyCode = account.currencyCode  ← lo que hacía el borrado
                    try context.save()
                }
            }
            """
        #expect(
            Self.methodsAssigningCurrencyWithoutRecalc(in: commented).isEmpty,
            "el scan cuenta comentarios como código y se acusaría a sí mismo"
        )
    }

    // MARK: - El barrido

    @Test("Los ficheros vigilados están limpios")
    func watchedFilesAreClean() throws {
        for path in Self.watchedFiles {
            let url = Self.repoRoot().appendingPathComponent(path)
            let source = try String(contentsOf: url, encoding: .utf8)
            let offenders = Self.methodsAssigningCurrencyWithoutRecalc(in: source)
            #expect(
                offenders.isEmpty,
                """
                \(path) reasigna `currencyCode` sin recomputar las derivadas en: \
                \(offenders.joined(separator: ", ")).
                Cambiar la divisa de una transacción ya persistida cambia el INPUT de la conversión: si \
                no se llama `recalculatePreferredCurrency` en el mismo método, `amountInPreferredCurrency`, \
                `exchangeRate`, `preferredCurrencyCode` e `isExchangeRateProvisional` se quedan con los \
                valores de la divisa anterior. Y no lo caza nada más: `currency_code` no pertenece a \
                ningún grupo de coherencia en `EntityEmissionMap`, así que `DeltaEmitter` no expande el \
                grupo `money` ni evalúa su guard. Ticket: bulk-update-account-leaves-converted-amount-stale.
                """
            )
        }
    }
}
