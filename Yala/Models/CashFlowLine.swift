//
//  CashFlowLine.swift
//  Yala
//
//  SwiftData model for a single line (income/expense) in a cash flow plan.
//

import Foundation
import SwiftData

// MARK: - EstimationMethod

/// Estimation method enum (not persisted — for type safety in code)
enum EstimationMethod: String, CaseIterable {
    case average3m, average6m, average12m
    case lastMonth, manual, trend, custom, scheduled

    var displayName: String {
        switch self {
        case .average3m: L10n.CashFlowPlan.average3m
        case .average6m: L10n.CashFlowPlan.average6m
        case .average12m: L10n.CashFlowPlan.average12m
        case .lastMonth: L10n.CashFlowPlan.lastMonth
        case .manual: L10n.CashFlowPlan.manual
        case .scheduled: L10n.CashFlowPlan.scheduled
        case .trend: L10n.CashFlowPlan.trend
        case .custom: L10n.CashFlowPlan.custom
        }
    }

    var descriptionText: String {
        switch self {
        case .average3m: L10n.CashFlowPlan.average3mDesc
        case .average6m: L10n.CashFlowPlan.average6mDesc
        case .average12m: L10n.CashFlowPlan.average12mDesc
        case .lastMonth: L10n.CashFlowPlan.lastMonthDesc
        case .manual: L10n.CashFlowPlan.manualDesc
        case .scheduled: L10n.CashFlowPlan.scheduledDesc
        case .trend: L10n.CashFlowPlan.trendDesc
        case .custom: L10n.CashFlowPlan.customDesc
        }
    }
}

// MARK: - CashFlowLine

@Model
final class CashFlowLine {
    // I12: identidad de sync del Modo Nube (`sync_id_source = CashFlowLine.id`).
    // `.preserveValueOnDeletion` para que el history tombstone conserve el `id` (metadata de History;
    // sin deploy .ckdb).
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    var name: String = ""
    var isIncome: Bool = false
    var sortOrder: Int = 0
    var isEnabled: Bool = true
    var isExpanded: Bool = false
    var estimationMethod: String = "average6m"
    var manualAmount: Double?
    var customMonthsRaw: String?

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify, inverse: \Category.cashFlowLines)
    var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Subcategory.cashFlowLines)
    var subcategory: Subcategory?

    @Relationship(deleteRule: .nullify, inverse: \ScheduledPayment.cashFlowLines)
    var scheduledPayment: ScheduledPayment?

    @Relationship(deleteRule: .nullify)
    var plan: CashFlowPlan?   // Explicit for CloudKit REFERENCE mapping

    /// Los ajustes de un mes de esta línea. Inversa de `CashFlowOverride.cashFlowLine`, que es la relación que
    /// sincroniza (ver su docblock). Es la que leen y escriben todos los caminos de la app.
    @Relationship(deleteRule: .cascade, inverse: \CashFlowOverride.cashFlowLine)
    var monthOverrides: [CashFlowOverride]?

    /// LEGADO: inversa de `CashFlowOverride.line`. Solo la mira `CashFlowOverrideLineMigration`; tras migrar queda
    /// vacía. Conserva el `.cascade` para que borrar una línea se lleve también un ajuste que aún no migró.
    @Relationship(deleteRule: .cascade, inverse: \CashFlowOverride.line)
    var overrides: [CashFlowOverride]?

    // MARK: - Computed

    /// El ajuste de ese mes que se pinta. Con dos del mismo mes (dos teléfonos que lo apuntaron mientras no
    /// sincronizaban), el mismo que conservará la pasada de arranque (`CashFlowOverrideLineMigration.survivor`):
    /// `.first` daba uno cualquiera, y podía cambiar entre aperturas.
    func monthOverride(for monthKey: String) -> CashFlowOverride? {
        CashFlowOverrideLineMigration.survivor(among: candidateOverrides.filter { $0.monthKey == monthKey })
    }

    /// Un ajuste por mes —el que se pinta—, ordenados por mes.
    var shownMonthOverrides: [CashFlowOverride] {
        let byMonth = Dictionary(grouping: candidateOverrides, by: \.monthKey)
        return byMonth.keys.sorted().compactMap { CashFlowOverrideLineMigration.survivor(among: byMonth[$0] ?? []) }
    }

    /// Los ajustes de esta línea con la misma clave que usa la pasada de arranque (`cashFlowLine ?? line`): los de la
    /// relación nueva y los de legado que aún no migraron. Sin los de legado, uno que llega a mitad de sesión desde una
    /// build vieja de `.dev` con menor `id` no se vería hasta el arranque siguiente, y entonces el importe cambiaría solo.
    private var candidateOverrides: [CashFlowOverride] {
        (monthOverrides ?? []) + (overrides ?? []).filter { $0.cashFlowLine == nil }
    }

    var method: EstimationMethod {
        EstimationMethod(rawValue: estimationMethod) ?? .average6m
    }

    var customMonths: [String] {
        guard let raw = customMonthsRaw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map(String.init)
    }

    // MARK: - Init

    init(
        name: String,
        isIncome: Bool = false,
        sortOrder: Int = 0,
        estimationMethod: EstimationMethod = .average6m,
        manualAmount: Double? = nil,
        category: Category? = nil,
        subcategory: Subcategory? = nil,
        scheduledPayment: ScheduledPayment? = nil
    ) {
        self.name = name
        self.isIncome = isIncome
        self.sortOrder = sortOrder
        self.estimationMethod = estimationMethod.rawValue
        self.manualAmount = manualAmount
        self.category = category
        self.subcategory = subcategory
        self.scheduledPayment = scheduledPayment
    }
}
