//
//  SettlementSaldar23Logic.swift
//  Yala
//
//  Saldar como en Splitwise (decisión 37 de la revisión 2.3, C1 + C2 + C3; Jürgen, 2026-11-09):
//  - C1: cualquiera apunta cualquier pago entre miembros. Si no lo apunta quien paga ni quien recibe, queda «Falta que
//    <quien recibe> lo confirme»; quien recibe lo confirma con el «¿Lo recibiste?» de L13-2.
//  - C2: «Todo» o «Una parte», con lo que queda y un aviso si se paga de más.
//  - C3: al guardar, un aviso con el saldo nuevo de la pareja y «Deshacer».
//
//  Lógica pura: la vista y el ViewModel solo la llaman.
//

import Foundation

nonisolated enum SettlementSaldar23Logic {

    // MARK: - C1 · Quién lo confirma

    /// Quién apunta el pago respecto a la pareja que salda.
    enum RecorderRole: Equatable {
        /// Quien paga: nace confirmado, como siempre.
        case payer
        /// Quien recibe: apuntarlo ya es confirmarlo.
        case receiver
        /// Ni uno ni otro (quien lleva las cuentas del viaje): espera a que quien recibe lo confirme.
        case thirdParty
    }

    /// `nil` (no se sabe quién eres en el grupo) se trata como hasta ahora: nace confirmado. Sin miembro resuelto
    /// Saldos no ofrece «Saldar» en ninguna deuda, así que en la práctica no llega aquí.
    static func recorderRole(recorderMemberID: String?, fromMemberID: String, toMemberID: String) -> RecorderRole {
        guard let recorder = recorderMemberID else { return .payer }
        if recorder == toMemberID { return .receiver }
        if recorder == fromMemberID { return .payer }
        return .thirdParty
    }

    /// El pago nace confirmado salvo que lo apunte un tercero.
    static func confirmsOnRecord(recorderMemberID: String?, fromMemberID: String, toMemberID: String) -> Bool {
        recorderRole(recorderMemberID: recorderMemberID, fromMemberID: fromMemberID, toMemberID: toMemberID)
            != .thirdParty
    }

    /// En Saldos, «Saldar» va en todas las deudas, no solo en las tuyas (antes de C1, solo con `involvesMe`). En una
    /// deuda entre otros hace falta saber quién eres y que quien recibe pueda confirmarlo: un miembro que salió del grupo
    /// o espera aprobación no puede, y el pago quedaría pendiente para siempre (review adversarial del 2026-11-12).
    static func offersSettle(involvesMe: Bool, currentUserMemberID: String?, receiverCanConfirm: Bool) -> Bool {
        involvesMe || (currentUserMemberID != nil && receiverCanConfirm)
    }

    /// Un pago sin confirmar apuntado por alguien que no es parte de él: en la lista dice quién lo apuntó.
    static func recordedByThirdParty(fromMemberID: String, toMemberID: String, recordedByMemberID: String?) -> Bool {
        guard let recorder = recordedByMemberID else { return false }
        return recorder != fromMemberID && recorder != toMemberID
    }

    // MARK: - C2 · Todo o una parte

    enum PaymentScope: Equatable {
        case all
        case part
    }

    /// Qué deja el importe escrito frente a lo que se debe.
    enum AmountOutcome: Equatable {
        /// Quedan a mano.
        case settles
        /// Queda esto por pagar.
        case leaves(Double)
        /// Se paga esto de más: quien recibe pasa a deber esa diferencia.
        case overpays(Double)
    }

    /// Menos de medio céntimo no cuenta: la deuda puede tener más decimales que los que se ven («33.33» de 100 / 3).
    static let tolerance: Double = 0.005

    /// `nil` sin importe: no hay nada que decir todavía (lo que falta lo dice el aviso de siempre).
    /// `matchesShownDebt`: el texto del campo es el de la deuda tal como se enseña. Así «Todo» siempre deja a mano
    /// aunque la deuda tenga más decimales que los que caben en el campo.
    static func amountOutcome(owed: Double, paying: Double, matchesShownDebt: Bool = false) -> AmountOutcome? {
        guard paying > 0, paying.isFinite, owed.isFinite else { return nil }
        if matchesShownDebt { return .settles }
        let difference = owed - paying
        if abs(difference) < tolerance { return .settles }
        return difference > 0 ? .leaves(difference) : .overpays(-difference)
    }

    /// Al escribir con «Todo» elegido otro importe que el de la deuda, la elección pasa a «Una parte».
    static func scopeAfterTyping(_ scope: PaymentScope, matchesShownDebt: Bool) -> PaymentScope {
        (scope == .all && !matchesShownDebt) ? .part : scope
    }

    // MARK: - C3 · El aviso al guardar

    /// Lo que queda entre la pareja después del pago, leído de las deudas ya recalculadas.
    struct PairRemainder: Equatable {
        /// Lo que quien pagó le sigue debiendo a quien recibió (o empezó a deberle).
        var payerOwes: [Debt]
        /// Lo que quien recibió pasa a deberle a quien pagó (pagó de más).
        var receiverOwes: [Debt]
        var isSettled: Bool { payerOwes.isEmpty && receiverOwes.isEmpty }
    }

    static func pairRemainder(debts: [Debt], fromMemberID: String, toMemberID: String) -> PairRemainder {
        PairRemainder(
            payerOwes: debts.filter { $0.fromMemberID == fromMemberID && $0.toMemberID == toMemberID },
            receiverOwes: debts.filter { $0.fromMemberID == toMemberID && $0.toMemberID == fromMemberID }
        )
    }

    /// El texto del aviso: qué pasó y cómo queda la pareja. `amount` y `format` llegan formateados por la vista (la
    /// preferencia «S/» / «PEN» vive allí); `name` da «Tú» para ti y el nombre del miembro para los demás.
    @MainActor
    static func savedNotice(
        fromMemberID: String,
        toMemberID: String,
        currentUserMemberID: String?,
        isConfirmed: Bool,
        amount: String,
        remainder: PairRemainder,
        name: (String) -> String,
        format: ([Debt]) -> String
    ) -> String {
        let from = name(fromMemberID)
        let to = name(toMemberID)
        let role = GroupBalancesPresentationLogic.pairRole(
            fromMemberID: fromMemberID, toMemberID: toMemberID, currentUserMemberID: currentUserMemberID)

        let what: String
        switch role {
        case .youPay: what = L10n.GruposSaldar23.noticeYouPaid(amount: amount, to: to)
        case .paysYou: what = L10n.GruposSaldar23.noticePaidYou(from: from, amount: amount)
        case .others: what = L10n.GruposSaldar23.noticeOthersPaid(from: from, amount: amount, to: to)
        }

        // Pendiente: el saldo no cambia hasta que lo confirme quien recibe.
        guard isConfirmed else {
            return what + " " + L10n.GruposSaldar23.noticeWaitingFor(to)
        }
        guard !remainder.isSettled else {
            return what + " " + L10n.GruposSaldar23.noticeSettled
        }

        var parts = [what]
        if !remainder.payerOwes.isEmpty {
            parts.append(owesSentence(debtorID: fromMemberID, creditorID: toMemberID, amounts: format(remainder.payerOwes),
                                      currentUserMemberID: currentUserMemberID, name: name))
        }
        if !remainder.receiverOwes.isEmpty {
            parts.append(owesSentence(debtorID: toMemberID, creditorID: fromMemberID, amounts: format(remainder.receiverOwes),
                                      currentUserMemberID: currentUserMemberID, name: name))
        }
        return parts.joined(separator: " ")
    }

    @MainActor
    private static func owesSentence(
        debtorID: String, creditorID: String, amounts: String, currentUserMemberID: String?, name: (String) -> String
    ) -> String {
        if debtorID == currentUserMemberID {
            return L10n.GruposSaldar23.noticeNowYouOwe(amounts: amounts, to: name(creditorID))
        }
        if creditorID == currentUserMemberID {
            return L10n.GruposSaldar23.noticeNowOwesYou(from: name(debtorID), amounts: amounts)
        }
        return L10n.GruposSaldar23.noticeNowOthersOwe(from: name(debtorID), amounts: amounts, to: name(creditorID))
    }
}
