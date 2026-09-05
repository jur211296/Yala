//
//  GroupExpenseAmountResolverTests.swift
//  YalaTests
//
//  Pure-logic tests for GroupExpenseAmountResolver — perspectiva personal.
//

import Foundation
import Testing

@testable import Yala

struct GroupExpenseAmountResolverTests {

    @Test func resolve_returnsYouAreOwed_whenIAmPayer() {
        let me = "member-A"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 100,
            currencyCode: "PEN",
            paidByMemberID: me
        )
        let myShare = SplitShare(expenseID: expense.id, memberID: me, amount: 30)

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: myShare,
            currentMemberID: me
        )

        // Yo pagué 100, me corresponde 30, presté 70
        #expect(result == .youAreOwed(amount: 70))
    }

    @Test func resolve_returnsYouOwe_whenIAmNotPayer() {
        let me = "member-B"
        let other = "member-A"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 100,
            currencyCode: "PEN",
            paidByMemberID: other
        )
        let myShare = SplitShare(expenseID: expense.id, memberID: me, amount: 25)

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: myShare,
            currentMemberID: me
        )

        // Otro pagó, me prestó mi parte (25)
        #expect(result == .youOwe(amount: 25))
    }

    @Test func resolve_returnsNotIncluded_whenNoShare() {
        let me = "member-C"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 100,
            currencyCode: "PEN",
            paidByMemberID: "member-A"
        )

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: nil,
            currentMemberID: me
        )

        #expect(result == .notIncluded)
    }

    /// Pagador sin `SplitShare` propio (otro le devuelve todo): participa por ser pagador
    /// y prestó el total. NO debe caer en `.notIncluded` (regla Splitwise).
    @Test func resolve_returnsYouAreOwedTotal_whenPayerHasNoShare() {
        let me = "member-A"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 100,
            currencyCode: "PEN",
            paidByMemberID: me
        )

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: nil,
            currentMemberID: me
        )

        // Pagué 100, mi parte es 0 → presté 100.
        #expect(result == .youAreOwed(amount: 100))
    }

    /// Pagador cuya parte es el total (gasto 100% propio dentro del grupo): prestó 0.
    @Test func resolve_returnsYouAreOwedZero_whenPayerOwnsFullShare() {
        let me = "member-A"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 100,
            currencyCode: "PEN",
            paidByMemberID: me
        )
        let myShare = SplitShare(expenseID: expense.id, memberID: me, amount: 100)

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: myShare,
            currentMemberID: me
        )

        #expect(result == .youAreOwed(amount: 0))
    }
}

// MARK: - Identidad sin resolver (bug de device 2026-08-28)

extension GroupExpenseAmountResolverTests {

    /// El bug tal cual se vio en dos teléfonos: A crea un gasto mitad y mitad, y B —cuya identidad
    /// local todavía no había resuelto— lee «No participaste» en un gasto que sí comparte.
    ///
    /// Antes de este caso, los dos llamadores pasaban `currentMemberID ?? ""`, y el centinela vacío
    /// no casa con ningún `paidByMemberID` ni con ningún `memberID` de share: la ignorancia recorría
    /// exactamente el mismo camino que el conocimiento y salía convertida en una frase categórica.
    @Test func resolve_identitySinResolver_noAfirmaQueNoParticipo() {
        let payer = "member-A"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 20,
            currencyCode: "PEN",
            paidByMemberID: payer
        )

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: nil,
            currentMemberID: nil
        )

        #expect(result == .identityUnresolved, """
            Con la identidad sin resolver el resolver NO puede afirmar nada sobre la participación.
            Si esto vuelve a dar `.notIncluded`, la pantalla le está diciendo a alguien que no
            participó en un gasto que quizá sí comparte — y contradiciendo al otro teléfono.
            """)
    }

    /// El centinela vacío era el bug, así que se pinnea que ya no puede colarse: la firma es
    /// `String?` y `nil` es el único «no sé». Un `""` significaría un id real vacío, que no existe.
    @Test func resolve_identitySinResolver_noSeConfundeConNotIncluded() {
        let payer = "member-A"
        let otro = "member-C"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 20,
            currencyCode: "PEN",
            paidByMemberID: payer
        )

        // Identidad SÍ resuelta, y de verdad no participo: eso sigue siendo `.notIncluded`.
        let conocido = GroupExpenseAmountResolver.resolve(
            expense: expense, share: nil, currentMemberID: otro)
        // Identidad sin resolver: otra cosa distinta.
        let desconocido = GroupExpenseAmountResolver.resolve(
            expense: expense, share: nil, currentMemberID: nil)

        #expect(conocido == .notIncluded)
        #expect(desconocido == .identityUnresolved)
        #expect(conocido != desconocido, """
            «Sé que no participas» y «no sé quién eres» tienen que ser estados DISTINTOS. Colapsarlos
            fue la causa de que el device leyera una afirmación falsa con toda seguridad.
            """)
    }

    /// La garantía «el pagador nunca cae en notIncluded» que el ticket daba por buena era NULA bajo
    /// identidad sin resolver: con `""` la comparación con `paidByMemberID` fallaba también para el
    /// pagador. Ahora ese caso sale por su propia rama, no por una afirmación falsa.
    @Test func resolve_identitySinResolver_tampocoAfirmaSobreElPagador() {
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 20,
            currencyCode: "PEN",
            paidByMemberID: "member-B"
        )

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: SplitShare(expenseID: expense.id, memberID: "member-B", amount: 10),
            currentMemberID: nil
        )

        #expect(result == .identityUnresolved)
    }
}
