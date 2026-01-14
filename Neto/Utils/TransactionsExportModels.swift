//
//  TransactionsExportModels.swift
//  Neto
//
//  Modelos y helpers para filtros y columnas de exportación de transacciones.
//  FIN-48: Modelo de filtros y columnas para exportación.
//
//  IMPORTANTE:
//  - Estos tipos deben ser reutilizados por el servicio de exportación (FIN-49)
//    y por el wizard de UI (FIN-50, FIN-51, FIN-52).
//  - No implementar aquí lógica de acceso a SwiftData ni generación de CSV.
//

import Foundation
import SwiftData

// MARK: - Filtro por monto

/// Representa la condición de filtro por monto utilizada en los filtros de exportación.
/// Se diseña como enum con valores asociados para evitar estados incoherentes.
///
/// Casos:
/// - any:     no se filtra por monto.
/// - greater: solo montos estrictamente mayores al valor indicado.
/// - less:    solo montos estrictamente menores al valor indicado.
/// - between: solo montos dentro del rango [min, max] (inclusive).
enum AmountFilterCondition: Equatable {
    case any
    case greaterThan(Decimal)
    case lessThan(Decimal)
    case between(min: Decimal, max: Decimal)

    /// Helper para validar si un monto concreto cumple la condición.
    /// Esto será útil dentro de `TransactionsExportService` (FIN-49).
    /// - Parameter amount: monto a evaluar.
    /// - Returns: `true` si el monto cumple la condición, `false` en caso contrario.
    func matches(_ amount: Decimal) -> Bool {
        switch self {
        case .any:
            return true
        case .greaterThan(let value):
            return amount > value
        case .lessThan(let value):
            return amount < value
        case .between(let min, let max):
            // Por diseño, asumimos que min <= max se valida desde la UI.
            return amount >= min && amount <= max
        }
    }

    /// Indica si la condición aplica algún filtro real (distinto de "cualquiera").
    var isActive: Bool {
        switch self {
        case .any:
            return false
        case .greaterThan, .lessThan, .between:
            return true
        }
    }

    /// Display text for filter chip (e.g., ">100", "<50", "100-500")
    var displayText: String {
        switch self {
        case .any:
            return ""
        case .greaterThan(let value):
            return ">\(value)"
        case .lessThan(let value):
            return "<\(value)"
        case .between(let min, let max):
            return "\(min)-\(max)"
        }
    }
}

// MARK: - Periodo de exportación

/// Representa el periodo seleccionado para filtrar transacciones en la exportación.
///
/// Casos:
/// - thisYear:       Año calendario actual.
/// - thisMonth:      Mes calendario actual.
/// - thisWeek:       Semana actual (según calendario del usuario).
/// - today:          Solo el día de hoy.
/// - thisYear:       Año en curso.
/// - thisMonth:      Mes en curso.
/// - thisWeek:       Semana en curso (inicia lunes).
/// - last7Days:      Últimos 7 días incluyendo hoy.
/// - last30Days:     Últimos 30 días incluyendo hoy.
/// - last90Days:     Últimos 90 días incluyendo hoy.
/// - last180Days:    Últimos 180 días incluyendo hoy.
/// - custom:         Periodo personalizado controlado por fechas `from` / `to` en `ExportFilters`.
enum ExportPeriod: String, CaseIterable, Identifiable {
    // Periodo actual (Current Period)
    case today
    case thisWeek
    case thisMonth
    case thisYear

    // Periodo móvil (Rolling Period)
    case last7Days
    case last30Days
    case last90Days
    case last180Days

    // Rango personalizado
    case custom

    var id: String { rawValue }

    /// Category this period belongs to
    var category: ExportPeriodCategory {
        switch self {
        case .today, .thisWeek, .thisMonth, .thisYear:
            return .current
        case .last7Days, .last30Days, .last90Days, .last180Days:
            return .rolling
        case .custom:
            return .custom
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .today: return "Hoy"
        case .thisWeek: return "Esta semana"
        case .thisMonth: return "Este mes"
        case .thisYear: return "Este año"
        case .last7Days: return "7 días"
        case .last30Days: return "30 días"
        case .last90Days: return "90 días"
        case .last180Days: return "180 días"
        case .custom: return "Personalizado"
        }
    }

    /// Devuelve un `DateInterval` estándar para los periodos no personalizados
    /// usando la fecha "hoy" como referencia.
    ///
    /// Para `.custom` devuelve siempre `nil`, ya que se resuelve con `from`/`to`
    /// dentro de `ExportFilters`.
    /// - Parameters:
    ///   - today:    Fecha de referencia (por defecto `Date()`).
    ///   - calendar: Calendario a utilizar (por defecto `.current`).
    /// - Returns: Intervalo de fechas, o `nil` si el periodo es `.custom`.
    func standardDateInterval(
        relativeTo today: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval? {
        let startOfToday = calendar.startOfDay(for: today)

        switch self {
        case .today:
            return calendar.dateInterval(of: .day, for: today)

        case .thisYear:
            guard let yearInterval = calendar.dateInterval(of: .year, for: today) else {
                return nil
            }
            return yearInterval

        case .thisMonth:
            guard let monthInterval = calendar.dateInterval(of: .month, for: today) else {
                return nil
            }
            return monthInterval

        case .thisWeek:
            // Usamos weekOfYear para respetar configuración regional del usuario.
            // PERO forzamos el inicio de semana en Lunes (2) según requerimiento.
            var mondayCalendar = calendar
            mondayCalendar.firstWeekday = 2  // 1 = Domingo, 2 = Lunes

            guard let weekInterval = mondayCalendar.dateInterval(of: .weekOfYear, for: today) else {
                return nil
            }
            return weekInterval

        case .last7Days:
            // Últimos 7 días incluyendo hoy: [hoy-6, hoy] a nivel de días completos.
            let end =
                calendar.date(
                    byAdding: DateComponents(day: 1, second: -1),
                    to: startOfToday
                ) ?? today
            let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: end)

        case .last30Days:
            let end =
                calendar.date(
                    byAdding: DateComponents(day: 1, second: -1),
                    to: startOfToday
                ) ?? today
            let start = calendar.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: end)

        case .last90Days:
            let end =
                calendar.date(
                    byAdding: DateComponents(day: 1, second: -1),
                    to: startOfToday
                ) ?? today
            let start = calendar.date(byAdding: .day, value: -89, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: end)

        case .last180Days:
            let end =
                calendar.date(
                    byAdding: DateComponents(day: 1, second: -1),
                    to: startOfToday
                ) ?? today
            let start = calendar.date(byAdding: .day, value: -179, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: end)

        case .custom:
            return nil
        }
    }

    /// Periodo por defecto para el flujo de exportación.
    /// Se alinea con lo descrito en FIN-48: un estado razonable es "Últimos 30 días".
    static var defaultPeriod: ExportPeriod {
        .last30Days
    }

    /// All periods in the current category
    static var currentPeriods: [ExportPeriod] {
        [.today, .thisWeek, .thisMonth, .thisYear]
    }

    static var rollingPeriods: [ExportPeriod] {
        [.last7Days, .last30Days, .last90Days, .last180Days]
    }
}

/// Category for export period options
enum ExportPeriodCategory: String, CaseIterable, Identifiable {
    case current
    case rolling
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .current: return "Periodo actual"
        case .rolling: return "Periodo móvil"
        case .custom: return "Rango personalizado"
        }
    }
}

// MARK: - Columnas de exportación

/// Columnas disponibles para exportar en el CSV.
/// El orden de este enum se utiliza como orden base del encabezado.
enum ExportColumn: String, CaseIterable, Hashable, Identifiable {
    case date
    case amount
    case currency
    case account
    case category
    case subcategory
    case tags
    case note

    var id: String { rawValue }

    /// Etiqueta de encabezado que se usará en el CSV.
    /// Debe ser compatible con la plantilla de importación en los campos comunes.
    var csvHeaderTitle: String {
        switch self {
        case .date: return "date"
        case .amount: return "amount"
        case .currency: return "currency"
        case .account: return "account"
        case .category: return "category"
        case .subcategory: return "subcategory"
        case .tags: return "tags"
        case .note: return "note"
        }
    }

    /// Nombre legible para la UI del wizard (FIN-51).
    var displayName: String {
        switch self {
        case .date: return "Fecha"
        case .amount: return "Monto"
        case .currency: return "Moneda"
        case .account: return "Cuenta"
        case .category: return "Categoría"
        case .subcategory: return "Subcategoría"
        case .tags: return "Etiquetas"
        case .note: return "Nota"
        }
    }

    /// Descripción opcional de la columna para mostrar en la UI.
    var description: String {
        switch self {
        case .date:
            return "Fecha en formato yyyy-MM-dd."
        case .amount:
            return "Monto de la transacción con 2 decimales."
        case .currency:
            return "Código de moneda (PEN, USD, EUR)."
        case .account:
            return "Nombre de la cuenta asociada."
        case .category:
            return "Categoría principal de la transacción."
        case .subcategory:
            return "Subcategoría específica."
        case .tags:
            return "Etiquetas asociadas, separadas por ';'."
        case .note:
            return "Nota libre asociada a la transacción."
        }
    }
}

/// Estructura que representa el conjunto de columnas activas para la exportación.
/// Internamente usa un `Set<ExportColumn>` para facilitar toggles desde la UI.
struct ExportColumns: Equatable {

    /// Conjunto de columnas activas.
    private(set) var activeColumns: Set<ExportColumn>

    /// Orden base para construir el encabezado del CSV.
    /// Se alinea con el orden de las columnas en el servicio de exportación (FIN-49).
    static let defaultOrder: [ExportColumn] = ExportColumn.allCases

    /// Estado por defecto: todas las columnas activas.
    static var `default`: ExportColumns {
        ExportColumns(activeColumns: Set(ExportColumn.allCases))
    }

    /// Inicializador principal.
    /// - Parameter activeColumns: conjunto de columnas activas.
    init(activeColumns: Set<ExportColumn>) {
        self.activeColumns = activeColumns
    }

    /// Lista de columnas activas ordenadas según `defaultOrder`.
    var orderedActiveColumns: [ExportColumn] {
        ExportColumns.defaultOrder.filter { activeColumns.contains($0) }
    }

    /// Lista de títulos de encabezado para las columnas activas,
    /// en el orden adecuado para el CSV.
    var csvHeaderTitles: [String] {
        orderedActiveColumns.map { $0.csvHeaderTitle }
    }

    /// Indica si al menos una columna sigue activa.
    var hasAtLeastOneActiveColumn: Bool {
        !activeColumns.isEmpty
    }

    /// Activa una columna concreta.
    mutating func activate(_ column: ExportColumn) {
        activeColumns.insert(column)
    }

    /// Desactiva una columna concreta.
    mutating func deactivate(_ column: ExportColumn) {
        activeColumns.remove(column)
    }

    /// Cambia el estado (on/off) de una columna.
    mutating func set(_ column: ExportColumn, isActive: Bool) {
        if isActive {
            activate(column)
        } else {
            deactivate(column)
        }
    }
}

// MARK: - Filtros de exportación

/// Modelo principal que representa todos los filtros aplicables a la exportación
/// de transacciones. Este tipo será construido por la UI del wizard (FIN-50)
/// y consumido por el servicio central `TransactionsExportService` (FIN-49).
struct ExportFilters: Equatable {

    // MARK: Cuentas / categorías / etiquetas / monedas

    /// Cuentas seleccionadas. Si el array está vacío, se entiende "todas las cuentas".
    ///
    /// Se utilizan referencias directas a `Account` para simplificar la integración
    /// con SwiftData. Otra opción en el futuro sería almacenar IDs persistentes.
    var selectedAccounts: [Account]

    /// Categorías seleccionadas. No es obligatorio que se usen siempre,
    /// porque el filtro principal suele operar a nivel de subcategorías.
    var selectedCategories: [Category]

    /// Subcategorías seleccionadas. Si está vacío, se asume "todas las subcategorías".
    var selectedSubcategories: [Subcategory]

    /// Nombres de etiquetas seleccionadas. Cuando exista el modelo de etiquetas,
    /// se podrá mapear a entidades concretas.
    var selectedTagNames: [String]

    /// Monedas seleccionadas (PEN, USD, EUR). Si está vacío, se asume "todas".
    var selectedCurrencies: [CurrencyCode]

    // MARK: Monto

    /// Condición de filtro por monto.
    var amountCondition: AmountFilterCondition

    // MARK: Periodo y fechas

    /// Fecha de inicio del periodo de exportación.
    var dateFrom: Date

    /// Fecha de fin del periodo de exportación.
    var dateTo: Date

    // MARK: Nota

    /// Texto a buscar dentro de la nota de la transacción.
    /// Si es `nil` o cadena vacía, no se filtra por nota.
    var noteContains: String?

    // MARK: Estado por defecto

    /// Estado por defecto recomendado para iniciar el flujo:
    /// - Sin filtros específicos de cuenta/categoría/subcategoría/etiquetas/monedas.
    /// - Sin filtro de monto.
    /// - Periodo "Últimos 30 días".
    /// - Sin filtro de nota.
    static var `default`: ExportFilters {
        let defaultInterval = DetailPeriod.last30Days.dateInterval()
        return ExportFilters(
            selectedAccounts: [],
            selectedCategories: [],
            selectedSubcategories: [],
            selectedTagNames: [],
            selectedCurrencies: [],  // vacío = todas las monedas
            amountCondition: .any,
            dateFrom: defaultInterval.start,
            dateTo: defaultInterval.end,
            noteContains: nil
        )
    }

    // MARK: Helpers de periodo

    /// Devuelve el `DateInterval` efectivo a aplicar al filtrar transacciones.
    func effectiveDateInterval() -> DateInterval {
        return DateInterval(start: dateFrom, end: dateTo)
    }
}
