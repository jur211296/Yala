//
//  RecurringPaymentChanges.swift
//  Yala
//
//  Pagos recurrentes, lote S2 (definición «Atajo del banco y suscripciones», 12-nov-2026; decisión 66 de Jürgen, 14-nov,
//  reconfirmada el 21-nov). Compara cada pago planificado con los cobros que de verdad llegaron y avisa de dos cosas:
//
//  - **Cambió de precio**: los dos últimos cobros coinciden entre sí y no con el pago («Netflix subió a S/ 49,90»).
//  - **Dejó de cobrarse**: el pago sigue activo y hace dos ciclos que no llega nada («¿Dejaste de pagar Spotify?»).
//    Pausarlo libera lo que se reservaba para él en las cifras.
//
//  Regla exacta, sin IA, en el teléfono. Aquí no hay SwiftData: entran pagos y cobros y salen avisos. Quien llama
//  (`RecurringChangesSource`) ya excluyó transferencias, ajustes, gastos de grupo e ingresos.
//

import Foundation

enum RecurringPaymentChanges {

    // MARK: - Parámetros

    /// Dos montos «iguales» difieren menos de un 1 % (o medio céntimo).
    static let sameAmountTolerance = 0.01
    /// El último cobro tiene que ser reciente para hablar de precio: un cobro de hace medio año no dice cuánto cuesta hoy.
    static let priceChangeMaxDaysSinceLastCharge = 60
    /// Un cambio de más del doble (o de menos de la mitad) es otra cosa, no un cambio de precio.
    static let priceChangeMaxRatio = 2.0
    /// Días sin cobro para decir que dejó de cobrarse: dos ciclos y un margen.
    static let stoppedMonthlyDays = 65
    static let stoppedWeeklyDays = 20
    /// Cobros mínimos que tiene que haber visto Yala para hablar de un pago que dejó de llegar.
    static let stoppedMinimumCharges = 2

    // MARK: - Entrada

    struct Planned: Equatable {
        let id: String
        let name: String
        let storedBrandID: String?
        let amount: Double
        let currencyCode: String
        let isVariableAmount: Bool
        /// `ScheduledPayment.recurrenceType` («monthly», «weekly»…).
        let recurrenceType: String
        let recurrenceInterval: Int
        let isActive: Bool
        let isRecurring: Bool
        let createdAt: Date
        let lastPaidDate: Date?
    }

    /// Un cobro ya filtrado. `amount` en positivo. `scheduledPaymentID` si se apuntó desde ese pago.
    struct Charge: Equatable {
        let date: Date
        let amount: Double
        let currencyCode: String
        let name: String
        let scheduledPaymentID: String?
    }

    // MARK: - Salida

    enum Kind: Equatable {
        /// Los dos últimos cobros fueron de `newAmount`; el pago dice otra cosa.
        case priceChanged(newAmount: Double, increased: Bool)
        /// Nada desde `lastSeen` (el último cobro o el último «pagado»).
        case stopped(lastSeen: Date)
    }

    struct Change: Equatable, Identifiable {
        let paymentID: String
        let kind: Kind
        var id: String { paymentID }

        /// Lo que se recuerda al contestar «Dejar así» o «Sigue activo»: si el precio vuelve a cambiar, o llega un cobro y
        /// después vuelve a pararse, el aviso sale otra vez.
        var token: String {
            switch kind {
            case .priceChanged(let amount, _):
                return "price:\(Int((amount * 100).rounded()))"
            case .stopped(let lastSeen):
                return "stop:\(Int(lastSeen.timeIntervalSince1970 / 86_400))"
            }
        }
    }

    // MARK: - Detección

    static func detect(
        planned: [Planned],
        charges: [Charge],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Change] {
        let candidates = planned.filter { $0.isActive && $0.isRecurring && $0.amount > 0 }
        let identities = candidates.map { PlannedIdentity($0) }
        var chargesByPayment: [String: [Charge]] = [:]
        for charge in charges where charge.amount > 0 && charge.date <= now {
            guard let owner = owner(of: charge, among: candidates, identities: identities) else { continue }
            chargesByPayment[owner.id, default: []].append(charge)
        }

        var changes: [Change] = []
        for payment in candidates {
            let own = (chargesByPayment[payment.id] ?? []).sorted { $0.date < $1.date }
            if let stopped = stopped(payment, charges: own, now: now, calendar: calendar) {
                changes.append(Change(paymentID: payment.id, kind: stopped))
            } else if let price = priceChange(payment, charges: own, now: now, calendar: calendar) {
                changes.append(Change(paymentID: payment.id, kind: price))
            }
        }
        return changes
    }

    /// El pago al que pertenece un cobro: el que lo generó o, si no, el de la misma divisa y comercio. Con dos pagos de
    /// la misma marca (YouTube Premium y YouTube Music), el de monto más cercano.
    private static func owner(of charge: Charge, among payments: [Planned], identities: [PlannedIdentity]) -> Planned? {
        if let id = charge.scheduledPaymentID, let linked = payments.first(where: { $0.id == id }) { return linked }
        let currency = charge.currencyCode.uppercased()
        let brand = RecurringPaymentDetector.brand(forChargeName: charge.name)
        let matching = payments.indices.filter {
            payments[$0].currencyCode.uppercased() == currency && identities[$0].matches(name: charge.name, brand: brand)
        }
        return matching.min { abs(payments[$0].amount - charge.amount) < abs(payments[$1].amount - charge.amount) }
            .map { payments[$0] }
    }

    // MARK: - Cambio de precio

    static func priceChange(_ payment: Planned, charges: [Charge], now: Date, calendar: Calendar) -> Kind? {
        guard !payment.isVariableAmount, charges.count >= 2 else { return nil }
        let last = charges[charges.count - 1]
        let previous = charges[charges.count - 2]
        guard RecurringPaymentDetector.daysBetween(last.date, now, calendar: calendar) <= priceChangeMaxDaysSinceLastCharge
        else { return nil }
        guard same(last.amount, previous.amount), !same(last.amount, payment.amount) else { return nil }
        let ratio = last.amount / payment.amount
        guard ratio <= priceChangeMaxRatio, ratio >= 1 / priceChangeMaxRatio else { return nil }
        return .priceChanged(newAmount: last.amount, increased: last.amount > payment.amount)
    }

    static func same(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) <= max(RecurringPaymentDetector.exactAmountTolerance, max(a, b) * sameAmountTolerance)
    }

    // MARK: - Dejó de cobrarse

    static func stopped(_ payment: Planned, charges: [Charge], now: Date, calendar: Calendar) -> Kind? {
        guard payment.recurrenceInterval == 1, charges.count >= stoppedMinimumCharges else { return nil }
        let limit: Int
        switch payment.recurrenceType {
        case "monthly": limit = stoppedMonthlyDays
        case "weekly": limit = stoppedWeeklyDays
        default: return nil
        }
        let lastCharge = charges[charges.count - 1].date
        let lastSeen = max(lastCharge, payment.lastPaidDate ?? lastCharge)
        guard RecurringPaymentDetector.daysBetween(lastSeen, now, calendar: calendar) > limit else { return nil }
        // Un pago recién creado no puede llevar dos ciclos sin cobrarse.
        guard RecurringPaymentDetector.daysBetween(payment.createdAt, now, calendar: calendar) > limit else { return nil }
        return .stopped(lastSeen: lastSeen)
    }

    // MARK: - Identidad

    private struct PlannedIdentity {
        let normalizedName: String
        let brandID: String?

        init(_ payment: Planned) {
            normalizedName = RecurringPaymentDetector.merchantName(payment.name)
            brandID = SubscriptionBrandCatalog.resolve(storedID: payment.storedBrandID, name: payment.name)?.id
        }

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
