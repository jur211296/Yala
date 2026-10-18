//
//  BudgetRemainingLogic.swift
//  Yala
//
//  Auditoría UX 2.2 · lote 9 (presupuestos). La pregunta con la que se abre Presupuestos es «¿cuánto me queda?»:
//  la fila (L9-1), el detalle (L9-6) y la tarjeta del Panel (L9-10) la contestan con la MISMA cuenta, que vive aquí.
//

import Foundation
import Observation
import SwiftData

enum BudgetRemainingLogic {

    /// Lo que queda: límite menos lo gastado. Negativo = te pasaste por esa cantidad.
    static func remaining(limit: Double, spent: Double) -> Double {
        let value = limit - spent
        // Medio céntimo de holgura: una conversión de divisa deja «1800.004» y saldría «Te pasaste por S/ 0.00».
        return abs(value) < 0.005 ? 0 : value
    }

    /// Te pasaste: lo gastado SUPERA el límite. Gastar justo el límite no es pasarse («Te quedan S/ 0.00»).
    static func isOver(limit: Double, spent: Double) -> Bool {
        remaining(limit: limit, spent: spent) < 0
    }

    /// Lo que se puede gastar al día para no pasarse: lo que queda entre los días que faltan, hoy incluido.
    /// Solo en un período EN CURSO (`daysRemaining > 0`; -1 = cerrado, 0 = aún no empieza) y con algo por gastar.
    static func perDay(remaining: Double, daysRemaining: Int) -> Double? {
        guard daysRemaining > 0, remaining > 0 else { return nil }
        return remaining / Double(daysRemaining)
    }
}

// MARK: - Período explícito (L9-6)

/// El período que enseñan las cifras, con nombre propio («octubre de 2026», «13 – 19 oct», «2026»): el detalle sigue el
/// período elegido en la lista y antes no lo decía.
enum BudgetPeriodTitleLogic {

    static func title(
        periodType: BudgetPeriodType,
        week: Date,
        month: Date,
        year: Int,
        uniqueStart: Date?,
        uniqueEnd: Date?,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        switch periodType {
        case .weekly:
            let end = calendar.date(byAdding: .day, value: 6, to: week) ?? week
            return range(from: week, to: end, template: "dMMM", calendar: calendar, locale: locale)
        case .monthly:
            return monthYear(month, calendar: calendar, locale: locale)
        case .yearly:
            return "\(year)"
        case .unique:
            guard let start = uniqueStart, let end = uniqueEnd else { return "" }
            return range(from: start, to: end, template: "dMMMyyyy", calendar: calendar, locale: locale)
        }
    }

    /// «octubre de 2026» en español, «October 2026» en inglés: la plantilla localizada pone el «de» que el formato
    /// fijo «MMMM yyyy» se comía (L9-8).
    static func monthYear(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: date).capitalizingFirstLetter(locale: locale)
    }

    private static func range(from start: Date, to end: Date, template: String, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

// MARK: - ¿Qué gastos cuenta? (L9-2)

extension Budget {
    /// Sin cuentas, categorías, etiquetas ni naturaleza elegidas, el presupuesto cuenta TODOS los gastos del período.
    /// Lectura de pantalla: no programa la auto-cura del espejo CSV.
    var countsAllExpenses: Bool {
        (resolvedAccountIDs() ?? []).isEmpty
            && (resolvedSubcategoryIDs() ?? []).isEmpty
            && (resolvedTagIDs() ?? []).isEmpty
            && (natures ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Mostrar en el widget (L9-12)

enum BudgetWidgetFavoriteLogic {

    /// Marca o desmarca un presupuesto para el widget con el mismo orden que la pantalla de favoritos: entra al final y,
    /// al salir, los demás se reordenan sin huecos. No guarda: lo hace quien llama.
    static func setShownInWidget(_ shown: Bool, for budget: Budget, among all: [Budget]) {
        guard budget.isFavorite != shown else { return }
        if shown {
            let maxOrder = all.filter { $0.isFavorite && $0.persistentModelID != budget.persistentModelID }
                .map(\.favoriteOrder).max() ?? -1
            budget.isFavorite = true
            budget.favoriteOrder = maxOrder + 1
        } else {
            budget.isFavorite = false
            budget.favoriteOrder = 0
            let remaining = all.filter { $0.isFavorite && $0.persistentModelID != budget.persistentModelID }
                .sorted { $0.favoriteOrder < $1.favoriteOrder }
            for (index, favorite) in remaining.enumerated() where favorite.favoriteOrder != index {
                favorite.favoriteOrder = index
            }
        }
    }
}

// MARK: - Tocar una alerta (L9-5)

/// El presupuesto que una alerta pide abrir. La notificación lleva `budgets/<uuid>`: el destino del router sigue siendo
/// `.budgets` —que ya sabe esperar al arranque en frío— y el id espera aquí, en el proceso, hasta que la VENTANA que
/// drena ese `.navigate(.budgets)` lo pasa a su `SceneNavigation.pendingBudgetID` (`ContentView.handleMainTabIntent`).
/// Así se abre en esa ventana y no en otra que también tenga Presupuestos montado.
@MainActor
@Observable
final class BudgetAlertRouting {
    static let shared = BudgetAlertRouting()

    private(set) var pendingBudgetID: UUID?
    private var requestedAt: Date?

    /// Si el `.navigate(.budgets)` se descarta (la shell de solo grupos, un buffer caducado), el id no puede quedarse
    /// esperando a que alguien vuelva a Presupuestos horas después y abra un detalle sin venir a cuento.
    static let maxAge: TimeInterval = 10 * 60

    nonisolated static let deepLinkPrefix = "budgets/"

    nonisolated static func deepLink(for budgetID: UUID) -> String {
        deepLinkPrefix + budgetID.uuidString
    }

    /// El id de `budgets/<uuid>`, o `nil` si el enlace no es de un presupuesto concreto.
    nonisolated static func budgetID(fromDeepLink link: String) -> UUID? {
        guard link.hasPrefix(deepLinkPrefix) else { return nil }
        return UUID(uuidString: String(link.dropFirst(deepLinkPrefix.count)))
    }

    func request(_ budgetID: UUID, now: Date = .now) {
        pendingBudgetID = budgetID
        requestedAt = now
    }

    /// Lo devuelve una sola vez, y nada si lleva más de `maxAge` esperando.
    func consume(now: Date = .now) -> UUID? {
        defer {
            pendingBudgetID = nil
            requestedAt = nil
        }
        guard let id = pendingBudgetID, let requestedAt, now.timeIntervalSince(requestedAt) <= Self.maxAge else {
            return nil
        }
        return id
    }
}
