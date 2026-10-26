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

/// Lo que el puente dejó en el store para UN gasto de grupo, leído después de guardarlo
/// (`GroupExpenseBridgeTraceReader`). Es la prueba con la que `confirmedOutcome` deja hablar a la pantalla de éxito.
nonisolated struct GroupExpenseBridgeTrace: Equatable {
    /// La cuenta de la transacción real (cuenta que no es de sistema) con este gasto; `nil` si no hay.
    var realAccountName: String?
    /// Hay una transacción en la cuenta virtual de Grupos con importe negativo: tu parte como gasto de grupo.
    var hasVirtualShare: Bool
    /// Hay un borrador «registrar también en tu Yala» pendiente en la Bandeja para este gasto.
    var hasPendingOptInDraft: Bool
    /// El puente falló y el gasto quedó marcado para reintentarlo.
    var bridgePending: Bool
}

/// Cómo terminó el «¿Registrar también en tu Yala personal?» (puente apagado y pagaste tú).
///
/// UX 2.2 · L13-7 (decisión B de Jürgen, 2026-10-18): «Sí, registrar» pide la cuenta ahí mismo y registra de verdad; el
/// borrador solo se queda en la Bandeja si la persona cierra sin elegir.
nonisolated enum GroupExpenseOptInResolution: Equatable {
    /// Eligió la cuenta (o enlazó un movimiento suyo): está en tus finanzas, en esa cuenta.
    case registered(accountName: String)
    /// Dijo que sí y cerró sin elegir: el borrador espera en la Bandeja.
    case waitingInInbox
    /// «Solo en el grupo», o el borrador no se pudo crear.
    case declined
}

extension GroupExpenseSuccessLogic {

    /// - Parameters:
    ///   - optIn: cómo terminó el aviso «¿Lo registramos?» (puente apagado y pagaste tú). `nil` mientras no se ha
    ///     contestado o si no se preguntó.
    ///   - isCreation: `false` en una edición. Si pagaste tú, la pantalla no sabe qué hizo el puente con la transacción de
    ///     antes (con el puente encendido conserva la cuenta original o, si cambió la moneda, deja un borrador; apagado,
    ///     puede quedar la de un «Sí» anterior): no dice nada antes que decir algo falso.
    nonisolated static func personalOutcome(
        isCaseA: Bool,
        isGroupsOnlySession: Bool,
        bridgeEnabled: Bool,
        accountName: String?,
        isCreation: Bool,
        optIn: GroupExpenseOptInResolution?,
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
        guard let optIn else { return .none }
        switch optIn {
        case .registered(let accountName):
            return accountName.isEmpty ? .none : .chargedToAccount(accountName: accountName)
        case .waitingInInbox:
            return .waitingInInbox
        case .declined:
            return share
        }
    }

    /// La línea «qué se apuntó en tus finanzas» solo si el puente lo escribió de verdad (card dx3m, ticket
    /// `group-expense-success-claims-a-bridge-write-that-did-not-happen`).
    ///
    /// `personalOutcome` espeja las ramas de `GroupTransactionBridge.bridgeExpense` sin leer lo que hizo, y hay seis
    /// casos en que el puente no escribe nada: el dominio de Grupos sellado, el grupo oculto, el gasto en el libro de
    /// conservados al desasociar, sin miembro propio resuelto, sin contexto, o un error. En los seis el store queda sin
    /// rastro de este gasto, así que la línea se confirma contra ese rastro y, sin él, se calla.
    ///
    /// - Parameter trace: lo que hay en el store para este gasto; `nil` si no se pudo leer (se calla: no se sabe).
    nonisolated static func confirmedOutcome(
        _ claimed: GroupExpensePersonalOutcome,
        trace: GroupExpenseBridgeTrace?
    ) -> GroupExpensePersonalOutcome {
        guard let trace, !trace.bridgePending else { return .none }
        switch claimed {
        case .chargedToAccount:
            // La cuenta que se nombra es la de la transacción que quedó, no la elegida en el formulario.
            guard let name = trace.realAccountName, !name.isEmpty else { return .none }
            return .chargedToAccount(accountName: name)
        case .waitingInInbox:
            return trace.hasPendingOptInDraft ? .waitingInInbox : .none
        case .shareAsGroupExpense:
            return trace.hasVirtualShare ? claimed : .none
        case .none:
            return .none
        }
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

// MARK: - Auditoría UX 2.2 · L13-9 · Qué falta para guardar

/// Lo primero que falta para poder guardar un gasto de grupo. UX 2.2 · L13-9 (decisión B de Jürgen, 2026-10-18):
/// «Guardar» siempre activo; al tocarlo con algo pendiente se marca ese campo y una línea dice qué falta.
nonisolated enum GroupExpenseMissingField: Equatable {
    case description
    case amount
    case payer
    case participants
    case split
    case account
}

nonisolated enum GroupExpenseMissingFieldLogic {

    /// En el orden en que se ve el formulario, de arriba abajo: descripción e importe arriba; quién pagó y el reparto en
    /// la frase; la cuenta debajo. `nil` si no falta nada (los mismos términos que `GroupExpenseViewModel.canSave`).
    static func firstMissing(
        descriptionValid: Bool,
        amountValid: Bool,
        payerValid: Bool,
        hasParticipants: Bool,
        sharesBalanced: Bool,
        accountRequired: Bool,
        accountCompatible: Bool
    ) -> GroupExpenseMissingField? {
        if !descriptionValid { return .description }
        if !amountValid { return .amount }
        if !payerValid { return .payer }
        if !hasParticipants { return .participants }
        if !sharesBalanced { return .split }
        if accountRequired && !accountCompatible { return .account }
        return nil
    }
}

// MARK: - Lote 12.3 · El mismo trato en los formularios hermanos (card rhgi)

/// Lo primero que falta para guardar un saldo inicial. Mismo criterio que L13-9 en el gasto: «Guardar» siempre activo y,
/// al tocarlo con algo pendiente, se marca el campo y una línea dice qué falta.
nonisolated enum GroupOpeningBalanceMissingField: Equatable {
    case debtor
    case creditor
    /// Quien debe y a quien le debe son la misma persona (los selectores lo evitan; una edición con datos raros, no).
    case samePerson
    case amount
}

nonisolated enum GroupOpeningBalanceMissingFieldLogic {

    /// En el orden en que se ve el formulario: quién debe, a quién, el importe. `nil` si se puede guardar (los mismos
    /// términos que pedía el `canSave` de antes).
    static func firstMissing(debtorMemberID: String, creditorMemberID: String, amount: Double) -> GroupOpeningBalanceMissingField? {
        if debtorMemberID.isEmpty { return .debtor }
        if creditorMemberID.isEmpty { return .creditor }
        if debtorMemberID == creditorMemberID { return .samePerson }
        if !(amount > 0) { return .amount }
        return nil
    }
}

/// «Apuntar pago» de una liquidación: lo único que puede faltar es el importe.
nonisolated enum SettlementMissingFieldLogic {
    static func amountMissing(_ amount: Double) -> Bool { !(amount > 0) }
}
