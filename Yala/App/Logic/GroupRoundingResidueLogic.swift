//
//  GroupRoundingResidueLogic.swift
//  Yala
//
//  Qué saldo de un grupo es RESIDUO DE REDONDEO y no una deuda (auditoría UX 2.2 · L19-10, decisión C de Jürgen del
//  18-oct: «no contar el residuo de redondeo como deuda»).
//
//  El caso medido: un grupo de tres que lista y detalle dan «a mano» y que no se podía eliminar, porque en Saldos
//  Beto quedaba en $ 0.02. Ese saldo no se lo debe nadie a nadie: los repartos de un gasto no sumaban exactamente su
//  importe (3 × 16.67 por 50.00) y el saldo NETO de cada persona (pagado − su parte) arrastra la diferencia, pero las
//  deudas de persona a persona, que salen de los repartos, no.
//
//  LA REGLA: cuenta como deuda lo que aparece en las deudas de persona a persona, simplificadas
//  (`GroupBalanceService.calculateDebts`, `simplifyDebts: true`). Es la misma fuente que «Están a mano» y que Saldos,
//  así que el bloqueo nunca dice otra cosa que lo que la persona ve. Por qué así y no con una tolerancia de céntimos
//  (la primera versión, que la review adversarial del 21-oct tumbó por dos lados):
//  - una tolerancia ESCONDE una deuda real pequeña: Beto debe 33.33 y liquida 33.31; quedan 0.02 que Saldos enseña
//    («Beto te debe $ 0.02») y que la tolerancia daba por saldados;
//  - y no PERDONA un residuo mayor que ella: el reparto exacto admite hasta dos céntimos de descuadre por gasto, así
//    que tres gastos de 10.00 repartidos a 3.33 dejan 0.03 que nadie le debe a nadie y que seguían bloqueando.
//  Las deudas simplificadas no tienen ninguno de los dos problemas: el descuadre entre importe y repartos no llega a
//  ellas, y una liquidación corta sí.
//
//  Falla CERRADO ante un importe no finito: si algún saldo neto no es un número, el grupo cuenta como con deuda.
//
//  Quién la usa: el bloqueo de «Eliminar» y el aviso de «Archivar» con deudas (`GroupSettingsView`), la red de
//  `GroupService.softDelete`, el aviso de salir con deuda y el de quitar a alguien que debe, y desde la card aeae
//  «Salir de todos mis grupos» y el aviso de borrar la cuenta (`memberHasOutstanding`).
//

import Foundation

enum GroupRoundingResidueLogic {

    /// Las deudas que cuentan, por divisa y sin convertir: las de persona a persona, simplificadas.
    static func outstandingDebts(
        expenses: [SplitExpense],
        shares: [SplitShare],
        settlements: [SplitSettlement]
    ) -> [Debt] {
        GroupBalanceService.calculateDebts(
            expenses: expenses,
            shares: shares,
            settlements: settlements,
            simplifyDebts: true
        )
    }

    /// ¿Queda alguna deuda en el grupo? Es lo que bloquea eliminar.
    ///
    /// - Parameter balances: los saldos netos del mismo grupo, solo para fallar cerrado ante un importe no finito.
    static func hasOutstanding(debts: [Debt], balances: [MemberBalance] = []) -> Bool {
        if balances.contains(where: { !$0.netBalance.isFinite }) { return true }
        return debts.contains { $0.amount > 0.01 || !$0.amount.isFinite }
    }

    /// ¿Participa `memberID` en alguna deuda? Decide el aviso de salir y el de quitar a alguien.
    static func hasOutstanding(debts: [Debt], memberID: String) -> Bool {
        debts.contains {
            ($0.fromMemberID == memberID || $0.toMemberID == memberID) && ($0.amount > 0.01 || !$0.amount.isFinite)
        }
    }

    /// ¿Tiene `memberID` alguna deuda en el grupo, contada como Saldos? Lo usan las dos superficies que decidían con el
    /// saldo NETO del usuario (`abs > 0.01`) y por eso tomaban el residuo de redondeo por deuda: «Salir de todos mis
    /// grupos» (`GroupService.batchHasOutstandingDebt`) y el aviso de borrar la cuenta
    /// (`GroupService.accountDeletionGroupsSummary`). Card aeae, 2026-10-24.
    ///
    /// Falla cerrado como `hasOutstanding(debts:balances:)`, pero solo con el saldo PROPIO no finito: un importe roto
    /// entre otros dos no es deuda de esta persona.
    static func memberHasOutstanding(
        memberID: String,
        expenses: [SplitExpense],
        shares: [SplitShare],
        members: [SplitMember],
        settlements: [SplitSettlement]
    ) -> Bool {
        let balances = GroupBalanceService.calculateBalances(
            expenses: expenses, shares: shares, members: members, settlements: settlements)
        if balances.contains(where: { $0.memberID == memberID && !$0.netBalance.isFinite }) { return true }
        let debts = outstandingDebts(expenses: expenses, shares: shares, settlements: settlements)
        return hasOutstanding(debts: debts, memberID: memberID)
    }
}
