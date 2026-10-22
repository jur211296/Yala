//
//  DevSeedChatSealedRate.swift
//  Yala
//
//  Fixture de QA para `chat-rows-sealed-before-the-fix-have-no-repair-path`
//  (`-uitest-seed-chat-sealed-rate <ISO>`): una fila **envenenada por el chat viejo** —
//  la que el barrido `fxOneToOneRepairSweep.v2` tiene que curar EN EL SITIO.
//
//  ## Qué población reproduce, y por qué NO es la del otro fixture
//
//  `ExchangeRateRepairLogic.rateFromStoredAmounts` documenta que bajo el mismo criterio de
//  `needsRepair` conviven **dos poblaciones**, y que tratarlas igual destruye datos:
//
//  - **La tasa miente, el monto NO** — el corpus del chat. `saveDraft` convertía de verdad y
//    plantaba `exchangeRate: 1.0` al lado. Es la que siembra este fixture.
//  - **Mienten los dos** — el corpus de `fx-partial-rate-rows-silent-1to1`: la conversión falló y
//    se guardó el monto crudo, así que el cociente vale 1.
//
//  `DevSeedForeignCurrencyAccount` siembra filas **sanas-pero-aproximadas**, que es el caso
//  contrario a éste: allí la tasa es buena y el flag avisa; aquí la tasa es falsa y nada avisa.
//
//  ## Lo que hace observable el arreglo, y por qué hacen falta DOS arranques
//
//  El barrido corre en `loadExchangeRates` —paso 2 del bootstrap— y este seed en
//  `applyUITestSeed`, que es el paso 19. En el arranque que siembra, el barrido ya pasó sobre un
//  store vacío y **no quema el flag** (su guard `candidates.isEmpty && fetchCount == 0`), así que:
//
//  1. **Arranque 1** (`-uitest-reset` + este arg): la fila queda envenenada y visible. El detalle
//     de la transacción dice «Tipo de cambio: 1,0000» (`TransactionDetailSheet.swift:463`).
//  2. **Arranque 2** (mismos args, SIN `-uitest-reset`): el barrido la encuentra, deduce la tasa
//     de los dos montos guardados y la corrige **sin tocar el importe convertido**.
//
//  Ese par es justamente el veredicto que pide el ticket, y sale del orden que ya existe: no hay
//  que tocar el bootstrap para conseguirlo.
//
//  ## El monto convertido se DERIVA, no se escribe
//
//  Es la condición que separa esta población de la otra: si el monto fuera crudo, el cociente
//  daría 1, `rateFromStoredAmounts` devolvería `nil` y la fila se reabriría en vez de curarse —
//  o sea, el fixture probaría el camino contrario al que el ticket quiere ver. Por eso el importe
//  en divisa preferida sale del converter REAL y solo `exchangeRate` se planta a mano.
//
//  ## Idempotente a propósito
//
//  El arranque 2 vuelve a pasar por aquí (el seam no toca `devSeedDataExecuted`). Sin el guard de
//  presencia sembraría una segunda fila envenenada al lado de la ya curada, y la lectura del QA
//  dejaría de ser un par limpio antes/después.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedChatSealedRate {

    // MARK: - Contrato observable (lo que un XCUITest puede afirmar)

    /// Nombre de la cuenta sembrada. **Deliberadamente SIN localizar**, por el mismo motivo que
    /// `DevSeedForeignCurrencyAccount.accountName`: es un asidero de automatización, no copy.
    static let accountName = "QA FX Chat"

    /// Nota de la transacción envenenada, para localizarla en Registros.
    static let note = "QA-CHAT-SEALED"

    /// Objetivo del gasto **en la divisa preferida**. Mismo criterio que el fixture hermano: lo que
    /// se fija es el peso en preferida y el importe nativo se deriva, para que el fixture valga
    /// igual con cualquier ISO.
    static let expenseTargetInPreferred: Double = 600

    // MARK: - Siembra

    /// Crea la cuenta y la fila envenenada. Devuelve `nil` sin tocar el store si el ISO no existe,
    /// si el ISO ES la divisa preferida, o si el fixture ya estaba sembrado.
    ///
    /// - Parameters:
    ///   - rawCode: el ISO que llegó por `-uitest-seed-chat-sealed-rate`. Se normaliza a mayúsculas.
    ///   - subcategoryLookup: categorías ya sembradas, indexadas por nombre.
    @MainActor
    @discardableResult
    static func create(
        currencyCode rawCode: String,
        subcategoryLookup: [String: Subcategory],
        in context: ModelContext
    ) -> TransactionItem? {
        let code = rawCode.uppercased()
        guard let currency = CurrencyCode(rawValue: code) else {
            print("DevSeedChatSealedRate: '\(rawCode)' no es un ISO conocido — no se siembra nada.")
            return nil
        }

        let preferred = CurrencyDefaults.currentPreferred
        // **Aquí sí aborta**, al revés que en el fixture hermano: con la divisa preferida la fila
        // no sería candidata de `needsRepair` (que exige divisa distinta), así que el fixture no
        // reproduciría nada y el QA leería un falso negativo del barrido.
        guard currency.rawValue != preferred else {
            print("""
            DevSeedChatSealedRate: '\(code)' ES la divisa preferida — `needsRepair` exige divisa \
            distinta, así que esta fila no sería candidata del barrido. No se siembra nada.
            """)
            return nil
        }

        if let existing = existingFixtureRow(in: context) {
            print("DevSeedChatSealedRate: el fixture ya estaba sembrado (tasa actual \(existing.exchangeRate)) — no se duplica.")
            return existing
        }

        rewindRepairSweepOneShot()

        // Fechada AYER, no hoy. La ventana que describe el ticket es de filas ya guardadas por una
        // build anterior, y una fila de hoy compite con el fixture de `-uitest-seed-foreign-account`
        // en los mismos buckets cuando ambos args se usan a la vez.
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date.now) ?? Date.now
        let date = calendar.date(byAdding: .day, value: -1, to: noon) ?? noon

        let nativeAmount = nativeAmount(
            forPreferred: expenseTargetInPreferred, currency: currency.rawValue,
            preferred: preferred, on: date, context: context
        )
        guard nativeAmount > 0 else {
            print("DevSeedChatSealedRate: importe nativo no derivable para \(code) — no se siembra nada.")
            return nil
        }

        let account = Account(
            name: accountName,
            currencyCode: currency.rawValue,
            colorHex: "#A78BFA",
            iconName: "bubble.left.and.text.bubble.right",
            type: AccountType.cash.rawValue
        )
        context.insert(account)

        let sub = subcategoryLookup[L10n.Subcategory.travel]
        let tx = TransactionItem(
            date: date,
            amount: -nativeAmount,
            currencyCode: currency.rawValue,
            note: note,
            category: sub?.category,
            subcategory: sub,
            account: account
        )
        tx.createdAt = date
        context.insert(tx)

        // **El monto convertido lo escribe el camino de producción**, igual que en el fixture
        // hermano: de ahí sale un `amountInPreferredCurrency` correcto y su tasa verdadera.
        tx.recalculatePreferredCurrency(context: context)

        // …y AHORA se plantan las dos columnas que el chat viejo dejaba mal. Este es el veneno, y
        // va DESPUÉS del recálculo a propósito: si fuera antes, `recalculatePreferredCurrency` lo
        // pisaría y el fixture nacería sano.
        //
        // `isExchangeRateProvisional = false` no es decoración: es lo que deja la fila fuera del
        // `#Predicate` del reparador de arranque (`== true`) y la convierte en el daño que el
        // ticket describe — una fila que nadie vuelve a mirar.
        let trueRate = tx.exchangeRate
        tx.exchangeRate = 1.0
        tx.isExchangeRateProvisional = false

        do { try context.save() } catch {
            print("DevSeedChatSealedRate: Error al guardar: \(error)")
        }
        print("""
        DevSeedChatSealedRate: sembrada 1 fila envenenada (\(code) \(nativeAmount) → \
        \(tx.amountInPreferredCurrency) \(preferred)); tasa real \(trueRate), sellada como 1.0. \
        Relanza SIN -uitest-reset para que el barrido la cure.
        """)
        return tx
    }

    // MARK: - Helpers

    /// Rebobina el one-shot del barrido para que el fixture sirva **más de una vez por simulador**.
    ///
    /// **Medido el 2026-09-09, y es lo que hacía inservible al fixture en el segundo uso:**
    /// `-uitest-reset` no limpia `UserDefaults` entero — `DataWipeService.removeUserPreferenceKeys`
    /// borra una lista explícita de claves, y `fxOneToOneRepairSweep.v2` no está en ella. Así que
    /// el primer QA que corriera esta receta sellaba el one-shot **para siempre en ese simulador**:
    /// a partir de ahí el barrido salía por su primer `guard` sin mirar nada, la fila se quedaba
    /// diciendo «1,0000» y el veredicto se leía como un FAIL del producto que no lo era.
    ///
    /// Rebobinarlo **aquí** y no en el wipe es lo mínimo: quien siembra una fila para que un
    /// barrido la cure es quien tiene que dejar ese barrido en condiciones de correr, y así no se
    /// toca el comportamiento del «Empezar de cero» de producto, que es otra decisión.
    ///
    /// La clave se duplica a propósito en vez de exponer la de `TransactionUpdateService`: hacerla
    /// `internal` solo para este fixture ampliaría su superficie pública. El precio es esta línea,
    /// y lo cubre `DevSeedChatSealedRateTests.rewindKeyMatchesTheSweep`.
    @MainActor
    private static func rewindRepairSweepOneShot() {
        UserDefaults.standard.removeObject(forKey: repairSweepKey)
    }

    /// Espejo de `TransactionUpdateService.repairSweepKey` (privada). Su paridad está fijada por test.
    static let repairSweepKey = "fxOneToOneRepairSweep.v2"

    /// La fila del fixture si ya está en el store. Se busca por la nota —no por la tasa— porque
    /// tras el arranque 2 la tasa ya no vale 1,0 y el guard tiene que seguir reconociéndola.
    @MainActor
    private static func existingFixtureRow(in context: ModelContext) -> TransactionItem? {
        let target = note
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.note == target }
        )
        do { return try context.fetch(descriptor).first } catch {
            print("DevSeedChatSealedRate: Error al buscar el fixture existente: \(error)")
            return nil
        }
    }

    /// Convierte el objetivo (en divisa preferida) a la divisa de la cuenta, con el converter.
    /// Misma forma que `DevSeedForeignCurrencyAccount.nativeAmount(...)`: una sola fuente para el
    /// importe nativo, de modo que el peso del fixture no dependa del ISO elegido.
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
