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
        .emailAlert, .applePay, .automation, .siri, .manual
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
