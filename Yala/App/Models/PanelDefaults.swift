//
//  PanelDefaults.swift
//  Yala
//
//  Fuente ÚNICA de verdad de los predeterminados del Panel.
//
//  Antes de este fichero, "lo que ve un usuario nuevo" estaba repartido en cinco
//  sitios: el seed de `AppPreferences`, la tabla de `WidgetConfig.defaultConfigs()`,
//  el auto-sanado de `PanelViewModel.buildOrderedRawWidgets` ("lista vacía ⇒ enseña
//  todo"), el orden de declaración de `PanelSectionKind` y dos `.medium` a pelo. Eso
//  ya había producido dos incoherencias vivas: `trend` sembrado en `.small` mientras
//  los fallbacks devolvían `.medium` —que NO es un tamaño legal para `trend`— y unos
//  `isVisible` que nadie lee.
//
//  Aquí no hay estado ni persistencia: es una tabla pura, y por eso se puede probar
//  sola. La consumen el seed (escritura), los accessors de `AppPreferences` (lectura,
//  mientras la siembra no ha corrido) y los «Restablecer» de la UI.
//

import Foundation

enum PanelDefaults {

    // MARK: - Widgets por sección

    /// Predeterminados de una sección temática: el orden completo y cuáles de esos
    /// widgets nacen apagados.
    ///
    /// Invariante: `hidden` es un subconjunto de `order` y respeta su mismo orden.
    /// No es cosmético — el seed persiste estas listas y las compara con `!=` en el
    /// `didSet`, así que un orden inestable (p. ej. mapear desde un `Set`) produciría
    /// escrituras redundantes y empujes repetidos a iCloud KV.
    struct SectionDefaults: Equatable {
        var order: [WidgetType]
        var hidden: [WidgetType]

        var visible: [WidgetType] {
            let hiddenSet = Set(hidden)
            return order.filter { !hiddenSet.contains($0) }
        }
    }

    /// Predeterminados de las secciones que tienen almacén por widget.
    ///
    /// Devuelve `nil` para las que no lo tienen (`accounts` y `health` no tienen
    /// ningún `WidgetType`; `latestRecords` y `tools` tienen uno solo y no se puede
    /// apagar por separado). Esas cuatro se gobiernan únicamente con
    /// `hiddenSections`, y sus setters en `AppPreferences` son no-op.
    static func section(_ kind: PanelSectionKind) -> SectionDefaults? {
        switch kind {
        case .tendencias:
            // Solo la gráfica de Tendencias. Promedio diario y Flujo de efectivo
            // nacen apagados y se recuperan desde el engranaje de la sección.
            return SectionDefaults(
                order: [.trend, .weekdayBar, .cashFlow],
                hidden: [.weekdayBar, .cashFlow]
            )

        case .distribucion:
            // La sección entera nace oculta (ver `hiddenSections`), pero su reparto
            // interno se conserva: quien la reactive encuentra algo que mirar, y
            // `isSectionEffectivelyEmpty` sigue siendo falso, así que el botón
            // «Restablecer widgets de Distribución» no llega a aparecer — que es lo
            // que evita la contradicción de restaurar widgets en una sección oculta.
            return SectionDefaults(
                order: [.categoriesPie, .subcategoriesPie, .expensesByNeed,
                        .topSpending, .topSubcategories, .tagsPie],
                hidden: [.topSpending, .topSubcategories, .tagsPie]
            )

        case .planificacion:
            // Pagos planificados + Presupuestos, ambos `.small` ⇒ emparejados en una
            // fila por `WidgetConfigManager.makeLayoutRows`.
            return SectionDefaults(
                order: [.scheduledPayments, .budgets],
                hidden: []
            )

        case .accounts, .health, .latestRecords, .tools:
            return nil
        }
    }

    // MARK: - Secciones

    /// Secciones que nacen ocultas. Se persiste en `panelSectionsHidden`, que es una
    /// lista NEGATIVA (guarda las ocultas, no las visibles).
    ///
    /// Es un array y no un `Set` por el mismo motivo que `SectionDefaults.hidden`:
    /// el orden tiene que ser estable entre arranques.
    static let hiddenSections: [PanelSectionKind] = [.health, .distribucion, .tools]

    /// Orden global de las secciones reordenables. Vacío a propósito: el orden de
    /// declaración de `PanelSectionKind` ya entrega Tendencias → Planificación →
    /// Últimos registros, así que sembrarlo sería duplicar la misma decisión en dos
    /// sitios que luego divergen.
    static let sectionsOrder: [PanelSectionKind] = []

    static var hiddenSectionRawValues: [String] {
        hiddenSections.map(\.rawValue)
    }

    // MARK: - Tamaños

    /// Tamaño inicial de cada widget.
    ///
    /// Es un `switch` y no un diccionario para que el compilador obligue a decidir
    /// el tamaño de cualquier `WidgetType` nuevo, en vez de que caiga en un fallback
    /// silencioso.
    ///
    /// Lo devuelto pasa por `size(for:)`, que lo sanea contra `supportedSizes`.
    private static func preferredSize(for type: WidgetType) -> WidgetSize {
        switch type {
        case .trend:              return .large   // la gráfica grande del arranque
        case .cashFlow:           return .medium
        case .categoriesPie:      return .small
        case .subcategoriesPie:   return .small
        case .topSpending:        return .medium
        case .topSubcategories:   return .medium
        case .expensesByNeed:     return .medium
        case .latestRecords:      return .medium
        case .budgets:            return .small
        case .scheduledPayments:  return .small
        case .exchangeRate:       return .medium
        case .weekdayBar:         return .small
        case .tagsPie:            return .small
        }
    }

    /// Tamaño inicial saneado: si el preferido no está entre los soportados por ese
    /// widget, cae al primero soportado en vez de propagar un valor imposible.
    ///
    /// Esto existe porque el código anterior sí propagaba uno: los dos fallbacks
    /// `.medium` de `PanelViewModel` se aplicaban también a `trend`, cuyos tamaños
    /// soportados son `[.small, .large]`.
    static func size(for type: WidgetType) -> WidgetSize {
        let preferred = preferredSize(for: type)
        guard type.supportedSizes.contains(preferred) else {
            return type.supportedSizes.first ?? .medium
        }
        return preferred
    }
}
