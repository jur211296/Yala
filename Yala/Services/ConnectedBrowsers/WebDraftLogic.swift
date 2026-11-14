//
//  WebDraftLogic.swift
//  Yala
//
//  Lo que se apunta en Yala web (lote 1) llega por la cola común de borradores del gateway, con la forma del correo del
//  banco y `source: "web"` (`webapp/src/worker/drafts.ts`). Aquí, lo que lo distingue al pasarlo a la Bandeja:
//
//  - Origen `.automation` y la línea de evidencia «Yala web». Un origen propio pide un caso nuevo en `DraftSourceType`
//    (modelo, cuatro `switch` y cinco tests): queda para su card (decisión P4 del lote 1).
//  - La cuenta y la subcategoría vienen elegidas por su id de la nube, que en el iPhone es el `shortcutID`. Un id que no
//    casa (otra cuenta, una borrada) se ignora y el borrador cae a la búsqueda de siempre: por divisa, o la pide.
//
//  Pura, para los tests: recibe las cuentas y subcategorías ya leídas.
//

import Foundation

nonisolated enum WebDraftLogic {
    static let source = "web"
    /// La línea de evidencia del borrador. Nombre de producto: igual en todos los idiomas.
    static let evidence = "Yala web"

    static func isWeb(source: String?) -> Bool {
        source == Self.source
    }

    static func uuid(_ raw: String?) -> UUID? {
        guard let raw, !raw.isEmpty else { return nil }
        return UUID(uuidString: raw)
    }

    /// ¿Vale la subcategoría que eligió la web? Solo si sigue visible y es del mismo lado que el importe (gasto o
    /// ingreso): un id viejo o manipulado no pone un ingreso en una subcategoría de gasto oculta.
    static func acceptsSubcategory(isVisible: Bool, isIncomeCategory: Bool?, amount: Double) -> Bool {
        guard isVisible, let isIncomeCategory else { return false }
        return isIncomeCategory == (amount > 0)
    }

    /// La cuenta elegida en la web, entre las activas del iPhone.
    static func account<A>(ref: String?, in accounts: [A], id: (A) -> UUID) -> A? {
        guard let wanted = uuid(ref) else { return nil }
        return accounts.first { id($0) == wanted }
    }
}
