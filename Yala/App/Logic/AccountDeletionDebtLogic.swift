//
//  AccountDeletionDebtLogic.swift
//  Yala
//
//  Lógica PURA del aviso de "Eliminar mi cuenta" (D5, §3.3.4 del estudio MODO-NUBE-GESTION-DATOS-UX):
//  detección de saldos pendientes en grupos + composición de las líneas del diálogo de confirmación.
//  Todo DARK hoy ([FLAG] — la fila de eliminar-cuenta solo existe con sesión backend viva).
//
//  Decisión owner D5 (2026-07-19): el aviso INFORMA, JAMÁS bloquea (línea roja GDPR del 2026-07-14). El
//  usuario que elimina su cuenta con deudas vivas debe SABER que los co-members quedarán cobrándole a
//  «Usuario eliminado» — pero el borrado nunca se impide. No se añade a "Cerrar sesión" (ahí la membership
//  sigue viva, nada se pierde — ensuciaría el modelo sesión≠datos).
//
//  Ambos enums son `nonisolated` y sin dependencias de UI/SwiftData: la detección recibe los saldos YA
//  calculados (el fetch read-only vive en `SplitSyncManager.accountDeletionGroupsSummary`, invariante de
//  quiescencia (b) intacto — cero saves) y la composición recibe flags. Testeables por tabla.
//

import Foundation

/// Resumen read-only de grupos para el aviso de eliminar-cuenta. Lo produce
/// `SplitSyncManager.accountDeletionGroupsSummary()` (fetches + cálculo puro, cero saves) y lo consume la
/// UI + la lógica pura de este archivo.
struct AccountDeletionGroupsSummary: Equatable {
    /// Nº de grupos con un saldo pendiente para el usuario actual.
    let outstandingDebtGroupCount: Int
    /// ¿Algún grupo con zona CloudKit viva (donde el nombre persiste tras el GDPR delete)?
    let hasLegacyCloudKitFootprint: Bool
    /// ¿Tiene el usuario algún grupo activo (`!isHiddenForAll`)? Gate del batch "salir de todos mis grupos"
    /// (D10): sin grupos, no se ofrece. Default `false` (back-compat con call-sites existentes).
    let hasGroups: Bool

    init(outstandingDebtGroupCount: Int, hasLegacyCloudKitFootprint: Bool, hasGroups: Bool = false) {
        self.outstandingDebtGroupCount = outstandingDebtGroupCount
        self.hasLegacyCloudKitFootprint = hasLegacyCloudKitFootprint
        self.hasGroups = hasGroups
    }

    static let empty = AccountDeletionGroupsSummary(
        outstandingDebtGroupCount: 0, hasLegacyCloudKitFootprint: false, hasGroups: false)

    var hasOutstandingDebt: Bool { outstandingDebtGroupCount > 0 }
}

/// Detección agregada de saldos pendientes del usuario actual a lo largo de todos sus grupos.
nonisolated enum AccountDeletionDebtLogic {

    /// Mismo umbral que `GroupBalanceService`/`GroupSettingsView` (molde `GroupSettingsView.swift:687-701`).
    static let epsilon: Double = 0.01

    /// Cuenta cuántos grupos tienen al menos un saldo neto pendiente (`|net| > epsilon`) para el usuario
    /// actual. `perGroupUserNetBalances` es, POR grupo, los saldos netos del usuario (uno por moneda — un
    /// grupo cross-currency puede aportar varios). Un grupo donde el usuario no participa o su balance es
    /// cero NO cuenta. Read-only por construcción (recibe datos ya calculados).
    static func groupsWithOutstandingBalance(perGroupUserNetBalances: [[Double]]) -> Int {
        perGroupUserNetBalances.filter { nets in
            nets.contains { abs($0) > epsilon }
        }.count
    }

    /// Conveniencia: ¿algún grupo con saldo pendiente del usuario?
    static func hasOutstandingBalance(perGroupUserNetBalances: [[Double]]) -> Bool {
        groupsWithOutstandingBalance(perGroupUserNetBalances: perGroupUserNetBalances) > 0
    }
}

/// Composición de las líneas del mensaje del PRIMER diálogo de eliminar-cuenta (§3.3.4.1). El orden es
/// FIJO; la vista mapea cada `Line` a su string localizado (la línea `base` elige la variante por modo).
/// Vive como lógica pura para testear la DECISIÓN de qué líneas aparecen (no el texto localizado).
nonisolated enum AccountDeletionMessageLogic {

    enum Line: Equatable {
        /// Copy base por modo (`.cloud` vs solo-grupos) — la vista elige la key concreta.
        case base
        /// Aviso de saldos pendientes (D5) — SOLO si hay deuda. Antes del desvío cruzado.
        case debtWarning
        /// Desvío cruzado hacia "Vaciar mis datos" (ya añadido en Fase 1, `5db1e0e5`). Siempre.
        case crossRefer
        /// La copia iCloud congelada pre-migración sobrevive → semántica reinstalación. SOLO en `.cloud`
        /// (sin migración no hay copia congelada; un 5b solo-grupos tiene su personal aún en `.icloud`).
        case frozenICloud
        /// Huella legacy: en grupos con zona CloudKit viva el nombre puede seguir visible (GDPR-percepción:
        /// `groups_forget_user` anonimiza SOLO el backend, no las zonas CloudKit). SOLO si el device tiene
        /// esa huella — un born-backend sin pasado CloudKit no la ve (evita un caveat falso).
        case legacyFootprint
    }

    /// Líneas EN ORDEN para el diálogo de confirmación.
    static func lines(
        isCloud: Bool,
        hasOutstandingDebt: Bool,
        hasLegacyCloudKitFootprint: Bool
    ) -> [Line] {
        var lines: [Line] = [.base]
        if hasOutstandingDebt { lines.append(.debtWarning) }
        lines.append(.crossRefer)
        if isCloud { lines.append(.frozenICloud) }
        if hasLegacyCloudKitFootprint { lines.append(.legacyFootprint) }
        return lines
    }
}
