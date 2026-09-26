//
//  LateICloudWipeLeftHalfwayTests.swift
//  YalaTests / CloudSync
//
//  Ticket `late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed`: el borrado del aviso del espejo
//  tardío que fallaba dejaba el arm puesto al salir, y el arranque siguiente lo terminaba A CIEGAS —zona, filas y dominio
//  de Grupos— sobre quien acababa de decir «déjalo así». Y el fallo de después de la zona se enseñaba con un copy falso
//  («Tus datos siguen en iCloud, intactos»).
//
//  Tres suites:
//   1. La lógica pura: qué dejó un borrado fallido y qué hace el arranque con él.
//   2. Las marcas durables, con un `UserDefaults` propio: el sub-estado «zona borrada» del arm y el «a medias».
//   3. El cableado (source-scan, sin comentarios): quién apunta la zona, qué hace cada fallo en la pantalla y en el
//      arranque, y que ninguna salida reanude a ciegas.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Borrado a medias · la lógica")
struct LateICloudWipeLeftHalfwayLogicTests {

    typealias Logic = WelcomePrivateICloudGateLogic

    /// La tabla entera, porque son tres entradas y un término mal puesto cambia qué se reanuda a ciegas.
    @Test(arguments: [
        // groupsPending, zoneDone, wasLeftHalfway → esperado
        (true, false, false, Logic.LateWipeFailure.groupsPending),
        (true, true, false, .groupsPending),
        (true, false, true, .groupsPending),
        (true, true, true, .groupsPending),
        (false, false, false, .untouched),
        (false, true, false, .leftHalfway),
        (false, false, true, .leftHalfway),
        (false, true, true, .leftHalfway),
    ])
    func classify(groupsPending: Bool, zoneDone: Bool, wasLeftHalfway: Bool, expected: Logic.LateWipeFailure) {
        #expect(Logic.classifyLateWipeFailure(groupsPending: groupsPending, zoneDone: zoneDone,
                                              wasLeftHalfway: wasLeftHalfway) == expected)
    }

    /// **El caso que el ticket pide cerrar**: la zona ya no está y el fallo es de después. Si esto dijera `.untouched`,
    /// la pantalla enseñaría «intactos» y el arranque volvería a intentarlo a ciegas.
    @Test func afterTheZone_isNeverUntouched() {
        #expect(Logic.classifyLateWipeFailure(groupsPending: false, zoneDone: true, wasLeftHalfway: false) == .leftHalfway)
    }

    /// Un reintento que falla ANTES de llegar a la zona, sobre un borrado que ya había quedado a medias, sigue a medias.
    @Test func aRetryThatFailsEarly_staysHalfway() {
        #expect(Logic.classifyLateWipeFailure(groupsPending: false, zoneDone: false, wasLeftHalfway: true) == .leftHalfway)
    }

    @Test(arguments: [
        (true, false, Logic.LateWipeLaunch.resume),
        (true, true, .resume),
        (false, true, .askLeftHalfway),
        (false, false, .none),
    ])
    func launch(armed: Bool, leftHalfway: Bool, expected: Logic.LateWipeLaunch) {
        #expect(Logic.lateWipeLaunch(armed: armed, leftHalfway: leftHalfway) == expected)
    }

    /// **EL PIN DEL BUG.** Sin arm y con el borrado a medias, el arranque PREGUNTA. Reanudar aquí es terminar a ciegas lo
    /// que la persona vio fallar y dejó.
    @Test func leftHalfwayWithoutArm_asksAndNeverResumes() {
        #expect(Logic.lateWipeLaunch(armed: false, leftHalfway: true) == .askLeftHalfway)
    }

    @Test func notice_identityIsTheFact() {
        let a = LateICloudNotice.corpus(.empty)
        let b = LateICloudNotice.wipeLeftHalfway
        #expect(a.id != b.id)
        #expect(b.id == LateICloudNotice.wipeLeftHalfway.id)
        #expect(RouterIntent.presentLateICloudMirrorNotice(a).id == RouterIntent.presentLateICloudMirrorNotice(b).id,
                "el dedup del router es por el HECHO: una sola hoja del aviso tardío en cola")
    }
}

@Suite("Borrado a medias · las marcas")
struct LateICloudWipeLeftHalfwayFlagsTests {

    private func freshDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "LateICloudWipeLeftHalfwayFlagsTests.\(UUID().uuidString)"))
    }

    /// La marca de la zona es un sub-estado del arm: sin arm no se escribe, y no puede describir un borrado que no existe.
    @Test func zoneDone_needsTheArm() throws {
        let d = try freshDefaults()
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeZoneDone(d))
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        #expect(StorageModePersistence.isICloudCorpusWipeZoneDone(d))
    }

    /// Se va con el arm: ningún camino que desarma (éxito, salida de la puerta, activación) puede dejarla viva.
    @Test func zoneDone_leavesWithTheArm() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.clearICloudCorpusWipeArm(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeZoneDone(d))
    }

    /// «Volver a intentarlo» re-arma con el arm ya puesto: la zona se borró en ESTE borrado y el reintento no lo olvida.
    @Test func rearming_keepsTheZoneMark() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.armICloudCorpusWipe(d)
        #expect(StorageModePersistence.isICloudCorpusWipeZoneDone(d))
    }

    /// Pasar a «a medias» desarma: **con el arm puesto, el arranque reanudaría a ciegas**.
    @Test func leavingHalfway_disarms() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.leaveICloudCorpusWipeHalfway(d)
        #expect(StorageModePersistence.isICloudCorpusWipeLeftHalfway(d))
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(!StorageModePersistence.isICloudCorpusWipeZoneDone(d))
        #expect(WelcomePrivateICloudGateLogic.lateWipeLaunch(
            armed: StorageModePersistence.isICloudCorpusWipeArmed(d),
            leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway(d)) == .askLeftHalfway)
        StorageModePersistence.clearICloudCorpusWipeLeftHalfway(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeLeftHalfway(d))
    }

    /// Grupos pendientes gana a la clasificación, pero si la zona ya se había ido en ESTE borrado, desarmar no puede
    /// olvidarlo: queda «a medias» (review adversarial del 2026-09-26).
    @Test func disarmingAFailure_keepsTheHalfwayWhenTheZoneWasGone() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.disarmFailedICloudCorpusWipe(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(StorageModePersistence.isICloudCorpusWipeLeftHalfway(d))

        let e = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(e)
        StorageModePersistence.disarmFailedICloudCorpusWipe(e)
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(e))
        #expect(!StorageModePersistence.isICloudCorpusWipeLeftHalfway(e), "sin zona borrada no hay nada a medias")
    }

    /// `cloudSync.*`: el barrido de preferencias no la toca, así que su único final con la sesión es el hook de cierre.
    @Test func keys_liveUnderCloudSync() {
        #expect(StorageModePersistence.icloudCorpusWipeZoneDoneKey.hasPrefix("cloudSync."))
        #expect(StorageModePersistence.icloudCorpusWipeLeftHalfwayKey.hasPrefix("cloudSync."))
    }
}

@Suite("Borrado a medias · el cableado")
struct LateICloudWipeLeftHalfwayWiringTests {

    private static let contentView = "Yala/App/ContentView.swift"
    private static let late = "Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift"

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

    /// El tramo entre dos marcadores, el segundo buscado DESPUÉS del primero.
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

    // MARK: Quien cruza la zona lo apunta

    @Test("el borrado apunta la zona justo tras borrarla, antes de tocar el teléfono")
    func wipe_marksTheZoneRightAfterIt() throws {
        let wipe = try Self.body(of: "private func performICloudCorpusWipe(_ scope: ICloudWipeScope) async -> String? {",
                                 in: Self.code(Self.contentView))
        try Self.expectOrder("await ICloudPersonalCorpusProbe.wipe()", before: "StorageModePersistence.markICloudCorpusWipeZoneDone()",
                             in: wipe, "la marca va DESPUÉS de la zona: un fallo de la zona no ha tocado nada")
        try Self.expectOrder("StorageModePersistence.markICloudCorpusWipeZoneDone()", before: "guard scope.deletesLocalRows",
                             in: wipe, "la marca va ANTES de cualquier fallo del teléfono, o ese fallo se leería «intacto»")
        // Y no dentro de la rama del fallo de la zona.
        let zoneFailure = try Self.slice(from: "if let failure = await ICloudPersonalCorpusProbe.wipe() {", to: "}", in: wipe)
        #expect(!zoneFailure.contains("markICloudCorpusWipeZoneDone"))
    }

    // MARK: El arranque

    @Test("el arranque pregunta por el borrado a medias y no lo reanuda")
    func launch_asksForTheHalfwayWipe() throws {
        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: Self.code(Self.contentView))
        #expect(check.contains("leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway()"))
        let ask = try Self.slice(from: "case .askLeftHalfway:", to: "case .resume:", in: check)
        #expect(ask.contains("RouterEntryGate.shared.submit(.presentLateICloudMirrorNotice(.wipeLeftHalfway))"))
        #expect(ask.contains("return"))
        #expect(!ask.contains("performICloudCorpusWipe"), "preguntar, no borrar: aquí no hay arm")
    }

    @Test("una reanudación que falla tras la zona pasa a «a medias» y lo enseña; antes de la zona el arm se queda")
    func launch_resumeFailureAfterTheZone_stopsResuming() throws {
        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: Self.code(Self.contentView))
        #expect(check.contains("zoneDone: StorageModePersistence.isICloudCorpusWipeZoneDone(),"))
        #expect(check.contains("wasLeftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway()"))
        let halfway = try Self.slice(from: "case .leftHalfway:", to: "guard failure == nil else { return }", in: check)
        #expect(halfway.contains("StorageModePersistence.leaveICloudCorpusWipeHalfway()"), """
            con el arm puesto tras borrar la zona, el arranque siguiente vuelve a intentarlo a ciegas: justo el bug.
            """)
        #expect(halfway.contains("RouterEntryGate.shared.submit(.presentLateICloudMirrorNotice(.wipeLeftHalfway))"))
        let pending = try Self.slice(from: "case .groupsPending:", to: "case .untouched:", in: check)
        #expect(pending.contains("StorageModePersistence.disarmFailedICloudCorpusWipe()"), """
            una reanudación tras un kill posterior a la zona que se para en los grupos tiene que recordar que iCloud ya no está
            """)
        let untouched = try Self.slice(from: "case .untouched:", to: "case .leftHalfway:", in: check)
        #expect(!untouched.contains("clearICloudCorpusWipeArm"), """
            antes de la zona y tras un kill, el arm se queda para terminar lo que la persona confirmó dos veces
            """)
    }

    @Test("la reanudación que termina retira también «a medias»")
    func launch_success_clearsTheHalfwayMark() throws {
        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: Self.code(Self.contentView))
        let success = try Self.slice(from: "guard failure == nil else { return }", to: "hasCompletedOnboarding = false", in: check)
        #expect(success.contains("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()"))
        #expect(success.contains("StorageModePersistence.clearICloudCorpusWipeArm()"), """
            sin desarmar al terminar, el arranque siguiente vuelve a reanudar el mismo borrado: bucle
            """)
    }

    // MARK: La pantalla

    @Test("al fallar, la pantalla cambia el estado durable ANTES de enseñar la fase")
    func screen_failure_writesStateOnEntry() throws {
        let run = try Self.body(of: "private func runPhase() async {", in: Self.code(Self.late))
        let untouched = try Self.slice(from: "case .untouched:", to: "case .leftHalfway:", in: run)
        try Self.expectOrder("StorageModePersistence.clearICloudCorpusWipeArm()", before: "phase = .failed", in: untouched,
                             "antes de la zona se desarma al ENTRAR en `.failed`: salir por donde sea ya no deja el arm")
        let halfway = try Self.slice(from: "case .leftHalfway:", to: "return", in: run)
        try Self.expectOrder("StorageModePersistence.leaveICloudCorpusWipeHalfway()", before: "phase = .leftHalfway",
                             in: halfway, "tras la zona se pasa a «a medias» al ENTRAR, no al salir")
        #expect(run.contains("zoneDone: StorageModePersistence.isICloudCorpusWipeZoneDone(),"))
    }

    @Test("grupos pendientes también desarma al entrar, sin olvidar la zona, y solo con un bloqueo de verdad")
    func screen_groupsPending_disarmsOnEntry() throws {
        let run = try Self.body(of: "private func runPhase() async {", in: Self.code(Self.late))
        #expect(run.contains("groupsPending: block != nil,"), """
            con otra entrada, un bloqueo por grupos se enseñaría como «no pudimos borrar» y perdería su pantalla
            """)
        let pending = try Self.slice(from: "case .groupsPending:", to: "case .untouched:", in: run)
        try Self.expectOrder("StorageModePersistence.disarmFailedICloudCorpusWipe()", before: "phase = .groupsPending(block)",
                             in: pending, "con el arm puesto, un kill mirando «faltan cambios» reanudaba a ciegas")
    }

    @Test("pasar a «a medias» escribe la marca ANTES de desarmar")
    func leaveHalfway_marksBeforeDisarming() throws {
        let leave = try Self.body(of: "static func leaveICloudCorpusWipeHalfway(_ defaults: UserDefaults = .standard) {",
                                  in: Self.code("Yala/Services/CloudSync/CloudSyncFlags.swift"))
        try Self.expectOrder("defaults.set(true, forKey: icloudCorpusWipeLeftHalfwayKey)",
                             before: "clearICloudCorpusWipeArm(defaults)", in: leave,
                             "un kill entre las dos, al revés, perdería el estado a medias")
    }

    @Test("el fallo de después de la zona no enseña el copy de «intactos»")
    func screen_halfwayHasItsOwnCopy() throws {
        let late = try Self.code(Self.late)
        let halfway = try Self.slice(from: "case .leftHalfway:\n", to: "case .confirmingFinish:\n", in: late)
        #expect(halfway.contains("L10n.Welcome.PrivateICloud.leftHalfwayBody"))
        #expect(!halfway.contains("wipeFailedBody"))
        #expect(halfway.contains("primaryAction: keepAfterHalfway,"), "la salida que no borra va arriba, como en el aviso")
        #expect(halfway.contains("destructiveAction: { phase = .confirmingFinish })"), """
            terminar pasa por su «¿seguro?»: la pantalla puede salir días después, con datos nuevos en el teléfono
            """)
        #expect(!halfway.contains("phase = .wiping"), "un toque no basta para terminar un borrado irreversible")
        let confirm = try Self.slice(from: "case .confirmingFinish:\n", to: "case .groupsPending(let block) where", in: late)
        #expect(confirm.contains("L10n.Welcome.PrivateICloud.leftHalfwayConfirmBody"))
        #expect(confirm.contains("primaryAction: { phase = .leftHalfway }"))
        #expect(confirm.contains("destructiveAction: { phase = .wiping })"), "terminar vuelve a correr el borrado entero")
    }

    @Test("quedarse tras el borrado a medias retira la marca y el testigo, y no borra nada")
    func screen_keepAfterHalfway() throws {
        let keep = try Self.body(of: "private func keepAfterHalfway() {", in: Self.code(Self.late))
        #expect(keep.contains("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()"))
        #expect(keep.contains("onKeep()"))
        #expect(!keep.contains("phase = .wiping"))
    }

    @Test("salir de un fallo, por el botón o por la barra, es «luego»: ni reanuda ni retira el testigo")
    func screen_exitsAfterAFailure() throws {
        let late = try Self.code(Self.late)
        let failed = try Self.slice(from: "case .failed:\n", to: "case .leftHalfway:\n", in: late)
        #expect(failed.contains("destructiveAction: { dismiss() })"))
        let bar = try Self.slice(from: "} else if phase == .failed || phase == .leftHalfway || phase == .confirmingFinish {",
                                 to: "} else {", in: late)
        #expect(bar.contains("dismiss()"))
        #expect(!bar.contains("onKeep"), "`onKeep` retira el testigo y el aviso ya no volvería a preguntar")
    }

    @Test("la hoja abre en su fase según lo que se presenta")
    func screen_initialPhaseFollowsTheNotice() throws {
        let late = try Self.code(Self.late)
        #expect(late.contains("case .wipeLeftHalfway: _phase = State(initialValue: .leftHalfway)"))
        #expect(late.contains("case .corpus: _phase = State(initialValue: .notice)"))
    }

    @Test("el borrado que termina desde la pantalla retira también «a medias»")
    func screen_success_clearsTheHalfwayMark() throws {
        let run = try Self.body(of: "private func runPhase() async {", in: Self.code(Self.late))
        try Self.expectOrder("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()",
                             before: "onWiped()", in: run, "terminar deja el estado entero: la pantalla no vuelve")
    }

    // MARK: Con la sesión

    @Test("«a medias» muere con la sesión, junto al testigo del aviso tardío")
    func signOutHook_clearsTheHalfwayMark() throws {
        let src = try Self.code("Yala/Utils/SwiftDataConfiguration.swift")
        try Self.expectOrder("StorageModePersistence.clearPrivateChoseWithoutICloud(defaults)",
                             before: "StorageModePersistence.clearICloudCorpusWipeLeftHalfway(defaults)", in: src,
                             "la persona siguiente no puede heredar «El borrado quedó a medias»")
    }

    // MARK: El copy

    /// El cuerpo tiene que decir dónde se borró y dónde no: sin nombrar iCloud, «quedó a medias» no se entiende.
    @Test("el copy de «a medias» nombra iCloud y no promete «intactos»")
    func copy_namesICloud() throws {
        for locale in ["es-419", "en"] {
            let strings = try String(contentsOf: Self.repoRoot.appendingPathComponent(
                "Yala/Resources/\(locale).lproj/Localizable.strings"), encoding: .utf8)
            let line = try #require(strings.split(separator: "\n").first {
                $0.hasPrefix("\"welcome.privateICloud.leftHalfwayBody\"")
            })
            let value = try #require(line.components(separatedBy: "\" = \"").last)
            #expect(value.contains("iCloud"), "[\(locale)] \(value)")
            #expect(!value.localizedCaseInsensitiveContains("intact"), "[\(locale)] \(value)")
        }
    }
}

/// «Vaciar datos» (y cualquier `wipeAllUserData`) resuelve el «a medias»: sin filas, ya no hay nada a medias, y la marca
/// sobrevivía al barrido de preferencias por ser `cloudSync.*` (review adversarial del 2026-09-26).
@Suite("Borrado a medias · «Vaciar datos» lo resuelve", .serialized, .wipeAppGroupMirrorIsolated)
@MainActor
struct LateICloudWipeLeftHalfwayDataWipeTests {

    @Test(arguments: [true, false])
    func wipeAllUserData_clearsTheHalfwayMark(resetsPreferences: Bool) throws {
        let context = try makeTestContext()
        UserDefaults.standard.set(true, forKey: StorageModePersistence.icloudCorpusWipeLeftHalfwayKey)
        defer { StorageModePersistence.clearICloudCorpusWipeLeftHalfway() }
        try DataWipeService.wipeAllUserData(in: context, broadcastSignal: false, resetsPreferences: resetsPreferences)
        #expect(!StorageModePersistence.isICloudCorpusWipeLeftHalfway(), """
            tras vaciar, el arranque ofrecería «Terminar de borrar» sobre el corpus nuevo
            """)
    }
}
