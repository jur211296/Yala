//
//  AntExpensesAILogic.swift
//  Yala
//
//  «Gastos hormiga» con IA, solo Pro (ticket `insights-ant-expenses-ai-version-for-pro`). Se SUMA a la tarjeta gratis,
//  que no cambia: la regla fija (`AntExpensesCalculator`) agrupa por descripción normalizada y no junta dos grafías de
//  la misma tienda («Starbucks» y «STARBUCKS COFFEE»). La IA propone qué grupos son el mismo sitio y escribe un consejo
//  corto; todo lo demás lo decide este fichero, en Swift:
//
//  - La IA solo devuelve IDS opacos de grupos que se le enviaron. Un id que no existe, repetido o en dos uniones se
//    descarta: no puede inventar compras ni nombres.
//  - Las cifras de cada unión (veces, total, período anterior) se suman aquí, nunca se copian de la respuesta.
//  - Una unión solo se enseña si lo que junta llega a ser hormiga (`AntExpensesCalculator.minOccurrences` veces o más)
//    y junta al menos dos grafías: es lo que la regla fija no podía ver.
//

import Foundation

/// Lo que contesta el servicio de IA, tal cual. Se guarda así (por huella) y se valida cada vez contra los datos.
struct AntAIResponse: Codable, Equatable {
    struct Merge: Codable, Equatable {
        let ids: [String]
    }

    let merges: [Merge]
    let tip: String?

    init(merges: [Merge], tip: String?) {
        self.merges = merges
        self.tip = tip
    }

    /// Tolerante con lo que falte: sin `merges` es «no juntó nada», no un error.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        merges = try container.decodeIfPresent([Merge].self, forKey: .merges) ?? []
        tip = try container.decodeIfPresent(String.self, forKey: .tip)
    }
}

/// Un grupo que la IA juntó: varias grafías de la misma compra.
struct AntAIMergedGroup: Equatable {
    /// La grafía más usada de las que se juntaron.
    let label: String
    /// Las otras grafías, de la más usada a la menos.
    let otherLabels: [String]
    let count: Int
    let total: Double
}

/// Lo que se enseña en el bloque Pro, ya validado.
struct AntAIInsight: Equatable {
    let mergedGroups: [AntAIMergedGroup]
    /// El total de gastos hormiga con las grafías juntas; `nil` si las uniones no cambian el de la tarjeta.
    let combinedTotal: Double?
    let combinedCount: Int?
    let tip: String?

    var isEmpty: Bool { mergedGroups.isEmpty && tip == nil }
}

enum AntExpensesAILogic {

    /// Grupos que viajan como mucho: los que más se repiten. Acota el coste y lo que sale del teléfono.
    static let candidateLimit = 40
    /// Largo máximo del consejo; lo que pase se corta (el prompt pide menos).
    static let tipMaxLength = 180

    /// Los grupos que se envían, con su id opaco (`g1`, `g2`…), en un orden estable: veces, total y clave.
    static func orderedCandidates(_ summary: AntExpensesSummary) -> [(id: String, group: AntExpenseGroup)] {
        let ordered = summary.candidates.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            return lhs.key < rhs.key
        }
        return ordered.prefix(candidateLimit).enumerated().map { ("g\($0.offset + 1)", $0.element) }
    }

    /// Compras sueltas por grupo como mucho, en el envío detallado.
    static let purchasesPerGroupLimit = 31
    /// Grupos del período anterior que hoy no aparecen, como mucho, en el envío detallado.
    static let previousOnlyLimit = 20

    /// Lo que se envía a la IA. Dos niveles, decididos por Jürgen el 2026-11-06:
    ///
    /// - **Privado** (`detailed == false`, decisión 1A): nombre (tal como se escribió más veces), veces y total de cada
    ///   compra pequeña, y lo mismo del período anterior para los mismos grupos. Ni fechas, ni importes sueltos, ni
    ///   cuentas.
    /// - **Nube** (`detailed == true`): «la IA puede leer todo lo que haga falta para leer con precisión». Además, cada
    ///   grafía con sus veces, la subcategoría, cada compra con su fecha e importe, y las compras pequeñas del período
    ///   anterior que hoy no aparecen. Sigue sin cuentas: no ayudan a juntar tiendas ni al consejo.
    static func payload(
        summary: AntExpensesSummary,
        currencyCode: String,
        currencyDisplay: String,
        language: String,
        periodLabel: String,
        previousLabel: String?,
        detailed: Bool = false
    ) -> [String: Any] {
        let candidates = orderedCandidates(summary)
        let previousByKey = Dictionary(
            (summary.previousCandidates ?? []).map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var payload: [String: Any] = [
            "currency": currencyCode,
            "currency_display": currencyDisplay,
            "locale": language,
            "period": periodLabel,
            "small_purchase_max": Int(summary.threshold.rounded()),
            "min_repeats": AntExpensesCalculator.minOccurrences,
            "ant_total": Int(summary.total.rounded()),
            "ant_count": summary.count,
            "groups": candidates.map { id, group -> [String: Any] in
                var row: [String: Any] = [
                    "id": id, "name": group.label, "count": group.count, "total": Int(group.total.rounded()),
                ]
                if summary.previousCandidates != nil {
                    let previous = previousByKey[group.key]
                    row["previous_count"] = previous?.count ?? 0
                    row["previous_total"] = Int((previous?.total ?? 0).rounded())
                }
                if detailed { row.merge(detail(of: group), uniquingKeysWith: { _, new in new }) }
                return row
            },
        ]
        if let previousLabel, summary.previousCandidates != nil { payload["previous_period"] = previousLabel }
        if detailed {
            payload["detail_level"] = "full"
            let sentKeys = Set(candidates.map(\.group.key))
            let previousOnly = (summary.previousCandidates ?? [])
                .filter { !sentKeys.contains($0.key) }
                .sorted { lhs, rhs in
                    if lhs.count != rhs.count { return lhs.count > rhs.count }
                    return lhs.key < rhs.key
                }
                .prefix(previousOnlyLimit)
            if !previousOnly.isEmpty {
                payload["previous_only_groups"] = previousOnly.map { group -> [String: Any] in
                    var row: [String: Any] = [
                        "name": group.label, "count": group.count, "total": Int(group.total.rounded()),
                    ]
                    if let category = group.categoryLabel { row["category"] = category }
                    return row
                }
            }
        }
        return payload
    }

    /// El detalle de un grupo en el envío de la nube: grafías, subcategoría y compras con fecha.
    static func detail(of group: AntExpenseGroup) -> [String: Any] {
        var row: [String: Any] = [:]
        if group.spellings.count > 1 {
            row["spellings"] = group.spellings
                .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .map { ["name": $0.key, "count": $0.value] as [String: Any] }
        }
        if let category = group.categoryLabel { row["category"] = category }
        if !group.purchases.isEmpty {
            row["purchases"] = group.purchases.prefix(purchasesPerGroupLimit).map {
                ["date": dayFormatter.string(from: $0.date), "amount": ($0.amount * 100).rounded() / 100] as [String: Any]
            }
        }
        return row
    }

    /// `AAAA-MM-DD` en el calendario y la zona de la persona.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Valida la respuesta contra los grupos enviados y suma las cifras. Lo que no cuadra se descarta.
    static func insight(from response: AntAIResponse, summary: AntExpensesSummary) -> AntAIInsight {
        let candidates = orderedCandidates(summary)
        let byID = Dictionary(candidates.map { ($0.id, $0.group) }, uniquingKeysWith: { first, _ in first })
        var used = Set<String>()
        var merged: [(group: AntAIMergedGroup, keys: Set<String>)] = []

        for merge in response.merges {
            var ids: [String] = []
            for id in merge.ids where byID[id] != nil && !used.contains(id) && !ids.contains(id) {
                ids.append(id)
            }
            guard ids.count >= 2 else { continue }
            let members = ids.compactMap { byID[$0] }.sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                return lhs.key < rhs.key
            }
            let count = members.reduce(0) { $0 + $1.count }
            guard count >= AntExpensesCalculator.minOccurrences, let head = members.first else { continue }
            used.formUnion(ids)
            merged.append((
                AntAIMergedGroup(
                    label: head.label,
                    otherLabels: members.dropFirst().map(\.label),
                    count: count,
                    total: members.reduce(0) { $0 + $1.total }
                ),
                Set(members.map(\.key))
            ))
        }

        merged.sort { lhs, rhs in
            if lhs.group.total != rhs.group.total { return lhs.group.total > rhs.group.total }
            return lhs.group.label < rhs.group.label
        }

        // El total con las grafías juntas: los grupos de la tarjeta que ninguna unión tocó, más las uniones.
        let mergedKeys = merged.reduce(into: Set<String>()) { $0.formUnion($1.keys) }
        let untouched = summary.groups.filter { !mergedKeys.contains($0.key) }
        let combinedTotal = untouched.reduce(0) { $0 + $1.total } + merged.reduce(0) { $0 + $1.group.total }
        let combinedCount = untouched.reduce(0) { $0 + $1.count } + merged.reduce(0) { $0 + $1.group.count }
        let changesTotal = !merged.isEmpty && combinedCount != summary.count

        return AntAIInsight(
            mergedGroups: merged.map(\.group),
            combinedTotal: changesTotal ? combinedTotal : nil,
            combinedCount: changesTotal ? combinedCount : nil,
            tip: cleanTip(response.tip)
        )
    }

    /// El consejo sin espacios de más, sin vacíos y con un largo máximo.
    static func cleanTip(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count > tipMaxLength else { return trimmed }
        return String(trimmed.prefix(tipMaxLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Las cifras que deciden si un cambio pide un consejo nuevo (`StatsAIAutoRefreshLogic.isRelevantChange`).
    static func snapshot(_ summary: AntExpensesSummary) -> StatsAIAutoRefreshLogic.Snapshot {
        StatsAIAutoRefreshLogic.Snapshot(transactionCount: summary.count, totals: [summary.total])
    }
}
