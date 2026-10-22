//
//  ChatUnsignedExpenseRepairLogic.swift
//  Yala
//
//  Qué transacción ya guardada salió del chat sin firmar, y con qué signo debe quedar.
//  Ticket `chat-rows-with-unsigned-amount-have-no-repair-path`.
//

import Foundation

/// Decide si una transacción **ya persistida** es una de las que
/// `ChatAssistantViewModel.saveDraft` guardó con la magnitud sin firmar, y cuál es su valor reparado.
///
/// **Es un barrido a ciegas, y eso es una decisión tomada, no un descuido** (Jürgen, 2026-09-08).
/// `TransactionItem` no tiene campo de origen: una fila del chat es indistinguible en el store de una
/// escrita a mano, y la única señal que queda —«categoría de gasto con monto positivo»— también la
/// tiene un dato legítimo, porque `TransactionClassificationLogic` documenta ese signo contrario como
/// reembolso intencionado. Se acepta que un reembolso registrado DENTRO de la ventana se voltee; lo
/// que acota el daño es la ventana, no la forma.
///
/// ## Lo que la ventana no acota, y por eso se filtra aparte
///
/// La forma «categoría de gasto + monto positivo» **no es exclusiva de los reembolsos**: también la
/// tienen filas que genera el sistema. Medido el 2026-09-08, el caso vivo es el **bridge de Grupos**:
/// `GroupTransactionBridge` construye sus transacciones con `category: subcat.safeCategory` explícita
/// y monto positivo en las ramas de cobro y liquidación, y los roles `loanCollection`,
/// `settlementSent` y `openingBalanceDebt` cuelgan de una categoría de sistema **de gasto**
/// (`GroupBridgeSystemEntities.parentCategoryRole`). Voltear una de ésas rompería el puente con el
/// grupo, que no es el daño que se aceptó.
///
/// El corte no es enumerar casos, sino mirar lo que el chat **no** escribe: `saveDraft` construye una
/// transacción **simple** —fecha, monto, divisa, nota, categoría, subcategoría, cuenta, etiquetas y
/// las cuatro columnas de divisa— y no toca **ninguno** de los cinco marcadores de sistema. Toda fila
/// que lleve uno tiene un origen conocido que no es el chat, así que descartarlas no pierde ni una
/// del corpus.
///
/// Si mañana aparece un marcador nuevo en `TransactionItem`, este es el sitio donde añadirlo: el
/// criterio es «sin marcadores», no «sin estos cinco».
///
/// ## Dos cosas que este filtro NO hace, y conviene no volver a creerlo
///
/// Hasta que la review adversarial lo midió, este docblock justificaba el filtro con dos ejemplos
/// **falsos**, y merecen quedarse escritos porque los dos suenan plausibles:
///
/// 1. **El saldo inicial de una cuenta no se salva por el marcador: se salva porque no tiene
///    categoría.** `InitialBalanceService` asigna `subcategory` y `balanceAdjustmentType` pero
///    **nunca `category`**, así que esas filas llegan con `category == nil` y las rechaza el guard de
///    categoría, que va antes. El razonamiento de que «Ajuste de saldo» cuelga de «Otros» y «Otros»
///    es `isIncome: false` es correcto pieza a pieza, y aun así la conclusión no se sostiene: la
///    categoría del padre de la subcategoría no es la categoría de la fila.
/// 2. **La pata de una transferencia que cuelga de «Otros» es la de SALIDA, y es negativa**
///    (`NewTransactionViewModel` guarda `outAmount = -amount` con `ensureTransferCategory`, que pide
///    `isIncome == false`). La de entrada usa `ensureIncomeTransferCategory`, de ingresos. Ninguna de
///    las dos pasa el criterio, con marcador o sin él.
enum ChatUnsignedExpenseRepairLogic {

    /// Los hechos de una fila que deciden si hay que voltearla. Se pasan sueltos —y no el
    /// `TransactionItem`— para que la decisión se pueda probar sin store ni schema.
    struct RowFacts {
        /// `amount` tal como está guardado.
        let amount: Double
        /// `category?.isIncome`. **`nil` (fila sin categoría) NO es candidata.**
        ///
        /// El chat siempre asigna una —`subcategory.safeCategory` no es opcional— pero de ahí **no**
        /// se sigue que una fila sin categoría venga de otro sitio, y creerlo sería un error: la
        /// relación es `@Relationship(deleteRule: .nullify)`, así que borrar una categoría deja a
        /// `nil` la de una fila del chat ya guardada; y SwiftData con CloudKit puede entregar una
        /// relación `nil` mientras su record va en vuelo.
        ///
        /// **Residual aceptado, no descuido:** esas filas se saltan, y como el barrido es one-shot no
        /// vuelven a mirarse. Se elige errar hacia no tocar, que es lo que corresponde a un barrido a
        /// ciegas: sin categoría no hay ninguna señal que permita afirmar que su signo está mal, y
        /// admitirlas metería en el criterio a toda fila huérfana positiva del store, del origen que
        /// sea. El saldo inicial de una cuenta es justo una de ésas.
        let categoryIsIncome: Bool?
        /// `createdAt`, que es lo que acota la ventana. **No `date`**: ver `isWithinWindow`.
        let createdAt: Date
        /// `true` si esta fila se creó **a la vez que otras**, que es la firma de una importación.
        /// Ver `batchFlags`. Una fila así no se toca, por decisión de Jürgen del 2026-09-08.
        let isPartOfACreationBatch: Bool
        let balanceAdjustmentType: String?
        let transferPairID: String?
        let splitExpenseID: String?
        let splitSettlementID: String?
        let scheduledPaymentID: String?

        init(
            amount: Double,
            categoryIsIncome: Bool?,
            createdAt: Date,
            isPartOfACreationBatch: Bool = false,
            balanceAdjustmentType: String? = nil,
            transferPairID: String? = nil,
            splitExpenseID: String? = nil,
            splitSettlementID: String? = nil,
            scheduledPaymentID: String? = nil
        ) {
            self.amount = amount
            self.categoryIsIncome = categoryIsIncome
            self.createdAt = createdAt
            self.isPartOfACreationBatch = isPartOfACreationBatch
            self.balanceAdjustmentType = balanceAdjustmentType
            self.transferPairID = transferPairID
            self.splitExpenseID = splitExpenseID
            self.splitSettlementID = splitSettlementID
            self.scheduledPaymentID = scheduledPaymentID
        }

        /// `true` si la fila la generó un flujo de sistema con origen conocido. Ninguno de estos cinco
        /// campos lo escribe `saveDraft`, así que descartarlos no pierde ni una fila del corpus.
        var hasSystemMarker: Bool {
            balanceAdjustmentType != nil
                || transferPairID != nil
                || splitExpenseID != nil
                || splitSettlementID != nil
                || scheduledPaymentID != nil
        }
    }

    /// Inicio de la ventana: el día en que nació `saveDraft` (`52d2ad6b`, 2026-04-27), la primera
    /// versión que ya guardaba sin firmar. Antes de esa fecha el chat no creaba transacciones.
    ///
    /// Se ancla al arranque del día en **UTC**, no en la zona del dispositivo: un borde local haría
    /// que la misma fila entrara o saliera de la ventana según dónde esté el teléfono. UTC-0 empieza
    /// cinco horas antes que Lima, donde se hizo el commit, así que el margen juega a no perder filas.
    static let windowStart: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 27
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        // El `?? .distantFuture` no es un caso alcanzable con estos componentes; es lo que evita el
        // force unwrap, y falla hacia el lado seguro: sin ventana no se repara nada.
        return calendar.date(from: components) ?? .distantFuture
    }()

    /// La ventana se mide sobre `createdAt` —cuándo se guardó la fila— y **nunca sobre `date`**, que
    /// es la fecha que el usuario le pone a la transacción y que el chat resuelve como
    /// `parsed.date ?? Date.now`: alguien puede dictar «un café en marzo» hoy, o registrar hoy un
    /// reembolso fechado en junio. Solo `createdAt` responde a «¿la escribió el código roto?».
    ///
    /// Y es fiable para todo el corpus: `createdAt` existe en el modelo desde el 2026-01-30
    /// (`c6c4dd9b`), tres meses antes de que naciera `saveDraft`, así que ninguna fila de la ventana
    /// lo tiene falseado por el valor por defecto de una migración posterior.
    ///
    /// - Parameter sweepRunAt: el cierre de la ventana, que es **el instante en que corre el barrido**
    ///   y no la fecha del commit del arreglo. El barrido es one-shot y solo se ejecuta desde un build
    ///   que ya firma, de modo que toda fila anterior a ese arranque pudo salir del código viejo,
    ///   incluidas las que el usuario dictó con el build de TestFlight entre el arreglo y su
    ///   instalación. Un corte fijo en la fecha del commit dejaría precisamente esas sin curar.
    static func isWithinWindow(createdAt: Date, sweepRunAt: Date) -> Bool {
        createdAt >= windowStart && createdAt <= sweepRunAt
    }

    /// `true` si hay que voltearle el signo a esta fila.
    static func isCandidate(_ row: RowFacts, sweepRunAt: Date) -> Bool {
        // Un gasto sin firmar es estrictamente positivo. El `> 0` deja fuera el cero, que no tiene
        // signo que corregir, y las filas ya correctas.
        guard row.amount > 0 else { return false }
        guard row.categoryIsIncome == false else { return false }
        guard !row.hasSystemMarker else { return false }
        guard !row.isPartOfACreationBatch else { return false }
        return isWithinWindow(createdAt: row.createdAt, sweepRunAt: sweepRunAt)
    }

    // MARK: - Los lotes de creación

    /// Hueco máximo entre dos filas para considerarlas creadas «a la vez».
    ///
    /// Dos segundos, y el número sale de los dos lados que hay que separar:
    /// - **El importador crea el lote entero sin `save()` intermedio** —su propio docblock lo dice:
    ///   «No realiza `context.save()`. El llamador debe guardar después»— así que sus filas nacen en
    ///   un bucle cerrado, con milisegundos entre una y la siguiente.
    /// - **El chat exige un toque humano por fila.** `saveDraft` tiene un único llamador
    ///   (`ChatAttachmentsView`), y es el `onSave` de UNA tarjeta: no hay «guardar todas». Entre dos
    ///   gastos dictados hay, como mínimo, el tiempo de pulsar dos veces.
    ///
    /// Dos segundos deja fuera cualquier lote y solo alcanzaría a un usuario que pulsara «Guardar» en
    /// dos tarjetas en menos de dos segundos. Ese caso se pierde a propósito: el encargo es no tocar
    /// lo importado, así que se falla hacia no tocar.
    static let batchTolerance: TimeInterval = 2

    /// Marca, para cada fecha de entrada, si esa fila nació dentro de un **lote de creación**.
    ///
    /// **Por qué esto identifica una importación, y por qué es la señal que hay.** El 2026-09-08 se
    /// midió que una fila importada por CSV es indistinguible campo a campo de una del chat: el
    /// importador no deja rastro en defaults, no hay modelo de sesión de import, y construye el
    /// `TransactionItem` con exactamente los mismos campos. Lo único que las separa es **cuántas
    /// nacen a la vez** — y no es una ocurrencia: el propio importador reconoce así sus filas, con un
    /// `importStart = Date.now` antes del bucle y un `filter { $0.createdAt >= importStart }` después,
    /// para no confundirlas con las históricas.
    ///
    /// Se agrupa por **huecos encadenados**, no por ventana fija: un import de mil filas puede tardar
    /// varios segundos en total, pero entre dos consecutivas nunca hay una pausa humana. Cortar por el
    /// hueco captura el lote entero sin tener que adivinar su tamaño.
    ///
    /// **Hay que pasarle TODAS las filas del store, no solo las candidatas.** Un import trae gastos e
    /// ingresos mezclados, y el vecino que delata el lote puede ser cualquiera de ellos: mirando solo
    /// las positivas, un import de quinientas filas con tres candidatas parecería tres gastos sueltos.
    ///
    /// **Residual conocido:** un import de **una sola fila** no tiene vecino y es indistinguible de un
    /// gasto dictado. No hay señal que lo separe.
    ///
    /// - Returns: un array **paralelo a la entrada**, en su mismo orden.
    static func batchFlags(
        createdAts: [Date],
        tolerance: TimeInterval = batchTolerance
    ) -> [Bool] {
        guard createdAts.count > 1 else { return Array(repeating: false, count: createdAts.count) }

        // Se ordenan los ÍNDICES, no las fechas, para poder devolver el resultado en el orden de
        // entrada: quien llama empareja cada bandera con su fila por posición.
        let ordered = createdAts.indices.sorted { createdAts[$0] < createdAts[$1] }
        var flags = Array(repeating: false, count: createdAts.count)

        var groupStart = 0
        func closeGroup(endingAt end: Int) {
            // Un grupo de uno es una fila solitaria: nadie nació con ella.
            guard end - groupStart >= 1 else { return }
            for position in groupStart...end { flags[ordered[position]] = true }
        }

        for position in 1..<ordered.count {
            let previous = createdAts[ordered[position - 1]]
            let current = createdAts[ordered[position]]
            if current.timeIntervalSince(previous) > tolerance {
                closeGroup(endingAt: position - 1)
                groupStart = position
            }
        }
        closeGroup(endingAt: ordered.count - 1)

        return flags
    }

    /// Los dos montos ya firmados con los que debe quedar una fila reparada.
    ///
    /// **Se firma la MAGNITUD, igual que hace el arreglo hacia delante** (`saveDraft` guarda
    /// `draft.isExpense ? -magnitud : magnitud`), y no se niega el valor guardado. Para `amount` da lo
    /// mismo —el criterio ya garantiza que es positivo— pero para la columna convertida no: negar a
    /// ciegas una fila que ya estuviera en negativo la dejaría positiva, es decir peor de como
    /// estaba. Firmar la magnitud da el mismo resultado en el corpus y no puede producir esa vuelta.
    ///
    /// **`exchangeRate` no se toca a propósito.** Producción la guarda con `abs()` y la deriva del
    /// cociente de las dos columnas; al voltear ambas a la vez el cociente no cambia de signo, así que
    /// la tasa guardada sigue siendo la correcta. Tocarla sería reescribir un número que ya está bien.
    ///
    /// Tampoco se pasa por `TransactionItem.recalculatePreferredCurrency`: ese método nunca asigna
    /// `amount` y alimenta el converter con el valor tal cual, de modo que **propaga** el signo malo a
    /// la columna convertida en vez de corregirlo. Pasar una fila del chat por él la deja igual de rota.
    static func repairedAmounts(
        amount: Double,
        amountInPreferredCurrency: Double
    ) -> (amount: Double, amountInPreferredCurrency: Double) {
        (amount: -abs(amount), amountInPreferredCurrency: -abs(amountInPreferredCurrency))
    }
}
