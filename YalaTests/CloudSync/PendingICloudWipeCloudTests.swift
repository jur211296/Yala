//
//  PendingICloudWipeCloudTests.swift
//  YalaTests / CloudSync
//
//  Ticket `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud` (decisión A de Jürgen, 2026-10-04:
//  «avisar o bloquear en la migración; no tragarse el borrado de iCloud pendiente en silencio al pasar a la nube»).
//
//  Hasta este ticket, quien pedía borrar su iCloud y activaba la nube antes de que el borrado terminara lo perdía sin
//  enterarse: ni la migración ni el adopt miraban el arm, y el arranque en `.cloud` lo retiraba en silencio
//  (`lateWipeLaunch` → `.retireInCloud`). Ahora:
//   · la puerta de Ajustes pregunta antes de activar la nube («Activar la nube sin borrar» / «Ahora no»), y lo elegido
//     es una RENUNCIA durable: el borrado no se retira hasta que el dispositivo llega a `.cloud`, y si el intento termina
//     en iCloud la renuncia caduca (la primera versión lo retiraba al arrancar la migración y lo perdía en silencio en
//     cada salida previa al cutover: lo cazaron las tres lentes de la review del 2026-10-04);
//   · mientras la migración está en vuelo, el arranque en iCloud no reanuda ni pregunta por el borrado;
//   · el arranque en la nube lo sigue retirando —terminarlo se llevaría los datos de la cuenta— pero lo cuenta una vez,
//     con una marca durable que sobrevive a un kill y que la hoja consume al montar.
//
//  Tres suites: la lógica pura del arranque, las marcas durables con un `UserDefaults` propio, y el cableado (source-scan
//  sin comentarios) de las tres pantallas que lo sostienen.
//

import Foundation
import Testing
@testable import Yala

@Suite("Borrado de iCloud pendiente y la nube · la lógica")
struct PendingICloudWipeCloudLogicTests {

    typealias Logic = WelcomePrivateICloudGateLogic

    private static func expected(armed: Bool, leftHalfway: Bool, notice: Bool, waived: Bool, atRest: Bool,
                                 mode: StorageMode) -> Logic.LateWipeLaunch {
        switch mode {
        case .cloud:
            if armed || leftHalfway { return waived ? .retireWaivedInCloud : .retireInCloud }
            return notice ? .tellCancelledInCloud : .none
        case .icloud:
            if (armed || leftHalfway) && !atRest { return .holdForMigration }
            if armed { return .resume }
            return leftHalfway ? .askLeftHalfway : .none
        }
    }

    /// La tabla entera, 64 celdas: un término mal puesto decide si un borrado se reanuda en mitad de la migración, si se
    /// retira en silencio o si se cuenta dos veces.
    @Test(arguments: [false, true], [false, true])
    func launch_fullTable(armed: Bool, leftHalfway: Bool) {
        for notice in [false, true] {
            for waived in [false, true] {
                for atRest in [false, true] {
                    for mode in [StorageMode.cloud, .icloud] {
                        let got = Logic.lateWipeLaunch(armed: armed, leftHalfway: leftHalfway,
                                                       cancelledInCloudNoticePending: notice, waivedForCloud: waived,
                                                       migrationAtRest: atRest, storageMode: mode)
                        #expect(got == Self.expected(armed: armed, leftHalfway: leftHalfway, notice: notice,
                                                     waived: waived, atRest: atRest, mode: mode),
                                "armed=\(armed) halfway=\(leftHalfway) notice=\(notice) waived=\(waived) atRest=\(atRest) \(mode)")
                    }
                }
            }
        }
    }

    /// **EL PIN DEL TICKET.** En la nube, un borrado pendiente sin renuncia se retira CONTÁNDOLO.
    @Test func cloud_withoutWaiver_retiresAndTells() {
        #expect(Logic.lateWipeLaunch(armed: true, leftHalfway: false, cancelledInCloudNoticePending: false,
                                     waivedForCloud: false, migrationAtRest: false, storageMode: .cloud) == .retireInCloud)
    }

    /// Con la renuncia de Ajustes, sin contarlo otra vez.
    @Test func cloud_withWaiver_retiresSilently() {
        #expect(Logic.lateWipeLaunch(armed: false, leftHalfway: true, cancelledInCloudNoticePending: false,
                                     waivedForCloud: true, migrationAtRest: false, storageMode: .cloud) == .retireWaivedInCloud)
    }

    /// **El hallazgo de la review.** Con la ida en vuelo, ni se reanuda ni se pregunta: sin esto, la renuncia que
    /// conserva el arm hasta el cutover dejaba al arranque borrar el corpus en mitad de la subida.
    @Test func icloud_migrationInFlight_holdsThePendingWipe() {
        for (armed, halfway) in [(true, false), (false, true), (true, true)] {
            #expect(Logic.lateWipeLaunch(armed: armed, leftHalfway: halfway, cancelledInCloudNoticePending: false,
                                         waivedForCloud: true, migrationAtRest: false,
                                         storageMode: .icloud) == .holdForMigration, "armed=\(armed) halfway=\(halfway)")
        }
    }

    /// Un aviso pendiente de un arranque que murió antes de enseñarlo se vuelve a contar — solo en la nube.
    @Test func noticePending_isToldOnlyInTheCloud() {
        #expect(Logic.lateWipeLaunch(armed: false, leftHalfway: false, cancelledInCloudNoticePending: true,
                                     waivedForCloud: false, migrationAtRest: true, storageMode: .cloud) == .tellCancelledInCloud)
        #expect(Logic.lateWipeLaunch(armed: false, leftHalfway: false, cancelledInCloudNoticePending: true,
                                     waivedForCloud: false, migrationAtRest: true, storageMode: .icloud) == .none)
    }

    @Test(arguments: [false, true], [false, true])
    func waiverLapses_onlyInICloudAtRest(waived: Bool, atRest: Bool) {
        #expect(Logic.waiverLapses(waivedForCloud: waived, migrationAtRest: atRest, storageMode: .icloud)
                == (waived && atRest))
        #expect(!Logic.waiverLapses(waivedForCloud: waived, migrationAtRest: atRest, storageMode: .cloud),
                "en la nube la renuncia la consume el retiro, no caduca")
    }

    @Test func cancelledNoticeLapses_onlyInICloud() {
        #expect(Logic.cancelledNoticeLapses(noticePending: true, storageMode: .icloud))
        #expect(!Logic.cancelledNoticeLapses(noticePending: true, storageMode: .cloud))
        #expect(!Logic.cancelledNoticeLapses(noticePending: false, storageMode: .icloud))
    }

    @Test func notice_identityIsItsOwn() {
        #expect(LateICloudNotice.wipeCancelledInCloud.id != LateICloudNotice.wipeLeftHalfway.id)
        #expect(LateICloudNotice.wipeCancelledInCloud.id != LateICloudNotice.corpus(.empty).id)
    }
}

@Suite("Borrado de iCloud pendiente y la nube · las marcas")
struct PendingICloudWipeCloudFlagsTests {

    private func freshDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "PendingICloudWipeCloudFlagsTests.\(UUID().uuidString)"))
    }

    @Test func pending_isTheArmOrTheHalfwayMark() throws {
        let none = try freshDefaults()
        #expect(!StorageModePersistence.hasPendingICloudCorpusWipe(none))

        let armed = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(armed)
        #expect(StorageModePersistence.hasPendingICloudCorpusWipe(armed))

        let halfway = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(halfway)
        StorageModePersistence.markICloudCorpusWipeZoneDone(halfway)
        StorageModePersistence.leaveICloudCorpusWipeHalfway(halfway)
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(halfway))
        #expect(StorageModePersistence.hasPendingICloudCorpusWipe(halfway), "«a medias» también es un borrado pendiente")
    }

    /// El arranque en la nube: retira las dos marcas Y deja apuntado el aviso. Sin el apunte, el bug del ticket.
    @Test(arguments: [false, true])
    func cancelInTheCloud_retiresAndLeavesTheNotice(halfway: Bool) throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        if halfway {
            StorageModePersistence.markICloudCorpusWipeZoneDone(d)
            StorageModePersistence.leaveICloudCorpusWipeHalfway(d)
        }
        StorageModePersistence.cancelPendingICloudCorpusWipeInTheCloud(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(!StorageModePersistence.isICloudCorpusWipeLeftHalfway(d))
        #expect(!StorageModePersistence.isICloudCorpusWipeZoneDone(d))
        #expect(StorageModePersistence.isICloudCorpusWipeCancelledInCloudNoticePending(d), """
            el borrado se retiró sin dejar el aviso: quien lo pidió no se entera de que no se hizo
            """)
    }

    /// Sin borrado pendiente no hay nada que contar: un aviso de más diría que se canceló algo que nadie pidió.
    @Test func cancelInTheCloud_withNothingPending_leavesNoNotice() throws {
        let d = try freshDefaults()
        StorageModePersistence.cancelPendingICloudCorpusWipeInTheCloud(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeCancelledInCloudNoticePending(d))
    }

    /// **La renuncia NO retira nada**: el arm y «a medias» siguen hasta que el dispositivo llega a la nube.
    @Test func waiver_keepsThePendingWipe() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.waivePendingICloudCorpusWipeForTheCloud(d)
        #expect(StorageModePersistence.isPendingICloudCorpusWipeWaivedForTheCloud(d))
        #expect(StorageModePersistence.isICloudCorpusWipeArmed(d), "retirado al renunciar, una migración que vuelve a iCloud lo pierde")
        #expect(StorageModePersistence.isICloudCorpusWipeZoneDone(d))
    }

    /// Sin borrado pendiente no hay nada a lo que renunciar.
    @Test func waiver_needsAPendingWipe() throws {
        let d = try freshDefaults()
        StorageModePersistence.waivePendingICloudCorpusWipeForTheCloud(d)
        #expect(!StorageModePersistence.isPendingICloudCorpusWipeWaivedForTheCloud(d))
    }

    /// La renuncia sobrevive al paso a «a medias» y se va con el último borrado pendiente, como el alcance.
    @Test func waiver_diesWithThePendingWipe() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.waivePendingICloudCorpusWipeForTheCloud(d)
        StorageModePersistence.leaveICloudCorpusWipeHalfway(d)
        #expect(StorageModePersistence.isPendingICloudCorpusWipeWaivedForTheCloud(d), "«a medias» sigue pendiente")
        StorageModePersistence.clearICloudCorpusWipeLeftHalfway(d)
        #expect(!StorageModePersistence.isPendingICloudCorpusWipeWaivedForTheCloud(d), """
            una renuncia que sobrevive a su borrado silenciaría el aviso de un borrado NUEVO que llegue a la nube
            """)
    }

    /// El arranque en la nube con la renuncia: retira todo SIN dejar el aviso.
    @Test func retireAsWaived_retiresWithoutTheNotice() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.waivePendingICloudCorpusWipeForTheCloud(d)
        StorageModePersistence.retirePendingICloudCorpusWipeAsWaived(d)
        #expect(!StorageModePersistence.hasPendingICloudCorpusWipe(d))
        #expect(!StorageModePersistence.isPendingICloudCorpusWipeWaivedForTheCloud(d))
        #expect(!StorageModePersistence.isICloudCorpusWipeCancelledInCloudNoticePending(d), "doble aviso")
    }

    @Test func notice_clears() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.cancelPendingICloudCorpusWipeInTheCloud(d)
        StorageModePersistence.clearICloudCorpusWipeCancelledInCloudNotice(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeCancelledInCloudNoticePending(d))
    }

    /// `cloudSync.*`: el barrido de preferencias no la toca, así que muere con la sesión en el hook de cierre (scan abajo).
    @Test func keys_liveUnderCloudSync() {
        #expect(StorageModePersistence.icloudCorpusWipeCancelledInCloudKey.hasPrefix("cloudSync."))
        #expect(StorageModePersistence.icloudCorpusWipeWaivedForCloudKey.hasPrefix("cloudSync."))
    }
}

@Suite("Borrado de iCloud pendiente y la nube · el cableado")
struct PendingICloudWipeCloudWiringTests {

    private static let contentView = "Yala/App/ContentView.swift"
    private static let notice = "Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift"
    private static let storage = "Yala/App/Views/Settings/StorageSettingsView.swift"
    private static let flags = "Yala/Services/CloudSync/CloudSyncFlags.swift"
    private static let swiftData = "Yala/Utils/SwiftDataConfiguration.swift"

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// El fichero SIN sus líneas de comentario: los comentarios de este arreglo citan los literales que se buscan.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    private static func slice(from start: String, to end: String, in source: String) throws -> String {
        let a = try #require(source.range(of: start), "no está: \(start)")
        let b = try #require(source.range(of: end, range: a.upperBound..<source.endIndex), "no está tras \(start): \(end)")
        return String(source[a.upperBound..<b.lowerBound])
    }

    private static func expectOrder(_ first: String, before second: String, in source: String, _ why: Comment,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try #require(source.range(of: first), "no está: \(first)", sourceLocation: sourceLocation)
        let b = try #require(source.range(of: second), "no está: \(second)", sourceLocation: sourceLocation)
        #expect(a.lowerBound < b.lowerBound, why, sourceLocation: sourceLocation)
    }

    private static func occurrences(of needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    // MARK: Las marcas

    @Test("el aviso se apunta ANTES de retirar el borrado: un kill entre medias no lo pierde")
    func flags_noticeBeforeRetiring() throws {
        let cancel = try Self.body(of: "static func cancelPendingICloudCorpusWipeInTheCloud(", in: Self.code(Self.flags))
        try Self.expectOrder("guard hasPendingICloudCorpusWipe(defaults) else { return }",
                             before: "defaults.set(true, forKey: icloudCorpusWipeCancelledInCloudKey)", in: cancel,
                             "sin borrado pendiente no se apunta nada")
        try Self.expectOrder("defaults.set(true, forKey: icloudCorpusWipeCancelledInCloudKey)",
                             before: "clearICloudCorpusWipeArm(defaults)", in: cancel,
                             "retirado antes de apuntar, un kill entre las dos se lleva el borrado sin aviso")
        try Self.expectOrder("defaults.set(true, forKey: icloudCorpusWipeCancelledInCloudKey)",
                             before: "clearICloudCorpusWipeLeftHalfway(defaults)", in: cancel,
                             "retirado antes de apuntar, un kill entre las dos se lleva el borrado sin aviso")
    }

    @Test("el cierre de sesión retira el aviso pendiente: es de la vida que se cierra")
    func signOutHook_clearsTheNotice() throws {
        let hook = try Self.body(of: "static func performSignOutWipeIfArmed(\n", in: Self.code(Self.swiftData))
        #expect(hook.contains("StorageModePersistence.clearICloudCorpusWipeCancelledInCloudNotice(defaults)"), """
            la persona siguiente vería «Un borrado no llegó a terminar» por una petición que no es suya
            """)
        #expect(hook.contains("StorageModePersistence.clearICloudCorpusWipeWaiver(defaults)"))
    }

    @Test("«Vaciar datos» retira el aviso pendiente: con las filas fuera, ya no es verdad")
    func dataWipe_clearsTheNotice() throws {
        let wipe = try Self.code("Yala/Utils/DataWipeService.swift")
        #expect(wipe.contains("StorageModePersistence.clearICloudCorpusWipeCancelledInCloudNotice()"))
    }

    @Test("la activación de Yala completo que llega a la nube lo cuenta antes de retirar a secas")
    func fullActivation_inTheCloudTells() throws {
        let complete = try Self.body(of: "private func completeFullActivation() {",
                                     in: Self.code("Yala/App/Views/Groups/FullModeActivationView.swift"))
        let cloud = try Self.slice(from: "if CloudSyncFlags.storageMode == .cloud {", to: "}", in: complete)
        #expect(cloud.contains("StorageModePersistence.cancelPendingICloudCorpusWipeInTheCloud()"))
        try Self.expectOrder("StorageModePersistence.cancelPendingICloudCorpusWipeInTheCloud()",
                             before: "StorageModePersistence.clearICloudCorpusWipeArm()", in: complete,
                             "retirado a secas antes de apuntar, el arranque en la nube ya no tiene nada que contar")
    }

    // MARK: El arranque

    @Test("el arranque lee sus cinco entradas, congela con la ida en vuelo y la nube cuenta lo que retira")
    func launch_tellsWhatItRetires() throws {
        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: Self.code(Self.contentView))
        #expect(check.contains(
            "cancelledInCloudNoticePending: StorageModePersistence.isICloudCorpusWipeCancelledInCloudNoticePending(),"))
        #expect(check.contains("waivedForCloud: StorageModePersistence.isPendingICloudCorpusWipeWaivedForTheCloud(),"))
        #expect(check.contains("migrationAtRest: migrationAtRest,"))
        try Self.expectOrder("await waitForBootstrap()",
                             before: "migrationAtRest = AppleIDChangeCloseLogic.migrationAtRest(MigrationRestReading.live)",
                             in: check, "sin el journal configurado la lectura dice `notStarted`, el lado que concede")
        try Self.expectOrder("migrationAtRest = AppleIDChangeCloseLogic.migrationAtRest(MigrationRestReading.live)",
                             before: "switch WelcomePrivateICloudGateLogic.lateWipeLaunch(", in: check,
                             "la decisión se toma con la lectura de reposo hecha")
        let lapse = try Self.slice(from: "if WelcomePrivateICloudGateLogic.waiverLapses(", to: "}", in: check)
        #expect(lapse.contains("StorageModePersistence.clearICloudCorpusWipeWaiver()"))
        let noticeLapse = try Self.slice(from: "if WelcomePrivateICloudGateLogic.cancelledNoticeLapses(", to: "}", in: check)
        #expect(noticeLapse.contains("StorageModePersistence.clearICloudCorpusWipeCancelledInCloudNotice()"))

        let retire = try Self.slice(from: "case .retireInCloud:", to: "case .askLeftHalfway:", in: check)
        try Self.expectOrder("StorageModePersistence.cancelPendingICloudCorpusWipeInTheCloud()",
                             before: "RouterEntryGate.shared.submit(.presentLateICloudMirrorNotice(.wipeCancelledInCloud))",
                             in: retire, "el aviso se pide con la marca ya apuntada")
        #expect(!retire.contains("clearICloudCorpusWipeArm()"), """
            retirar a mano salta el apunte del aviso: el borrado vuelve a desaparecer en silencio
            """)
        let waived = try Self.slice(from: "case .retireWaivedInCloud:", to: "case .tellCancelledInCloud:", in: check)
        #expect(waived.contains("StorageModePersistence.retirePendingICloudCorpusWipeAsWaived()"))
        #expect(!waived.contains("presentLateICloudMirrorNotice"), "doble aviso: la persona lo eligió en Ajustes")
        let tell = try Self.slice(from: "case .tellCancelledInCloud:", to: "case .holdForMigration:", in: check)
        #expect(tell.contains("RouterEntryGate.shared.submit(.presentLateICloudMirrorNotice(.wipeCancelledInCloud))"))
        let hold = try Self.slice(from: "case .holdForMigration:", to: "let watching", in: check)
        #expect(hold.contains("return"))
        #expect(!hold.contains("performLateICloudWipe") && !hold.contains("presentLateICloudMirrorNotice"),
                "con la ida en vuelo ni se borra ni se pregunta")
    }

    // MARK: La hoja

    @Test("la hoja abre en su fase informativa, sin botón destructivo, y consume la marca al montar")
    func sheet_informsAndConsumesOnMount() throws {
        let src = try Self.code(Self.notice)
        #expect(src.contains("case .wipeCancelledInCloud: _phase = State(initialValue: .cancelledInCloud)"))
        let phase = try Self.slice(from: "case .cancelledInCloud:\n", to: "}\n    }", in: src)
        #expect(phase.contains("primary: L10n.Common.understood"))
        #expect(!phase.contains("destructive:"), "en la nube no hay nada que terminar: ningún botón que borre")
        let mount = try Self.body(of: ".onAppear {", in: src)
        #expect(mount.contains("if notice == .wipeCancelledInCloud {")
                && mount.contains("StorageModePersistence.clearICloudCorpusWipeCancelledInCloudNotice()"), """
            consumida al pedirla, un anchor ocupado o un kill antes de montar se llevaban el aviso
            """)
        // La barra de cierre no retira el testigo del espejo tardío desde esta fase: `onKeep` no es suyo.
        let close = try Self.slice(from: "} else if phase == .cancelledInCloud {", to: "} else if phase == .failed", in: src)
        #expect(close.contains("dismiss()") && !close.contains("onKeep"))
    }

    // MARK: La puerta de Ajustes

    @Test("«Activar la nube» pregunta por el borrado pendiente antes que nada")
    func storage_asksBeforeEverything() throws {
        let src = try Self.code(Self.storage)
        #expect(src.contains(
            "UITestHooks.fakePendingICloudWipe || StorageModePersistence.hasPendingICloudCorpusWipe()"))
        let tap = try Self.slice(from: "isLoading: controller.isCheckingMigrationIdentity", to: ".accessibilityIdentifier(\"storage_migrate_button\")", in: src)
        try Self.expectOrder("pendingICloudWipeWaived = false", before: "guard !hasPendingICloudWipe else {", in: tap,
                             "un «sin borrar» de un intento anterior se arrastraría al siguiente")
        try Self.expectOrder("confirmPendingICloudWipe = true", before: "beginActivation(controller, isAdopt: isAdopt)", in: tap,
                             "con un borrado pendiente, el diálogo va antes del consentimiento")
        #expect(!tap.contains("showConsent = true"), "el toque saltaba el diálogo directo al consentimiento")
        let dialog = try Self.slice(from: ".confirmationDialog(L10n.Storage.PendingICloudWipe.title,",
                                    to: "} message: {", in: src)
        try Self.expectOrder("pendingICloudWipeWaived = true", before: "beginActivation(controller, isAdopt: isAdopt)", in: dialog,
                             "«Activar la nube sin borrar» tiene que dejar la renuncia ANTES de seguir")
        let wait = try Self.slice(from: "Button(L10n.Storage.PendingICloudWipe.wait) {", to: "}", in: dialog)
        #expect(wait.trimmingCharacters(in: .whitespacesAndNewlines) == "StorageModePersistence.clearICloudCorpusWipeWaiver()",
                "«Ahora no» solo retira una renuncia vieja: el borrado se queda como estaba")
        #expect(!dialog.contains("role: .cancel"), "en iOS 26 el diálogo anclado no pinta el botón de cancelar")
    }

    @Test("la renuncia se apunta al arrancar la migración y NO retira el borrado; todo arranque pasa por ahí")
    func storage_waiverRecordedAtStart() throws {
        let src = try Self.code(Self.storage)
        let start = try Self.body(of: "private func startActivation(", in: src)
        try Self.expectOrder("StorageModePersistence.waivePendingICloudCorpusWipeForTheCloud()",
                             before: "controller?.startMigration(consentPath: path, signIn: plan)", in: start,
                             "la renuncia tiene que existir antes de que la migración pueda llegar a la nube")
        #expect(start.contains("if pendingICloudWipeWaived {"))
        for retiring in ["clearICloudCorpusWipeArm", "clearICloudCorpusWipeLeftHalfway",
                         "retirePendingICloudCorpusWipeAsWaived", "cancelPendingICloudCorpusWipeInTheCloud"] {
            #expect(!src.contains(retiring), """
                `\(retiring)` en Ajustes: retirar antes del cutover pierde el borrado en cada salida que vuelve a iCloud
                """)
        }
        #expect(Self.occurrences(of: ".startMigration(consentPath:", in: src) == 1, """
            otro arranque de la migración en esta pantalla salta la renuncia
            """)
        #expect(Self.occurrences(of: "waivePendingICloudCorpusWipeForTheCloud()", in: src) == 1)
        let flag = try Self.body(of: ".onChange(of: showsMigrateCard) { _, shown in", in: src)
        #expect(flag.contains("if !shown { confirmPendingICloudWipe = false }"), """
            sin bajar el flag, el diálogo reaparece solo cuando la tarjeta vuelve
            """)
    }

    @Test("el seam del XCUITest se llama igual en los dos lados")
    func seam_argNameParity() throws {
        let launcher = try Self.code("YalaUITests/Support/XCUIApplication+Yala.swift")
        let hooks = try Self.code("Yala/App/UITestHooks.swift")
        #expect(launcher.contains("args.append(\"-uitest-pending-icloud-wipe\")"))
        #expect(hooks.contains("hasArg(\"-uitest-pending-icloud-wipe\")"))
        #expect(Self.occurrences(of: "UITestHooks.fakePendingICloudWipe", in: try Self.code(Self.storage)) == 1,
                "el seam finge la entrada en la tarjeta y en ningún otro sitio")
    }
}
