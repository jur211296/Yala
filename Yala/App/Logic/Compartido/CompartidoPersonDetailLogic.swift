//
//  CompartidoPersonDetailLogic.swift
//  Yala
//
//  El detalle de una persona en Compartido (lote 2, 26-nov-2026): lo que se ve al abrir su tarjeta en el chip Personas.
//  Espejo del detalle de grupo con un filtro de grupo («Todos los grupos · <grupos> · Sin grupo») en las tres páginas.
//  Lógica pura, sin SwiftData: recibe, grupo a grupo, las deudas tal como las enseña ese grupo (las de su
//  `GroupDetailViewModel`, con «Menos pagos» y «Ver en una moneda» de ESE grupo) y devuelve lo que dice cada página.
//
//  Tres reglas:
//  · Solo cuenta lo que hay entre tú y la persona: una deuda entre otros dos miembros del grupo no es suya.
//  · Las cifras van en céntimos enteros: lo que se salda grupo a grupo suma EXACTAMENTE lo de «Todos los grupos».
//  · «Saldar todo» apunta un pago por grupo y moneda, cada uno en su sentido (en un grupo te debe y en otro le debes).
//

import Foundation

enum CompartidoPersonDetailLogic {

    // MARK: - Filtro

    /// Qué parte de lo compartido con la persona se ve.
    enum Filter: Hashable, Sendable {
        /// Todos los grupos y lo sin grupo.
        case all
        /// Un grupo (su `cloudKitZoneID`).
        case group(String)
        /// Lo compartido fuera de un grupo: el grupo de dos de la persona (`SplitGroup.isPerson`).
        case noGroup
    }

    // MARK: - Entrada

    /// Un grupo que compartes con la persona, con sus deudas ya calculadas.
    struct Slice: Equatable, Sendable {
        let groupKey: String
        let groupName: String
        /// Es el grupo de dos de la persona: se nombra «Sin grupo».
        let isPerson: Bool
        /// Mi fila de miembro en este grupo; `nil` si no se pudo resolver (sin ella no hay nada mío que contar).
        let myMemberID: String?
        /// Las filas de la persona en este grupo.
        let personMemberIDs: Set<String>
        /// Las deudas como las enseña el grupo.
        let debts: [Debt]
        /// Las deudas del grupo se convirtieron a una moneda («Ver en una moneda»): la cifra es aproximada.
        var debtsWereConverted = false
    }

    // MARK: - Opciones del filtro

    /// «Todos los grupos», cada grupo en el orden recibido y «Sin grupo» al final si hay un grupo de dos.
    static func filterOptions(_ slices: [Slice]) -> [Filter] {
        var options: [Filter] = [.all]
        for slice in slices where !slice.isPerson {
            options.append(.group(slice.groupKey))
        }
        if slices.contains(where: \.isPerson) { options.append(.noGroup) }
        return options
    }

    /// Los grupos que entran en un filtro.
    static func slices(_ slices: [Slice], in filter: Filter) -> [Slice] {
        switch filter {
        case .all: return slices
        case .group(let key): return slices.filter { $0.groupKey == key && !$0.isPerson }
        case .noGroup: return slices.filter(\.isPerson)
        }
    }

    /// Un filtro que ya no existe (el grupo se archivó y salió de la lista, o se borró) vuelve a «Todos los grupos».
    static func resolved(_ filter: Filter, options: [Filter]) -> Filter {
        options.contains(filter) ? filter : .all
    }

    // MARK: - Lo que hay entre los dos

    /// Neto en céntimos por moneda entre tú y la persona en UN grupo: positivo, te debe; negativo, le debes.
    static func pairNetCents(_ slice: Slice) -> [String: Int] {
        guard let me = slice.myMemberID else { return [:] }
        var result: [String: Int] = [:]
        for debt in slice.debts {
            let cents = Int((debt.amount * 100).rounded())
            if debt.toMemberID == me, slice.personMemberIDs.contains(debt.fromMemberID) {
                result[debt.currencyCode, default: 0] += cents
            } else if debt.fromMemberID == me, slice.personMemberIDs.contains(debt.toMemberID) {
                result[debt.currencyCode, default: 0] -= cents
            }
        }
        return result.filter { $0.value != 0 }
    }

    /// Una fila del desglose: un grupo (o «Sin grupo») con su neto por moneda.
    struct BreakdownRow: Equatable, Sendable, Identifiable {
        var id: String { groupKey }
        let groupKey: String
        let groupName: String
        let isPerson: Bool
        /// Céntimos por moneda: positivo, te debe; negativo, le debes. Sin las monedas en cero.
        let netCents: [String: Int]
        /// El grupo convirtió sus deudas («Ver en una moneda»): la marca «≈» de ESTA fila, no la de todo el filtro.
        var isEstimate = false
    }

    /// El desglose de un filtro, en el orden de los grupos y con lo sin grupo al final. Sin los grupos a cero.
    static func breakdown(_ slices: [Slice], filter: Filter) -> [BreakdownRow] {
        let inFilter = Self.slices(slices, in: filter)
        let ordered = inFilter.filter { !$0.isPerson } + inFilter.filter(\.isPerson)
        return ordered.compactMap { slice in
            let net = pairNetCents(slice)
            guard !net.isEmpty else { return nil }
            return BreakdownRow(
                groupKey: slice.groupKey, groupName: slice.groupName, isPerson: slice.isPerson, netCents: net,
                isEstimate: slice.debtsWereConverted)
        }
    }

    /// El neto del filtro: la suma de su desglose, moneda a moneda.
    static func netCents(_ slices: [Slice], filter: Filter) -> [String: Int] {
        var total: [String: Int] = [:]
        for row in breakdown(slices, filter: filter) {
            for (currency, cents) in row.netCents { total[currency, default: 0] += cents }
        }
        return total.filter { $0.value != 0 }
    }

    /// Lo que va en la cifra grande: lo que te debe y lo que le debes, por moneda y en positivo, ordenado por moneda.
    struct Hero: Equatable {
        let owedToMe: [GroupBalancesPresentationLogic.CurrencyAmount]
        let iOwe: [GroupBalancesPresentationLogic.CurrencyAmount]

        var isSettled: Bool { owedToMe.isEmpty && iOwe.isEmpty }
    }

    static func hero(_ slices: [Slice], filter: Filter) -> Hero {
        let sorted = netCents(slices, filter: filter).sorted { $0.key < $1.key }
        return Hero(
            owedToMe: sorted.filter { $0.value > 0 }.map { .init(currencyCode: $0.key, amount: Double($0.value) / 100) },
            iOwe: sorted.filter { $0.value < 0 }.map { .init(currencyCode: $0.key, amount: Double(-$0.value) / 100) })
    }

    /// En un grupo te debe y en otro le debes: la frase «Tú no le debes nada» bajo el neto sería falsa grupo a grupo, y la
    /// cifra la omite (el desglose de Saldos lo cuenta).
    static func hasOpposingGroups(_ slices: [Slice], filter: Filter) -> Bool {
        let values = breakdown(slices, filter: filter).flatMap { $0.netCents.values }
        return values.contains { $0 > 0 } && values.contains { $0 < 0 }
    }

    /// Las monedas de la cifra que llevan «≈»: por moneda, lo que aportan los grupos que convirtieron sus deudas
    /// (numerador, |neto del par| de cada uno) contra el neto que se pinta en esa moneda (denominador), con el umbral de
    /// la app (`ApproximateMarkThreshold`). Una moneda en la que ningún grupo convirtió nunca se marca.
    static func estimatedCurrencies(_ slices: [Slice], filter: Filter) -> Set<String> {
        let rows = breakdown(slices, filter: filter)
        var approximate: [String: Int] = [:]
        var total: [String: Int] = [:]
        for row in rows {
            for (currency, cents) in row.netCents {
                total[currency, default: 0] += cents
                if row.isEstimate { approximate[currency, default: 0] += abs(cents) }
            }
        }
        return Set(approximate.compactMap { currency, cents in
            let shown = abs(total[currency] ?? 0)
            return ApproximateMarkThreshold.marks(approximate: Double(cents) / 100, total: Double(shown) / 100)
                ? currency : nil
        })
    }

    // MARK: - Saldar

    /// Un pago que hay que apuntar: en un grupo, entre tus filas y las de la persona, en una moneda.
    struct SettleItem: Equatable, Sendable, Identifiable {
        var id: String { "\(groupKey)-\(debt.currencyCode)" }
        let groupKey: String
        let groupName: String
        let isPerson: Bool
        /// El grupo convirtió sus deudas: el importe de este pago lleva «≈».
        var isEstimate = false
        /// La deuda que se salda, tal como la daría el grupo (de quien paga a quien recibe), con el importe redondeado.
        let debt: Debt
        /// `true` si pagas tú.
        var iPay: Bool { debt.fromMemberID == myMemberID }
        let myMemberID: String
    }

    /// Los pagos que dejan a mano lo del filtro: uno por grupo y moneda.
    static func settlePlan(_ slices: [Slice], filter: Filter) -> [SettleItem] {
        let inFilter = Self.slices(slices, in: filter)
        let ordered = inFilter.filter { !$0.isPerson } + inFilter.filter(\.isPerson)
        var plan: [SettleItem] = []
        for slice in ordered {
            guard let me = slice.myMemberID else { continue }
            for (currency, cents) in pairNetCents(slice).sorted(by: { $0.key < $1.key }) {
                // Con quién en concreto: la fila de la persona que aparece en las deudas de esa moneda (la primera, si
                // una zona migrada dejó dos).
                guard let person = personMemberID(in: slice, me: me, currency: currency, theyOweMe: cents > 0) else {
                    continue
                }
                let amount = Double(abs(cents)) / 100
                let debt = cents > 0
                    ? Debt(fromMemberID: person, toMemberID: me, amount: amount, currencyCode: currency)
                    : Debt(fromMemberID: me, toMemberID: person, amount: amount, currencyCode: currency)
                plan.append(SettleItem(
                    groupKey: slice.groupKey, groupName: slice.groupName, isPerson: slice.isPerson,
                    isEstimate: slice.debtsWereConverted, debt: debt, myMemberID: me))
            }
        }
        return plan
    }

    private static func personMemberID(in slice: Slice, me: String, currency: String, theyOweMe: Bool) -> String? {
        let candidates = slice.debts.filter { $0.currencyCode == currency }.compactMap { debt -> String? in
            if theyOweMe, debt.toMemberID == me, slice.personMemberIDs.contains(debt.fromMemberID) {
                return debt.fromMemberID
            }
            if !theyOweMe, debt.fromMemberID == me, slice.personMemberIDs.contains(debt.toMemberID) {
                return debt.toMemberID
            }
            return nil
        }
        return candidates.first ?? slice.personMemberIDs.sorted().first
    }

    /// Las deudas del par en un grupo, las que `GroupBalancesView` enseña con un grupo elegido: solo entre tú y la persona.
    static func pairDebts(_ slice: Slice) -> [Debt] {
        guard let me = slice.myMemberID else { return [] }
        return slice.debts.filter { debt in
            (debt.fromMemberID == me && slice.personMemberIDs.contains(debt.toMemberID))
                || (debt.toMemberID == me && slice.personMemberIDs.contains(debt.fromMemberID))
        }
    }

    // MARK: - Gastos

    /// Un gasto es «con la persona» si estáis los dos: pagó uno y el otro tiene parte, o los dos tenéis parte.
    static func isSharedExpense(
        paidBy: String, participants: Set<String>, myMemberID: String?, personMemberIDs: Set<String>
    ) -> Bool {
        guard let me = myMemberID else { return false }
        let involved = participants.union([paidBy])
        return involved.contains(me) && !involved.isDisjoint(with: personMemberIDs)
    }

    /// Un pago es «con la persona» si va de uno al otro.
    static func isSharedSettlement(from: String, to: String, myMemberID: String?, personMemberIDs: Set<String>) -> Bool {
        guard let me = myMemberID else { return false }
        return (from == me && personMemberIDs.contains(to)) || (to == me && personMemberIDs.contains(from))
    }

    // MARK: - Estadísticas

    /// Para juntar a la persona y a ti entre grupos en «¿Quién puso más?» y «Mi parte»: cada fila tuya va a tu primera
    /// fila y cada fila suya a su primera (filas reales, así sus nombres salen de los miembros de siempre). Los demás
    /// miembros se quedan con la suya. `me`: tu fila de referencia, la que Estadísticas trata como «Tú».
    static func memberAliases(_ slices: [Slice]) -> (aliases: [String: String], me: String?) {
        let me = slices.compactMap(\.myMemberID).first
        let person = slices.compactMap { $0.personMemberIDs.sorted().first }.first
        var aliases: [String: String] = [:]
        for slice in slices {
            if let mine = slice.myMemberID, let me { aliases[mine] = me }
            if let person {
                for id in slice.personMemberIDs { aliases[id] = person }
            }
        }
        return (aliases, me)
    }

    /// «Por grupo» en Estadísticas: cuánto te debe (o le debes) en cada grupo, con la barra proporcional a lo mayor en
    /// la moneda de la primera fila. Solo con «Todos» y más de un grupo con algo pendiente.
    struct ByGroupRow: Equatable, Sendable, Identifiable {
        var id: String { groupKey }
        let groupKey: String
        let groupName: String
        let isPerson: Bool
        let netCents: [String: Int]
        /// El grupo convirtió sus deudas: la cifra de la fila lleva «≈» (la misma que en el desglose de Saldos).
        var isEstimate = false
        /// De 0 a 1, para la barra.
        let fraction: Double
    }

    static func byGroup(_ slices: [Slice]) -> [ByGroupRow] {
        let rows = breakdown(slices, filter: .all)
        guard rows.count > 1 else { return [] }
        // La barra compara en la moneda que más se repite entre los grupos (la de la cifra grande, casi siempre).
        let counts = rows.flatMap { $0.netCents.keys }.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let reference = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.first?.key
        let top = rows.compactMap { row in reference.flatMap { row.netCents[$0] }.map(abs) }.max() ?? 0
        return rows.map { row in
            let value = reference.flatMap { row.netCents[$0] }.map(abs) ?? 0
            return ByGroupRow(
                groupKey: row.groupKey, groupName: row.groupName, isPerson: row.isPerson, netCents: row.netCents,
                isEstimate: row.isEstimate, fraction: top > 0 ? Double(value) / Double(top) : 0)
        }
    }
}
