//
//  InboxDraftGroupChipLogic.swift
//  Yala
//
//  El chip de grupo del editor de la Bandeja (decisión de Jürgen del 22-nov-2026): reemplaza al enlace «Convertir a gasto
//  compartido». Se elige el grupo en el chip y «Guardar» sigue el flujo de convertir de siempre, ya con ese grupo.
//  «Guardar y hacer recurrente» pasa al menú «…». Paso 0 del encargo, D1-D6.
//

import Foundation

enum InboxDraftGroupChipLogic {

    /// El chip sale donde salía «Convertir a gasto compartido» (`DraftConversionEligibilityLogic.canOffer`) sin esperar al
    /// monto —un chip que aparece con el primer dígito movería la fila—, y siempre que ya haya un grupo elegido, para
    /// poder quitarlo.
    static func showsChip(
        sourceType: DraftSourceType,
        isExpense: Bool,
        hasEligibleGroups: Bool,
        status: DraftStatus,
        isPayingNow: Bool,
        hasChosenGroup: Bool
    ) -> Bool {
        if hasChosenGroup { return true }
        guard !isPayingNow else { return false }
        return DraftConversionEligibilityLogic.canOffer(
            sourceType: sourceType,
            isExpense: isExpense,
            hasAmount: true,
            hasEligibleGroups: hasEligibleGroups,
            status: status
        )
    }

    /// Con grupo, «Guardar» solo pide el monto: la cuenta y la categoría se eligen en el gasto de grupo, como al convertir.
    static func canSave(hasChosenGroup: Bool, hasAmount: Bool, isReadyToApprove: Bool) -> Bool {
        hasChosenGroup ? hasAmount : isReadyToApprove
    }

    /// «Guardar y hacer recurrente» en el menú «…»: donde se ofrecía abajo, y no con un grupo elegido (un gasto de grupo
    /// no se guarda como registro personal recurrente).
    static func offersRecurringInMenu(offersRecurring: Bool, hasChosenGroup: Bool) -> Bool {
        offersRecurring && !hasChosenGroup
    }

    /// El grupo elegido se suelta si deja de tener sentido: el registro pasó a ingreso o el grupo ya no admite gastos.
    static func keepsChosenGroup(_ chosen: UUID?, isExpense: Bool, eligibleGroupIDs: Set<UUID>) -> Bool {
        guard let chosen else { return false }
        return isExpense && eligibleGroupIDs.contains(chosen)
    }
}
