//
//  PersonalToGroupConversionLogic.swift
//  Yala
//
//  «Convertir a gasto compartido» desde Editar de un registro (2.3): qué registros se pueden pasar a un grupo.
//
//  Pasar un registro no lo copia: el registro pasa a ser la pata real del gasto de grupo que se crea, como cuando se
//  enlaza un movimiento desde la Bandeja («¿Ya lo apuntaste?», L13-15, `GroupExpenseLinkCandidateLogic`). Por eso los
//  criterios son los de ese enlace, sin la coincidencia de día e importe (aquí el gasto nace del registro), más los que
//  impiden que el puente reescriba lo que salió de la cuenta:
//
//  - solo un GASTO (decisión de Jürgen del 2026-11-07: ingresos y transferencias quedan fuera);
//  - con finanzas personales: en una sesión solo-grupos el puente borra toda pata real;
//  - en una cuenta real, no archivada, de la misma moneda que el registro: el puente conserva la pata solo si su moneda
//    es la del gasto, y el gasto toma la del registro;
//  - sin «Mi parte»: su importe es solo tu parte y el puente lo reescribiría al total del gasto.
//

import Foundation

nonisolated enum PersonalToGroupConversionLogic {

    /// Lo que hace falta saber del registro, sin `@Model` (testeable sin contexto).
    struct Record: Equatable {
        let amount: Double
        /// `Category.isIncome` de su categoría; `nil` sin categoría (decide el signo, como en Registros).
        let categoryIsIncome: Bool?
        let hasGroupPointer: Bool
        let isDerivedGroupLeg: Bool
        let isTransfer: Bool
        let isBalanceAdjustment: Bool
        let hasAccount: Bool
        let accountIsSystem: Bool
        let accountIsArchived: Bool
        let accountCurrencyMatches: Bool
        /// Usó «Mi parte» (`splitTotalAmount`/`splitMyValue` sin puntero de grupo).
        let usesPersonalSplit: Bool
        let isGroupPaymentRecord: Bool
        let isConservedFromDetach: Bool
    }

    enum Verdict: Equatable {
        case eligible
        /// No se ofrece y no hace falta decir por qué: no es un gasto personal (ingreso, transferencia, de un grupo…).
        case notOffered
        /// Se dice por qué no: guardó solo tu parte con «Mi parte».
        case blockedByPersonalSplit
    }

    static func verdict(_ record: Record, hasPrivateSession: Bool) -> Verdict {
        guard hasPrivateSession,
              record.amount < 0,
              !TransactionClassificationLogic.isIncome(
                categoryIsIncome: record.categoryIsIncome, signedAmount: record.amount),
              !record.hasGroupPointer,
              !record.isDerivedGroupLeg,
              !record.isTransfer,
              !record.isBalanceAdjustment,
              record.hasAccount,
              !record.accountIsSystem,
              !record.accountIsArchived,
              record.accountCurrencyMatches,
              !record.isGroupPaymentRecord,
              !record.isConservedFromDetach
        else { return .notOffered }
        return record.usesPersonalSplit ? .blockedByPersonalSplit : .eligible
    }

    /// El nombre del gasto en el grupo: la nota del registro y, sin nota, su subcategoría (el formulario de grupo exige
    /// nombre). Solo propone: se edita en la revisión y no cambia la nota del registro.
    static func expenseDescription(note: String?, subcategoryName: String?) -> String {
        let trimmed = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return subcategoryName ?? ""
    }
}
