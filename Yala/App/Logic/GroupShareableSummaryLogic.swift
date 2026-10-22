//
//  GroupShareableSummaryLogic.swift
//  Yala
//
//  «Cierre del viaje»: arma el resumen compartible de UN grupo a partir de los datos que ya se
//  calculan hoy. Lógica pura y SOLO-LECTURA — no crea, modifica ni borra nada (ni SwiftData ni
//  CloudKit): recibe arrays ya fetcheados y devuelve un `Snapshot` de valores.
//
//  Cuatro fronteras, decididas aquí y no en la vista, porque son las que hacen que los números del
//  resumen cuadren entre sí:
//
//  1. **Todo el historial, sin filtro de período** (decisión del owner, 2026-09-06). El resumen es
//     el cierre del viaje: un solo comportamiento, que no depende del filtro que el usuario tenga
//     puesto en la pestaña de Estadísticas.
//
//  2. **Los saldos iniciales no son gasto, pero sí son deuda.** El total y las columnas
//     «pagó»/«le corresponde» salen de los gastos REALES (`!isOpeningBalance`) — misma frontera que
//     `GroupStatsViewModel.periodExpenses()`, y la que hace que la suma de lo pagado por cada
//     miembro dé el total. Los «pagos para saldar», en cambio, salen de las deudas COMPLETAS
//     (saldos iniciales dentro, liquidaciones confirmadas descontadas): es lo que hay que
//     transferir de verdad, y es lo que muestra la pestaña Balances.
//
//  3. **Un gasto saldado sigue siendo gasto del viaje.** `isSettled` no aparta la fila del total ni
//     del desglose —se gastó, y el resumen cuenta lo que costó el viaje, igual que Estadísticas—,
//     pero sí la aparta de los pagos, porque `GroupBalanceService.rawDebts` la filtra. Es la misma
//     asimetría del punto 2 leída por el otro eje, y aquí queda dicha porque no es obvia: la pestaña
//     Balances SÍ excluye esos gastos de sus columnas, así que en un grupo con gastos saldados las
//     dos pantallas no enseñan los mismos totales por miembro. Hoy nada local enciende ese flag
//     (solo lo trae el pull), pero eso es una frecuencia, no una garantía.
//
//  4. **Una moneda, un bloque: los totales NUNCA se suman entre divisas.** Ni siquiera con
//     `showDebtsInSingleCurrency`, porque una conversión al tipo de cambio del momento se congela en
//     una imagen que cada miembro leería distinto según cuándo se generó.
//
//     **Los PAGOS son la excepción, y no por gusto:** cuando ese ajuste está encendido, las
//     liquidaciones del grupo se ESCRIBEN en la moneda del grupo, no en la del gasto
//     (`SettlementFormView.effectiveCurrency` recibe una deuda ya consolidada). Así que en ese caso
//     las deudas por divisa cruda no netean contra sus propias liquidaciones: la deuda original
//     seguiría viva en USD y el pago aparecería como una deuda inversa en PEN, y el resumen mandaría
//     al chat dos transferencias fantasma en direcciones opuestas por dinero que ya no se debe.
//     Con el ajuste encendido, por tanto, los pagos se consolidan a la moneda del grupo —igual que
//     hace la pestaña Balances— y se marcan como aproximados; los bloques de las demás divisas dejan
//     de mostrar su sección de pagos, para no afirmar «todo saldado» sobre unas deudas que se están
//     contando en otro sitio.
//
//  Y una que se aparta de la pantalla a propósito: **los pagos van SIEMPRE simplificados**
//  (`simplifyDebts: true`), tenga el grupo la preferencia puesta o no. Lo que este resumen responde
//  es «cómo saldamos esto en los menos pagos posibles», que es la pregunta del cierre del viaje. El
//  precio, dicho para que nadie lo descubra por sorpresa: en un grupo con la preferencia APAGADA,
//  la lista de aquí puede no coincidir con la de la pestaña Balances — misma deuda total, distinto
//  reparto de transferencias.
//

import Foundation

@MainActor
enum GroupShareableSummaryLogic {

    // MARK: - Modelo

    /// Una fila del desglose por miembro, dentro de una moneda.
    /// `paid` es lo que puso de su bolsillo; `owed`, lo que le correspondía según los repartos.
    struct MemberLine: Identifiable, Equatable {
        let memberID: String
        let displayName: String
        let paid: Double
        let owed: Double

        var id: String { memberID }
    }

    /// Una transferencia de la lista mínima para saldar (salida de `DebtSimplificationService`).
    struct PaymentLine: Identifiable, Equatable {
        let fromMemberID: String
        let toMemberID: String
        let fromName: String
        let toName: String
        let amount: Double

        var id: String { "\(fromMemberID)-\(toMemberID)" }
    }

    /// Todo lo del resumen en UNA moneda. Nunca mezcla montos de otra.
    struct CurrencyBlock: Identifiable, Equatable {
        let currencyCode: String
        let totalSpent: Double

        /// `false` cuando esta divisa no tiene ni un gasto real detrás (solo saldos iniciales, o solo
        /// es la moneda en la que se saldan las deudas de otra). La tarjeta entonces NO pinta el
        /// total: un «Total gastado 0,00» encima de transferencias reales se lee como un error.
        var hasSpending: Bool { !members.isEmpty || totalSpent != 0 }
        let members: [MemberLine]
        let payments: [PaymentLine]

        /// `false` en los bloques que NO deben pintar la sección de pagos: ocurre cuando el grupo
        /// consolida sus deudas a una sola moneda y todas se han contado en el bloque de esa divisa.
        /// Sin este flag, los demás bloques dirían «todo saldado» sobre unas deudas que existen y que
        /// están listadas más arriba.
        let showsPayments: Bool

        /// Los importes de `payments` vienen de convertir otra divisa al tipo de cambio actual: se
        /// muestran con el prefijo «≈», igual que hace la pestaña Balances.
        let paymentsAreConverted: Bool

        var id: String { currencyCode }
        /// Sin deudas vivas que mostrar aquí: la sección de pagos se sustituye por «todo saldado».
        var isSettled: Bool { showsPayments && payments.isEmpty }
    }

    /// El resumen entero, listo para renderizar. Sin `@Model` dentro: se puede pasar a una vista
    /// que se rasteriza fuera del árbol de la app sin arrastrar contexto de SwiftData.
    struct Snapshot: Equatable {
        let groupName: String
        let iconName: String
        let colorHex: String
        let blocks: [CurrencyBlock]

        /// Nada que resumir (grupo sin gastos reales ni deudas): el punto de entrada no se ofrece.
        var isEmpty: Bool { blocks.isEmpty }
        /// `true` cuando NINGUNA moneda tiene deudas vivas — el viaje está cerrado del todo.
        ///
        /// Mira solo los bloques que CUENTAN pagos. Leer `isSettled` de todos daría `false` en un
        /// grupo consolidado y saldado: los bloques de las otras divisas tienen `showsPayments`
        /// apagado, que significa «esto se cuenta en otro sitio», no «queda deuda».
        var isFullySettled: Bool {
            blocks.allSatisfy { !$0.showsPayments || $0.payments.isEmpty }
        }
    }

    // MARK: - Construcción

    /// Arma el resumen de un grupo. Todos los arrays vienen ya fetcheados por el caller
    /// (`GroupDetailViewModel` los tiene cacheados), así que esto no toca el `ModelContext`.
    ///
    /// - Parameter unknownMemberName: qué poner cuando un `memberID` no casa con ningún miembro
    ///   (miembro borrado de la zona, dato a medio sincronizar). Se inyecta en vez de leer `L10n`
    ///   dentro para que los tests fijen el texto y no dependan del idioma del simulador.
    static func build(
        group: SplitGroup,
        members: [SplitMember],
        expenses: [SplitExpense],
        shares: [SplitShare],
        settlements: [SplitSettlement],
        unknownMemberName: String
    ) -> Snapshot {
        // Dedup por id: defensa contra duplicados de CloudKit (race en merge resolution), molde
        // exacto de `GroupBalanceService`. Aquí pesa más que en una pantalla: un total inflado por
        // un duplicado se congela en una imagen y se reparte por el chat del grupo.
        let uniqueExpenses = Dictionary(grouping: expenses, by: \.id).values.compactMap(\.first)
        let realExpenses = uniqueExpenses.filter { !$0.isOpeningBalance }
        // Los shares también, y por su PROPIO id: deduplicar solo los gastos blinda el total y la
        // columna «pagó» y deja «le tocaba» al doble, con lo que la misma imagen se contradice a sí
        // misma. Llegan repetidos por la misma vía que los gastos (merge de CloudKit) y por una
        // propia: `GroupExpenseService.updateExpense` borra los shares viejos y crea otros con id
        // nuevo, así que un tombstone que se aplique tarde deja los dos juegos conviviendo.
        let uniqueShares = Dictionary(grouping: shares, by: \.id).values.compactMap(\.first)

        // Nombres tal cual, SIN el badge «(Tú)» que el resto de Grupos añade al miembro propio
        // (`L10n.Groups.Member.you`, ver `GroupMemberRow`). Es deliberado y no un olvido: esta imagen
        // se manda al chat del grupo, y ahí «(Tú)» se refiere a quien la generó — para todos los
        // demás no identifica a nadie. El resumen habla del grupo en tercera persona.
        let nameByMemberID = Dictionary(
            members.map { ($0.id.uuidString, $0.resolvedDisplayName) },
            uniquingKeysWith: { first, _ in first }
        )
        func name(_ memberID: String) -> String {
            nameByMemberID[memberID] ?? unknownMemberName
        }

        // Deudas vivas del grupo, simplificadas y por moneda (el servicio agrupa por divisa
        // internamente y simplifica cada una por separado).
        let rawDebts = GroupBalanceService.calculateDebts(
            expenses: uniqueExpenses,
            shares: uniqueShares,
            settlements: settlements,
            simplifyDebts: true
        )

        // Regla 4 de la cabecera: con el ajuste encendido los pagos van todos a la moneda del grupo,
        // porque es la moneda en la que ese grupo escribe sus liquidaciones. Espeja exactamente lo
        // que hace `GroupDetailViewModel.recalculate()` para la pestaña Balances.
        let consolidatesPayments = group.showDebtsInSingleCurrency
        let paymentsCurrency = group.currencyCode
        let paymentsAreConverted = consolidatesPayments
            && rawDebts.contains { $0.currencyCode != paymentsCurrency }
        let debts = paymentsAreConverted
            ? GroupBalanceService.consolidatedDebts(from: rawDebts, targetCurrency: paymentsCurrency)
            : rawDebts

        let expensesByCurrency = Dictionary(grouping: realExpenses, by: \.currencyCode)
        let debtsByCurrency = Dictionary(grouping: debts, by: \.currencyCode)

        // UNIÓN, no solo las monedas con gasto: una divisa puede tener deuda viva sin un solo gasto
        // real detrás (todo saldo inicial, o todos sus gastos marcados como saldados). Recorrer solo
        // `expensesByCurrency` haría desaparecer esos pagos del resumen sin dejar rastro.
        var allCurrencies = Set(expensesByCurrency.keys).union(debtsByCurrency.keys)
        // Consolidando, la moneda del grupo es la ÚNICA que puede llevar la sección de pagos. Si no
        // tuviera bloque propio —todo el gasto en otra divisa, y las deudas ya saldadas— el resumen
        // se quedaría sin sitio donde decir «todo saldado», que es media razón de mandarlo. El
        // `!isEmpty` conserva el caso «nada que resumir»: sin gastos ni deudas no se inventa bloque.
        if consolidatesPayments && !allCurrencies.isEmpty {
            allCurrencies.insert(paymentsCurrency)
        }
        let sharesByExpense = Dictionary(grouping: uniqueShares, by: \.expenseID)

        let blocks = orderedCurrencies(allCurrencies, mainCurrency: group.currencyCode)
            .map { code -> CurrencyBlock in
                buildBlock(
                    currencyCode: code,
                    expenses: expensesByCurrency[code] ?? [],
                    debts: debtsByCurrency[code] ?? [],
                    sharesByExpense: sharesByExpense,
                    // Consolidando, la sección de pagos existe SOLO en la moneda del grupo: en las
                    // demás las deudas ya están contadas arriba y un «todo saldado» aquí mentiría.
                    showsPayments: !consolidatesPayments || code == paymentsCurrency,
                    paymentsAreConverted: paymentsAreConverted,
                    name: name
                )
            }

        return Snapshot(
            groupName: group.name,
            iconName: group.iconName,
            colorHex: group.colorHex,
            blocks: blocks
        )
    }

    // MARK: - Helpers

    private static func buildBlock(
        currencyCode: String,
        expenses: [SplitExpense],
        debts: [Debt],
        sharesByExpense: [UUID: [SplitShare]],
        showsPayments: Bool,
        paymentsAreConverted: Bool,
        name: (String) -> String
    ) -> CurrencyBlock {
        var paid: [String: Double] = [:]
        var owed: [String: Double] = [:]

        for expense in expenses {
            paid[expense.paidByMemberID, default: 0] += expense.amount
            for share in sharesByExpense[expense.id] ?? [] {
                owed[share.memberID, default: 0] += share.amount
            }
        }

        let total = expenses.reduce(0) { $0 + $1.amount }

        // La columna «le tocaba» PUEDE no sumar exactamente el total, y no se fuerza a que cuadre.
        //
        // Con el reparto equitativo de la app NO pasa: `GroupSplitCalculator.equalSplit` calcula la
        // base con `floor` y va soltando los céntimos sobrantes uno a uno, así que las partes de un
        // gasto suman el gasto EXACTO. Las vías por las que sí puede descuadrar son otras dos, y
        // ninguna es un redondeo nuestro: el reparto exacto acepta una tolerancia de ±0,02 frente al
        // total (`GroupSplitCalculator`/`GroupExpenseService.validateSharesSum`), y los importes que
        // bajan del wire no pasan por ningún calculador. Cuadrarlo aquí significaría repartir el
        // residuo por nuestra cuenta y enseñar en la imagen una cifra distinta de la que el grupo
        // tiene guardada como parte de cada uno: el resumen es fiel al dato, no al redondeo bonito.
        // Lo que sí cuadra siempre es la columna «pagó», que son los importes de los gastos sin
        // dividir.
        //
        // (El desajuste que se ve en el simulador con el seed `grupos` —123,34 × 3 contra un total
        // de 370— es del propio seed, que redondea cada gasto por separado sin repartir el resto. Es
        // un fixture, no el comportamiento de producción: conviene no leerlo como tal.)
        //
        // Un miembro entra en el desglose si puso dinero O si le tocaba parte. Quien no hizo ninguna
        // de las dos cosas en esta moneda no aparece: una fila de ceros no dice nada.
        let memberLines = Set(paid.keys).union(owed.keys)
            .map { memberID in
                MemberLine(
                    memberID: memberID,
                    displayName: name(memberID),
                    paid: roundToTwoDecimals(paid[memberID] ?? 0),
                    owed: roundToTwoDecimals(owed[memberID] ?? 0)
                )
            }
            // Orden total sobre el conjunto recibido, y estable: importe, luego nombre, luego id
            // (los nombres se repiten). Aquí sí basta para que dos generaciones den la misma tabla,
            // porque el conjunto de miembros no depende de nadie más.
            .sorted { lhs, rhs in
                if lhs.paid != rhs.paid { return lhs.paid > rhs.paid }
                if lhs.displayName != rhs.displayName { return lhs.displayName < rhs.displayName }
                return lhs.memberID < rhs.memberID
            }

        let payments = debts
            .map { debt in
                PaymentLine(
                    fromMemberID: debt.fromMemberID,
                    toMemberID: debt.toMemberID,
                    fromName: name(debt.fromMemberID),
                    toName: name(debt.toMemberID),
                    amount: debt.amount
                )
            }
            // Mismo criterio, pero aquí el orden NO alcanza para garantizar la misma imagen dos
            // veces: ante un empate exacto de saldos, `DebtSimplificationService` elige acreedor y
            // deudor con `max(by:)`/`min(by:)` sobre un `Dictionary`, cuyo orden de iteración cambia
            // entre procesos. El CONJUNTO de transferencias puede salir distinto (todas correctas y
            // por el mismo total), y ningún `sorted` posterior reconcilia eso. Es de aguas arriba y
            // lo comparten Balances y el recordatorio de deudas → ticket
            // `debt-simplification-nondeterministic-ties`.
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
                if lhs.fromName != rhs.fromName { return lhs.fromName < rhs.fromName }
                return lhs.id < rhs.id
            }

        return CurrencyBlock(
            currencyCode: currencyCode,
            totalSpent: roundToTwoDecimals(total),
            members: memberLines,
            payments: showsPayments ? payments : [],
            showsPayments: showsPayments,
            paymentsAreConverted: paymentsAreConverted
        )
    }

    /// Monedas con la principal del grupo primero, luego alfabético — molde de
    /// `GroupStatsViewModel.orderedCurrencies`, para que el resumen y las estadísticas no ordenen
    /// las divisas al revés.
    private static func orderedCurrencies(_ codes: Set<String>, mainCurrency: String) -> [String] {
        codes.sorted { lhs, rhs in
            if lhs == mainCurrency { return true }
            if rhs == mainCurrency { return false }
            return lhs < rhs
        }
    }

    private static func roundToTwoDecimals(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
