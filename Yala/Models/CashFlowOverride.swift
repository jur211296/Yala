//
//  CashFlowOverride.swift
//  Yala
//
//  SwiftData model for month-specific overrides in a cash flow line.
//

import Foundation
import SwiftData

// MARK: - CashFlowOverride

@Model
final class CashFlowOverride {
    // I12: identidad de sync del Modo Nube (`sync_id_source = CashFlowOverride.id`).
    // `.preserveValueOnDeletion` para que el history tombstone conserve el `id` (metadata de History;
    // sin deploy .ckdb).
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    var monthKey: String = ""        // "2026-04"
    var amount: Double = 0
    var note: String = ""

    /// La línea del flujo de caja a la que pertenece el ajuste. Campo de iCloud `CD_cashFlowLine` (STRING).
    ///
    /// **Sustituye a `line`**, cuyo campo `CD_line` es REFERENCE en Production y la app escribe STRING: iCloud
    /// rechazaba todo ajuste que lo trajera, y con él se atascaba el resto de la subida (ticket
    /// `personal-cloudkit-cashflow-override-line-declared-as-reference`). Un tipo no se cambia en Production, así
    /// que la relación pasó a esta propiedad con otro nombre, y por tanto a un campo nuevo.
    @Relationship(deleteRule: .nullify)
    var cashFlowLine: CashFlowLine?

    /// LEGADO: solo para leer los ajustes de antes. **La app no lo escribe nunca** salvo para vaciarlo:
    /// `CashFlowOverrideLineMigration` pasa su valor a `cashFlowLine` y lo deja en `nil` en el mismo guardado,
    /// porque un registro con `CD_line` puesto lo rechaza Production. No se borra del modelo: el campo sigue en
    /// Production para siempre y es lo que permite leer el valor viejo en cada dispositivo.
    @Relationship(deleteRule: .nullify)
    var line: CashFlowLine?

    init(monthKey: String, amount: Double, note: String = "") {
        self.monthKey = monthKey
        self.amount = amount
        self.note = note
    }
}
