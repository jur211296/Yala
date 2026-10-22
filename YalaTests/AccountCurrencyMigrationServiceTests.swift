//
//  AccountCurrencyMigrationServiceTests.swift
//  YalaTests
//
//  Reexpresar el histórico de una cuenta al cambiarle la divisa.
//  Ticket `changing-an-account-currency-orphans-its-whole-history`.
//
//  **Es el primer sitio del repo que reescribe el `amount` de transacciones ya persistidas.** Las
//  cuatro derivadas (`amountInPreferredCurrency`, `exchangeRate`, `preferredCurrencyCode`,
//  `isExchangeRateProvisional`) tienen reparador y se pueden recalcular; la columna cruda no. Por eso
//  aquí se fija sobre todo QUÉ NÚMERO sale, y no solo que salga uno.
//
//  Fichero propio a propósito: `makeTestContext()` reusa el container por `#fileID`, así que el store
//  es de esta suite. `.serialized` porque cada test pide contexto y el helper vacía el store en cada
//  llamada — dos tests en paralelo se borrarían las filas el uno al otro.
//
//  Las tasas se siembran a mano y `convertHistory` no toca la red: eso separa el fallo de cálculo del
//  fallo de red, que aquí es constante (`ExchangeRateService` cae por AppAttest en todos los
//  arranques del simulador). `prepareRates` no se prueba aquí por ese mismo motivo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Reexpresar el histórico de una cuenta", .serialized)
struct AccountCurrencyMigrationServiceTests {

    // MARK: - Helpers

    /// Dos fechas con tasas DISTINTAS, que es lo que hace discriminante a esta suite.
    ///
    /// Con una sola tasa, un servicio que usara la fecha de hoy en vez de la de cada fila daría
    /// exactamente el mismo resultado y todos los tests pasarían con el bug puesto.
    private enum Fixture {
        /// 100 PEN de este día valen 100 / 3,75 = 26,666… USD.
        static let earlyKey = "2026-01-15"
        static let earlyPEN = 3.75
        /// 100 PEN de este día valen 100 / 4,00 = 25,00 USD. Redondo a propósito: es el número que
        /// se lee en la aserción.
        static let lateKey = "2026-06-15"
        static let latePEN = 4.00
    }

    /// **UTC y mediodía, no la zona del simulador.** `CurrencyConverter` deriva el `dateKey` con un
    /// formatter fijado en UTC (`:137-140`), así que una fecha construida en horario local se
    /// convierte en la clave del día ANTERIOR en cualquier zona al este de Greenwich: la fila
    /// sembrada no se encuentra, la conversión cae al escalón arrastrado y `approximateCount` sale 1
    /// donde el test espera 0. El fallo sería por zona horaria del simulador y no por el código.
    private func date(_ key: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: key + " 12:00") ?? Date()
    }

    private func seedRates(_ context: ModelContext) throws {
        _ = try makeTestExchangeRate(
            context: context, dateKey: Fixture.earlyKey,
            rates: ["USD": 1.0, "PEN": Fixture.earlyPEN, "EUR": 0.92])
        _ = try makeTestExchangeRate(
            context: context, dateKey: Fixture.lateKey,
            rates: ["USD": 1.0, "PEN": Fixture.latePEN, "EUR": 0.92])
        try context.save()
    }

    private func makeRow(
        _ context: ModelContext, amount: Double, on key: String, currency: String = "PEN"
    ) throws -> TransactionItem {
        let account = makeTestAccount(context: context, name: "Cuenta \(UUID().uuidString)", currencyCode: currency)
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        return makeTestTransaction(
            context: context, amount: amount, date: date(key),
            account: account, category: category, subcategory: sub, currencyCode: currency)
    }

    // MARK: - El número, y de qué fecha sale

    /// **El test que fija la decisión.** Dos filas del MISMO importe en fechas con tasas distintas
    /// tienen que salir con importes distintos: eso es lo único que distingue «la tasa de su fecha»
    /// de «la tasa de hoy», que es lo que hace el resto de la app al PINTAR y sería incorrecto al
    /// PERSISTIR.
    @Test func cadaFilaSeConvierteConLaTasaDeSuFecha() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let early = try makeRow(context, amount: -100, on: Fixture.earlyKey)
        let late = try makeRow(context, amount: -100, on: Fixture.lateKey)

        let outcome = AccountCurrencyMigrationService.convertHistory(
            rows: [early, late], to: "USD", context: context)

        #expect(outcome.convertedCount == 2)
        // 100 / 3,75 = 26,666… · 100 / 4,00 = 25,00
        #expect(abs(early.amount - (-26.6667)) < 0.001)
        #expect(abs(late.amount - (-25.0)) < 0.001)
        // Y, sobre todo, que NO sean el mismo número.
        #expect(early.amount != late.amount)
    }

    @Test func elSignoSePreserva_ungastoSigueSiendoGasto() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let gasto = try makeRow(context, amount: -400, on: Fixture.lateKey)
        let ingreso = try makeRow(context, amount: 400, on: Fixture.lateKey)

        AccountCurrencyMigrationService.convertHistory(
            rows: [gasto, ingreso], to: "USD", context: context)

        #expect(gasto.amount < 0)
        #expect(ingreso.amount > 0)
        #expect(abs(gasto.amount - (-100.0)) < 0.001)
        #expect(abs(ingreso.amount - 100.0) < 0.001)
    }

    @Test func laDivisaDeLaFilaPasaALaNueva() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let row = try makeRow(context, amount: -100, on: Fixture.lateKey)
        AccountCurrencyMigrationService.convertHistory(rows: [row], to: "USD", context: context)

        #expect(normalizeCurrencyCode(row.currencyCode) == "USD")
    }

    // MARK: - Las derivadas describen el importe NUEVO

    /// Si el recálculo de derivadas corriera ANTES de escribir el importe, `exchangeRate` describiría
    /// el importe viejo: la forma exacta del bug que este ticket cierra, una columna más abajo.
    ///
    /// Se afirma sobre `exchangeRate` porque es la derivada que no depende de qué divisa preferida
    /// tenga el simulador: convertida a USD y sea cual sea la preferida, la tasa que sale de la fila
    /// es la de USD→preferida, y con la fila viva convertida ya no puede ser la de PEN.
    @Test func lasDerivadasDescribenElImporteYaConvertido() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let row = try makeRow(context, amount: -400, on: Fixture.lateKey)
        // Antes: 400 PEN con la derivada plantada por la factoría.
        let ratioAntes = row.amountInPreferredCurrency / row.amount

        AccountCurrencyMigrationService.convertHistory(rows: [row], to: "USD", context: context)

        // La derivada sigue siendo coherente con el importe que hay AHORA (que ya es 100 USD), no
        // con los 400 PEN de antes.
        let ratioDespues = row.amountInPreferredCurrency / row.amount
        #expect(abs(ratioDespues - row.exchangeRate) < 0.001 || abs(ratioDespues + row.exchangeRate) < 0.001)
        #expect(abs(row.amountInPreferredCurrency) < abs(400.0 * ratioAntes) + 0.001)
    }

    // MARK: - Lo que no se toca

    /// Una fila ya estampada en la divisa destino no es una fila convertida. Contarla inflaría el
    /// número que el usuario acaba de confirmar en pantalla.
    @Test func filaYaEnLaDivisaDestino_niSeTocaNiSeCuenta() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let yaUSD = try makeRow(context, amount: -50, on: Fixture.lateKey, currency: "USD")
        let importeAntes = yaUSD.amount

        let outcome = AccountCurrencyMigrationService.convertHistory(
            rows: [yaUSD], to: "USD", context: context)

        #expect(outcome.convertedCount == 0)
        #expect(yaUSD.amount == importeAntes)
    }

    /// El origen de cada fila es su propio `currencyCode`, no la divisa de su cuenta. Importa
    /// justo en el caso que este ticket existe para cerrar: una cuenta que YA venía desemparejada.
    @Test func elOrigenEsLaDivisaDeLaFila_noLaDeLaCuenta() throws {
        let context = try makeTestContext()
        try seedRates(context)

        // Cuenta en PEN con una fila estampada en EUR (desemparejada de antes).
        let account = makeTestAccount(context: context, name: "Mixta", currencyCode: "PEN")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let row = makeTestTransaction(
            context: context, amount: -92, date: date(Fixture.lateKey),
            account: account, category: category, subcategory: sub, currencyCode: "EUR")

        AccountCurrencyMigrationService.convertHistory(rows: [row], to: "USD", context: context)

        // 92 EUR / 0,92 = 100 USD. Si hubiera partido de PEN (la divisa de la CUENTA) saldrían 23.
        #expect(abs(row.amount - (-100.0)) < 0.01)
    }

    // MARK: - Calidad de la tasa

    /// Una fecha sin fila de tasas no puede convertirse con la tasa exacta de ese día. El número
    /// sigue saliendo —del escalón que haya— pero el conteo tiene que decirlo: sin él no hay forma de
    /// distinguir «convertido con el dato bueno» de «convertido con lo que había».
    ///
    /// **El destino se elige para que NO sea la divisa preferida, y no es un detalle del test.**
    /// `isExchangeRateProvisional` lo escribe `recalculatePreferredCurrency`, que describe la pata
    /// `amount → preferida`: cuando el destino ES la preferida esa pata es la identidad, sale
    /// `.exact`, y el flag queda en `false` **aunque la conversión de origen a destino haya sido
    /// aproximada**. Fijar el destino en `"USD"` hacía que este test pasara o fallara según qué
    /// divisa preferida tuviera la máquina — verde en local con PEN, rojo en CI. El conteo
    /// (`approximateCount`) no tiene ese problema: mide la conversión que de verdad se hizo.
    ///
    /// Y el hueco que esto destapa es del PRODUCTO, no del test: con destino == preferida, un importe
    /// convertido por la tabla estática queda sellado como exacto y fuera del reparador. Lo que lo
    /// cierra es que `confirmCurrencyConversion` **no convierte** si falta cobertura de tasas.
    @Test func sinTasaDeEseDia_cuentaComoAproximada() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let preferida = normalizeCurrencyCode(CurrencyDefaults.currentPreferred)
        let destino = preferida == "USD" ? "EUR" : "USD"

        // Un año antes de la primera fila sembrada: no hay tasa de ese día ni anterior.
        let huerfana = try makeRow(context, amount: -100, on: "2025-01-15")
        let outcome = AccountCurrencyMigrationService.convertHistory(
            rows: [huerfana], to: destino, context: context)

        #expect(outcome.convertedCount == 1)
        #expect(outcome.approximateCount == 1)
        #expect(huerfana.isExchangeRateProvisional)
    }

    /// **El control de la asimetría de arriba, y la razón de que este fichero no pueda fijar el
    /// destino a un literal.** La misma conversión aproximada, pero HACIA la divisa preferida: el
    /// conteo sigue diciendo que fue aproximada —mide origen→destino— y el flag queda en `false`,
    /// porque describe la otra pata y ahí destino y preferida son la misma divisa.
    ///
    /// Corre en cualquier máquina sin depender de cuál sea esa divisa, y demuestra que el rojo que
    /// el CI cazó no era del código: era una aserción que dependía del entorno.
    @Test func haciaLaDivisaPreferida_elConteoLoDiceYElFlagNo() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let preferida = normalizeCurrencyCode(CurrencyDefaults.currentPreferred)
        // El origen tiene que ser distinto del destino o no habría conversión que medir.
        let origen = preferida == "PEN" ? "EUR" : "PEN"
        let huerfana = try makeRow(context, amount: -100, on: "2025-01-15", currency: origen)

        let outcome = AccountCurrencyMigrationService.convertHistory(
            rows: [huerfana], to: preferida, context: context)

        #expect(outcome.convertedCount == 1)
        #expect(outcome.approximateCount == 1)
        // El hueco del producto que esto documenta: sellada como exacta pese a venir de la tabla
        // estática. Lo cierra `confirmCurrencyConversion`, que no convierte si falta cobertura.
        #expect(huerfana.isExchangeRateProvisional == false)
    }

    @Test func conTasaExactaDelDia_noCuentaComoAproximada() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let row = try makeRow(context, amount: -100, on: Fixture.lateKey)
        let outcome = AccountCurrencyMigrationService.convertHistory(
            rows: [row], to: "USD", context: context)

        #expect(outcome.convertedCount == 1)
        #expect(outcome.approximateCount == 0)
    }

    // MARK: - El divisor LOCAL viaja con el importe

    /// Un split personal (la calculadora «dividir entre N») no lleva `splitExpenseID`, así que no lo
    /// manda ningún grupo y se convierte. Pero `splitTotalAmount` es DINERO: dejarlo sin tocar hace
    /// que al reabrir la transacción la calculadora enseñe «Total 400 / entre 4» sobre un importe que
    /// ya vale 25, y que la exportación escriba ese 400 con el símbolo nuevo.
    @Test func elSplitLocalSeReexpresaConElImporte() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let row = try makeRow(context, amount: -100, on: Fixture.lateKey)
        row.splitTotalAmount = 400          // dinero
        row.splitType = "equal"
        row.splitDivisor = 4                // personas — NO es dinero
        row.splitMyValue = 4                // en "equal" son personas, tampoco

        AccountCurrencyMigrationService.convertHistory(rows: [row], to: "USD", context: context)

        #expect(abs(row.amount - (-25.0)) < 0.01)
        #expect(abs((row.splitTotalAmount ?? 0) - 100.0) < 0.01)
        // Y lo que NO es dinero se queda como está: multiplicar personas por un tipo de cambio no
        // significa nada.
        #expect(row.splitDivisor == 4)
        #expect(row.splitMyValue == 4)
    }

    /// `splitMyValue` sí es dinero cuando el tipo es `exact` — y solo entonces.
    @Test func elValorExactoDelSplitSiEsDinero() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let row = try makeRow(context, amount: -100, on: Fixture.lateKey)
        row.splitTotalAmount = 400
        row.splitType = "exact"
        row.splitMyValue = 100

        AccountCurrencyMigrationService.convertHistory(rows: [row], to: "USD", context: context)

        #expect(abs((row.splitMyValue ?? 0) - 25.0) < 0.01)
    }

    // MARK: - No convertir a ciegas

    /// La decisión que separa «convertir con el dato bueno» de «convertir con lo que había». Se
    /// prueba sin red a propósito: el camino por el fetch mediría el timeout, no el guard.
    @Test func conTasasDeTodasLasFechas_noFaltaNada() throws {
        let context = try makeTestContext()
        try seedRates(context)

        let row = try makeRow(context, amount: -100, on: Fixture.lateKey)
        // Hoy también hace falta (es la tasa del saldo vivo): sin su fila, falta algo.
        #expect(AccountCurrencyMigrationService.missingRateDates(
            rows: [row], to: "USD", context: context).isEmpty == false)

        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        _ = try makeTestExchangeRate(context: context, dateKey: f.string(from: Date()),
                                     rates: ["USD": 1.0, "PEN": 4.0, "EUR": 0.92])
        try context.save()
        #expect(AccountCurrencyMigrationService.missingRateDates(
            rows: [row], to: "USD", context: context).isEmpty)
    }

    @Test func sinLaTasaDeUnaFecha_esaFechaSaleComoQueFalta() throws {
        let context = try makeTestContext()
        try seedRates(context)
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        _ = try makeTestExchangeRate(context: context, dateKey: f.string(from: Date()),
                                     rates: ["USD": 1.0, "PEN": 4.0, "EUR": 0.92])
        try context.save()

        // Un año antes de todo lo sembrado: esa fecha no tiene fila.
        let huerfana = try makeRow(context, amount: -100, on: "2025-01-15")
        let missing = AccountCurrencyMigrationService.missingRateDates(
            rows: [huerfana], to: "USD", context: context)

        #expect(missing.isEmpty == false)
    }

    /// Una fila en una TERCERA divisa —ni la vieja ni la nueva— también tiene que contar. Preguntar
    /// solo por el par daría por cubierta una fecha a la que le falta justo esa.
    @Test func laDivisaDeUnaTerceraFilaTambienCuenta() throws {
        let context = try makeTestContext()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        let hoy = f.string(from: Date())
        // Fila de hoy SIN la divisa de la transacción (JPY).
        _ = try makeTestExchangeRate(context: context, dateKey: hoy,
                                     rates: ["USD": 1.0, "PEN": 4.0])
        try context.save()

        let row = try makeRow(context, amount: -1000, on: hoy, currency: "JPY")
        let missing = AccountCurrencyMigrationService.missingRateDates(
            rows: [row], to: "USD", context: context)

        #expect(missing.isEmpty == false)
    }

    @Test func listaVacia_noHaceNada() throws {
        let context = try makeTestContext()
        let outcome = AccountCurrencyMigrationService.convertHistory(
            rows: [], to: "USD", context: context)
        #expect(outcome == .empty)
    }
}
