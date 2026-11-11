//
//  ReturnToICloudSheetLogicTests.swift
//  YalaTests
//
//  Revisión 2.3, zona 41, decisiones 53 y 57: volver a tu iCloud y activar con un borrado pendiente se deciden en hojas
//  con fases. Aquí, lo puro: qué fase sigue, qué dice cada elección con su cifra, y que la tarjeta ya no promete lo que
//  la cuenta no puede cumplir. Lo que el toque hace de verdad lo fijan `ReverseICloudPriorDataUITests` y
//  `PendingICloudWipeMigrationUITests`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Volver a tu iCloud · fases y textos de la hoja (revisión 2.3, decisión 53)")
struct ReturnToICloudSheetLogicTests {

    private func corpus(transactions: Int = 0, groups: Int = 0, accounts: Int = 0, budgets: Int = 0,
                        other: Int = 0, truncated: Bool = false) -> ICloudForeignCorpus {
        ICloudForeignCorpus(transactions: transactions, groupTransactions: groups, accounts: accounts,
                            budgets: budgets, otherRecords: other, truncated: truncated, fieldsUnread: false)
    }

    @Test func seguir_withoutPriorData_goesStraightToTheUsualConfirmation() {
        #expect(ReturnToICloudSheetLogic.phaseAfterWhatHappens(priorData: nil) == .confirm(.plain))
    }

    @Test func seguir_withPriorData_asksWhatToDoWithIt() {
        #expect(ReturnToICloudSheetLogic.phaseAfterWhatHappens(priorData: corpus(transactions: 3)) == .choosePrior)
    }

    /// La elección lleva su cifra; sin cifras que decir, la versión que no promete números.
    @Test func priorBody_carriesTheFigure_orNone() {
        #expect(ReturnToICloudSheetLogic.priorBody(corpus(transactions: 3))
                == L10n.Storage.Revert.Sheet.priorBody(L10n.Welcome.Restore.foundTransactions(3)))
        #expect(ReturnToICloudSheetLogic.priorBody(corpus(other: 2)) == L10n.Storage.Revert.Sheet.priorBodyNoCount)
    }

    /// Los registros de grupos llegan sin su grupo: «Sumarlos» lo dice solo cuando hay alguno.
    @Test func mergeDetail_namesTheGroupRecordsOnlyWhenThereAreAny() {
        #expect(ReturnToICloudSheetLogic.mergeDetail(corpus(transactions: 3, groups: 9))
                .hasSuffix(L10n.Storage.Revert.Prior.groupsNote))
        #expect(ReturnToICloudSheetLogic.mergeDetail(corpus(transactions: 3)) == L10n.Storage.Revert.Sheet.mergeDetail)
    }

    /// La confirmación repite lo elegido con la cifra; la vuelta de siempre no tiene elección que repetir.
    @Test func confirmLine_repeatsTheChoice() {
        let found = corpus(transactions: 3, groups: 9)
        let summary = ReverseICloudPriorDataLogic.summaryParts(found).joined(separator: ", ")
        #expect(ReturnToICloudSheetLogic.confirmLine(.plain, priorData: nil) == nil)
        #expect(ReturnToICloudSheetLogic.confirmLine(.mergePrior, priorData: found)
                == L10n.Storage.Revert.Sheet.confirmMerge(summary))
        #expect(ReturnToICloudSheetLogic.confirmLine(.discardPrior, priorData: found)
                == L10n.Storage.Revert.Sheet.confirmDiscard(summary))
        #expect(ReturnToICloudSheetLogic.confirmLine(.discardPrior, priorData: corpus(other: 1))
                == L10n.Storage.Revert.Sheet.confirmDiscardNoCount)
        #expect(ReturnToICloudSheetLogic.confirmLine(.mergePrior, priorData: corpus(other: 1))
                == L10n.Storage.Revert.Sheet.confirmMergeNoCount)
    }

    /// El botón que borra dice que borra; los otros dos, volver.
    @Test func confirmButton_namesTheDeletionOnlyWhenItDeletes() {
        #expect(ReturnToICloudSheetLogic.confirmButton(.discardPrior) == L10n.Storage.Revert.Sheet.confirmDiscardButton)
        #expect(ReturnToICloudSheetLogic.confirmButton(.mergePrior) == L10n.Storage.Revert.button)
        #expect(ReturnToICloudSheetLogic.confirmButton(.plain) == L10n.Storage.Revert.button)
    }
}

/// **La regresión de la decisión 53, en el texto de referencia**: la tarjeta prometía «sin perder nada» y «queda en pausa
/// por si vuelves», y volver a la nube con esa cuenta hoy no se puede. Se lee el catálogo es-419 (la referencia completa);
/// la paridad de idiomas ya obliga a los otros quince a tener las mismas claves.
@Suite("Volver a tu iCloud · la tarjeta no promete lo que no se cumple")
struct ReturnToICloudCardPromiseTests {

    private static func strings() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Yala/Resources/es-419.lproj/Localizable.strings"),
                          encoding: .utf8)
    }

    private static func value(_ key: String, in strings: String) -> String? {
        strings.split(separator: "\n").first { $0.hasPrefix("\"\(key)\" = ") }.map(String.init)
    }

    @Test func theCardNoLongerPromisesNothingIsLost_norAPauseInCaseYouComeBack() throws {
        let strings = try Self.strings()
        let body = try #require(Self.value("storage.revert.body", in: strings))
        #expect(!body.contains("sin perder nada"))
        #expect(Self.value("storage.revert.desenlaceNote", in: strings) == nil, "volvió «queda en pausa por si vuelves»")
        #expect(!strings.contains("por si vuelves"))
        let cannot = try #require(Self.value("storage.revert.sheet.cloudAgainDetail", in: strings))
        #expect(cannot.contains("Hoy no se puede"))
    }

    /// Decisión 57: «Activar sin borrar» no decía qué no se borraba. Ahora cada salida dice lo que hace.
    @Test func thePendingWipeChoicesSayWhatTheyDo() throws {
        let strings = try Self.strings()
        let proceed = try #require(Self.value("storage.pendingICloudWipe.proceed", in: strings))
        #expect(!proceed.contains("sin borrar"))
        #expect(proceed.contains("conservar mis datos de iCloud"))
        let finish = try #require(Self.value("storage.pendingICloudWipe.finishDetail", in: strings))
        #expect(finish.contains("de este dispositivo y de tu iCloud"))
        // A medias, iCloud ya está vacío: esa hoja no puede decir que los datos de iCloud se quedan.
        let halfway = try #require(Self.value("storage.pendingICloudWipe.bodyHalfway", in: strings))
        #expect(halfway.contains("ya se borró"))
        #expect(!halfway.contains("se quedan"))
    }
}
