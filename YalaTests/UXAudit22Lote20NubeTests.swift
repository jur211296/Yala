//
//  UXAudit22Lote20NubeTests.swift
//  YalaTests
//
//  Las decisiones de Jürgen sobre nube e iCloud del lote 20 de la auditoría UX 2.2 (L20-11…18). La lógica pura se prueba
//  por comportamiento; el cableado de las pantallas (qué abre cada toque, qué ya no se pinta) con source-scans acotados
//  a cuerpos enteros, el molde de `MigrationIdentityGateWiringTests`: son `View`s sin salida asertable.
//

import Foundation
import Testing

@testable import Yala

// MARK: - L20-18 · qué dice cada «reabre Yala»

@MainActor
@Suite("L20-18 · reabrir Yala: los checks son verdad en su caso")
struct RelaunchChecklistCopyLogicTests {

    @Test("la ida y el adopt: los datos ya están en la cuenta de la nube, sin frase de después")
    func forward_saysTheDataIsInTheCloudAccount() {
        let copy = RelaunchChecklistCopyLogic.storage(direction: .toCloud, reverseAborted: false)
        #expect(copy.title == L10n.UXL20N.relaunchAlmostTitle)
        #expect(copy.done == [L10n.UXL20N.relaunchDoneInCloud])
        #expect(copy.afterNote == nil)
    }

    @Test("la vuelta: los datos ya bajaron a este iPhone y suben a iCloud al reabrir")
    func reverse_saysTheDataIsOnThePhone_andUploadsAfter() {
        let copy = RelaunchChecklistCopyLogic.storage(direction: .toICloud, reverseAborted: false)
        #expect(copy.title == L10n.UXL20N.relaunchAlmostTitle)
        #expect(copy.done == [L10n.UXL20N.relaunchDoneOnPhone])
        #expect(copy.afterNote == L10n.UXL20N.relaunchAfterToICloud)
        // `reverseAborted` solo existe en la ida: la vuelta no lo mira.
        #expect(RelaunchChecklistCopyLogic.storage(direction: .toICloud, reverseAborted: true) == copy)
    }

    @Test("la vuelta cancelada: los datos siguen en la nube y no dice «ya casi está»")
    func reverseAborted_keepsTheCloudTitle_andSaysTheReturnStopped() {
        let copy = RelaunchChecklistCopyLogic.storage(direction: .toCloud, reverseAborted: true)
        #expect(copy.title == L10n.Storage.ReverseAbort.relaunchTitle)
        #expect(copy.done == [L10n.UXL20N.relaunchDoneReverseStopped])
        #expect(copy.afterNote == nil)
    }

    @Test("con botón de inicio, el primer paso es la doble pulsación; los otros dos no cambian")
    func homeButton_changesOnlyTheFirstStep() {
        let swipe = RelaunchSteps.steps(hasHomeButton: false).map(\.text)
        let home = RelaunchSteps.steps(hasHomeButton: true).map(\.text)
        #expect(swipe.first == L10n.UXL20N.relaunchStep1)
        #expect(home.first == L10n.UXL20N.relaunchStep1HomeButton)
        #expect(Array(swipe.dropFirst()) == Array(home.dropFirst()))
    }

    @Test("los tres pasos, numerados y en orden, para el aviso «iCloud ya disponible»")
    func inlineSteps_areTheThreeStepsNumbered() {
        let lines = RelaunchSteps.inlineText.split(separator: "\n").map(String.init)
        #expect(lines == RelaunchSteps.all.enumerated().map { "\($0.offset + 1). \($0.element.text)" })
        #expect(lines.count == 3)
        #expect(RelaunchSteps.all.map(\.text).dropFirst().elementsEqual([L10n.UXL20N.relaunchStep2,
                                                                       L10n.UXL20N.relaunchStep3]))
    }
}

// MARK: - L20-14 · el detalle técnico viaja en el correo

@Suite("L20-14 · «Contacta con nosotros» lleva el código en el cuerpo")
struct SupportMailBodyTests {

    @Test("con cuerpo: asunto y cuerpo, los dos codificados")
    func url_withBody_encodesBoth() throws {
        let url = try #require(SupportMailLinkLogic.url(
            to: "admin@yala-app.pe", subject: "Yala: iCloud no sincroniza", body: "Detalle técnico: CKError.3"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.first { $0.name == "subject" }?.value == "Yala: iCloud no sincroniza")
        #expect(items.first { $0.name == "body" }?.value == "Detalle técnico: CKError.3")
        #expect(url.absoluteString.hasPrefix("mailto:admin@yala-app.pe?"))
    }

    @Test("sin cuerpo: el enlace de siempre, solo con asunto")
    func url_withoutBody_isTheOldOne() throws {
        let url = try #require(SupportMailLinkLogic.url(to: "admin@yala-app.pe", subject: "Asunto"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.map(\.name) == ["subject"])
    }
}

// MARK: - Los textos, por idioma

@Suite("L20-11 · «Pasarán N registros, N cuentas y N presupuestos» con su plural")
struct UXAudit22Lote20NubeStringsTests {

    private func bundle(_ code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }

    private func plural(_ key: String, _ code: String, _ n: Int) throws -> String {
        let b = try #require(bundle(code), "Falta \(code).lproj")
        let format = b.localizedString(forKey: key, value: "__FALTA__", table: nil)
        return String(format: format, locale: Locale(identifier: code), arguments: [n])
    }

    @Test("es-419: singular y plural de cada cifra")
    func spanish_pluralizesEachCount() throws {
        #expect(try plural("l20n.count.records", "es-419", 1) == "1 registro")
        #expect(try plural("l20n.count.records", "es-419", 32) == "32 registros")
        #expect(try plural("l20n.count.accounts", "es-419", 1) == "1 cuenta")
        #expect(try plural("l20n.count.budgets", "es-419", 6) == "6 presupuestos")
    }

    @Test("en: singular y plural")
    func english_pluralizes() throws {
        #expect(try plural("l20n.count.records", "en", 1) == "1 record")
        #expect(try plural("l20n.count.accounts", "en", 2) == "2 accounts")
    }

    @Test("pl: las cuatro formas")
    func polish_hasItsFourForms() throws {
        #expect(try plural("l20n.count.records", "pl", 1) == "1 wpis")
        #expect(try plural("l20n.count.records", "pl", 3) == "3 wpisy")
        #expect(try plural("l20n.count.records", "pl", 5) == "5 wpisów")
    }

    @Test("«registros» y no «movimientos» (L7-18) en las frases nuevas en español")
    func spanish_saysRecords() throws {
        for code in ["es-419", "es-ES", "es-AR", "es"] {
            let b = try #require(bundle(code))
            for key in ["l20n.sheet.willMove", "l20n.sheet.accessDetail", "l20n.sheet.exportCopy"] {
                let value = b.localizedString(forKey: key, value: "__FALTA__", table: nil)
                #expect(!value.lowercased().contains("movimiento"), "\(code) · \(key): «\(value)»")
            }
        }
    }

    @Test("ningún texto nuevo nombra al proveedor de IA")
    func noNewTextNamesTheAIProvider() throws {
        for code in ["es-419", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "pt-BR", "pt-PT", "nl", "pl", "ja",
                     "zh-Hans", "es", "pt"] {
            // El FUENTE del repo: el `.strings` del bundle va compilado a plist binario.
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Yala/Resources/\(code).lproj/Localizable.strings")
            let text = try String(contentsOf: source, encoding: .utf8)
            for line in text.split(separator: "\n") where line.hasPrefix("\"l20n.") {
                #expect(!line.lowercased().contains("openai"), "\(code): \(line)")
            }
        }
    }
}

// MARK: - El cableado de las pantallas

@Suite("L20-11…17 · el cableado de las pantallas")
struct UXAudit22Lote20NubeWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// El fichero sin sus líneas de comentario: los docblocks citan a propósito lo que ya no está.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func body(of marker: String, in source: String) throws -> [String] {
        let start = try #require(source.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n")
            .map { line -> String in
                var code = String(line)
                if let comment = code.range(of: "//") { code = String(code[..<comment.lowerBound]) }
                return code.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    private static let storage = "Yala/App/Views/Settings/StorageSettingsView.swift"
    private static let sheet = "Yala/App/Views/Settings/CloudActivationSheet.swift"
    private static let icloud = "Yala/App/Views/Settings/iCloudSyncSettingsView.swift"
    private static let alerts = "Yala/App/Views/Shared/ShellDataAlertsModifier.swift"
    private static let appleID = "Yala/App/Views/Shared/AppleIDCloseNoticeView.swift"

    @Test("L20-11: activar ya no pasa por el consentimiento suelto ni por «¿Activar la nube?» / «¿Seguro?»")
    func storage_hasNoMigrateConfirmations_andMountsTheSingleSheet() throws {
        let src = try Self.code(Self.storage)
        #expect(!src.contains("L10n.Storage.Confirm.migrateTitle"))
        #expect(!src.contains("L10n.Storage.Confirm.migrate2Title"))
        #expect(!src.contains("CloudConsentView("), "la pantalla volvió a montar el consentimiento suelto")
        #expect(src.contains(".sheet(item: $activationRequest, onDismiss: onActivationSheetDismissed) { request in"))
        #expect(!src.contains("L10n.Storage.Migrate.previewButton"), "«Ver qué migraría» volvió a la tarjeta")
    }

    @Test("L20-11: la hoja arranca solo con el plan que quemó su botón, y con la hoja ya abajo")
    func storage_sheetDismissStartsOnlyWithAPlan() throws {
        let dismissed = try Self.body(of: "private func onActivationSheetDismissed() {", in: try Self.code(Self.storage))
        #expect(Array(dismissed.prefix(7)) == [
            "guard let plan = activationPlan else { return }",
            "activationPlan = nil",
            "guard !abortIfCloudEntryClosed() else { return }",
            "guard let controller, controller.uiState == .idle, !controller.isWorking else { return }",
            "let path = consentPath",
            "guard path != .bornCloud else { return }",
            "switch signInDecision(isAdopt: path == .adopt) {",
        ])
        // Solo `startActivation` arranca, y solo en dos ramas: con sesión viva y con el proveedor elegido.
        #expect(dismissed.filter { $0.hasPrefix("startActivation(") } == [
            "startActivation(path, .reuseLiveSession)",
            "startActivation(path, plan)",
        ])
        let sheetBody = try Self.body(
            of: ".sheet(item: $activationRequest, onDismiss: onActivationSheetDismissed) { request in",
            in: try Self.code(Self.storage))
        #expect(sheetBody.contains("activationPlan = plan"))
        #expect(sheetBody.contains("activationRequest = nil"))
        // Lo que enseña la hoja viaja DENTRO del `item`: con otro `@State` leído en el cierre, la primera vez salía vacía.
        #expect(sheetBody.contains("preview: request.preview,"))
        #expect(sheetBody.contains("path: request.path,"))
        #expect(!sheetBody.contains(where: { $0.contains("startActivation") || $0.contains("startMigration") }),
                "la hoja arrancaba la migración con ella misma arriba")
    }

    @Test("L20-11: abrir la hoja re-mide la entrada (kill-switch y App Attest)")
    func storage_presentingTheSheetRechecksTheEntry() throws {
        let present = try Self.body(
            of: "private func presentActivationSheet(_ controller: CloudMigrationController, isAdopt: Bool) {",
            in: try Self.code(Self.storage))
        #expect(present.first == "guard !abortIfCloudEntryClosed() else { return }")
    }

    @Test("L20-11/12: tocar «Continuar con…» registra el consentimiento ANTES de seguir")
    func sheet_acceptRegistersConsentFirst() throws {
        let accept = try Self.body(of: "private func accept(_ plan: CloudMigrationController.SignInPlan) {",
                                   in: try Self.code(Self.sheet))
        #expect(accept == [
            "CloudConsentRegistrar.register()",
            "MetricsService.cloudConsentAccepted(path: path.rawValue)",
            "onContinue(plan)",
        ])
    }

    @Test("L20-11: con sesión viva, un solo botón; nunca los dos proveedores")
    func sheet_liveSessionShowsOneButton() throws {
        let footer = try Self.body(of: "private var footer: some View {", in: try Self.code(Self.sheet))
        let ask = try #require(footer.firstIndex(of: "case .askProvider:"))
        let live = try #require(footer.firstIndex(of: "case .reuseLiveSession(let provider):"))
        #expect(Array(footer[(ask + 1)..<live]) == ["providerButton(.apple)", "providerButton(.google)"])
        let blocked = try #require(footer.firstIndex(of: "case .blockedOtherAccount:"))
        let liveBranch = Array(footer[(live + 1)..<blocked])
        #expect(liveBranch.filter { $0.hasPrefix("providerButton(") } == ["providerButton(provider)"])
    }

    @Test("L20-17: una sola confirmación para volver a iCloud, con su «Cancelar» visible")
    func storage_revertHasOneConfirmation() throws {
        let src = try Self.code(Self.storage)
        #expect(!src.contains("L10n.Storage.Confirm.revert2Title"))
        #expect(src.components(separatedBy: ".confirmationDialog(L10n.Storage.Confirm.revertTitle,").count - 1 == 1)
        let modifier = try Self.body(of: "private struct StorageConfirmations: ViewModifier {", in: src)
        #expect(modifier.contains("Button(L10n.Storage.Confirm.revert2Confirm, role: .destructive) { onRevert() }"))
        #expect(modifier.contains("Button(L10n.Common.cancel) {}"), "el «Cancelar» de no hacer nada, sin rol (B6)")
        #expect(!modifier.contains(where: { $0.contains("role: .cancel") }))
    }

    /// L20-15 (opción B de Jürgen, 2026-10-23): «Datos no disponibles» es una hoja, con «Seguir esperando» ARRIBA y relleno
    /// y «Empezar de cero» debajo, en rojo. Cada elección corre su salida de siempre, en el `onDismiss` de la hoja.
    @Test("L20-15: la hoja pone «Seguir esperando» primero y relleno; cada elección corre su salida de siempre al cerrarse")
    func remoteWipe_sheetOrderAndActions() throws {
        let alerts = try Self.code(Self.alerts)
        #expect(!alerts.contains(".alert(L10n.iCloud.remoteWipeTitle"), "volvió el aviso del sistema")
        #expect(!alerts.contains(".sheet("), "la hoja volvió a `ShellDataAlertsModifier`, donde no llega a presentarse")

        let view = try Self.code("Yala/App/ContentView.swift")
        #expect(view.contains("""
            .modifier(RemoteWipeNoticeSheetModifier(
                        isPresented: $showRemoteWipeAlert,
                        noticePending: remoteWipeNoticePending,
                        onAnswered: { answerRemoteWipeNotice() },
                        onStartFreshChosen: { startFreshAfterRemoteWipeNotice() },
                        onKeepWaitingChosen: { dismissRemoteWipeNotice() }))
            """))

        let sheet = try Self.code("Yala/App/Views/Shared/RemoteWipeNoticeSheet.swift")
        let run = try Self.body(of: "private func runChoice() {", in: sheet)
        let guardLine = try #require(run.firstIndex(of: "guard noticePending else { return }"))
        let switchLine = try #require(run.firstIndex(of: "switch picked {"))
        #expect(guardLine < switchLine, "con la condición ya soltada (la señal llegó antes del cierre) no corre ninguna salida")
        #expect(run.contains("case .startFresh: onStartFreshChosen()"))
        #expect(run.contains("case .keepWaiting: onKeepWaitingChosen()"))
        #expect(run.contains("case nil: break"), "sin elección, el cierre no debe ejecutar ninguna salida")
        let choose = try Self.body(of: "private func choose(_ picked: RemoteWipeNoticeSheet.Choice) {", in: sheet)
        #expect(choose == ["guard choice == nil else { return }", "choice = picked", "onAnswered()"],
                "tocar un botón apunta la PRIMERA elección y cierra la hoja, nada más")

        let keep = try #require(sheet.range(of: "YalaPrimaryButton(L10n.iCloud.remoteWipeCancel) { onChoose(.keepWaiting) }"))
        let startFresh = try #require(sheet.range(of: "onChoose(.startFresh)"))
        #expect(keep.lowerBound < startFresh.lowerBound, "«Seguir esperando» dejó de ir primero")
        #expect(sheet.contains("Button(role: .destructive) {"), "«Empezar de cero» dejó de ir en rojo")
        #expect(sheet.contains(".interactiveDismissDisabled()"), "un deslizamiento no dice cuál de las dos salidas era")
    }

    /// Al tocar, la hoja se cierra y la red de presentación se para, pero la condición viva SIGUE puesta hasta el
    /// `onDismiss`: si se soltara al tocar, el router drenaría otra presentación al mismo ancla mientras la hoja se va.
    @Test("L20-15: contestar la hoja cierra y para la red sin soltar la condición viva, con respaldo si no hay onDismiss")
    func remoteWipe_answerKeepsTheMatrixUntilDismiss() throws {
        let view = try Self.code("Yala/App/ContentView.swift")
        let answer = try Self.body(of: "private func answerRemoteWipeNotice() {", in: view)
        #expect(answer.first == "remoteWipeNoticeNetTask?.cancel()")
        #expect(answer.last == "showRemoteWipeAlert = false")
        #expect(!answer.contains("remoteWipeNoticePending = false"), "contestar soltó la condición viva antes del onDismiss")
        // El respaldo: si el `onDismiss` no llega, se suelta como «Seguir esperando» (no borra), con su canario.
        #expect(answer.contains("guard remoteWipeNoticePending, !ModalPresentationProbe.isAnythingPresented else { return }"))
        #expect(answer.contains("dismissRemoteWipeNotice()"))
        #expect(!answer.contains("startFreshAfterRemoteWipeNotice()"), "el respaldo nunca puede borrar")
    }

    @Test("L20-16: «Exportar mis registros» va entre «Ahora no» y «Cerrar sesión y quitarlos», y no cierra nada")
    func appleID_exportBeforeTheDestructiveExit() throws {
        let src = try Self.code(Self.appleID)
        let later = try #require(src.range(of: "YalaPrimaryButton(L10n.iCloud.appleIDChangedLater) { later() }"))
        let export = try #require(src.range(of: "YalaSecondaryButton(L10n.Settings.signOutAttestExportButton"))
        let close = try #require(src.range(of: "Text(L10n.iCloud.appleIDChangedConfirm)"))
        #expect(later.lowerBound < export.lowerBound && export.lowerBound < close.lowerBound)
        let exportBody = try Self.body(of: "private func exportEverything() {", in: src)
        #expect(!exportBody.contains(where: { $0.contains("requestClose") || $0.contains("notice =") }),
                "exportar tocó el aviso o arrancó el cierre")
        #expect(exportBody.contains(where: { $0.contains("scheduleTagBackfill: false)") }))
    }

    @Test("L20-14: sin «Ver detalle técnico» en pantalla; el código solo dentro del correo")
    func icloud_technicalCodeOnlyInTheMail() throws {
        let src = try Self.code(Self.icloud)
        #expect(!src.contains("L10n.iCloud.Detail.CTA.viewTechnical"))
        #expect(src.components(separatedBy: "L10n.iCloud.Detail.technicalCode(").count - 1 == 1)
        let contact = try Self.body(of: "private func contactSection(code: String) -> some View {", in: src)
        #expect(contact.contains("body: L10n.iCloud.Detail.technicalCode(code)) {"))
        #expect(src.contains("YalaSettingsList {"), "la pantalla dejó de ser una lista agrupada")
    }

    @Test("L20-14: sin cuenta no promete iCloud y ofrece abrir los Ajustes")
    func icloud_noAccountIsCoherent() throws {
        let body = try Self.body(of: "var body: some View {", in: try Self.code(Self.icloud))
        let account = try #require(body.firstIndex(of: "if showsNoAccount {"))
        #expect(body[account + 1] == "noAccountSection")
        #expect(body[account + 2] == "} else {")
        #expect(body[account + 3] == "forceSyncSection")
        // La descripción («se sincronizan automáticamente con iCloud») solo con cuenta, por el MISMO predicado.
        let description = try #require(body.firstIndex(of: "Text(L10n.iCloud.description)"))
        let gate = try #require(body.firstIndex(of: "if !showsNoAccount {"))
        #expect(gate < description)
        let predicate = try Self.body(of: "private var showsNoAccount: Bool {", in: try Self.code(Self.icloud))
        #expect(predicate == ["!syncService.isAccountAvailable || syncService.status.isNoAccount"])
        let noAccount = try Self.body(of: "private var noAccountSection: some View {", in: try Self.code(Self.icloud))
        #expect(noAccount.contains("guard let url = URL(string: UIApplication.openSettingsURLString) else { return }"))
    }
}
