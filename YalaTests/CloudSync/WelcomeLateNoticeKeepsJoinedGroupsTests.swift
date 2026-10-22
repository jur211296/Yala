//
//  WelcomeLateNoticeKeepsJoinedGroupsTests.swift
//  YalaTests / CloudSync
//
//  Ticket `late-notice-of-a-welcome-private-session-purges-groups-joined-later`.
//
//  Quien empieza Yala con «Es mi primera vez → privado» sin iCloud (o sin red) sigue con el testigo del espejo tardío.
//  Si después se une a un grupo, el día que iCloud vuelve le sale «Encontramos datos tuyos en iCloud», y su «Empezar de
//  cero» borraba con el alcance del relevo de usuario (`.handover`): se llevaba los grupos, su sesión de Grupos y
//  sellaba el dominio, aunque el aviso solo nombra «tus registros, tus cuentas y tus presupuestos».
//
//  El arreglo separa los dos borrados del aviso: EMPEZAR uno es `.importedRows` para todas las sesiones, y TERMINAR uno
//  (el borrado a medias y la reanudación del arranque) usa el alcance con que ese borrado entró, que él mismo apunta. Así
//  el borrado a medias del Welcome sigue sellando el dominio de quien usó el teléfono antes.
//
//  Mutantes que estos tests matan (medidos, ver el PR):
//   (1) `.startFresh` devolviendo `.handover` → la tabla y la cadena.
//   (2) `.finishPending` ignorando el alcance apuntado → la tabla y la cadena.
//   (3) desarmar retirando el apunte con «a medias» puesto → su vida y la cadena.
//   (4) retirar «a medias» sin retirar el apunte → su vida.
//   (5) apuntar sin el arm puesto → su vida.
//   (6) el aviso pasando un valor fijo en vez del tipo de aviso, o la reanudación como borrado nuevo → el cableado.
//   (7) el borrado sin apuntar su alcance, o apuntándolo después del primer `await` → el cableado.
//   (8) las señales bajadas a ciegas tras el borrado → el cableado.
//   (9) `resolve` sin mirar «a medias» → su tabla.
//   (10) apuntar `.zoneOnly` encima de un «a medias» → su vida.
//   (11) la salida «sin iCloud» del Welcome sin retirar «a medias» con el teléfono medido → su tabla y el cableado.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct WelcomeLateNoticeKeepsJoinedGroupsTests {

    // MARK: - La tabla

    @Test("empezar de cero desde el aviso conserva los grupos, venga de donde venga la sesión", arguments: [false, true])
    func startFresh_keepsGroups(_ bornFromActivation: Bool) {
        let scope = ICloudWipeScope.lateNotice(.startFresh, sessionBornFromFullActivation: bornFromActivation)
        #expect(scope == .importedRows)
        #expect(scope.purgesGroupsDomain == false, """
            «Empezar de cero» del aviso tardío purga el dominio de Grupos: se lleva los grupos a los que la persona se unió
            después de elegir privado, y el copy solo nombra registros, cuentas y presupuestos.
            """)
        #expect(scope.deletesLocalRows, """
            sin borrar las filas personales, el espejo re-exporta a la zona recién vaciada lo que el aviso prometía borrar
            """)
    }

    @Test("terminar un borrado pendiente usa el alcance con que entró",
          arguments: ICloudWipeScope.allCases, [false, true])
    func finishPending_usesTheArmedScope(_ armed: ICloudWipeScope, _ bornFromActivation: Bool) {
        #expect(ICloudWipeScope.lateNotice(.finishPending(armedWith: armed),
                                           sessionBornFromFullActivation: bornFromActivation) == armed, """
            el aviso termina un borrado con un alcance distinto del que se armó: el borrado a medias del Welcome dejaría de
            sellar el dominio de la persona anterior, o el del propio aviso se llevaría los grupos
            """)
    }

    @Test("termina quien lo dice y cualquiera con «a medias» puesto; empezar es lo demás",
          arguments: [false, true], [false, true])
    func resolve_finishesWhenAskedOrHalfway(_ asked: Bool, _ halfway: Bool) {
        let wipe = ICloudWipeScope.LateWipe.resolve(finishingPendingWipe: asked, leftHalfway: halfway, armedWith: .handover)
        if asked || halfway {
            #expect(wipe == .finishPending(armedWith: .handover), """
                con «a medias» puesto el aviso EMPIEZA un borrado nuevo: el que quedó a medias no se termina con su alcance
                """)
        } else {
            #expect(wipe == .startFresh, "sin nada pendiente el aviso termina un borrado que no existe")
        }
    }

    @Test("el alcance se apunta con su nombre: los rawValue son formato persistido")
    func scopeRawValues_arePersistedFormat() {
        #expect(ICloudWipeScope.zoneOnly.rawValue == "zoneOnly")
        #expect(ICloudWipeScope.importedRows.rawValue == "importedRows")
        #expect(ICloudWipeScope.handover.rawValue == "handover", """
            renombrar un case cambia lo que se lee del disco: un borrado armado con el build anterior se terminaría con
            el alcance de reserva, no con el suyo
            """)
    }

    // MARK: - La vida del apunte

    @Test("sin arm no se apunta nada")
    func record_withoutArm_writesNothing() {
        let d = makeIsolatedDefaults(prefix: "test.wipeScope.noArm")
        StorageModePersistence.recordICloudCorpusWipeScope(.handover, d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == nil, """
            el apunte existe sin borrado pendiente: el siguiente que se arme podría terminarse con un alcance ajeno
            """)
    }

    @Test("el apunte sobrevive al paso a «a medias» y se va con él")
    func scope_survivesTheHalfway_andLeavesWithIt() {
        let d = makeIsolatedDefaults(prefix: "test.wipeScope.halfway")
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.recordICloudCorpusWipeScope(.handover, d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == .handover)

        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.leaveICloudCorpusWipeHalfway(d)
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == .handover, """
            el apunte se fue con el arm: «Terminar de borrar» del borrado a medias del Welcome no sabría que era un relevo
            de usuario, y el dominio de la persona anterior se quedaría sin sellar
            """)

        // «Terminar de borrar» vuelve a armar: el apunte sigue, y retirar «a medias» con el arm puesto no se lo lleva.
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.clearICloudCorpusWipeLeftHalfway(d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == .handover, """
            el apunte se fue con «a medias» aunque el borrado seguía armado: un kill ahí terminaría con otro alcance
            """)

        StorageModePersistence.clearICloudCorpusWipeArm(d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == nil, """
            el apunte sobrevive al borrado que describe: un borrado nuevo lo heredaría
            """)
    }

    @Test("desarmar sin «a medias» retira el apunte")
    func clearingTheArm_withoutHalfway_retiresTheScope() {
        let d = makeIsolatedDefaults(prefix: "test.wipeScope.clearArm")
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.recordICloudCorpusWipeScope(.importedRows, d)
        StorageModePersistence.clearICloudCorpusWipeArm(d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == nil)
    }

    @Test("retirar el arm y «a medias» retira el apunte, en cualquier orden", arguments: [true, false])
    func clearingBoth_inEitherOrder_retiresTheScope(_ armFirst: Bool) {
        let d = makeIsolatedDefaults(prefix: "test.wipeScope.order")
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.recordICloudCorpusWipeScope(.handover, d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.leaveICloudCorpusWipeHalfway(d)
        StorageModePersistence.armICloudCorpusWipe(d)

        if armFirst {
            StorageModePersistence.clearICloudCorpusWipeArm(d)
            #expect(StorageModePersistence.icloudCorpusWipeScope(d) == .handover, "«a medias» sigue: el apunte también")
            StorageModePersistence.clearICloudCorpusWipeLeftHalfway(d)
        } else {
            StorageModePersistence.clearICloudCorpusWipeLeftHalfway(d)
            StorageModePersistence.clearICloudCorpusWipeArm(d)
        }
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == nil, """
            sin arm ni «a medias» el apunte sigue vivo: describe un borrado que ya no existe
            """)
    }

    @Test("un fallo que desarma conserva el apunte solo si la zona ya se fue", arguments: [true, false])
    func disarmFailed_keepsTheScope_onlyWithTheZoneGone(_ zoneGone: Bool) {
        let d = makeIsolatedDefaults(prefix: "test.wipeScope.disarmFailed")
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.recordICloudCorpusWipeScope(.importedRows, d)
        if zoneGone { StorageModePersistence.markICloudCorpusWipeZoneDone(d) }
        StorageModePersistence.disarmFailedICloudCorpusWipe(d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == (zoneGone ? .importedRows : nil))
    }

    @Test("un borrado nuevo sobrescribe el apunte")
    func record_overwrites() {
        let d = makeIsolatedDefaults(prefix: "test.wipeScope.overwrite")
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.recordICloudCorpusWipeScope(.importedRows, d)
        StorageModePersistence.recordICloudCorpusWipeScope(.handover, d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == .handover, "lo que se termina es lo último que se pidió")
    }

    @Test("un borrado que no llega a las filas no apunta, ni pisa el apunte de un «a medias»")
    func zoneOnly_neitherRecordsNorOverwrites() {
        let d = makeIsolatedDefaults(prefix: "test.wipeScope.zoneOnly")
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.recordICloudCorpusWipeScope(.zoneOnly, d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == nil, "`.zoneOnly` no deja nada que terminar")

        StorageModePersistence.recordICloudCorpusWipeScope(.handover, d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)
        StorageModePersistence.leaveICloudCorpusWipeHalfway(d)
        // La puerta privada de la activación arma y entra con `.zoneOnly` encima del «a medias» del Welcome.
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.recordICloudCorpusWipeScope(.zoneOnly, d)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == .handover, """
            un borrado solo de zona pisó el alcance del «a medias» del Welcome: su «Terminar de borrar» dejaría las filas
            de la persona anterior en el teléfono
            """)
    }

    @Test("un apunte que no se reconoce se lee como ausente")
    func unknownRaw_readsAsAbsent() {
        let d = makeIsolatedDefaults(prefix: "test.wipeScope.unknown")
        d.set("otroAlcance", forKey: StorageModePersistence.icloudCorpusWipeScopeKey)
        #expect(StorageModePersistence.icloudCorpusWipeScope(d) == nil)
    }

    // MARK: - La cadena hasta los grupos

    enum Origin: String, CaseIterable, Sendable {
        /// «Empezar de cero» del aviso con el corpus de iCloud.
        case noticeStartsFresh
        /// «Terminar de borrar» de un borrado que armó el propio aviso y quedó a medias.
        case noticeHalfwayFinished
        /// «Terminar de borrar» del aviso con el corpus cuyo propio borrado quedó a medias delante: la hoja sigue siendo
        /// `.corpus`, así que el llamador dice «empezar».
        case corpusSheetFinishesItsOwnHalfway
        /// «Terminar de borrar» del borrado a medias de la puerta del Welcome: el control.
        case welcomeHalfwayFinished
    }

    /// Encadena lo que hacen las vistas y `performICloudCorpusWipe` con el disco —armar, apuntar el alcance al entrar,
    /// cruzar la zona y quedar a medias— hasta la purga real del dominio. `performICloudCorpusWipe` es `private` en
    /// `ContentView` y habla con CloudKit; su tramo local purga el dominio solo con `scope.purgesGroupsDomain` (lo fija
    /// `HandoverGroupsDomainTests`), y el cableado de abajo fija que apunta el alcance al entrar.
    @Test("los grupos sobreviven al aviso tardío salvo cuando termina el borrado del Welcome",
          arguments: Origin.allCases)
    func lateWipe_groupsSurvive_unlessItFinishesTheWelcomeWipe(_ origin: Origin) throws {
        let d = makeIsolatedDefaults(prefix: "test.lateWipe.\(origin.rawValue)")
        let context = try makeTestContext()
        for group in try context.fetch(FetchDescriptor<SplitGroup>()) { context.delete(group) }
        context.insert(SplitGroup(name: "Viaje a Cusco"))
        try context.save()

        let callerSaysFinishing: Bool
        switch origin {
        case .noticeStartsFresh:
            callerSaysFinishing = false
        case .noticeHalfwayFinished, .welcomeHalfwayFinished, .corpusSheetFinishesItsOwnHalfway:
            // El borrado que quedó a medias entró con su alcance, cruzó la zona y la persona salió.
            StorageModePersistence.armICloudCorpusWipe(d)
            StorageModePersistence.recordICloudCorpusWipeScope(
                origin == .welcomeHalfwayFinished ? .handover : .importedRows, d)
            StorageModePersistence.markICloudCorpusWipeZoneDone(d)
            StorageModePersistence.leaveICloudCorpusWipeHalfway(d)
            // «Terminar de borrar» vuelve a armar antes de borrar.
            StorageModePersistence.armICloudCorpusWipe(d)
            callerSaysFinishing = origin != .corpusSheetFinishesItsOwnHalfway
        }

        // Lo mismo que lee `ContentView.performLateICloudWipe` (fijado abajo), desde el disco.
        let scope = ICloudWipeScope.lateNotice(
            .resolve(finishingPendingWipe: callerSaysFinishing,
                     leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway(d),
                     armedWith: StorageModePersistence.icloudCorpusWipeScope(d)),
            sessionBornFromFullActivation: PrivateSessionMark.isBornFromFullActivation(d))
        if scope.purgesGroupsDomain {
            try DataWipeService.wipeLocalGroupsDomain(
                in: context, defaults: d, retireCloudSession: {}, resetSyncState: {}, witness: .quiet)
        }

        let remaining = try context.fetchCount(FetchDescriptor<SplitGroup>())
        switch origin {
        case .noticeStartsFresh:
            #expect(remaining == 1, "«Empezar de cero» del aviso tardío se llevó los grupos a los que la persona se unió")
        case .noticeHalfwayFinished, .corpusSheetFinishesItsOwnHalfway:
            #expect(remaining == 1, """
                terminar el borrado a medias del propio aviso se llevó los grupos: el alcance apuntado no llegó al final
                """)
        case .welcomeHalfwayFinished:
            // El control positivo: el mismo tramo sí purga, así que los dos casos de arriba miden algo.
            #expect(remaining == 0, """
                terminar el borrado a medias del Welcome no purgó el dominio: el de la persona anterior se queda sin sellar
                """)
        }
    }

    // MARK: - El cableado de producción

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Fuente sin líneas de comentario: documentar un invariante no puede hacer que se «cumpla».
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas a partir de un marcador.
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

    /// Normalizado: líneas trimmeadas y unidas por un espacio, para fijar una expresión que ocupa varias líneas.
    private static func normalized(_ text: String) -> String {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    @Test("el borrado apunta su alcance antes del primer `await`")
    func corpusWipe_recordsItsScopeBeforeTheFirstAwait() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wipe = try Self.body(of: "private func performICloudCorpusWipe(_ scope: ICloudWipeScope) async -> String? {",
                                 in: src)
        let record = try #require(wipe.range(of: "StorageModePersistence.recordICloudCorpusWipeScope(scope)"), """
            el borrado del corpus ya no apunta su alcance: un kill o un borrado a medias se terminaría con el de reserva
            """)
        let firstAwait = try #require(wipe.range(of: "await "))
        #expect(record.lowerBound < firstAwait.lowerBound, """
            el alcance se apunta después del primer `await`: un kill en esa espera deja el arm sin apunte
            """)
    }

    @Test("solo el borrado del corpus apunta el alcance, y nadie escribe la key a mano")
    func onlyTheCorpusWipeRecordsTheScope() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala")
        let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var recorders: [String] = []
        var rawWriters: [String] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if url.lastPathComponent != "CloudSyncFlags.swift", text.contains("recordICloudCorpusWipeScope(") {
                recorders.append(url.lastPathComponent)
            }
            if text.contains("icloudCorpusWipeScopeKey") || text.contains("cloudSync.icloudCorpusWipeScope") {
                rawWriters.append(url.lastPathComponent)
            }
        }
        #expect(recorders == ["ContentView.swift"], """
            alguien más apunta el alcance del borrado pendiente: el apunte tiene que decirlo quien borra. Sitios: \(recorders)
            """)
        #expect(rawWriters == ["CloudSyncFlags.swift"], "alguien toca la key a mano. Sitios: \(rawWriters)")
    }

    @Test("el aviso empieza o termina según lo que enseña, y la reanudación termina")
    func noticeAndResume_passWhichWipeTheyAre() throws {
        let src = try Self.code("Yala/App/ContentView.swift")

        #expect(src.contains(
            "performWipe: { await performLateICloudWipe(finishingPendingWipe: notice == .wipeLeftHalfway) }"), """
            el aviso dejó de decir si empieza un borrado o termina uno: o el corpus se borra con el alcance del Welcome
            (los grupos se van), o el borrado a medias del Welcome se termina sin sellar
            """)

        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: src)
        #expect(check.contains("let failure = await performLateICloudWipe(finishingPendingWipe: true)"), """
            la reanudación del arranque dejó de terminar el borrado que se armó
            """)

        let wipe = try Self.body(of: "private func performLateICloudWipe(finishingPendingWipe: Bool) async -> String? {",
                                 in: src)
        #expect(Self.normalized(wipe).contains("""
            let scope = ICloudWipeScope.lateNotice( .resolve(finishingPendingWipe: finishingPendingWipe, \
            leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway(), \
            armedWith: StorageModePersistence.icloudCorpusWipeScope()), sessionBornFromFullActivation: \
            PrivateSessionMark.isBornFromFullActivation())
            """), "el borrado tardío no decide su alcance por qué borrado es. Tramo leído: \(Self.normalized(wipe))")
    }

    // MARK: - La salida «sin iCloud» de la puerta del Welcome

    @Test("la salida sin iCloud retira «a medias» solo en el Welcome y con el teléfono medido",
          arguments: [WelcomePrivateICloudGateLogic.HalfwayWipe.leaveForLateNotice, .finishOnReentry, .nothingLeftBehind],
          [false, true])
    func unverifiedExit_retiresHalfway_onlyWhenTheWelcomeMeasuredThePhone(
        _ halfway: WelcomePrivateICloudGateLogic.HalfwayWipe, _ measuredDevice: Bool
    ) {
        let retires = WelcomePrivateICloudGateLogic.unverifiedExitRetiresHalfway(halfway, measuredDevice: measuredDevice)
        #expect(retires == (halfway == .leaveForLateNotice && measuredDevice), """
            con el teléfono medido vacío, la marca «a medias» sobrevive a la salida sin iCloud: tras el onboarding, su
            «Terminar de borrar» es el `.handover` del Welcome y purga los grupos a los que la persona se unió después
            """)
    }

    @Test("la salida sin iCloud escribe el testigo y, con la mitad resuelta, retira la marca antes que el arm")
    func unverifiedExit_wiring() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let exit = try Self.body(of: "private func continueWithoutValidating() {", in: src)
        #expect(Self.normalized(exit) == """
            StorageModePersistence.markPrivateChoseWithoutICloud() if \
            WelcomePrivateICloudGateLogic.unverifiedExitRetiresHalfway(halfwayWipe, measuredDevice: deviceCorpus != nil) { \
            StorageModePersistence.clearICloudCorpusWipeLeftHalfway() StorageModePersistence.clearICloudCorpusWipeArm() \
            } else { discardPendingWipe() } onProceed()
            """, "Tramo leído: \(Self.normalized(exit))")
    }

    @Test("tras el borrado tardío las señales se miden, no se bajan")
    func settle_alwaysRemeasures() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let settle = try Self.body(of: "private func settleAfterLateICloudWipe() {", in: src)
        #expect(Self.normalized(settle) == """
            cancelWipeGrace() hasExistingData = checkHasExistingData() hasPersonalData = checkHasPersonalData() \
            hasCompletedOnboarding = false
            """, """
            el cierre del borrado tardío cambió: con los grupos conservados, bajar `hasExistingData` a ciegas le dice a la
            app que el teléfono está vacío. Tramo leído: \(Self.normalized(settle))
            """)
    }
}
