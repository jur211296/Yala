//
//  DraftConversionEligibilityLogic.swift
//  Yala
//
//  Pure-logic: decide si un `InboxDraft` personal puede ofrecer la acción
//  "Convertir a gasto compartido" (redirigirlo a un grupo en vez de aprobarlo
//  como `TransactionItem` personal). Extraído para tests sin SwiftData/ModelContext.
//
//  Alcance (decisión owner): solo GASTOS PUNTUALES personales. Se excluyen los
//  sources de grupo (ya tienen su ciclo) y los recurrentes (`scheduledPayment`/
//  `subscription` — para compartir un recurrente existe "pagos planificados de grupo").
//

import Foundation

enum DraftConversionEligibilityLogic {
    /// Sources personales puntuales que pueden convertirse. Allowlist EXPLÍCITO: un
    /// `DraftSourceType` nuevo NO se ofrece hasta decidirlo aquí (más seguro que una
    /// blocklist, que ofrecería fuentes futuras por accidente).
    static let convertibleSources: Set<DraftSourceType> = [
        .voice, .receiptPhoto, .screenshotList, .screenshotSingle,
        .emailAlert, .applePay, .automation, .siri, .manual, .aiConnector
    ]

    /// `true` si el draft debe mostrar el botón "Convertir a gasto compartido".
    /// - Parameters:
    ///   - sourceType: fuente del draft.
    ///   - isExpense: estado editado VIVO del sheet (un ingreso no se comparte).
    ///   - hasAmount: hay un monto válido (> 0) para prellenar el gasto.
    ///   - hasEligibleGroups: existe ≥1 grupo donde el user puede crear gastos.
    ///   - status: solo drafts pendientes (un approved/rejected no se convierte).
    static func canOffer(
        sourceType: DraftSourceType,
        isExpense: Bool,
        hasAmount: Bool,
        hasEligibleGroups: Bool,
        status: DraftStatus
    ) -> Bool {
        guard status == .pending else { return false }
        guard convertibleSources.contains(sourceType) else { return false }
        return isExpense && hasAmount && hasEligibleGroups
    }
}

/// La pantalla de lo leído (foto o voz) tras «Convertir a gasto compartido» (bug de Jürgen del 2026-11-20). Lo que pasó
/// a un grupo cuenta como guardado: sale marcado y, si no queda nada pendiente, la hoja se cierra como al guardar el
/// último. Cancelar el formulario no cambia nada.
enum DraftGroupConversionReviewLogic {
    /// Lo registrado en grupos tras volver del formulario. `converted` es `nil` si se canceló; uno repetido no se suma.
    static func registered<ID: Hashable>(_ current: [ID], adding converted: ID?) -> [ID] {
        guard let converted, !current.contains(converted) else { return current }
        return current + [converted]
    }

    /// Cuántas filas enseña la pantalla: los borradores que siguen y lo que ya pasó a un grupo.
    static func rowCount(drafts: Int, registeredInGroup: Int) -> Int {
        drafts + registeredInGroup
    }

    /// Cuántas de esas filas están guardadas: las aprobadas como personales y las registradas en un grupo.
    static func savedCount(approved: Int, registeredInGroup: Int) -> Int {
        approved + registeredInGroup
    }

    /// Todo lo de la pantalla quedó guardado: hay algo y no queda nada pendiente.
    static func allSaved(pending: Int, drafts: Int, registeredInGroup: Int) -> Bool {
        pending == 0 && rowCount(drafts: drafts, registeredInGroup: registeredInGroup) > 0
    }

    /// Sin borradores ni nada registrado, la pantalla no tiene qué enseñar y se cierra en el acto.
    static func closesEmpty(drafts: Int, registeredInGroup: Int) -> Bool {
        rowCount(drafts: drafts, registeredInGroup: registeredInGroup) == 0
    }
}
