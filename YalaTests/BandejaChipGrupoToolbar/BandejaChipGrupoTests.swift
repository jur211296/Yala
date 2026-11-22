//
//  BandejaChipGrupoTests.swift
//  YalaTests
//
//  El editor de la Bandeja con chip de grupo (decisión de Jürgen del 22-nov-2026): abajo solo «Dejar para después» y
//  «Guardar»; el grupo se elige en un chip de la fila y «Guardar y hacer recurrente» vive en el menú «…».
//
//  - `InboxDraftGroupChipLogic`: cuándo sale el chip, qué pide «Guardar» con grupo, cuándo se ofrece el recurrente.
//  - Cableado (source-scan) del editor: sin los dos enlaces de antes, el chip en la fila y el recurrente en el menú.
//  - Los textos nuevos en su tabla, en los 16 idiomas.
//

import Foundation
import Testing
@testable import Yala

@Suite("Bandeja · chip de grupo — lógica")
struct BandejaChipGrupoLogicTests {

    @Test func chip_saleDondeSalíaConvertir_sinEsperarAlMonto() {
        #expect(InboxDraftGroupChipLogic.showsChip(
            sourceType: .applePay, isExpense: true, hasEligibleGroups: true, status: .pending,
            isPayingNow: false, hasChosenGroup: false))
    }

    @Test func chip_noSale_enIngresoSinGruposDesdePagarAhoraNiEnFuentesQueNoSeConvierten() {
        #expect(!InboxDraftGroupChipLogic.showsChip(
            sourceType: .manual, isExpense: false, hasEligibleGroups: true, status: .pending,
            isPayingNow: false, hasChosenGroup: false), "Un ingreso no se comparte.")
        #expect(!InboxDraftGroupChipLogic.showsChip(
            sourceType: .manual, isExpense: true, hasEligibleGroups: false, status: .pending,
            isPayingNow: false, hasChosenGroup: false), "Sin grupos donde apuntarlo.")
        #expect(!InboxDraftGroupChipLogic.showsChip(
            sourceType: .manual, isExpense: true, hasEligibleGroups: true, status: .pending,
            isPayingNow: true, hasChosenGroup: false), "Desde «Pagar ahora» no se convertía.")
        #expect(!InboxDraftGroupChipLogic.showsChip(
            sourceType: .scheduledPayment, isExpense: true, hasEligibleGroups: true, status: .pending,
            isPayingNow: false, hasChosenGroup: false), "Un pago planificado no se convierte.")
        #expect(!InboxDraftGroupChipLogic.showsChip(
            sourceType: .manual, isExpense: true, hasEligibleGroups: true, status: .rejected,
            isPayingNow: false, hasChosenGroup: false), "Un descartado no se convierte.")
    }

    @Test func chip_conGrupoElegido_siempreSale_paraPoderQuitarlo() {
        #expect(InboxDraftGroupChipLogic.showsChip(
            sourceType: .manual, isExpense: true, hasEligibleGroups: false, status: .pending,
            isPayingNow: false, hasChosenGroup: true))
    }

    @Test func guardar_conGrupo_soloPideElMonto() {
        #expect(InboxDraftGroupChipLogic.canSave(hasChosenGroup: true, hasAmount: true, isReadyToApprove: false))
        #expect(!InboxDraftGroupChipLogic.canSave(hasChosenGroup: true, hasAmount: false, isReadyToApprove: false))
        #expect(!InboxDraftGroupChipLogic.canSave(hasChosenGroup: false, hasAmount: true, isReadyToApprove: false),
                "Sin grupo, «Guardar» sigue pidiendo cuenta y categoría.")
        #expect(InboxDraftGroupChipLogic.canSave(hasChosenGroup: false, hasAmount: true, isReadyToApprove: true))
    }

    @Test func recurrente_enElMenu_noConGrupoElegido() {
        #expect(InboxDraftGroupChipLogic.offersRecurringInMenu(offersRecurring: true, hasChosenGroup: false))
        #expect(!InboxDraftGroupChipLogic.offersRecurringInMenu(offersRecurring: true, hasChosenGroup: true))
        #expect(!InboxDraftGroupChipLogic.offersRecurringInMenu(offersRecurring: false, hasChosenGroup: false))
    }

    @Test func grupoElegido_seSuelta_alPasarAIngresoOSiYaNoEsElegible() {
        let id = UUID()
        #expect(InboxDraftGroupChipLogic.keepsChosenGroup(id, isExpense: true, eligibleGroupIDs: [id]))
        #expect(!InboxDraftGroupChipLogic.keepsChosenGroup(id, isExpense: false, eligibleGroupIDs: [id]))
        #expect(!InboxDraftGroupChipLogic.keepsChosenGroup(id, isExpense: true, eligibleGroupIDs: [UUID()]))
        #expect(!InboxDraftGroupChipLogic.keepsChosenGroup(nil, isExpense: true, eligibleGroupIDs: [id]))
    }
}

@Suite("Bandeja · chip de grupo — cableado (source-scan)")
struct BandejaChipGrupoWiringTests {

    private static let repoRoot: URL = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: path), encoding: .utf8)
            .components(separatedBy: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("//")
            }
            .joined(separator: "\n")
    }

    private static let editor = "Yala/App/Views/Inbox/InboxDraftEditSheet.swift"

    @Test func editor_yaNoTieneElEnlaceDeConvertir_yTieneElChipEnLaFila() throws {
        let source = try Self.code(Self.editor)
        #expect(!source.contains("inbox_convert_to_shared_button"), "Volvió el enlace «Convertir a gasto compartido».")
        #expect(!source.contains("L10n.Inbox.convertToShared"), "Volvió el texto del enlace de convertir.")
        let chipRow = try #require(source.range(of: "private func bottomChipRow"))
        let chip = try #require(source.range(of: "groupChip(iconOnly: groupIconOnly)"))
        #expect(chipRow.lowerBound < chip.lowerBound, "El chip de grupo va en la fila de chips de abajo.")
        #expect(source.contains("\"draft_editor_group_chip\""))
    }

    @Test func guardar_conGrupo_sigueElFlujoDeConvertir() throws {
        let source = try Self.code(Self.editor)
        #expect(source.contains("onConvertToGroupExpense?(draft, [group])"),
                "«Guardar» con grupo tiene que convertir con ESE grupo (un solo grupo: form directo).")
        #expect(source.contains("isDisabled: !canSave"))
    }

    @Test func recurrente_viveEnElMenuDeArriba_noBajoGuardar() throws {
        let source = try Self.code(Self.editor)
        let menu = try #require(source.range(of: "private var toolbarContent"))
        let more = try #require(source.range(of: "\"draft_editor_more\""))
        let recurring = try #require(source.range(of: "\"inbox_approve_and_make_recurring_button\""))
        #expect(menu.lowerBound < recurring.lowerBound && recurring.lowerBound < more.lowerBound,
                "«Guardar y hacer recurrente» tiene que ir dentro del menú «…».")
        #expect(source.components(separatedBy: "approveAndMakeRecurring").count == 2,
                "«Guardar y hacer recurrente» sale una sola vez: en el menú.")
        let actions = try #require(source.range(of: "private var actionButtons"))
        let afterActions = String(source[actions.lowerBound...])
        #expect(!afterActions.contains("approvesIntoRecurring = true"), "Volvió el enlace del recurrente abajo.")
    }
}

@Suite("Bandeja · chip de grupo — textos")
struct BandejaChipGrupoTextosTests {

    private static let locales = [
        "de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl", "pt-BR", "pt-PT", "pt",
        "zh-Hans",
    ]

    @Test(arguments: locales)
    func laTablaTieneLasTresClaves(_ locale: String) throws {
        let path = try #require(Bundle(for: BundleMarker.self).path(forResource: locale, ofType: "lproj")
            ?? Bundle.main.path(forResource: locale, ofType: "lproj"))
        let table = try #require(Bundle(path: path))
        for key in ["bandejaChipGrupo.chip", "bandejaChipGrupo.chipHint", "bandejaChipGrupo.none"] {
            let value = table.localizedString(forKey: key, value: "__FALTA__", table: L10n.BandejaChipGrupo.tabla)
            #expect(value != "__FALTA__" && !value.isEmpty, "Falta \(key) en \(locale).")
        }
    }
}

private final class BundleMarker {}
