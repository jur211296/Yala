//
//  CorreosDelBancoGuiaTests.swift
//  YalaTests
//
//  Guía de «Correo del banco» (pedido de Jürgen del 2026-11-23): un paso hecho se puede volver a abrir —un «Hecho»
//  tocado sin querer ya no deja el paso cerrado—, el avance reabierto se guarda, la guía lo ofrece en cada paso hecho,
//  la dirección se copia desde la cabecera en cualquier paso, y los textos nuevos están en los 16 idiomas.
//

import Foundation
import Testing

@testable import Yala

struct CorreosDelBancoGuiaReopenTests {

    /// Llegó al paso 3 de 5 sin querer: tocar el 1 lo deja activo y el 2 vuelve a pendiente.
    @Test func reopeningAnEarlierStep_makesItActiveAndTheLaterOnesPending() {
        var progress = StepGuideProgress(total: 5, completed: 2)
        progress.reopen(0)
        #expect(progress.activeIndex == 0)
        #expect(progress.completed == 0)
        #expect((0..<5).map(progress.phase(of:)) == [.active, .upcoming, .upcoming, .upcoming, .upcoming])
        #expect(progress.displayedStep == 1)
        #expect(progress.remaining == 5)
    }

    @Test func reopeningTheLastDoneStep_goesBackOneStep() {
        var progress = StepGuideProgress(total: 5, completed: 3)
        progress.reopen(2)
        #expect(progress.activeIndex == 2)
        #expect((0..<5).map(progress.phase(of:)) == [.done, .done, .active, .upcoming, .upcoming])
    }

    /// Con la guía terminada también se puede volver: el pie deja de ofrecer «Listo» hasta rehacerlo.
    @Test func reopeningAFinishedGuide_leavesItUnfinished() {
        var progress = StepGuideProgress(total: 3, completed: 3)
        #expect(progress.isFinished)
        progress.reopen(1)
        #expect(!progress.isFinished)
        #expect(progress.activeIndex == 1)
    }

    /// Solo se vuelve a un paso hecho: ni al activo, ni a uno pendiente, ni fuera de rango.
    @Test(arguments: [2, 3, 4, 5, -1])
    func reopeningAStepThatIsNotDone_changesNothing(index: Int) {
        var progress = StepGuideProgress(total: 5, completed: 2)
        progress.reopen(index)
        #expect(progress.completed == 2)
        #expect(progress.activeIndex == 2)
    }

    @Test func canReopen_onlyTheDoneSteps() {
        let progress = StepGuideProgress(total: 4, completed: 2)
        #expect((-1..<5).map(progress.canReopen) == [false, true, true, false, false, false])
    }

    /// Reabrir y volver a avanzar: «Hecho» sigue avanzando de uno en uno desde el paso reabierto.
    @Test func afterReopening_completingAdvancesFromThatStep() {
        var progress = StepGuideProgress(total: 5, completed: 4)
        progress.reopen(0)
        progress.complete(0)
        #expect(progress.activeIndex == 1)
        // Un toque tardío sobre el paso que se rehízo no se salta el siguiente.
        progress.complete(0)
        #expect(progress.activeIndex == 1)
    }

    /// «Tu avance se guarda» vale también para lo reabierto: salir y volver deja la guía en el paso reabierto.
    @Test func reopenedProgress_isSavedAndLoadedBack() {
        let defaults = makeIsolatedDefaults(prefix: "correosGuia")
        let guide = StepGuideProgressStore.bankEmailGmail
        var progress = StepGuideProgress(total: 5, completed: 3)
        StepGuideProgressStore.save(progress, guideID: guide, defaults: defaults)
        progress.reopen(1)
        StepGuideProgressStore.save(progress, guideID: guide, defaults: defaults)
        let loaded = StepGuideProgressStore.load(guide, total: 5, defaults: defaults)
        #expect(loaded.activeIndex == 1)
        #expect(loaded.completed == 1)
    }
}

/// El cableado en las vistas: source-scan, porque la guía es SwiftUI y lo que se fija es dónde se ofrece la vuelta.
struct CorreosDelBancoGuiaWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cada paso hecho lleva «Volver a este paso» y la fila entera reabre: vale para las tres guías.
    @Test func everyDoneStep_offersToGoBackToIt() throws {
        let guide = try Self.source("Yala/App/DesignSystem/StepGuide.swift")
        #expect(guide.contains("if phase == .done {\n                reopenButton(index: index)"))
        #expect(guide.contains("step_guide_reopen_\\(index)"))
        #expect(guide.contains("if progress.canReopen(index) { reopen(index) }"))
        #expect(guide.contains("progress.reopen(index)"))
        // Lo reabierto se guarda, como lo avanzado.
        let reopenBody = try #require(guide.range(of: "private func reopen(_ index: Int) {"))
        let tail = guide[reopenBody.upperBound...].prefix(400)
        #expect(tail.contains("StepGuideProgressStore.save(progress, guideID: progressID)"))
    }

    /// La dirección se copia desde la cabecera, en cualquier paso, y los pasos usan la tabla nueva.
    @Test func bankEmailGuide_copiesFromTheHeader_andUsesTheNewTexts() throws {
        let view = try Self.source("Yala/App/Views/Settings/BankEmailForwardingView.swift")
        #expect(view.contains("accessory: model.info.map { AnyView(BankEmailGuideCopyButton(address: $0.address)) }"))
        #expect(view.contains("bank_email_guide_copy"))
        for old in ["stepCopyTitle", "gmailAddDetail", "gmailFilterDetail", "outlookRuleDetail", "icloudRuleDetail",
                    "stepWaitDetail", "gmailConfirmWaiting", "BankEmail.guideLine"] {
            #expect(!view.contains("L10n.BankEmail.\(old)"), "La guía sigue con el texto viejo «\(old)».")
        }
        // Los pasos del filtro o la regla empiezan diciendo cómo encontrar la dirección del banco.
        #expect(view.components(separatedBy: "CorreosBancoGuia.findBank + ").count - 1 == 3)
    }
}

/// Los textos nuevos, en los 16 idiomas y sin hueco: la tabla propia no la cubre la paridad de `Localizable.strings`.
struct CorreosDelBancoGuiaTextosTests {

    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Yala/Resources")

    private static func table(_ code: String) -> [String: String] {
        let url = resources.appendingPathComponent("\(code).lproj/CorreosBancoGuia.strings")
        return (NSDictionary(contentsOf: url) as? [String: String]) ?? [:]
    }

    @Test(arguments: SupportedLocale.allCases.map(\.code))
    func everyKey_isInEveryLanguage(_ code: String) {
        let strings = Self.table(code)
        for key in L10n.CorreosBancoGuia.keys {
            let value = strings["correosGuia.\(key)"]
            #expect(value?.isEmpty == false, "\(code): falta «correosGuia.\(key)»")
        }
        #expect(strings.count == L10n.CorreosBancoGuia.keys.count, "\(code): claves de más o de menos")
    }

    /// El código de Gmail se inserta en todos los idiomas.
    @Test(arguments: SupportedLocale.allCases.map(\.code))
    func gmailCode_hasItsPlaceholder(_ code: String) {
        #expect(Self.table(code)["correosGuia.gmail.confirm.code"]?.contains("%@") == true, "\(code)")
    }

    /// Los pasos nombran los botones de la guía tal como se ven en ese idioma («Copiar dirección», «Abrir Gmail»…).
    @Test(arguments: SupportedLocale.allCases.map(\.code))
    func steps_nameTheGuideButtonsAsShown(_ code: String) {
        let strings = Self.table(code)
        let main = StringsFileParser.parseStrings(forLocale: code)
        let copy = main["bankEmail.copyAddress"]
        let open = main["bankEmail.openProvider"].map { String(format: $0, "Gmail") }
        let check = main["bankEmail.checkCode"]
        let copyCode = main["bankEmail.copyCode"]
        if let copy { #expect(strings["correosGuia.copy.detail"]?.contains(copy) == true, "\(code): «\(copy)»") }
        if let open { #expect(strings["correosGuia.gmail.add.detail"]?.contains(open) == true, "\(code): «\(open)»") }
        if let check {
            #expect(strings["correosGuia.gmail.confirm.waiting"]?.contains(check) == true, "\(code): «\(check)»")
        }
        if let copyCode {
            #expect(strings["correosGuia.gmail.confirm.code"]?.contains(copyCode) == true, "\(code): «\(copyCode)»")
        }
    }

    /// es-419 en español neutro: sin voseo ni vocabulario de España.
    @Test func neutralSpanish_hasNoVoseoNorSpainWords() {
        let text = Self.table("es-419").values.joined(separator: " ")
        for word in ["Tocá", "tenés", "Añad", "vosotros", "móvil", "ordenador"] {
            #expect(!text.contains(word), "es-419 dice «\(word)»")
        }
    }

    /// es y pt son copia de es-419 y pt-BR, como en el resto del catálogo.
    @Test func baseLanguages_copyTheirReference() {
        #expect(Self.table("es") == Self.table("es-419"))
        #expect(Self.table("pt") == Self.table("pt-BR"))
    }
}
