//
//  RecurringPaymentDetector.swift
//  Yala
//
//  Pagos recurrentes, lote S1 (definición «Atajo del banco y suscripciones», 12-nov-2026; decisión de Jürgen del
//  14-nov: todas las recomendadas). Busca en el historial los cobros que se repiten para proponerlos como pago
//  planificado. Regla exacta, sin IA, en el teléfono:
//
//  - mismo comercio: la marca del catálogo (`SubscriptionBrandCatalog`) o, sin marca, el nombre normalizado;
//  - cada divisa por separado;
//  - 3 cobros mensuales (±4 días) o 4 semanales (±1 día) seguidos, contados desde el último hacia atrás (S2);
//  - monto dentro de un 15 % del último, o exacto si es una marca de suscripción;
//  - el último cobro hace menos de 45 días;
//  - sin un pago planificado parecido (por marca o por nombre).
//
//  Quien llama ya excluyó transferencias, gastos de grupo, ingresos y lo que generó un pago planificado que existe
//  (`RecurringProposalsSource`). Aquí no hay SwiftData: entra una lista de cobros y sale una lista de propuestas.
//

import Foundation

enum RecurringPaymentDetector {

    // MARK: - Parámetros de la regla

    static let minimumMonthlyCharges = 3
    static let minimumWeeklyCharges = 4
    static let monthlyToleranceDays = 4
    static let weeklyToleranceDays = 1
    static let amountTolerance = 0.15
    /// «Menos de 45 días» desde el último cobro.
    static let maximumDaysSinceLastCharge = 45
    /// Dos montos «exactos» difieren menos de medio céntimo (coma flotante).
    static let exactAmountTolerance = 0.005

    // MARK: - Entrada

    /// Un cobro ya filtrado. `amount` es la magnitud (positiva). `ref` es el índice con que quien llama lo encuentra.
    struct Charge: Equatable {
        let ref: Int
        let date: Date
        let amount: Double
        let currencyCode: String
        let name: String
    }

    /// Un pago planificado que ya existe, para no proponer otro parecido.
    struct PlannedPayment: Equatable {
        let name: String
        /// `ScheduledPayment.brandLogoID` tal como está guardado.
        let storedBrandID: String?
    }

    // MARK: - Salida

    enum Cadence: Equatable {
        /// Cada mes. `day` es el día típico; `isApproximate` si los cobros cayeron en días distintos («hacia el 3»).
        case monthly(day: Int, isApproximate: Bool)
        /// Cada semana. `weekday` como `Calendar` (1 = domingo).
        case weekly(weekday: Int)
    }

    struct Proposal: Equatable, Identifiable {
        /// Clave estable del comercio y la divisa: `brand:netflix|PEN` o `name:luz del sur|PEN`. Es lo que se recuerda
        /// al descartar o posponer.
        let key: String
        let displayName: String
        let brandID: String?
        let currencyCode: String
        let cadence: Cadence
        /// Cobros de la serie que cumple la regla (no todos los del comercio).
        let chargeCount: Int
        let firstChargeDate: Date
        let lastChargeDate: Date
        /// El monto que se propone: el del último cobro.
        let amount: Double
        let isVariableAmount: Bool
        let nextDueDate: Date
        let lastChargeRef: Int
        let chargeRefs: [Int]

        var id: String { key }
        var isSubscriptionBrand: Bool { brandID != nil }
    }

    // MARK: - Detección

    static func detect(
        charges: [Charge],
        plannedPayments: [PlannedPayment],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Proposal] {
        let today = calendar.startOfDay(for: now)
        let planned = plannedPayments.map { PlannedIdentity($0) }

        var groups: [String: (brand: SubscriptionBrand?, charges: [Charge])] = [:]
        // Muchos cobros repiten nombre: normalizar y buscar la marca una vez por nombre, no por cobro.
        var identityCache: [String: (normalized: String, brand: SubscriptionBrand?)] = [:]
        for charge in charges where charge.amount > 0 && calendar.startOfDay(for: charge.date) <= today {
            let identity: (normalized: String, brand: SubscriptionBrand?)
            if let cached = identityCache[charge.name] {
                identity = cached
            } else {
                identity = (merchantName(charge.name), brand(forChargeName: charge.name))
                identityCache[charge.name] = identity
            }
            guard !identity.normalized.isEmpty else { continue }
            let merchant = identity.brand.map { "brand:\($0.id)" } ?? "name:\(identity.normalized)"
            let key = "\(merchant)|\(charge.currencyCode.uppercased())"
            groups[key, default: (identity.brand, [])].charges.append(charge)
        }

        var proposals: [Proposal] = []
        for (key, group) in groups {
            let sorted = group.charges.sorted { $0.date < $1.date }
            guard let last = sorted.last else { continue }
            guard daysBetween(last.date, now, calendar: calendar) < maximumDaysSinceLastCharge else { continue }
            guard !planned.contains(where: { $0.matches(name: last.name, brand: group.brand) }) else { continue }
            guard let series = series(in: sorted, isSubscriptionBrand: group.brand != nil, calendar: calendar) else {
                continue
            }
            proposals.append(makeProposal(key: key, brand: group.brand, series: series, now: now, calendar: calendar))
        }
        return proposals.sorted {
            $0.nextDueDate != $1.nextDueDate ? $0.nextDueDate < $1.nextDueDate : $0.key < $1.key
        }
    }

    // MARK: - Serie

    private struct Series {
        let charges: [Charge]
        let isWeekly: Bool
    }

    /// La serie más larga que acaba en el último cobro y cumple intervalo y monto. Mensual primero.
    private static func series(in sorted: [Charge], isSubscriptionBrand: Bool, calendar: Calendar) -> Series? {
        let monthly = trailingRun(in: sorted, isSubscriptionBrand: isSubscriptionBrand) { previous, next in
            isMonthlyStep(from: previous, to: next, calendar: calendar)
        }
        if monthly.count >= minimumMonthlyCharges { return Series(charges: monthly, isWeekly: false) }

        let weekly = trailingRun(in: sorted, isSubscriptionBrand: isSubscriptionBrand) { previous, next in
            abs(daysBetween(previous, next, calendar: calendar) - 7) <= weeklyToleranceDays
        }
        if weekly.count >= minimumWeeklyCharges { return Series(charges: weekly, isWeekly: true) }
        return nil
    }

    private static func trailingRun(
        in sorted: [Charge],
        isSubscriptionBrand: Bool,
        step: (Date, Date) -> Bool
    ) -> [Charge] {
        guard let last = sorted.last else { return [] }
        var run = [last]
        var index = sorted.count - 2
        while index >= 0 {
            let candidate = sorted[index]
            guard let earliest = run.first,
                  step(candidate.date, earliest.date),
                  amountMatches(candidate.amount, reference: last.amount, exact: isSubscriptionBrand) else { break }
            run.insert(candidate, at: 0)
            index -= 1
        }
        return run
    }

    /// Un mes de calendario después, con ±4 días: del 31 de enero al 28 de febrero es un mes.
    static func isMonthlyStep(from previous: Date, to next: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: previous)
        guard let expected = calendar.date(byAdding: .month, value: 1, to: start) else { return false }
        return abs(daysBetween(expected, next, calendar: calendar)) <= monthlyToleranceDays
    }

    static func amountMatches(_ amount: Double, reference: Double, exact: Bool) -> Bool {
        if exact { return abs(amount - reference) < exactAmountTolerance }
        return abs(amount - reference) <= reference * amountTolerance + exactAmountTolerance
    }

    // MARK: - Propuesta

    private static func makeProposal(
        key: String, brand: SubscriptionBrand?, series: Series, now: Date, calendar: Calendar
    ) -> Proposal {
        let charges = series.charges
        let last = charges[charges.count - 1]
        let amounts = charges.map(\.amount)
        let isVariable = (amounts.max() ?? 0) - (amounts.min() ?? 0) >= exactAmountTolerance

        let cadence: Cadence
        if series.isWeekly {
            cadence = .weekly(weekday: calendar.component(.weekday, from: last.date))
        } else {
            let days = charges.map { calendar.component(.day, from: $0.date) }
            let ordered = days.sorted()
            let median = ordered[(ordered.count - 1) / 2]
            cadence = .monthly(day: median, isApproximate: Set(days).count > 1)
        }

        let trimmed = last.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Proposal(
            key: key,
            displayName: brand?.name ?? trimmed,
            brandID: brand?.id,
            currencyCode: last.currencyCode.uppercased(),
            cadence: cadence,
            chargeCount: charges.count,
            firstChargeDate: charges[0].date,
            lastChargeDate: last.date,
            amount: last.amount,
            isVariableAmount: isVariable,
            nextDueDate: nextDueDate(after: last.date, cadence: cadence, now: now, calendar: calendar),
            lastChargeRef: last.ref,
            chargeRefs: charges.map(\.ref)
        )
    }

    /// La primera fecha de la serie después del último cobro que no haya pasado ya (hoy cuenta).
    static func nextDueDate(after lastCharge: Date, cadence: Cadence, now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: lastCharge)
        switch cadence {
        case .weekly:
            for weeks in 1...520 {
                guard let candidate = calendar.date(byAdding: .day, value: 7 * weeks, to: start) else { break }
                if candidate >= today { return candidate }
            }
            return today
        case .monthly(let day, _):
            // Desde el mes del último cobro: si ese cobro se corrió al mes siguiente (día típico 30, cobrado el 1),
            // el ciclo que falta todavía es de este mes. Y una fecha a ±4 días del último cobro es el ciclo que ya se
            // pagó (día típico 1, cobrado el 30 del mes anterior).
            for months in 0...120 {
                guard let monthDate = calendar.date(byAdding: .month, value: months, to: start),
                      let candidate = date(inMonthOf: monthDate, day: day, calendar: calendar) else { continue }
                guard daysBetween(start, candidate, calendar: calendar) > monthlyToleranceDays else { continue }
                if candidate >= today { return candidate }
            }
            return today
        }
    }

    /// El día `day` del mes de `monthDate`, o su último día si el mes es más corto.
    private static func date(inMonthOf monthDate: Date, day: Int, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
        components.day = min(day, range.count)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    // MARK: - Marca

    /// Palabras que pueden ir detrás del nombre de un servicio sin cambiar de comercio («NETFLIX.COM», «Spotify Premium»,
    /// «Disney Plus Mensual»).
    static let brandTrailingNoise: Set<String> = [
        "com", "net", "pe", "co", "mx", "ar", "es", "www", "inc", "llc", "sa", "sac", "ltd",
        "premium", "plus", "family", "familiar", "duo", "individual", "student", "estudiante", "standard", "basic",
        "mensual", "monthly", "anual", "annual", "subscription", "suscripcion", "membership", "membresia", "app",
        "bill", "payment", "pago", "cobro", "digital",
    ]

    /// La marca de un cobro, más estricta que la del editor: el catálogo casa también por prefijo («Prime Gym» con el
    /// alias «prime»), y aquí la marca decide el nombre, el logo y que el monto sea exacto. Solo vale si el nombre ES
    /// el servicio o lo que sigue al servicio son palabras de relleno.
    static func brand(forChargeName name: String) -> SubscriptionBrand? {
        guard let brand = SubscriptionBrandCatalog.match(name: name) else { return nil }
        let normalized = merchantName(name)
        for candidate in [brand.name] + brand.aliases {
            let alias = merchantName(candidate)
            guard !alias.isEmpty else { continue }
            if normalized == alias { return brand }
            guard normalized.hasPrefix(alias + " ") else { continue }
            let rest = normalized.dropFirst(alias.count + 1).split(separator: " ").map(String.init)
            if rest.allSatisfy({ brandTrailingNoise.contains($0) }) { return brand }
        }
        return nil
    }

    // MARK: - Utilidades

    /// Días de calendario entre dos fechas (con signo). Por días y no por segundos: un cambio de hora no lo mueve.
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    /// El nombre del comercio para agrupar: normalizado como el catálogo de marcas y sin las palabras que son solo
    /// números (referencias, últimos dígitos de la tarjeta).
    static func merchantName(_ raw: String) -> String {
        SubscriptionBrandCatalog.normalize(raw)
            .split(separator: " ")
            .filter { !$0.allSatisfy(\.isNumber) }
            .joined(separator: " ")
    }

    /// Un pago planificado existente, listo para comparar.
    private struct PlannedIdentity {
        let normalizedName: String
        let brandID: String?

        init(_ payment: PlannedPayment) {
            normalizedName = RecurringPaymentDetector.merchantName(payment.name)
            brandID = SubscriptionBrandCatalog.resolve(storedID: payment.storedBrandID, name: payment.name)?.id
        }

        /// Parecido: la misma marca, el mismo nombre, o uno empieza por el otro («Netflix» y «Netflix familiar»).
        func matches(name: String, brand: SubscriptionBrand?) -> Bool {
            if let brand, brand.id == brandID { return true }
            let other = RecurringPaymentDetector.merchantName(name)
            guard !other.isEmpty, !normalizedName.isEmpty else { return false }
            return other == normalizedName
                || other.hasPrefix(normalizedName + " ")
                || normalizedName.hasPrefix(other + " ")
        }
    }
}
