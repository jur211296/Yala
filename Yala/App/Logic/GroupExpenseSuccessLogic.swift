//
//  GroupExpenseSuccessLogic.swift
//  Yala
//
//  Pure-logic que traduce el reparto de un gasto de grupo recién creado/editado en la
//  deuda que le queda al usuario actual. Alimenta `GroupExpenseSuccessView` y es testeable
//  sin `ModelContext` (sin SwiftData ni singletons).
//

import Foundation

/// Impacto de un gasto de grupo para el usuario actual, tras crearlo/editarlo.
/// `nonisolated`: bajo `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` el enum sería `@MainActor`
/// por default y su conformance `Equatable` no podría usarse desde contexto nonisolated
/// (tests Swift Testing) — error en Swift 6.
nonisolated enum GroupExpenseDebt: Equatable {
    /// El usuario pagó; los demás le deben este monto (total − su parte).
    case theyOweMe(Double)
    /// Pagó otra persona; el usuario le debe su parte.
    case iOwe(Double)
    /// El usuario pagó y era el único participante (o el resto ≈ 0): sin deuda pendiente.
    case settled
}

nonisolated enum GroupExpenseSuccessLogic {

    /// Umbral bajo el cual una diferencia se trata como cero — evita mostrar
    /// "te deben 0.00" por redondeos de la división.
    static let epsilon = 0.005

    /// Traduce el reparto de un gasto en la deuda del usuario actual.
    /// - Si el usuario pagó (`paidByMemberID == currentUserMemberID`): los demás le deben
    ///   `total − miParte` → `.theyOweMe` (o `.settled` si ese resto es ~0).
    /// - Si pagó otra persona: el usuario le debe su parte → `.iOwe` (o `.settled` si su parte es ~0).
    /// - `currentUserMemberID == nil` (caso edge, current user no resuelto) → `.settled`.
    static func debt(
        total: Double,
        shares: [(memberID: String, amount: Double)],
        currentUserMemberID: String?,
        paidByMemberID: String
    ) -> GroupExpenseDebt {
        let myShare = currentUserMemberID.flatMap { myID in
            shares.first(where: { $0.memberID == myID })?.amount
        } ?? 0

        let iPaid = currentUserMemberID != nil && paidByMemberID == currentUserMemberID
        if iPaid {
            let owedToMe = total - myShare
            return owedToMe > epsilon ? .theyOweMe(owedToMe) : .settled
        } else {
            return myShare > epsilon ? .iOwe(myShare) : .settled
        }
    }
}

// MARK: - Auditoría UX 2.2 · L13-3 · Qué pasó con tu dinero

/// Qué apuntó Yala en tus finanzas personales al guardar un gasto de grupo. Espeja las ramas de
/// `GroupTransactionBridge.bridgeExpense`: la pantalla de éxito no puede prometer algo que el puente no hizo.
nonisolated enum GroupExpensePersonalOutcome: Equatable {
    /// Pagaste tú con el puente encendido: el total sale de esa cuenta (la pata real `-total`).
    case chargedToAccount(accountName: String)
    /// Puente apagado y dijiste «Sí, registrar»: quedó un borrador en la Bandeja para elegir la cuenta.
    case waitingInInbox
    /// Pagó otra persona, o pagaste tú con el puente apagado y sin borrador: tu parte entra como gasto de grupo, sin
    /// tocar ninguna cuenta (la pata virtual `-miParte`).
    case shareAsGroupExpense(amount: Double)
    /// Nada que contar: sesión solo-grupos (sin finanzas personales), tu parte es cero, o una edición donde no se sabe.
    case none
}

extension GroupExpenseSuccessLogic {

    /// - Parameters:
    ///   - optInDraftCreated: respuesta al aviso «¿Lo registramos?» (puente apagado y pagaste tú). `nil` mientras no
    ///     se ha contestado o si no se preguntó.
    ///   - isCreation: `false` en una edición. Si pagaste tú, la pantalla no sabe qué hizo el puente con la transacción de
    ///     antes (con el puente encendido conserva la cuenta original o, si cambió la moneda, deja un borrador; apagado,
    ///     puede quedar la de un «Sí» anterior): no dice nada antes que decir algo falso.
    nonisolated static func personalOutcome(
        isCaseA: Bool,
        isGroupsOnlySession: Bool,
        bridgeEnabled: Bool,
        accountName: String?,
        isCreation: Bool,
        optInDraftCreated: Bool?,
        myShare: Double
    ) -> GroupExpensePersonalOutcome {
        guard !isGroupsOnlySession else { return .none }
        let share: GroupExpensePersonalOutcome = myShare > epsilon ? .shareAsGroupExpense(amount: myShare) : .none
        guard isCaseA else { return share }
        // En una edición el puente conserva la cuenta original (no la pisa) y, si cambió la moneda, deja un borrador en la
        // Bandeja: «−S/ X en <cuenta elegida>» podría ser falso.
        guard isCreation else { return .none }
        if bridgeEnabled {
            guard let accountName, !accountName.isEmpty else { return .none }
            return .chargedToAccount(accountName: accountName)
        }
        guard let optInDraftCreated else { return .none }
        return optInDraftCreated ? .waitingInInbox : share
    }

    /// Quién te debe y cuánto, sin ti. Para la línea «Ana y Beto, S/ 50 cada uno».
    nonisolated static func debtors(
        participants: [(id: String, name: String, amount: Double)],
        currentUserMemberID: String?
    ) -> [(name: String, amount: Double)] {
        participants
            .filter { $0.id != currentUserMemberID && $0.amount > epsilon }
            .map { (name: $0.name, amount: $0.amount) }
    }

    /// Todas las partes iguales al céntimo: se dice una vez «cada uno». Con 33,33 / 33,34 no: alguien debe un céntimo
    /// más y «33,33 cada uno» sería falso.
    nonisolated static func allEqual(_ amounts: [Double]) -> Bool {
        guard let first = amounts.first else { return false }
        return amounts.allSatisfy { abs($0 - first) < 0.005 }
    }
}
