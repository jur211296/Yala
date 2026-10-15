//
//  GroupsLote13FixesTests.swift
//  YalaTests
//
//  Bugs claros del lote 13 de la auditoría UX 2.2 (Grupos II: gastos y saldar cuentas).
//

import Foundation
import Testing
@testable import Yala

@Suite("Lote 13 · Grupos II")
struct GroupsLote13FixesTests {

    // MARK: - B2 · «¿De qué cuenta sale?» solo para quien paga

    @Test func settlementForm_asksForAccount_onlyWhenIPay() {
        #expect(SettlementFormAccountLogic.asksForAccount(currentUserMemberID: "me", payerMemberID: "me"))
        // Cobro yo: el puente no usa la cuenta (Caso D, me llega mi borrador).
        #expect(!SettlementFormAccountLogic.asksForAccount(currentUserMemberID: "me", payerMemberID: "ana"))
    }

    @Test func settlementForm_accountSectionIsGatedByThePayer() throws {
        let source = try Self.source("Yala/App/Views/Groups/SettlementFormView.swift")
        #expect(Self.normalized(source).contains(
            "if sessionState.hasPrivateSession && bridgeEnabled && SettlementFormAccountLogic.asksForAccount( currentUserMemberID: currentUserMemberID, payerMemberID: debt.fromMemberID) {"))
    }

    @Test func settlementForm_withoutIdentity_stillAsks() {
        // Sin identidad resuelta se conserva el comportamiento de antes: el puente resuelve por su cuenta.
        #expect(SettlementFormAccountLogic.asksForAccount(currentUserMemberID: nil, payerMemberID: "ana"))
    }

    // MARK: - B3 · El borrador de quien paga pide la cuenta de ORIGEN

    @Test func settlementDraft_outgoingIsTheNegativeAmount() {
        #expect(GroupSettlementDraftAccountLabelLogic.isOutgoing(amount: -420))
        #expect(!GroupSettlementDraftAccountLabelLogic.isOutgoing(amount: 30))
        #expect(!GroupSettlementDraftAccountLabelLogic.isOutgoing(amount: nil))
    }

    @Test func settlementDraft_sheetPicksTheLabelByDirection() throws {
        let source = try Self.source("Yala/App/Views/Inbox/GroupSettlementDraftFinalizationSheet.swift")
        #expect(source.contains("GroupSettlementDraftAccountLabelLogic.isOutgoing(amount: draft.amount)"))
        #expect(source.contains("? L10n.Inbox.GroupExpenseAccountDraft.assignAccount"))
        // El chip y el selector usan la etiqueta elegida, no «Cuenta de destino» fija.
        #expect(!source.contains("?? L10n.Inbox.GroupSettlementDraft.assignAccount"))
        #expect(!source.contains("title: L10n.Inbox.GroupSettlementDraft.assignAccount"))
    }

    // MARK: - B5 · Ningún error de desarrollo en inglés llega a la persona

    @Test func userFacingError_knownErrorsKeepTheirLocalizedText() {
        #expect(GroupsUserFacingErrorLogic.message(for: GroupExpenseServiceError.notOwner)
                == L10n.Groups.OpeningBalance.errorNotOwner)
        #expect(GroupsUserFacingErrorLogic.message(for: DraftServiceError.missingAccount)
                == L10n.Inbox.errorNoAccount)
    }

    @Test func userFacingError_anyOtherErrorIsTheGenericMessage() {
        let raw = NSError(domain: "NSCocoaErrorDomain", code: 134_030,
                          userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed."])
        #expect(GroupsUserFacingErrorLogic.message(for: raw) == L10n.Groups.Errors.actionFailed)
        #expect(GroupsUserFacingErrorLogic.message(for: GroupTransactionBridgeError.noContext)
                == L10n.Groups.Errors.actionFailed)
    }

    @Test func serviceErrors_neverCarryDeveloperText() {
        let underlying = NSError(domain: "t", code: 1, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        let groupCases: [GroupExpenseServiceError] = [
            .noContext, .invalidAmount, .noShares, .sharesSumMismatch, .noPayer,
            .selfSettlement, .inactiveMember, .saveFailed(underlying),
        ]
        for error in groupCases {
            let text = error.errorDescription ?? ""
            #expect(!text.contains("GroupExpenseService"), "\(error) enseña texto de desarrollo")
            #expect(!text.contains("disk full"))
        }
        let draftCases: [DraftServiceError] = [.noContext, .saveFailed(underlying), .groupScheduledExpenseRequiresForm]
        for error in draftCases {
            let text = error.errorDescription ?? ""
            #expect(!text.contains("DraftService"), "\(error) enseña texto de desarrollo")
            #expect(!text.contains("disk full"))
        }
    }

    /// Las ocho pantallas del lote que enseñaban `localizedDescription` en una alerta.
    @Test(arguments: [
        "Yala/App/Views/Groups/GroupOpeningBalanceFormView.swift",
        "Yala/App/Views/Groups/SettlementFormView.swift",
        "Yala/App/Views/Groups/BridgeActivationSheet.swift",
        "Yala/App/Views/Groups/BridgeDeactivationSheet.swift",
        "Yala/App/Views/Inbox/GroupExpenseDraftFinalizationSheet.swift",
        "Yala/App/Views/Inbox/GroupSettlementDraftFinalizationSheet.swift",
        "Yala/App/Views/Inbox/GroupSettlementAmountChangeSheet.swift",
    ])
    func screens_doNotShowTheRawError(path: String) throws {
        let source = try Self.source(path)
        #expect(!source.contains("= error.localizedDescription"), "\(path) vuelve a enseñar el error en crudo")
        #expect(source.contains("GroupsUserFacingErrorLogic.message(for: error)"))
    }

    // MARK: - B1 · «1 parte», no «1 partes»

    @Test func sharesUnit_isSingularOnlyForOne() {
        #expect(L10n.Split.sharesUnit(1) == L10n.Split.sharesPart)
        #expect(L10n.Split.sharesUnit(2) == L10n.Split.sharesParts)
        #expect(L10n.Split.sharesUnit(0) == L10n.Split.sharesParts)
        #expect(L10n.Split.sharesPart != L10n.Split.sharesParts)
    }

    @Test func sharesLabels_countWhatIsShown() throws {
        let card = Self.normalized(try Self.source("Yala/App/Views/Groups/GroupSplitEditorCard.swift"))
        #expect(card.contains("Text(L10n.Split.sharesUnit(sharesShown(for: id)))"))
        // Lo que se ve: lo escrito o, vacío, el placeholder.
        #expect(card.contains("if let typed = Int(viewModel.sharesCounts[id] ?? \"\") { return typed }"))
        #expect(card.contains("return Int(placeholder) ?? 0"))
        let sheet = try Self.source("Yala/App/Views/Shared/SplitCalculatorSheet.swift")
        #expect(sheet.contains("Text(L10n.Split.sharesUnit(Int(fieldState.totalSharesText) ?? 0))"))
        #expect(!card.contains("Text(L10n.Split.sharesParts)") && !sheet.contains("Text(L10n.Split.sharesParts)"))
    }

    // MARK: - B8 · «S/» o «PEN» según la preferencia

    @Test func currencyLabel_followsThePreference() {
        #expect(CurrencyDisplayFormat.code.label(for: "PEN") == "PEN")
        #expect(CurrencyDisplayFormat.symbol.label(for: "PEN") == CurrencyCode.symbol(for: "PEN"))
    }

    @Test(arguments: [
        "Yala/App/Views/Groups/SettlementFormView.swift",
        "Yala/App/Views/Groups/GroupOpeningBalanceFormView.swift",
    ])
    func forms_labelTheCurrencyWithThePreference(path: String) throws {
        let source = try Self.source(path)
        #expect(source.contains("appPreferences.currencyDisplayFormat.label(for:"))
        #expect(!source.contains("Text(effectiveCurrency)"))
        #expect(!source.contains("Text(selectedCurrency.rawValue)"))
    }

    // MARK: - B4 · El selector de Saldos iniciales dice qué se elige

    @Test func openingBalancePickers_carryTheirOwnTitle() throws {
        let picker = try Self.source("Yala/App/Views/Groups/MemberPickerView.swift")
        #expect(!picker.contains("navigationTitle(L10n.Groups.Expense.paidByTitle)"))
        let form = try Self.source("Yala/App/Views/Groups/GroupOpeningBalanceFormView.swift")
        #expect(form.contains("title: L10n.Groups.OpeningBalance.debtorLabel"))
        #expect(form.contains("title: L10n.Groups.OpeningBalance.creditorLabel"))
    }

    // MARK: - B7 · «Cancelar» visible en los diálogos de borrar

    /// Con `role: .cancel` el diálogo (sale como popover en iOS 26) no pinta la salida: medido en el lote 13.
    @Test(arguments: [
        "Yala/App/Views/Groups/GroupExpenseFormView.swift",
        "Yala/App/Views/Groups/GroupRecordsView.swift",
        "Yala/App/Views/Groups/GroupOpeningBalanceDetailSheet.swift",
        "Yala/App/Views/Groups/GroupBalancesView.swift",
    ])
    func deleteDialogs_showAPlainCancel(path: String) throws {
        let source = try Self.source(path)
        #expect(source.contains("Button(L10n.Common.cancel) {"), "\(path) sin «Cancelar» visible")
        #expect(!source.contains("Button(L10n.Common.cancel, role: .cancel)"))
    }

    // MARK: - B6 / B9 · Textos que decían algo falso o en inglés

    @Test func bridgeTexts_noEnglishWordsAndNoFalseScope() throws {
        for locale in ["es-419", "es", "es-ES", "es-AR"] {
            let strings = try Self.strings(locale)
            #expect(!(strings["groups.bridge.editSettlementInGroup"] ?? "").contains("settlement"), "\(locale)")
            #expect(!(strings["groups.bridge.assignFromInbox"] ?? "").contains("Inbox"), "\(locale)")
            let body = strings["groups.bridge.activateBody"] ?? ""
            #expect(!body.contains("cuenta de grupos"), "\(locale)")
            #expect(!body.contains("este grupo"), "\(locale)")
            #expect(!(strings["groups.bridge.activateOptionImportAllHint"] ?? "").contains("liquidaciones"), "\(locale)")
        }
    }

    @Test func activateTexts_keepTheirSingleCount() {
        // Las dos claves siguen recibiendo UN %d: sin plural que concordar con el número.
        #expect(L10n.Groups.Bridge.activateBody(1).contains("1"))
        #expect(L10n.Groups.Bridge.activateOptionImportAllHint(7).contains("7"))
    }

    // MARK: - Helpers

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(path), encoding: .utf8)
    }

    /// Líneas recortadas, sin comentarios, unidas por un espacio.
    private static func normalized(_ source: String) -> String {
        source.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
            .joined(separator: " ")
    }

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = repoRoot().appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
        return (NSDictionary(contentsOf: url) as? [String: String]) ?? [:]
    }
}
