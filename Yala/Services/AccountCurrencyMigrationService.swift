//
//  AccountCurrencyMigrationService.swift
//  Yala
//
//  Reexpresa el histórico de una cuenta cuando cambia su divisa.
//  Ticket `changing-an-account-currency-orphans-its-whole-history`.
//

import Foundation
import SwiftData

/// Convierte los movimientos de UNA cuenta a la divisa nueva de esa cuenta.
///
/// **Es el primer sitio del repo que reexpresa el `amount` de transacciones ya persistidas**, y la
/// distinción importa: `CurrencyChangeService` (cambio de divisa PREFERIDA) barre el corpus entero
/// pero escribe solo las cuatro derivadas —`amountInPreferredCurrency`, `exchangeRate`,
/// `preferredCurrencyCode`, `isExchangeRateProvisional`—, que un reparador puede volver a calcular.
/// Aquí se toca la columna cruda, que **no tiene reparador**: es el dato de origen. Por eso el
/// llamador pide confirmación explícita antes y por eso las tasas se refrescan ANTES de convertir.
///
/// Qué filas llegan aquí lo decide `AccountCurrencyChangeLogic`: las que manda otra entidad
/// —transferencias, gastos de grupo, liquidaciones— no entran nunca, porque su conversión no se
/// sostendría. Este servicio no vuelve a comprobarlo: recibe la lista ya filtrada.
@MainActor
enum AccountCurrencyMigrationService {

    /// Qué se hizo, para poder afirmarlo en un test y contarlo en el log.
    struct Outcome: Equatable, Sendable {
        /// Filas cuyo importe se reexpresó.
        let convertedCount: Int
        /// De esas, cuántas salieron con una tasa que no era la exacta de su día (arrastrada de un
        /// día anterior o de la tabla estática). No es un fallo —el número sigue siendo del orden
        /// correcto— pero es lo que distingue «convertido con el dato bueno» de «convertido con lo
        /// que había», y sin contarlo no hay forma de saber cuál de los dos pasó.
        let approximateCount: Int

        static let empty = Outcome(convertedCount: 0, approximateCount: 0)
    }

    // MARK: - Tasas primero

    /// Trae las tasas que la conversión va a necesitar, **antes** de tocar ningún importe.
    ///
    /// **El orden no es cosmético**: es la lección de `fx-partial-rate-rows-silent-1to1`, que
    /// `CurrencySettingsView` ya paga por su lado. Convertir primero y refrescar después deja los
    /// importes escritos con lo que hubiera —en el caso normal, `1.0`, porque el preload histórico
    /// solo cubre las divisas que el usuario ya usaba— y **no se recupera solo**: repoblar
    /// `ExchangeRate` después no vuelve a convertir nada.
    ///
    /// Se nombran las dos divisas (`needing:`) en vez de pedir la fila a secas: una fila de tasas que
    /// existe pero no trae la divisa pedida es indistinguible de una completa si solo se pregunta por
    /// la fila, y ese era justamente el cuarto estado que `RateQuality` existe para separar.
    ///
    /// **Por fechas SUELTAS y no por intervalo, y la diferencia es de dos órdenes de magnitud.**
    /// `ensureRates(for:needing:)` recorre el rango día a día, así que un histórico de dos años con
    /// cuarenta movimientos pediría ~730 días para necesitar cuarenta. `ExchangeRateService` ya avisa
    /// de esto en el docblock de `uncoveredDates` —«su cola son transacciones concretas, no un
    /// intervalo»— y expone la versión buena; usar la del rango habría sido repetir el error que el
    /// reparador de arranque ya pagó.
    /// - Returns: `true` si al terminar **todas** las fechas tienen cubiertas las divisas que hacen
    ///   falta. `false` significa «no conviertas»: es la única señal que separa una conversión con el
    ///   dato bueno de una con lo que hubiera, y en la columna cruda esa diferencia no se puede
    ///   deshacer después.
    ///
    /// Las divisas se toman de las FILAS, no solo del par vieja→nueva. Una cuenta que ya venía
    /// desemparejada puede tener filas en una tercera divisa —caso que `convertHistory` soporta a
    /// propósito— y pedir cobertura solo del par daría por cubierta una fecha que a esa tercera le
    /// falta.
    ///
    /// **`extra` cubre lo que no es historial** (ticket
    /// `account-currency-change-leaves-scheduled-and-favorites-stale`): las fechas de los borradores
    /// pendientes y las divisas de los programados y favoritos, que se convierten con la tasa de HOY.
    /// Hoy entra siempre que haya algo que pedir, así que una cuenta sin movimientos pero con un
    /// alquiler programado también exige la fila de hoy antes de tocar nada — la misma regla
    /// todo-o-nada que el historial (decisión D2).
    static func prepareRates(
        rows: [TransactionItem],
        extra: RateNeeds = .none,
        to newCurrencyCode: String,
        context: ModelContext
    ) async -> Bool {
        guard !rows.isEmpty || !extra.isEmpty else { return true }

        let missing = missingRateDates(rows: rows, extra: extra, to: newCurrencyCode, context: context)
        if missing.isEmpty { return true }

        _ = await ExchangeRateService.shared.fetchRates(for: missing, context: context)
        // `fetchRates` persiste filas nuevas pero **no** postea la notificación que invalida la caché
        // en memoria de `convertWithLatestRate` (solo lo hacen `forceUpdateToday` y
        // `forceRefreshRates`). Sin esto, lo que la app pinta a «tasa de hoy» —presupuestos, saldo
        // vivo— seguiría leyendo la tasa anterior justo después de que este flujo la trajera.
        NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)

        // **Se vuelve a preguntar en vez de fiarse del `Bool` de `fetchRates`.** Ese booleano dice si
        // las peticiones salieron bien, no si el proveedor trajo las divisas pedidas: los dos fallos
        // llevan al mismo sitio —convertir con la tabla estática— pero solo uno se ve en el `catch`.
        // La pregunta que de verdad decide es la misma que decide la calidad de la conversión.
        return missingRateDates(rows: rows, extra: extra, to: newCurrencyCode, context: context).isEmpty
    }

    /// Lo que la conversión necesita además de las filas del historial.
    nonisolated struct RateNeeds: Equatable, Sendable {
        /// Fechas propias que no son de una `TransactionItem` (los borradores pendientes).
        var dates: Set<Date> = []
        /// Divisas de origen de esas fechas y de lo que se convierte con la tasa de hoy.
        var currencies: Set<String> = []

        static let none = RateNeeds()
        var isEmpty: Bool { dates.isEmpty && currencies.isEmpty }
    }

    /// Las fechas a las que les falta alguna de las divisas en juego. **No toca la red.**
    ///
    /// Está separada de `prepareRates` para que la DECISIÓN («¿se puede convertir con el dato bueno?»)
    /// se pueda fijar con un test que no dependa de que el simulador tenga salida — aquí
    /// `ExchangeRateService` cae por AppAttest en todos los arranques, así que un test del camino de
    /// fallo a través del fetch mediría el timeout de la red y no el guard.
    ///
    /// Las divisas se toman de las FILAS, no solo del par vieja→nueva. Una cuenta que ya venía
    /// desemparejada puede tener filas en una tercera divisa —caso que `convertHistory` soporta a
    /// propósito— y pedir cobertura solo del par daría por cubierta una fecha que a esa tercera le
    /// falta.
    static func missingRateDates(
        rows: [TransactionItem],
        extra: RateNeeds = .none,
        to newCurrencyCode: String,
        context: ModelContext
    ) -> [Date] {
        guard !rows.isEmpty || !extra.isEmpty else { return [] }

        var needed: Set<String> = [normalizeCurrencyCode(newCurrencyCode)]
        for row in rows { needed.insert(normalizeCurrencyCode(row.currencyCode)) }
        for code in extra.currencies { needed.insert(normalizeCurrencyCode(code)) }

        // Hoy entra siempre, aunque el histórico acabe antes: es la tasa con la que el resto de la
        // app pinta el saldo vivo, y dejarla fuera haría que la cuenta recién convertida se leyera
        // con una tasa más vieja que la que acaba de sellar cada fila. Y es la tasa con la que se
        // convierten los programados y los favoritos.
        let wanted = Set(rows.map(\.date)).union(extra.dates).union([Date.now])
        return ExchangeRateService.shared.uncoveredDates(
            among: wanted, needing: needed, context: context)
    }

    // MARK: - Conversión

    /// Reexpresa cada fila a `newCurrencyCode` usando la tasa **de su propia fecha**.
    ///
    /// No hace red: consume lo que `prepareRates` haya dejado en el store. Eso permite fijar el
    /// comportamiento con tests que no dependen de que el simulador tenga salida —aquí
    /// `ExchangeRateService` falla por AppAttest en todos los arranques— y separa el fallo de red del
    /// fallo de cálculo.
    ///
    /// **El origen de cada fila es `tx.currencyCode`, no la divisa de la cuenta.** Son cosas
    /// distintas justo en el caso que importa: si la cuenta ya venía desemparejada de antes, cada
    /// fila se convierte desde la divisa en la que de verdad está estampada, no desde la que la
    /// cuenta dice.
    ///
    /// No llama a `context.save()`: quien orquesta el guardado del formulario decide cuándo, y así la
    /// conversión y el resto de propiedades de la cuenta entran en la misma transacción.
    @discardableResult
    static func convertHistory(
        rows: [TransactionItem],
        to newCurrencyCode: String,
        context: ModelContext
    ) -> Outcome {
        let target = normalizeCurrencyCode(newCurrencyCode)
        var converted = 0
        var approximate = 0

        for row in rows {
            let source = normalizeCurrencyCode(row.currencyCode)
            // Misma divisa: no hay nada que reexpresar. Se salta ANTES de contar, porque una fila que
            // ya estaba en la divisa destino no es una fila convertida — decir que sí inflaría el
            // número que el usuario acaba de confirmar en pantalla.
            guard source != target else { continue }

            // `CurrencyConverter` concreto y no el protocolo `CurrencyConverting`: la variante que
            // recibe `ModelContext` solo existe en la clase. La del protocolo cae al `modelContext`
            // interno del converter, que en un test recién montado está vacío — y entonces convierte
            // por la tabla estática sin que nada lo diga.
            let outcome = CurrencyConverter.shared.convertChecked(
                Decimal(row.amount),
                from: source,
                to: target,
                on: row.date,
                context: context
            )

            let rate = ratio(of: outcome.amount, over: row.amount)

            row.amount = (outcome.amount as NSDecimalNumber).doubleValue
            row.currencyCode = target
            reexpressLocalSplit(of: row, by: rate)
            // Las derivadas se recalculan desde el importe YA reexpresado: leerlas antes las dejaría
            // describiendo el importe viejo, que es la forma exacta del bug que este ticket cierra,
            // solo que una columna más abajo.
            row.recalculatePreferredCurrency(context: context)

            converted += 1
            if !outcome.quality.isExact { approximate += 1 }
        }

        #if DEBUG
        print("AccountCurrencyMigrationService: reexpresadas \(converted) filas a \(target) (\(approximate) con tasa aproximada)")
        #endif

        return Outcome(convertedCount: converted, approximateCount: approximate)
    }

    // MARK: - Lo que no es historial

    /// Un importe convertido con la tasa de HOY, para enseñarlo en el aviso y para escribirlo.
    ///
    /// Una sola función para los dos usos a propósito: si el aviso calculara su número por un camino
    /// y la conversión por otro, la persona confirmaría una cifra y se guardaría otra.
    struct TodayConversion: Equatable, Sendable {
        let from: Decimal
        let to: Decimal
        /// La tasa de hoy era la exacta. `false` = arrastrada de otro día o de la tabla estática.
        let isExact: Bool
    }

    /// Convierte `amount` de `source` a `target` con la tasa de hoy y lo redondea a los decimales de
    /// `target` (decisión D5). Misma divisa: el importe tal cual, exacto.
    static func convertToday(
        _ amount: Double,
        from source: String,
        to target: String,
        context: ModelContext,
        now: Date = .now
    ) -> TodayConversion {
        let from = normalizeCurrencyCode(source)
        let to = normalizeCurrencyCode(target)
        let original = Decimal(amount)
        guard from != to else {
            return TodayConversion(from: original, to: original, isExact: true)
        }
        let outcome = CurrencyConverter.shared.convertChecked(
            original, from: from, to: to, on: now, context: context)
        return TodayConversion(
            from: original,
            to: AccountCurrencyPlanLogic.rounded(outcome.amount, to: to),
            isExact: outcome.quality.isExact
        )
    }

    /// Pasa los pagos programados y los favoritos de la cuenta a `newCurrencyCode` con la tasa de hoy.
    ///
    /// **El origen es la divisa de CADA uno, no la vieja de la cuenta** —el mismo criterio que
    /// `convertHistory`—: un programado que ya venía desemparejado se convierte desde la divisa en la
    /// que de verdad está. Un favorito sin divisa (los antiguos) se lee en `fallbackSourceCode`, la de
    /// la cuenta al abrir el formulario, que es la que usaba al precargarse.
    ///
    /// Qué programados entran lo decide el llamador con `AccountCurrencyPlanLogic`; aquí no se vuelve
    /// a mirar. No llama a `context.save()`: va en el mismo guardado que la cuenta.
    @discardableResult
    static func convertPlans(
        scheduled: [ScheduledPayment],
        favorites: [FavoritePayment],
        fallbackSourceCode: String,
        to newCurrencyCode: String,
        context: ModelContext,
        now: Date = .now
    ) -> Outcome {
        let target = normalizeCurrencyCode(newCurrencyCode)
        var converted = 0
        var approximate = 0

        for payment in scheduled {
            let source = normalizeCurrencyCode(payment.currencyCode)
            guard source != target else { continue }
            let result = convertToday(payment.amount, from: source, to: target, context: context, now: now)
            payment.amount = (result.to as NSDecimalNumber).doubleValue
            payment.currencyCode = target
            converted += 1
            if !result.isExact { approximate += 1 }
        }

        for favorite in favorites {
            let source = normalizeCurrencyCode(favorite.currencyCode ?? fallbackSourceCode)
            guard source != target else {
                // Un favorito sin divisa que ya estaba en la nueva: se le pone la etiqueta y nada más.
                if favorite.currencyCode == nil { favorite.currencyCode = target }
                continue
            }
            if let amount = favorite.amount {
                let result = convertToday(amount, from: source, to: target, context: context, now: now)
                favorite.amount = (result.to as NSDecimalNumber).doubleValue
                if !result.isExact { approximate += 1 }
            }
            favorite.currencyCode = target
            converted += 1
        }

        #if DEBUG
        print("AccountCurrencyMigrationService: \(converted) programados/favoritos a \(target) (\(approximate) con tasa aproximada)")
        #endif
        return Outcome(convertedCount: converted, approximateCount: approximate)
    }

    /// Reexpresa los borradores pendientes de la cuenta con la tasa de **su** fecha (decisión D1 de
    /// Jürgen, 2026-10-08): son movimientos que aún no se aprobaron y se tratan como el historial.
    ///
    /// El borrador no guarda divisa: la toma de la cuenta al aprobarse. Su importe está en
    /// `sourceCode`, la divisa de la cuenta al abrir el formulario. Sin redondeo, como el historial.
    @discardableResult
    static func convertPendingDrafts(
        _ drafts: [InboxDraft],
        from sourceCode: String,
        to newCurrencyCode: String,
        context: ModelContext
    ) -> Outcome {
        let source = normalizeCurrencyCode(sourceCode)
        let target = normalizeCurrencyCode(newCurrencyCode)
        guard source != target else { return .empty }
        var converted = 0
        var approximate = 0

        for draft in drafts {
            guard let amount = draft.amount else { continue }
            let outcome = CurrencyConverter.shared.convertChecked(
                Decimal(amount),
                from: source,
                to: target,
                on: draft.date ?? draft.createdAt,
                context: context
            )
            draft.amount = (outcome.amount as NSDecimalNumber).doubleValue
            // Un borrador rechazado y devuelto a pendientes conserva la divisa con la que se archivó
            // (`returnToPending` no la limpia), y «Convertir a gasto de grupo» la lee: sin esto, el
            // importe ya en dólares se precargaría como soles.
            if draft.cachedCurrencyCode != nil { draft.cachedCurrencyCode = target }
            converted += 1
            if !outcome.quality.isExact { approximate += 1 }
        }

        #if DEBUG
        print("AccountCurrencyMigrationService: \(converted) borradores a \(target) (\(approximate) con tasa aproximada)")
        #endif
        return Outcome(convertedCount: converted, approximateCount: approximate)
    }

    // MARK: - El split LOCAL viaja con el importe

    /// La proporción que aplicó la conversión, para reusarla en los campos que no pasan por el
    /// converter. Con importe cero no hay proporción derivable y se devuelve `nil`: multiplicar por
    /// una tasa inventada sería peor que dejar el campo como está.
    private static func ratio(of converted: Decimal, over original: Double) -> Double? {
        guard abs(original) > 0.0001 else { return nil }
        return (converted as NSDecimalNumber).doubleValue / original
    }

    /// Reexpresa los campos del divisor **local** (la calculadora de «dividir entre N»), que no tiene
    /// nada que ver con los grupos.
    ///
    /// **Por qué hay que tocarlos y por qué no bloquean la fila.** Una transacción con split local no
    /// lleva `splitExpenseID` ni `splitSettlementID`, así que no la manda ninguna otra entidad y se
    /// puede convertir sin problema — pero `splitTotalAmount` (y `splitMyValue` cuando el tipo es
    /// `exact`) son DINERO en la divisa vieja. Dejarlos sin tocar hace que al reabrir la transacción
    /// la calculadora enseñe «Total 400 / entre 4 = 100» sobre un importe que ya vale 25, y que la
    /// exportación escriba ese 400 con el símbolo nuevo.
    ///
    /// `splitDivisor` y el `splitMyValue` de los demás tipos NO se tocan: son personas, partes o un
    /// porcentaje. Multiplicarlos por un tipo de cambio no significa nada.
    private static func reexpressLocalSplit(of row: TransactionItem, by rate: Double?) {
        guard let rate else { return }
        if let total = row.splitTotalAmount { row.splitTotalAmount = total * rate }
        if row.splitType == "exact", let mine = row.splitMyValue {
            row.splitMyValue = mine * rate
        }
    }
}
