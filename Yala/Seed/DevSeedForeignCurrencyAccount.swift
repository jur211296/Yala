//
//  DevSeedForeignCurrencyAccount.swift
//  Yala
//
//  Fixture de QA para la familia FX (`-uitest-seed-foreign-account <ISO>`): una cuenta en una
//  divisa AUSENTE de la fila de tasas sembrada, con transacciones cuya conversión la decide el
//  converter REAL.
//
//  ## Por qué existe
//
//  Toda la familia FX pendiente necesita el mismo estado de partida y ninguna de las dos vías para
//  llegar a él servía. Por UI, el selector de Moneda del formulario de cuenta es un `NavigationLink`
//  y no responde a los taps sintéticos de la automatización (medido el 2026-09-08 con cuatro
//  técnicas distintas; el control cruzado descarta que sea un bug de la app — el otro
//  `NavigationLink` del mismo formulario tampoco abre). Por seed, `DevSeedAccounts` crea PEN y USD
//  y `DevSeedExchangeRates` siembra exactamente esas tres divisas (`PEN`/`EUR`/`USD`), así que el
//  corpus era multi-divisa pero **nunca** producía el único estado que este módulo necesita:
//  una divisa fuera de la fila.
//
//  ## Lo que produce, y por qué esa es la forma correcta
//
//  Una divisa ausente de la fila del día es el escenario nº1 de `.claude/rules/currency-fx.md`: la
//  fila EXISTE (el seed la escribe para hoy) pero no trae la divisa pedida, así que `resolveRates`
//  la completa bajando escalones hasta la tabla estática y devuelve `.staticFallback`. De ahí sale,
//  por el camino de producción y no por una constante escrita aquí:
//
//  - `exchangeRate` ≠ 1,0 — el valor de la tabla estática, no el crudo;
//  - `isExchangeRateProvisional == true` — porque `.staticFallback.isExact` es `false`;
//  - y, aguas arriba, el «≈» en los totales que agregan esas filas.
//
//  **Las transacciones se crean y luego se recalculan con `recalculatePreferredCurrency`, jamás con
//  la tasa escrita a mano**, y eso es lo que separa este fixture de los otros seeds. El resto de
//  `DevSeedTransactions` planta `exchangeRate: basePenRate` directamente, así que su
//  `isExchangeRateProvisional` se queda en el default `false` y ninguna aserción sobre él podría
//  ponerse roja. Aquí la calidad la decide `CurrencyConverter`: si mañana alguien rompe el
//  escalonado, el fixture nace sellado como exacto y el test lo canta. Es la exigencia que cierra
//  esa misma rule — «muta y exige rojo, y el fixture tiene que poder construir la fila incompleta».
//
//  ## Dos lados, no uno
//
//  Siembra gasto **e** ingreso a propósito. La marca de aproximado va separada por lado
//  (ingreso / gasto) —lo dice el contrato de la rule, y el hero del Panel en modo Solo Gastos pinta
//  solo uno de los dos—, así que un fixture de gastos dejaría el lado de ingresos sin ninguna
//  superficie que verificar.
//
//  ## Los importes se derivan, no se escriben
//
//  El seam acepta cualquier ISO y el peso de la marca es una PROPORCIÓN (`ApproximateMarkThreshold`,
//  5 %). Un importe nativo fijo pesaría cosas distintas según la divisa: 12.000 unidades son ~285
//  soles en yenes y ~45 en pesos chilenos, o sea marca en una y no en la otra, con el mismo comando.
//  Por eso lo que se fija es el objetivo **en la divisa preferida** y el importe nativo se deriva
//  convirtiendo con el mismo converter — una sola fuente, y el peso es el mismo con cualquier ISO.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedForeignCurrencyAccount {

    // MARK: - Contrato observable (lo que un XCUITest puede afirmar)

    /// Nombre de la cuenta sembrada. **Deliberadamente SIN localizar.**
    ///
    /// Es un asidero de automatización, no copy de producto: un nombre traducido cambiaría con el
    /// idioma del simulador y obligaría a cada XCUITest a resolver la traducción para encontrar la
    /// fila. El resto del seed sí usa `L10n.DevSeed.*` porque esos nombres se enseñan en capturas.
    static let accountName = "QA FX"

    /// Prefijo de la nota de cada transacción sembrada, para localizarlas en Registros.
    static let notePrefix = "QA-FX"

    /// Objetivo de cada transacción **en la divisa preferida**, no en la extranjera.
    ///
    /// Dimensionado contra el corpus del perfil `realista`, cuyo mes tiene un ingreso de 8.500 y un
    /// gasto del orden de 4.000-6.000 (alquiler 2.200 + recurrentes). Con estos números la parte
    /// aproximada queda MUY por encima del 5 % de `ApproximateMarkThreshold` en los dos lados, que
    /// es lo que hace observable la marca sin depender de dónde caiga el random walk del seed.
    static let incomeTargetInPreferred: Double = 1_500
    static let expenseTargetsInPreferred: [Double] = [400, 350]

    // MARK: - Siembra

    /// Crea la cuenta y sus transacciones. Devuelve `nil` sin tocar el store si el ISO no existe.
    ///
    /// - Parameters:
    ///   - rawCode: el ISO que llegó por `-uitest-seed-foreign-account`. Se normaliza a mayúsculas.
    ///   - subcategoryLookup: categorías ya sembradas, indexadas por nombre. Si viene vacío las
    ///     transacciones nacen sin subcategoría, que sigue sirviendo para el AC (la clasificación
    ///     income/expense cae entonces al signo del importe).
    @MainActor
    @discardableResult
    static func create(
        currencyCode rawCode: String,
        subcategoryLookup: [String: Subcategory],
        in context: ModelContext
    ) -> Account? {
        let code = rawCode.uppercased()
        guard let currency = CurrencyCode(rawValue: code) else {
            print("DevSeedForeignCurrencyAccount: '\(rawCode)' no es un ISO conocido — no se siembra nada.")
            return nil
        }

        let preferred = CurrencyDefaults.currentPreferred
        // No es un error y por eso no aborta: pedir la divisa preferida es un control negativo
        // legítimo (misma divisa ⇒ `.exact` por construcción, sin marca). Pero decirlo evita que
        // alguien lea la ausencia de «≈» como un fallo del fixture.
        if currency.rawValue == preferred {
            print("""
            DevSeedForeignCurrencyAccount: '\(code)' ES la divisa preferida — la conversión será \
            exacta por construcción y NO habrá tasa aproximada ni «≈». Para el escenario FX pide \
            una divisa fuera de la fila sembrada (PEN/EUR/USD), p. ej. JPY o CLP.
            """)
        }

        let account = Account(
            name: accountName,
            currencyCode: currency.rawValue,
            colorHex: "#F59E0B",
            iconName: "airplane",
            type: AccountType.cash.rawValue
        )
        context.insert(account)

        // Todas el MISMO día (hoy), a horas distintas. Anclarlas a hoy es lo que las mete a la vez
        // en el día, la semana y el mes en curso —los tres buckets que pintan el «≈»— sin depender
        // de qué día del mes se corra el test: un offset de días se saldría del mes en curso al
        // correrlo un día 1 o 2. Las 12:00 evitan además la medianoche compartida que el CLAUDE.md
        // documenta (`DateInterval` cerrado en ambos extremos ⇒ doble conteo en buckets adyacentes).
        let calendar = Calendar.current
        let today = calendar.date(
            bySettingHour: 12, minute: 0, second: 0, of: Date.now
        ) ?? Date.now

        var created = 0
        func insert(targetInPreferred: Double, isIncome: Bool, subcategoryKey: String) {
            let nativeAmount = nativeAmount(
                forPreferred: targetInPreferred, currency: currency.rawValue,
                preferred: preferred, on: today, context: context
            )
            guard nativeAmount > 0 else {
                print("DevSeedForeignCurrencyAccount: importe nativo no derivable para \(code) — fila omitida.")
                return
            }

            let sub = subcategoryLookup[subcategoryKey]
            let tx = TransactionItem(
                date: today,
                amount: isIncome ? nativeAmount : -nativeAmount,
                currencyCode: currency.rawValue,
                note: "\(notePrefix) \(code)",
                category: sub?.category,
                subcategory: sub,
                account: account
            )
            // Orden estable dentro del día, como hace el resto del seed.
            tx.createdAt = today.addingTimeInterval(Double(created))
            context.insert(tx)

            // **El paso que hace que esto no sea una aserción vacua.** La tasa, el monto convertido
            // y el flag `isExchangeRateProvisional` los escribe el camino de producción a partir de
            // la calidad REAL que devuelva `resolveRates` — no se plantan aquí.
            tx.recalculatePreferredCurrency(context: context)
            created += 1
        }

        insert(
            targetInPreferred: incomeTargetInPreferred,
            isIncome: true,
            subcategoryKey: L10n.Subcategory.freelance
        )
        for target in expenseTargetsInPreferred {
            insert(targetInPreferred: target, isIncome: false, subcategoryKey: L10n.Subcategory.travel)
        }

        do { try context.save() } catch {
            print("DevSeedForeignCurrencyAccount: Error al guardar: \(error)")
        }
        return account
    }

    // MARK: - Helpers

    /// Convierte el objetivo (en divisa preferida) a la divisa de la cuenta, con el converter.
    ///
    /// Redondea a 2 decimales: el importe nativo es un dato de entrada del fixture, y un número con
    /// cola de coma flotante ensuciaría la lectura del QA sin cambiar ningún veredicto — la tasa y
    /// la marca las decide la conversión POSTERIOR, sobre este importe ya redondeado.
    @MainActor
    private static func nativeAmount(
        forPreferred target: Double,
        currency: String,
        preferred: String,
        on date: Date,
        context: ModelContext
    ) -> Double {
        let converted = CurrencyConverter.shared.convertChecked(
            Decimal(target), from: preferred, to: currency, on: date, context: context
        ).amount
        let value = (converted as NSDecimalNumber).doubleValue
        guard value.isFinite, value > 0 else { return 0 }
        return (value * 100).rounded() / 100
    }
}
#endif
