//
//  TransactionUpdateService.swift
//  Yala
//
//  Service to update transactions with provisional exchange rates.
//  Called on app launch to update transactions that were imported
//  without exact exchange rates for their dates.
//

import Foundation
import SwiftData

// MARK: - Transaction Update Service

/// Service that updates transactions with provisional exchange rates.
/// Called on app launch to fill in missing exchange rate data.
@MainActor
enum TransactionUpdateService {

    /// Updates all transactions that have provisional exchange rates.
    /// This function:
    /// 1. Finds all transactions where isExchangeRateProvisional == true
    /// 2. For each unique date, fetches exchange rates from API if missing
    /// 3. Recalculates and updates the transactions
    /// 4. Sets isExchangeRateProvisional = false
    ///
    /// - Parameter context: SwiftData ModelContext
    /// Clave del flag idempotente del barrido de reparación. Se corre UNA vez por dispositivo.
    ///
    /// **`.v2` desde el 2026-09-08, y el número es el mecanismo: subirlo REBOBINA el one-shot.** El
    /// dispositivo que ya tenga marcada la `.v1` vuelve a barrer una vez, porque entre aquel barrido y
    /// hoy se siguió produciendo el daño que la `.v1` fue a curar (ticket
    /// `chat-rows-sealed-before-the-fix-have-no-repair-path`).
    ///
    /// La `.v1` **no se borra**: cuesta un bool en `UserDefaults` y es lo único que dice, en un
    /// dispositivo concreto, si aquel primer barrido llegó a correr.
    private static let repairSweepKey = "fxOneToOneRepairSweep.v2"

    /// Devuelve a la cola de reparación las transacciones que quedaron con un 1:1 envenenado **antes**
    /// de que existiera el fix (`fx-partial-rate-rows-silent-1to1`, paso 2).
    ///
    /// No reconvierte nada: solo levanta `isExchangeRateProvisional`, y de eso ya se ocupa
    /// `updateProvisionalTransactions` unas líneas después, en el mismo arranque. Así hay UNA sola
    /// implementación de la conversión, no dos que se desincronizan — y el barrido se limita a
    /// deshacer el sellado, que es el daño que hay que revertir.
    ///
    /// ## Por qué se rebobina el flag, y qué corpus alcanza la `.v2`
    ///
    /// La `.v1` nació el 2026-09-03 (`6ddc4367`) dando por hecho que **el estado que busca solo lo
    /// produce el código viejo**. Era falso: `ChatAssistantViewModel.saveDraft` siguió plantando
    /// `exchangeRate: 1.0` literal hasta el 2026-09-08 (`chat-assistant-plants-exchange-rate-one`), y
    /// con la conversión EXACTA —el caso normal— el flag quedaba en `false`, así que esas filas
    /// tampoco entraban en el `#Predicate` del reparador (`== true`). Ni el barrido ni el reparador
    /// las miraban: se quedaban diciendo «1,0000» para siempre.
    ///
    /// **Qué alcanza la `.v2`, y por qué no es «solo el delta».** El criterio no cambia
    /// (`ExchangeRateRepairLogic.needsRepair`), así que vuelve a mirar la tabla entera con la misma
    /// vara. Lo escrito **después** de la `.v1` es el corpus que motiva el rebobinado —la ventana del
    /// chat—, pero **no es todo lo que va a encontrar**, y creer lo contrario sería contradecir el
    /// párrafo de abajo: en un dispositivo donde la `.v1` se quemó antes de tiempo, también hay corpus
    /// ANTERIOR sin curar. Se alcanza igual, que es justamente lo que se quiere. Y un cambio de divisa
    /// preferida entre los dos barridos mueve la población candidata sin tocar una línea del criterio,
    /// porque `needsRepair` compara contra la preferida **de hoy**.
    ///
    /// **Lo que la `.v2` NO cura, con ticket propio:** la banda `0 < |monto| <= 0.0001`. Ni se le
    /// deduce tasa (el umbral de `rateFromStoredAmounts` es el mismo) ni sirve reabrirla, porque el
    /// reparador tiene ese mismo umbral y volvería a escribir `1.0` —
    /// `fx-rate-derivation-threshold-reseals-one-to-one`. El valor absoluto no es un detalle: desde el
    /// PR #102 los gastos del chat se guardan **negativos**, o sea la mitad que un rango sin `abs`
    /// dejaría fuera.
    ///
    /// ## Lo que emite al canal nube, que no es gratis
    ///
    /// Las dos columnas que este barrido escribe —`exchangeRate` e `isExchangeRateProvisional`— están
    /// en el grupo de coherencia `money`, y `DeltaEmitter` expande **cualquiera** de ellas al grupo
    /// entero con un HLC fresco: cada fila tocada emite las cinco. Aquí no hay escritura idéntica que
    /// el guard de igualdad pueda ahorrar —todas cambian algo—, así que el coste es una emisión por
    /// fila candidata, y punto.
    ///
    /// **Eso es lo que decide QUÉ se escribe, y no es un detalle de eficiencia.** Reabrir una fila
    /// emite el grupo `money` con la tasa envenenada TODAVÍA puesta y un HLC nuevo: bajo LWW por
    /// unidad, este barrido le ganaría a un dispositivo par que ya la hubiera reparado, y difundiría
    /// el veneno en vez de curarlo. Corrigiendo la tasa **antes** de guardar, lo que viaja es el valor
    /// bueno. La fila que no se puede corregir en el sitio sí se reabre, y ahí el riesgo es real pero
    /// acotado: son filas cuyo monto tampoco está convertido, o sea que el par tampoco tenía nada que
    /// preservar.
    ///
    /// ## One-shot, pero que no se queme antes de servir
    ///
    /// Sigue siendo one-shot a propósito: repetirlo en cada arranque sería recorrer todas las
    /// transacciones para siempre a cambio de nada. Lo que cambia es **cuándo tiene derecho a
    /// sellarse**, porque un one-shot que se marca sin haber visto el corpus deja el daño sin cura para
    /// siempre. Dos comprobaciones, y hacen cosas distintas:
    ///
    /// 1. **El gate de quiescencia** evita el `save()` sobre el store personal mientras el import está
    ///    EN VUELO —lo que `ccbc97e9` gateó en el resto del boot y este barrido, nacido después, no
    ///    tenía— y, sobre todo, evita sellar en un arranque donde `updateProvisionalTransactions` sale
    ///    por su propio gate tres líneas más abajo y no cura nada.
    ///    **Lo que este gate NO cubre, medido:** `isImportQuiescent` vale `true` ANTES de que empiece
    ///    ningún import (`lastImportDate == nil`), y así lo documenta `BootSaveGateLogic`. En el
    ///    arranque en frío de un restore, el paso 2 llega antes del primer evento de CloudKit y el
    ///    gate está ABIERTO. No es el gate de seis entradas de `awaitPersonalStoreReady`, que este
    ///    barrido no usa porque no espera nada en absoluto.
    /// 2. **El guard de presencia** es el que tapa ese hueco: sobre un store sin ninguna transacción no
    ///    se sella. Es el punto ciego que `ChatUnsignedExpenseRepairService` cerró para su propio
    ///    barrido citando a éste por su nombre.
    ///
    /// **Residual que queda, y conviene no maquillarlo:** el guard distingue *vacío* de *no vacío*, no
    /// *completo* de *parcial*. Un restore que ya ha entregado tres filas de cinco mil pasa el guard y
    /// sella; las 4.997 restantes no las barre nadie. Cerrar eso pedía el gate de store-ready, que aquí
    /// no rige, así que el residual se declara en vez de darlo por resuelto.
    ///
    /// **Y el otro residual, el de cualquier one-shot:** un segundo dispositivo con el build viejo
    /// puede seguir emitiendo filas envenenadas por el canal nube después de que aquí ya se haya
    /// sellado — el applier las escribe verbatim, porque el grupo `money` es autoritativo y tiene
    /// prohibido recalcular (`EntityApplyMap`). Se cierra solo cuando ese dispositivo actualiza y corre
    /// el suyo.
    ///
    /// - Parameter isQuiescent: si el store personal está quieto. Se inyecta —en vez de consultarlo
    ///   dentro, como hace `updateProvisionalTransactions`— porque en un test el singleton de sync
    ///   responde `true` por ausencia de import, y un gate que nunca puede cerrarse es un gate sin
    ///   probar: el caso que importa es justamente el que difiere. Es opcional y no un `Bool` con
    ///   valor por defecto porque el default de un parámetro se evalúa FUERA del actor, y
    ///   `isImportQuiescent` está aislado a `@MainActor`; `nil` significa «pregúntaselo al singleton»,
    ///   que es lo que hace producción.
    @discardableResult
    static func repairLegacyOneToOneRatesIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        isQuiescent: Bool? = nil
    ) -> (fixed: Int, reopened: Int) {
        guard !defaults.bool(forKey: repairSweepKey) else { return (0, 0) }

        // Gate de quiescencia, el mismo que su vecino `updateProvisionalTransactions`. Sin marcar el
        // flag: no es que no hubiera nada que hacer, es que no se ha podido mirar.
        guard isQuiescent ?? iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("TransactionUpdateService.repairLegacyOneToOne", "import not quiescent")
            return (0, 0)
        }

        let preferred = CurrencyDefaults.currentPreferred
        // El predicado filtra por `exchangeRate == 1.0` y la comparación de divisas se hace en Swift:
        // un `#Predicate` que compara dos propiedades del mismo modelo entre sí es terreno resbaladizo
        // en SwiftData, y aquí no compensa el riesgo (ver la regla de `#Predicate` en las rules).
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.exchangeRate == 1.0 }
        )

        do {
            let candidates = try context.fetch(descriptor).filter {
                ExchangeRateRepairLogic.needsRepair(
                    exchangeRate: $0.exchangeRate,
                    currencyCode: $0.currencyCode,
                    preferredCurrencyCode: preferred
                )
            }
            // **Dos poblaciones bajo el mismo criterio, y cada una tiene su arreglo.** Ver
            // `ExchangeRateRepairLogic.rateFromStoredAmounts`: si de los montos ya guardados se deduce
            // una tasa, la conversión SÍ ocurrió y lo único falso es la columna `exchangeRate`, que se
            // corrige en el sitio; si no se deduce ninguna, tampoco se convirtió el monto y la fila
            // tiene que volver a la cola para que el reparador la reconvierta.
            //
            // Se filtra por `!isExchangeRateProvisional` para las dos: la fila que ya está en la cola
            // la va a arreglar el reparador tres líneas más abajo, con la lógica buena y en este mismo
            // arranque. Tocarla aquí sería adelantarle trabajo y ensuciar la fila por nada — el filtro
            // (`needsRepair`) mira la tasa y la divisa, **nunca el flag**.
            var fixedCount = 0
            var reopenedCount = 0
            for transaction in candidates where !transaction.isExchangeRateProvisional {
                if let derived = ExchangeRateRepairLogic.rateFromStoredAmounts(
                    amount: transaction.amount,
                    amountInPreferredCurrency: transaction.amountInPreferredCurrency
                ) {
                    transaction.exchangeRate = derived
                    fixedCount += 1
                } else {
                    transaction.isExchangeRateProvisional = true
                    reopenedCount += 1
                }
            }
            if fixedCount + reopenedCount > 0 {
                SaveBreadcrumb.willSave("TransactionUpdateService.repairLegacyOneToOne")
                try context.save()
                SaveBreadcrumb.didSave("TransactionUpdateService.repairLegacyOneToOne")
            }

            // **El flag no se quema sobre un store que todavía no tiene el corpus.**
            //
            // Antes se marcaba siempre, con el argumento de que «el barrido HIZO su trabajo». Vale
            // cuando hay filas y ninguna encaja; no vale cuando no hay NINGUNA fila, porque entonces el
            // barrido no ha mirado el corpus: lo ha adelantado. Un primer arranque tras reinstalar
            // —sesión de iCloud aún no lista, o restore más lento que la gracia del gate de guardado—
            // sellaba el one-shot y dejaba sin cura todo lo que bajara después.
            //
            // La pregunta se hace **solo cuando no hubo candidatas**, que es el único caso en que la
            // respuesta cambia algo: si las hubo, el store obviamente tiene corpus. Y se hace con
            // `fetchCount` sobre un descriptor sin predicado —no trayendo las filas— porque lo único
            // que se necesita es «¿hay alguna?».
            //
            // El coste en un usuario nuevo de verdad es un conteo por arranque hasta que registre su
            // primera transacción.
            if candidates.isEmpty,
                try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0
            {
                #if DEBUG
                print("TransactionUpdateService: store sin transacciones; el barrido se reintenta en el próximo arranque")
                #endif
                return (0, 0)
            }

            defaults.set(true, forKey: repairSweepKey)
            #if DEBUG
            print(
                "TransactionUpdateService: repair sweep fixed \(fixedCount) in place and reopened \(reopenedCount) of \(candidates.count) candidates"
            )
            #endif
            return (fixed: fixedCount, reopened: reopenedCount)
        } catch {
            // Sin marcar el flag: si el fetch falló, el barrido no ha corrido y debe reintentarse en el
            // próximo arranque.
            //
            // Tampoco hace falta deshacer lo ya asignado sobre el contexto: el barrido es idempotente
            // por construcción —solo toca la fila que aún no está marcada—, así que persista o no lo
            // que hubiera en vuelo, el reintento del próximo arranque no vuelve a tocar lo mismo.
            #if DEBUG
            print("TransactionUpdateService: repair sweep failed: \(error)")
            #endif
            return (0, 0)
        }
    }

    /// Clave de la huella del último barrido que no curó nada. Ver `FXRepairQueueLogic`.
    private static let futileSweepKey = "fxRepairQueue.futileSweepFingerprint.v1"

    static func updateProvisionalTransactions(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) async {
        // Gate de quiescencia: actualiza `TransactionItem` (store personal) + `save()`; diferir durante
        // el import del restore (idempotente: las provisionales se re-procesan en el próximo arranque).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("TransactionUpdateService.updateProvisional", "import not quiescent")
            return
        }
        // 1. Find transactions with provisional exchange rates
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.isExchangeRateProvisional == true }
        )

        let transactions: [TransactionItem]
        do {
            transactions = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("TransactionUpdateService: Error fetching provisional transactions: \(error)")
            #endif
            return
        }
        guard !transactions.isEmpty else {
            // La cola está vacía: la huella describe un estado que ya no existe y retenerla podría
            // silenciar un barrido futuro por coincidencia.
            defaults.removeObject(forKey: futileSweepKey)
            return
        }

        // 1bis. La salida del bucle. Si nada de lo que decide el resultado se ha movido desde un
        // barrido que ya se demostró estéril, repetirlo da el mismo cero: se sale ANTES de pedir nada
        // por red. Coste de un arranque atascado: los dos fetches locales de arriba.
        //
        // Las divisas se piden NORMALIZADAS, que es como las compara quien decide la calidad
        // (`CurrencyConverter.resolveRates`). Con el código crudo, una grafía distinta haría que su
        // fecha figurase como descubierta para siempre: refetch inútil en cada intento.
        var needed = Set(transactions.map { normalizeCurrencyCode($0.currencyCode) })
        needed.insert(normalizeCurrencyCode(CurrencyDefaults.currentPreferred))
        let dates = Set(transactions.map { $0.date })

        let service = ExchangeRateService.shared
        // Las FECHAS de la cola, no su rango. Un gasto de 2023 y otro de hoy son dos fechas, no mil
        // días: pedir el intervalo entero refetchearía el histórico completo en cada intento, porque
        // si al proveedor le falta esa divisa le falta todos los días.
        let uncoveredBefore = service.uncoveredDates(among: dates, needing: needed, context: context)

        let fingerprintBefore = FXRepairQueueLogic.fingerprint(
            provisionalCount: transactions.count, uncoveredDateCount: uncoveredBefore.count)
        if FXRepairQueueLogic.shouldSkipSweep(
            current: fingerprintBefore, lastFutile: defaults.string(forKey: futileSweepKey))
        {
            #if DEBUG
            print(
                "TransactionUpdateService: cola atascada (\(transactions.count) provisionales, \(uncoveredBefore.count) fechas sin cubrir); nada nuevo desde el último intento, se salta"
            )
            #endif
            MetricsService.canary(
                .fxRepairQueueStuck, detail: "skipped", value: Double(transactions.count))
            return
        }

        // 2. Pedir las tasas que faltan. El resultado dice si TODAS las peticiones salieron bien: un
        //    fallo de red es transitorio y no puede sellarse como estéril.
        let allFetchesSucceeded = await service.fetchRates(for: uncoveredBefore, context: context)

        // 3. Recalcular cada transacción provisional.
        //
        // Antes esto preguntaba `hasExactRate(for:)` y, si decía que sí, reimplementaba a mano las
        // mismas cinco líneas de `TransactionItem.recalculatePreferredCurrency`. Dos problemas, los
        // dos del ticket `fx-partial-rate-rows-silent-1to1`: (a) `hasExactRate` responde por que la
        // FILA EXISTA, no por que traiga la divisa que hace falta, así que sobre una fila parcial
        // decía `true`, la conversión devolvía el monto crudo y la línea final sellaba
        // `isExchangeRateProvisional = false` — un 1:1 marcado como oficial y ya nunca revisitado,
        // porque el `#Predicate` de arriba solo busca `== true`; y (b) el cálculo duplicado se
        // desincroniza del punto de paso en cuanto uno de los dos cambia.
        //
        // Ahora se delega, y quien decide si sigue provisional es la CALIDAD de la tasa. El efecto
        // para el usuario es que una transacción con tasa aproximada se corrige sola en cuanto llegan
        // las tasas reales, en vez de quedarse con el número malo para siempre.
        //
        // Se cuentan DOS cosas distintas y hacen falta las dos: `sealedCount` son las que dejaron de
        // ser provisionales —lo que el log llama «curadas»— y `changedCount` las que cambiaron ALGO.
        // Una tasa arrastrada mejor que la anterior mejora el monto sin poder sellarlo: con el
        // contador de selladas como único criterio, ese trabajo no se guardaba y encima el barrido se
        // marcaba estéril, bloqueando el reintento de una mejora que sí había ocurrido.
        var sealedCount = 0
        var changedCount = 0

        for transaction in transactions {
            let before = MoneySnapshot(transaction)
            transaction.recalculatePreferredCurrency(context: context)
            if MoneySnapshot(transaction) != before { changedCount += 1 }
            if !transaction.isExchangeRateProvisional { sealedCount += 1 }
        }

        // 4. Guardar lo que haya cambiado.
        var savedCleanly = true
        if changedCount > 0 {
            do {
                SaveBreadcrumb.willSave("TransactionUpdateService.updateProvisional")
                try context.save()
                SaveBreadcrumb.didSave("TransactionUpdateService.updateProvisional")
            } catch {
                savedCleanly = false
                #if DEBUG
                print("TransactionUpdateService: Failed to save updates: \(error)")
                #endif
            }
            // Los importes se mutaron EN SITIO y quien los pinta precalculado —el Panel— no observa
            // los `@Model` uno a uno: sin este aviso seguía con los números de antes toda la sesión
            // (ticket `reparacion-de-tasas-no-avisa-al-panel`). Va aquí, en el escritor, y no en sus
            // llamadores: son cuatro y el quinto se lo olvidaría. Solo con el guardado hecho: con el
            // `save()` fallido no hay nada nuevo en disco que recargar.
            if savedCleanly {
                SessionState.shared.incrementDataVersion()
            }
        }

        // 5. Dejar constancia del resultado, y sobre todo del NO-resultado.
        //
        // **El log estaba dentro del `if updatedCount > 0`, así que el único estado que no imprimía
        // nada era justo el que hay que ver: la cola atascada.** Cuanto peor iba, más callaba.
        #if DEBUG
        print(
            "TransactionUpdateService: cola de reparación: \(transactions.count) provisionales, \(sealedCount) curadas, \(changedCount) tocadas, \(transactions.count - sealedCount) siguen"
        )
        #endif

        // 6. Sellar el veredicto.
        //
        // Solo se marca «estéril» un intento COMPLETO que no movió nada: si alguna petición falló o el
        // guardado no llegó a disco, el resultado es indeterminado y la huella **no se toca** —ni se
        // escribe ni se borra—. Escribirla convertiría un corte de red en una transacción que se queda
        // mal; borrarla dejaría sin freno un `save()` que falla siempre.
        if changedCount > 0 && savedCleanly {
            defaults.removeObject(forKey: futileSweepKey)
        } else if changedCount == 0 && allFetchesSucceeded {
            // La huella se recalcula AQUÍ, no se reusa la de la entrada: si el paso 2 trajo tasas
            // nuevas y aun así no curó nada, lo que hay que recordar es que **con esas tasas ya
            // incluidas** no había nada que hacer. Guardar la de antes dejaría el bucle vivo, porque
            // el arranque siguiente vería otra cobertura y volvería a intentarlo igual.
            let uncoveredAfter = service.uncoveredDates(
                among: dates, needing: needed, context: context)
            defaults.set(
                FXRepairQueueLogic.fingerprint(
                    provisionalCount: transactions.count, uncoveredDateCount: uncoveredAfter.count),
                forKey: futileSweepKey)
            MetricsService.canary(
                .fxRepairQueueStuck, detail: "futile", value: Double(transactions.count))
        }
    }

    /// Las cuatro columnas que `recalculatePreferredCurrency` puede tocar, para saber si tocó alguna.
    ///
    /// No se usa `context.hasChanges`: mide el contexto ENTERO —en el arranque lo comparten varios
    /// barridos— y diría que sí por el trabajo de otro.
    private struct MoneySnapshot: Equatable {
        let rate: Double
        let amountInPreferred: Double
        let preferredCode: String
        let isProvisional: Bool

        init(_ transaction: TransactionItem) {
            rate = transaction.exchangeRate
            amountInPreferred = transaction.amountInPreferredCurrency
            preferredCode = transaction.preferredCurrencyCode
            isProvisional = transaction.isExchangeRateProvisional
        }
    }
}
