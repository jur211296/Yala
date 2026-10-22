//
//  DevSeedGroupBridgeFXLegs.swift
//  Yala
//
//  Fixture de QA para `bridge-de-grupos-pierde-la-marca-de-sus-patas`
//  (`-uitest-seed-group-bridge-fx <ISO>`): un gasto de grupo bridgeado cuyas **dos patas están
//  selladas con coberturas de tasa distintas** — la real exacta, la de préstamo provisional.
//
//  ## Por qué no se llega aquí con los otros seeds
//
//  `GroupTransactionBridge` crea las dos patas con la misma divisa y la misma fecha
//  (`GroupTransactionBridge.swift:428` exige `providedAccount.currencyCode == expense.currencyCode`),
//  así que **nacen con el mismo flag**. La asimetría que este ticket describe llega DESPUÉS, y el
//  propio ticket mide tres caminos: aprobar tarde un draft cuyo `createVirtualLent` ya corrió, el
//  reparador trabajando por cola —que cura una pata y deja la otra—, y editar la pata real, que la
//  reconvierte con la escalera de hoy.
//
//  Este fixture reproduce el **estado resultante**, que es lo único que la marca puede observar.
//  Por eso los flags se fuerzan después de convertir: el importe sale del converter real, y lo que
//  se planta a mano es exactamente la asimetría que los tres caminos producen.
//
//  ## Qué tiene que ver el QA, y por qué el escenario es discriminante
//
//  La pata real es **exacta**. Si la síntesis del bridge no leyera la pata de préstamo —el bug del
//  ticket—, la magnitud dudosa del gasto sería CERO y el mes no llevaría «≈». Con el arreglo, la
//  magnitud dudosa es la de la pata de préstamo y el mes marca. O sea: el fixture distingue el
//  código arreglado del código con el bug, que es lo que un fixture tiene que hacer.
//
//  Números, en divisa preferida y con el corpus del perfil `realista` como denominador: la pata
//  real vale −1.050 (el gasto COMPLETO, sellada exacta) y la de préstamo +900 (provisional), así
//  que el importe sintetizado son −150 —mi parte— y la magnitud dudosa 900. Ese 900 queda muy por
//  encima del 5 % de `ApproximateMarkThreshold` sobre un mes de ~3.900 de gasto. A solas —sin
//  perfil— también marca, porque entonces es casi todo el gasto.
//
//  ## La anatomía que el adjustment exige (medido en `GroupBridgeStatsAdjustment.build`)
//
//  - Las dos patas comparten `splitExpenseID` (es la clave de agrupación, `:167`).
//  - Las dos tienen `account != nil`, o el grupo entero se salta por conservador (`:172`).
//  - La pata real vive en una cuenta con `isSystemAccount == false` y es **negativa**.
//  - La pata de préstamo vive en la cuenta de sistema (`isSystemAccount == true`) y es
//    **positiva**: el filtro es por SIGNO (`loanBySign`, `:177`), no por subcategoría, cuando hay
//    pata de costo. La subcategoría de rol `loanToGroups` se pone igual porque es lo que crea el
//    bridge real y porque sin ella la fila no se distinguiría de un «saldo inicial: me deben» si
//    algún día desapareciera la pata de costo.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedGroupBridgeFXLegs {

    // MARK: - Contrato observable (lo que un XCUITest puede afirmar)

    /// Nombre de la cuenta REAL sembrada. **Deliberadamente SIN localizar** (asidero, no copy).
    /// La cuenta de sistema NO se nombra aquí: la crea `GroupBridgeSystemEntities` con su propio
    /// nombre localizado, y duplicarlo aquí sería inventar un segundo criterio.
    static let accountName = "QA FX Grupo"

    /// Prefijo de la nota de las dos patas, para localizarlas en Registros.
    static let notePrefix = "QA-BRIDGE"

    /// Mi parte del gasto, **en divisa preferida**. Es lo que el usuario acaba viendo como importe
    /// del gasto (`-total + lent`), no lo que se escribe en ninguna pata.
    static let myShareInPreferred: Double = 150

    /// Lo que adelanté por los demás, **en divisa preferida**. Es la pata de préstamo, y va sellada
    /// como PROVISIONAL: es la magnitud dudosa que el bug perdía.
    static let lentInPreferred: Double = 900

    /// El gasto completo, que es lo que lleva la pata REAL **en negativo**. Derivado, no escrito a
    /// mano: la relación `lent = total - myShare` es la que mantiene coherente la síntesis.
    static var totalInPreferred: Double { myShareInPreferred + lentInPreferred }

    /// Identificador del gasto compartido sintético. Fijo y con prefijo propio para que sea
    /// reconocible en un dump y no colisione con un id real de CloudKit.
    static let splitExpenseID = "qa-fx-bridge-fixture"

    // MARK: - Siembra

    /// Crea la cuenta real, la de sistema y las dos patas. Devuelve `nil` sin tocar el store si el
    /// ISO no existe o si el fixture ya estaba sembrado.
    @MainActor
    @discardableResult
    static func create(
        currencyCode rawCode: String,
        subcategoryLookup: [String: Subcategory],
        in context: ModelContext
    ) -> TransactionItem? {
        let code = rawCode.uppercased()
        guard let currency = CurrencyCode(rawValue: code) else {
            print("DevSeedGroupBridgeFXLegs: '\(rawCode)' no es un ISO conocido — no se siembra nada.")
            return nil
        }

        let preferred = CurrencyDefaults.currentPreferred
        // No aborta con la divisa preferida —la asimetría de flags se planta a mano, así que el
        // escenario sigue siendo válido— pero se dice, porque entonces el fixture ya no prueba
        // nada sobre la CONVERSIÓN: la identidad es `.exact` por construcción.
        if currency.rawValue == preferred {
            print("""
            DevSeedGroupBridgeFXLegs: '\(code)' ES la divisa preferida. Las patas se siembran igual \
            y la marca sigue saliendo (los flags se plantan), pero la conversión no se ejercita. \
            Para el escenario completo pide una divisa fuera de la fila sembrada, p. ej. JPY.
            """)
        }

        if let existing = existingFixtureRealLeg(in: context) {
            print("DevSeedGroupBridgeFXLegs: el fixture ya estaba sembrado — no se duplica.")
            return existing
        }

        // Misma ancla que el fixture hermano: hoy a las 12:00. Mete las dos patas a la vez en el
        // día, la semana y el mes en curso sin depender de qué día del mes se corra, y evita la
        // medianoche compartida que documenta el `CLAUDE.md`.
        let calendar = Calendar.current
        let today = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date.now) ?? Date.now

        let systemAccount: Account
        let loanSubcategory: Subcategory
        do {
            systemAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
                currencyCode: currency.rawValue, context: context
            )
            loanSubcategory = try GroupBridgeSystemEntities.systemSubcategory(
                role: .loanToGroups, context: context
            )
        } catch {
            print("DevSeedGroupBridgeFXLegs: no se pudo preparar la cuenta/subcategoría de sistema: \(error)")
            return nil
        }

        let realAccount = Account(
            name: accountName,
            currencyCode: currency.rawValue,
            colorHex: "#34D399",
            iconName: "person.2",
            type: AccountType.cash.rawValue
        )
        context.insert(realAccount)

        let travelSub = subcategoryLookup[L10n.Subcategory.travel]

        // --- Pata REAL: el gasto COMPLETO en negativo, sellada como EXACTA ---
        //
        // **No es «mi parte», y confundirlo invierte la síntesis.** Producción escribe
        // `amount: -totalAmount` (`GroupTransactionBridge.swift:428`) y `lentAmount = totalAmount -
        // mySharedAmount` (`:248`), así que el neto que reconstruye el adjustment es
        // `-total + lent = -myShare`. Con la pata real puesta a `-myShare` el neto sale `+lent`:
        // un gasto de grupo que aparece como INGRESO. Medido aquí el 2026-09-09 antes de corregir.
        guard let realNative = nativeAmount(
            forPreferred: totalInPreferred, currency: currency.rawValue,
            preferred: preferred, on: today, context: context
        ) else {
            print("DevSeedGroupBridgeFXLegs: importe nativo no derivable para \(code) — no se siembra nada.")
            return nil
        }
        let realLeg = TransactionItem(
            date: today,
            amount: -realNative,
            currencyCode: currency.rawValue,
            note: "\(notePrefix) mi parte",
            category: travelSub?.category,
            subcategory: travelSub,
            account: realAccount
        )
        realLeg.splitExpenseID = splitExpenseID
        // `splitTotalAmount` y `splitType` no los mira el adjustment, pero producción los escribe
        // (`GroupTransactionBridge.swift:432-435`) y una fila de grupo sin ellos es una fila que no
        // existe en la app real. `splitGroupZoneID` se queda nil a propósito: exige una zona de
        // CloudKit y ningún consumidor de la marca lo lee.
        realLeg.splitTotalAmount = totalInPreferred
        realLeg.splitType = "equal"
        realLeg.createdAt = today
        context.insert(realLeg)
        realLeg.recalculatePreferredCurrency(context: context)

        // --- Pata de PRÉSTAMO: lo adelantado, ingreso, en la cuenta de sistema ---
        guard let lentNative = nativeAmount(
            forPreferred: lentInPreferred, currency: currency.rawValue,
            preferred: preferred, on: today, context: context
        ) else {
            print("DevSeedGroupBridgeFXLegs: importe nativo de la pata de préstamo no derivable — no se siembra nada.")
            return nil
        }
        let loanLeg = TransactionItem(
            date: today,
            amount: lentNative,
            currencyCode: currency.rawValue,
            note: "\(notePrefix) préstamo",
            category: loanSubcategory.safeCategory,
            subcategory: loanSubcategory,
            account: systemAccount
        )
        loanLeg.splitExpenseID = splitExpenseID
        loanLeg.splitTotalAmount = totalInPreferred
        loanLeg.splitType = "equal"
        loanLeg.createdAt = today.addingTimeInterval(1)
        context.insert(loanLeg)
        loanLeg.recalculatePreferredCurrency(context: context)

        // **La asimetría, plantada al final y a propósito.** Las dos patas acaban de convertirse
        // con la misma cobertura —es lo que hace producción— así que aquí se reproduce el estado al
        // que llegan los tres caminos del ticket: una pata curada y la otra todavía no.
        //
        // Va DESPUÉS de los dos `recalculatePreferredCurrency`: si fuera antes, el recálculo
        // pisaría el flag y el fixture nacería simétrico, que es justo el caso que NO prueba nada.
        realLeg.isExchangeRateProvisional = false
        loanLeg.isExchangeRateProvisional = true

        do { try context.save() } catch {
            print("DevSeedGroupBridgeFXLegs: Error al guardar: \(error)")
        }
        print("""
        DevSeedGroupBridgeFXLegs: sembradas 2 patas (\(code)) — real \
        \(realLeg.amountInPreferredCurrency) \(preferred) EXACTA, préstamo \
        \(loanLeg.amountInPreferredCurrency) \(preferred) PROVISIONAL. Importe sintetizado: \
        \(realLeg.amountInPreferredCurrency + loanLeg.amountInPreferredCurrency) \(preferred).
        """)
        return realLeg
    }

    // MARK: - Helpers

    /// La pata real del fixture si ya está en el store, buscada por `splitExpenseID` —que es la
    /// clave con la que el adjustment las agrupa— y no por la nota.
    @MainActor
    private static func existingFixtureRealLeg(in context: ModelContext) -> TransactionItem? {
        let target = splitExpenseID
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == target }
        )
        do {
            // La real es la negativa; la de sistema es la positiva.
            return try context.fetch(descriptor).first { $0.amount < 0 }
        } catch {
            print("DevSeedGroupBridgeFXLegs: Error al buscar el fixture existente: \(error)")
            return nil
        }
    }

    /// Convierte un objetivo en divisa preferida a la divisa de las patas. `nil` si no se puede
    /// derivar un importe usable — devolver 0 dejaría una pata que el adjustment sí agrupa pero
    /// que no aporta magnitud, y el QA leería un falso negativo.
    @MainActor
    private static func nativeAmount(
        forPreferred target: Double,
        currency: String,
        preferred: String,
        on date: Date,
        context: ModelContext
    ) -> Double? {
        let converted = CurrencyConverter.shared.convertChecked(
            Decimal(target), from: preferred, to: currency, on: date, context: context
        ).amount
        let value = (converted as NSDecimalNumber).doubleValue
        guard value.isFinite, value > 0 else { return nil }
        return (value * 100).rounded() / 100
    }
}
#endif
