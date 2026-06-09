//
//  GroupDraftFinalizationLogic.swift
//  Yala
//
//  Pure-logic del contrato de finalización de drafts de grupo (Caso A del bridge).
//  Co-localiza las dos mitades del contrato:
//    - bridge-side: qué `needsUserInput` escribe el bridge en un draft Caso A, y si debe
//      (re)crear un draft de subcategoría para una TX real sin clasificar.
//    - inbox-side: qué sheet de finalización mostrar según ese `needsUserInput`.
//  Testeable sin SwiftData/ModelContext (R8).
//
//  Contexto: la subcategoría de un gasto se hereda del grupo vía `matchSubcategory`. Si el
//  nombre no coincide, el Caso B ya pide clasificar (draft TX-puntero); el Caso A no lo hacía
//  (quedaba sin clasificar). Enfoque B cierra la asimetría — si faltan cuenta + subcategoría,
//  se piden juntas en un solo sheet.
//

import Foundation

enum GroupDraftFinalizationLogic {

    // MARK: - Bridge-side

    /// `needsUserInput` para un draft Caso A pendiente de cuenta. Siempre pide cuenta; pide
    /// subcategoría además cuando el auto-match de subcategoría falló (Enfoque B).
    static func caseADraftNeedsUserInput(needsSubcategory: Bool) -> [String] {
        needsSubcategory
            ? [DraftInputRequirement.account, DraftInputRequirement.subcategory]
            : [DraftInputRequirement.account]
    }

    /// ¿(Re)crear un draft `[.subcategory]` para una TX real Caso A sin clasificar?
    /// True solo si: existe la TX real, su subcategoría es nil, el auto-match sigue fallando,
    /// y NO estamos dentro de `DraftService.approve` (`skipDraftCleanup` — ahí el user ya
    /// asignó subcat y el cleanup del bridge no debe interferir con el draft activo).
    static func shouldOfferCaseASubcategoryFallback(
        skipDraftCleanup: Bool,
        hasRealTx: Bool,
        realTxSubcategoryIsNil: Bool,
        autoMatchFailed: Bool
    ) -> Bool {
        !skipDraftCleanup && hasRealTx && realTxSubcategoryIsNil && autoMatchFailed
    }

    /// ¿(Re)crear el draft TX-puntero `[.subcategory]` del virtual `-myShare` en los paths
    /// virtual-only (Caso B, Caso A bridge-OFF, Caso A `.groupInvite`)?
    /// False si la subcat resolvió — o si un draft opt-in pendiente ya pide subcategoría
    /// (sheet combinado `[.account, .subcategory]`): el bridge es delete+recreate idempotente
    /// y cada re-bridge (sync round-trip, retry) recrearía el puntero que el opt-in ya cubre,
    /// duplicando el ask en el Inbox; además el puntero quedaría huérfano al aprobar el opt-in,
    /// cuando el virtual `-myShare` se reconcilia a `+lent`/no-virtual (B6-25/B6-26).
    static func shouldCreateVirtualSubcategoryPointer(
        autoMatchFailed: Bool,
        optInDraftCoversSubcategory: Bool
    ) -> Bool {
        autoMatchFailed && !optInDraftCoversSubcategory
    }

    // MARK: - Inbox-side

    /// Qué sheet de finalización mostrar para un draft `.groupExpense`.
    enum Route: Equatable {
        /// Solo falta la cuenta → `GroupExpenseAccountFinalizationSheet`.
        case accountOnly
        /// Faltan cuenta + subcategoría → `GroupExpenseAccountAndSubcategoryFinalizationSheet`.
        case accountAndSubcategory
        /// Solo falta la subcategoría (TX-puntero M5, o fallback Caso A/B) →
        /// `GroupExpenseDraftFinalizationSheet`.
        case subcategoryOnly
    }

    /// Decide el route. `accountOnly`/`accountAndSubcategory` requieren `targetTransactionID == nil`
    /// (drafts M6 que crean TX real). El path subcat heredado M5 (`targetTransactionID != nil`)
    /// y los drafts solo-subcategoría → `subcategoryOnly`.
    static func route(
        targetTransactionIDIsNil: Bool,
        needsAccount: Bool,
        needsSubcategory: Bool
    ) -> Route {
        guard targetTransactionIDIsNil else { return .subcategoryOnly }
        if needsAccount && needsSubcategory { return .accountAndSubcategory }
        if needsAccount { return .accountOnly }
        return .subcategoryOnly
    }

    // MARK: - Approve-side

    /// Resolución de un draft-puntero `.groupExpense` (Caso A fallback / Caso B / M5 heredado)
    /// cuyo target — la TX con `splitExpenseID == splitID && subcategory == nil` — NO se encontró.
    /// Sin esta decisión, `approveDraft` caía al path genérico e insertaba una TX nueva SIN
    /// `splitExpenseID` → transacción fantasma duplicada (account/amount/subcategory no-nil pasan
    /// los `guard let`). Ningún draft de grupo debe materializar una TX nueva por fall-through.
    enum StalePointerResolution: Equatable {
        /// Ya existe una TX para ese `splitExpenseID` (clasificada en otro device y sincronizada).
        /// El draft es redundante → borrarlo y devolver la TX existente (idempotente).
        case discardRedundant
        /// No existe NINGUNA TX para ese `splitExpenseID` (el expense se borró remotamente).
        /// Borrar el draft stale y lanzar error claro (la sheet lo muestra).
        case deleteStaleAndThrow
    }

    /// - Parameter existsAnyTxForSplitID: ¿hay CUALQUIER TX con ese `splitExpenseID`,
    ///   independientemente de su subcategoría?
    static func resolveMissingPointerTarget(existsAnyTxForSplitID: Bool) -> StalePointerResolution {
        existsAnyTxForSplitID ? .discardRedundant : .deleteStaleAndThrow
    }
}
