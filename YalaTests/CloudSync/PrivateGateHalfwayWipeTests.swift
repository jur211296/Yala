//
//  PrivateGateHalfwayWipeTests.swift
//  YalaTests / CloudSync
//
//  Ticket `private-gate-leave-after-a-halfway-wipe-forgets-the-zone`.
//
//  La puerta privada borra primero la zona de iCloud y después las filas del teléfono. Si fallaba en la segunda mitad y
//  la persona salía («Dejarlo por ahora»), la puerta retiraba el arm y con él la marca de la zona: nada recordaba que
//  iCloud había quedado vacío con lo del teléfono dentro. Ahora cada montaje lo recuerda con el remedio de su alcance:
//
//   · Welcome (`.handover`): la marca «a medias», que pregunta el aviso tardío.
//   · Activación, «Empezar desde cero» (`.importedRows`): la marca, y la termina la propia puerta al volver.
//   · Activación, puerta privada (`.zoneOnly`): nada, porque su borrado no toca filas.
//
//  Y ningún activador llega al remedio del aviso tardío (`.handover`, que purgaría sus grupos), y ninguna cuenta de la
//  nube tampoco.
//
//  (A) La lógica pura: qué recuerda cada montaje y qué hace con iCloud vacío.
//  (B) Las marcas de verdad, con un `UserDefaults` propio: el recorrido que el ticket describe.
//  (C) El cableado (source-scan, sin comentarios): la puerta, sus tres montajes, la activación y el arranque.
//

import Foundation
import Testing
@testable import Yala

// MARK: - (A) La lógica

@Suite("Puerta privada · borrado a medias · la lógica")
struct PrivateGateHalfwayWipeLogicTests {

    typealias Logic = WelcomePrivateICloudGateLogic

    /// Solo un borrado que llega a las filas puede quedar a medias. El de la puerta privada de la activación es de zona.
    @Test(arguments: [
        (Logic.HalfwayWipe.leaveForLateNotice, true),
        (.finishOnReentry, true),
        (.nothingLeftBehind, false),
    ])
    func reachesDeviceRows(_ halfway: Logic.HalfwayWipe, expected: Bool) {
        #expect(halfway.reachesDeviceRows == expected)
    }

    /// La tabla entera: tres montajes × marca × marca de la zona × si se midió el teléfono.
    @Test(arguments: [
        // montaje, a medias, zona ida, midió el teléfono → esperado
        (Logic.HalfwayWipe.leaveForLateNotice, false, false, false, Logic.EmptyMeasure.proceed(retiresHalfway: false)),
        (.leaveForLateNotice, false, false, true, .proceed(retiresHalfway: true)),
        (.leaveForLateNotice, true, false, false, .proceed(retiresHalfway: false)),
        (.leaveForLateNotice, true, false, true, .proceed(retiresHalfway: true)),
        (.leaveForLateNotice, false, true, false, .proceed(retiresHalfway: false)),
        (.leaveForLateNotice, false, true, true, .proceed(retiresHalfway: true)),
        (.finishOnReentry, false, false, false, .proceed(retiresHalfway: false)),
        (.finishOnReentry, false, false, true, .proceed(retiresHalfway: false)),
        (.finishOnReentry, true, false, false, .finishHalfwayWipe),
        (.finishOnReentry, true, false, true, .finishHalfwayWipe),
        (.finishOnReentry, false, true, false, .finishHalfwayWipe),
        (.finishOnReentry, false, true, true, .finishHalfwayWipe),
        (.nothingLeftBehind, false, false, false, .proceed(retiresHalfway: false)),
        (.nothingLeftBehind, false, false, true, .proceed(retiresHalfway: false)),
        (.nothingLeftBehind, true, false, false, .proceed(retiresHalfway: false)),
        (.nothingLeftBehind, true, false, true, .proceed(retiresHalfway: false)),
        (.nothingLeftBehind, false, true, false, .proceed(retiresHalfway: false)),
        (.nothingLeftBehind, false, true, true, .proceed(retiresHalfway: false)),
    ])
    func afterEmptyMeasure(_ halfway: Logic.HalfwayWipe, leftHalfway: Bool, zoneDone: Bool, measuredDevice: Bool,
                           expected: Logic.EmptyMeasure) {
        #expect(Logic.afterEmptyMeasure(halfway, leftHalfway: leftHalfway, zoneDone: zoneDone,
                                        measuredDevice: measuredDevice) == expected)
    }

    /// **EL PIN DE LA ACTIVACIÓN.** Con la marca puesta e iCloud vacío, «Empezar desde cero» termina su borrado. Seguir
    /// dejaría a quien activa en el onboarding encima de las filas importadas, que el espejo vuelve a subir.
    @Test func discardGate_withTheMark_finishesInsteadOfProceeding() {
        #expect(Logic.afterEmptyMeasure(.finishOnReentry, leftHalfway: true, zoneDone: false, measuredDevice: false)
                == .finishHalfwayWipe)
    }

    /// **Y tras un kill justo después de la zona**, que deja el arm y la marca de la zona sin «a medias»: nadie salió por
    /// `disarm()`, y en solo-grupos ningún arranque devuelve a la puerta (review adversarial, dos lentes).
    @Test func discardGate_afterAKillPastTheZone_finishes() {
        #expect(Logic.afterEmptyMeasure(.finishOnReentry, leftHalfway: false, zoneDone: true, measuredDevice: false)
                == .finishHalfwayWipe)
    }

    /// Sin medir el teléfono no consta que no quede mitad: retirar la marca ahí sería dar por terminado un borrado
    /// del que solo se sabe una parte.
    @Test func welcomeWithoutMeasuringThePhone_keepsTheMark() {
        #expect(Logic.afterEmptyMeasure(.leaveForLateNotice, leftHalfway: true, zoneDone: false, measuredDevice: false)
                == .proceed(retiresHalfway: false))
    }

    /// El copy del fallo: la zona de este intento, o la de un borrado anterior que quedó a medias.
    @Test(arguments: [
        (false, false, false),
        (true, false, true),
        (false, true, true),
        (true, true, true),
    ])
    func failureFoundZoneGone(zoneDone: Bool, leftHalfway: Bool, expected: Bool) {
        #expect(Logic.failureFoundZoneGone(zoneDone: zoneDone, leftHalfway: leftHalfway) == expected)
    }
}

// MARK: - (B) Las marcas

@Suite("Puerta privada · borrado a medias · las marcas", .serialized)
struct PrivateGateHalfwayWipeFlagsTests {

    typealias Logic = WelcomePrivateICloudGateLogic

    private func freshDefaults(_ name: String = #function) throws -> UserDefaults {
        let suite = "test.privateGateHalfway.\(name).\(UUID().uuidString)"
        UserDefaults().removePersistentDomain(forName: suite)
        return try #require(UserDefaults(suiteName: suite))
    }

    /// **El recorrido del ticket.** Borrado armado, zona borrada, falla lo del teléfono, la persona sale: con el
    /// desarme de la puerta del Welcome queda «a medias» sin arm, y el arranque PREGUNTA en vez de olvidarlo o de
    /// terminarlo a ciegas.
    @Test func welcomeLeavingAfterTheZone_remembersAndTheLaunchAsks() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)

        StorageModePersistence.disarmFailedICloudCorpusWipe(d)

        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(StorageModePersistence.isICloudCorpusWipeLeftHalfway(d), "salir olvidó que iCloud ya quedó vacío")
        #expect(Logic.lateWipeLaunch(armed: StorageModePersistence.isICloudCorpusWipeArmed(d),
                                     leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway(d),
                                     storageMode: .icloud) == .askLeftHalfway)
    }

    /// El comportamiento de antes, que sigue siendo el de la puerta privada de la activación: retirar a secas se
    /// lleva la zona. Es la premisa del ticket, y por qué ese montaje no puede usar el mismo desarme que el Welcome.
    @Test func plainDisarm_forgetsTheZone() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeZoneDone(d)

        StorageModePersistence.clearICloudCorpusWipeArm(d)

        #expect(!StorageModePersistence.isICloudCorpusWipeLeftHalfway(d))
        #expect(!StorageModePersistence.isICloudCorpusWipeZoneDone(d))
    }

    /// Salir de un fallo que NO llegó a la zona no inventa un «a medias».
    @Test func leavingBeforeTheZone_leavesNothingBehind() throws {
        let d = try freshDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)

        StorageModePersistence.disarmFailedICloudCorpusWipe(d)

        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(d))
        #expect(!StorageModePersistence.isICloudCorpusWipeLeftHalfway(d))
    }

    /// Un reintento que vuelve a fallar ANTES de la zona, sobre un borrado que ya estaba a medias, no lo pierde al salir.
    @Test func aRetryThatFailsEarly_keepsTheHalfwayOnLeave() throws {
        let d = try freshDefaults()
        d.set(true, forKey: StorageModePersistence.icloudCorpusWipeLeftHalfwayKey)
        StorageModePersistence.armICloudCorpusWipe(d)

        StorageModePersistence.disarmFailedICloudCorpusWipe(d)

        #expect(StorageModePersistence.isICloudCorpusWipeLeftHalfway(d))
        #expect(Logic.failureFoundZoneGone(zoneDone: StorageModePersistence.isICloudCorpusWipeZoneDone(d),
                                           leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway(d)),
                "la pantalla de ese fallo diría «intactos» con iCloud ya vacío")
    }
}

// MARK: - (C) El cableado

@Suite("Puerta privada · borrado a medias · cableado (source-scan)")
struct PrivateGateHalfwayWipeWiringTests {

    private static let gate = "Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift"
    private static let container = "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"
    private static let activation = "Yala/App/Views/Groups/FullModeActivationView.swift"
    private static let contentView = "Yala/App/ContentView.swift"

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    /// Sin las líneas de comentario: los docblocks citan los literales que aquí se buscan.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo por llaves balanceadas, desde un marcador que abre una.
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

    /// Los argumentos de cada llamada, por paréntesis balanceados. Todas: hay dos montajes por fichero.
    private static func calls(of marker: String, in source: String) -> [String] {
        var result: [String] = []
        var cursor = source.startIndex
        while let start = source.range(of: marker, range: cursor..<source.endIndex) {
            let chars = Array(source[start.upperBound...])
            var depth = 1
            var i = 0
            while i < chars.count {
                if chars[i] == "(" { depth += 1 }
                if chars[i] == ")" { depth -= 1; if depth == 0 { break } }
                i += 1
            }
            result.append(String(chars[0..<min(i, chars.count)]))
            cursor = start.upperBound
        }
        return result
    }

    private static func slice(from start: String, to end: String, in text: String) throws -> String {
        let a = try #require(text.range(of: start), "no está: \(start)")
        let b = try #require(text.range(of: end, range: a.upperBound..<text.endIndex), "no está: \(end) tras \(start)")
        return String(text[a.upperBound..<b.lowerBound])
    }

    private static func expectOrder(_ first: String, before second: String, in text: String, _ why: String,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try #require(text.range(of: first), "no está: \(first)", sourceLocation: sourceLocation)
        let b = try #require(text.range(of: second), "no está: \(second)", sourceLocation: sourceLocation)
        #expect(a.lowerBound < b.lowerBound, Comment(rawValue: why), sourceLocation: sourceLocation)
    }

    // MARK: La puerta

    /// **EL PIN DEL BUG.** Salir de la puerta pasa por `disarm()`, no por el desarme a secas que se llevaba la zona. Y
    /// desde cualquier fase (ticket `private-gate-back-from-found-keeps-a-resumed-arm`): la salida no pregunta en qué
    /// fase está, porque la única que no debe desarmar —el borrado en vuelo— no tiene «volver».
    @Test("salir de la puerta desarma sin olvidar la zona, desde cualquier fase")
    func leaveGate_disarmsWithoutForgettingTheZone() throws {
        let src = try Self.code(Self.gate)
        let leave = try Self.body(of: "private func leaveGate() {", in: src)
        try Self.expectOrder("disarm()", before: "onBack()", in: leave, "desarma antes de salir")
        for filtro in ["if ", "guard ", "switch "] {
            #expect(!leave.contains(filtro), """
                la salida vuelve a filtrar por fase (`\(filtro)`): desde `.found`, `.confirmingWipe`, `.foundDevice` o
                `.checking` —a las que el arranque trae de vuelta tras un kill en `.wiping`— el arm sobrevive y la nube lo
                reanuda a ciegas. Leído: \(leave)
                """)
        }
        // **La otra mitad, y ahora es la única red**: desarmar sin condición solo es seguro porque el «volver» no existe
        // con un borrado en vuelo. Sin estas dos líneas, el chevron sale en pleno borrado y retira el arm con la
        // operación corriendo: un kill después deja la zona o las filas a medias sin nada que lo termine.
        let back = try Self.body(of: "private var backAction: (() -> Void)? {", in: src)
        #expect(back.contains("if phase == .wiping { return nil }"), "leído: \(back)")
        #expect(back.contains("if case .wipingDevice = phase { return nil }"), "leído: \(back)")
        #expect(!leave.contains("clearICloudCorpusWipeArm"), """
            el desarme a secas se lleva la marca de la zona: tras «Dejarlo por ahora» nada recuerda que iCloud ya está vacío
            """)
    }

    /// El desarme bifurca por el montaje: con filas, el de «a medias»; sin filas (solo zona), el de siempre.
    @Test("el desarme es el del aviso tardío donde el borrado toca filas, y el de siempre donde no")
    func disarm_forksOnTheMount() throws {
        let src = try Self.code(Self.gate)
        let disarm = try Self.body(of: "private func disarm() {", in: src)
        let rama = try Self.slice(from: "if halfwayWipe.reachesDeviceRows {", to: "} else {", in: disarm)
        #expect(rama.contains("StorageModePersistence.disarmFailedICloudCorpusWipe()"), "leído: \(rama)")
        #expect(!rama.contains("clearICloudCorpusWipeArm"))
        let otra = try Self.slice(from: "} else {", to: "}", in: disarm)
        #expect(otra.contains("StorageModePersistence.clearICloudCorpusWipeArm()"), "leído: \(otra)")
        let discard = try Self.body(of: "private func discardPendingWipe() {", in: src)
        #expect(discard.contains("disarm()"), "las salidas sin validar también pueden llegar con la zona ya ida")
        #expect(!discard.contains("clearICloudCorpusWipeArm"))
    }

    /// `measure()`: la marca y la medida del teléfono deciden; terminar va a `.wiping`, y retirar va antes del arm.
    @Test("iCloud vacío: termina, retira o sigue según el montaje")
    func measure_resolvesTheHalfwayByMount() throws {
        let src = try Self.code(Self.gate)
        let measure = try Self.body(of: "private func measure() async {", in: src)
        let plano = measure.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(plano.contains("WelcomePrivateICloudGateLogic.afterEmptyMeasure( halfwayWipe, "
                               + "leftHalfway: StorageModePersistence.isICloudCorpusWipeLeftHalfway(), "
                               + "zoneDone: StorageModePersistence.isICloudCorpusWipeZoneDone(), "
                               + "measuredDevice: deviceCorpus != nil )"), "leído: \(measure)")
        let finish = try Self.slice(from: "case .finishHalfwayWipe:", to: "case .proceed(retiresHalfway: true):",
                                    in: measure)
        // Aplanado y entero: `contains("phase = .wiping")` lo cumpliría también `.wipingDevice(…)`, que en la activación
        // (sin corpus del teléfono) cae en el fallo y no borra las filas importadas.
        #expect(finish.split(whereSeparator: \.isWhitespace).joined(separator: " ") == "phase = .wiping",
                "leído: \(finish)")
        #expect(!finish.contains("onProceed()"), "terminar el borrado no puede seguir al onboarding encima de las filas")
        let retires = try Self.slice(from: "case .proceed(retiresHalfway: true):",
                                     to: "case .proceed(retiresHalfway: false):", in: measure)
        try Self.expectOrder("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()",
                             before: "StorageModePersistence.clearICloudCorpusWipeArm()", in: retires,
                             "un kill entre las dos deja la marca sin arm: el arranque no vuelve a la puerta")
        #expect(retires.contains("onProceed()"))
        let keeps = try Self.slice(from: "case .proceed(retiresHalfway: false):", to: "case .foundData", in: measure)
        #expect(!keeps.contains("clearICloudCorpusWipeLeftHalfway"), "sin medir las dos mitades no se retira")
        #expect(keeps.contains("discardPendingWipe()"))
    }

    /// El borrado que termina bien resuelve el «a medias» donde toca filas, antes del arm y nunca en el fallo.
    @Test("un borrado de la puerta que termina bien retira la marca donde toca filas")
    func wipeSuccess_retiresTheHalfway() throws {
        let src = try Self.code(Self.gate)
        let wipe = try Self.body(of: "private func wipe() async {", in: src)
        let fallo = try Self.slice(from: "guard failure == nil else {", to: "return", in: wipe)
        #expect(!fallo.contains("clearICloudCorpusWipeLeftHalfway"), "un fallo no resuelve nada")
        let exito = String(wipe[try #require(wipe.range(of: "if clearsResidualPreferencesOnWipe {")).lowerBound...])
        let retiro = try Self.slice(from: "if halfwayWipe.reachesDeviceRows {", to: "}", in: exito)
        #expect(retiro.contains("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()"), "leído: \(exito)")
        try Self.expectOrder("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()",
                             before: "StorageModePersistence.clearICloudCorpusWipeArm()", in: exito,
                             "la marca antes que el arm, como en `measure()`")
    }

    // MARK: Los tres montajes

    /// Cada montaje declara su remedio, y va emparejado con SU borrado. Un `.leaveForLateNotice` en la activación
    /// llevaría a quien activa al `.handover` del aviso tardío, que purga sus grupos.
    @Test("cada montaje declara el remedio de su alcance")
    func mounts_declareTheRemedyOfTheirScope() throws {
        let welcome = Self.calls(of: "WelcomePrivateICloudGateView(", in: try Self.code(Self.container))
        #expect(welcome.count == 2)
        for call in welcome {
            #expect(call.contains("halfwayWipe: .leaveForLateNotice"), "leído: \(call)")
        }
        let activation = Self.calls(of: "WelcomePrivateICloudGateView(", in: try Self.code(Self.activation))
        #expect(activation.count == 2)
        let zoneOnly = try #require(activation.first(where: { $0.contains("performWipe: { await performICloudZoneWipe() }") }))
        #expect(zoneOnly.contains("halfwayWipe: .nothingLeftBehind"), "leído: \(zoneOnly)")
        let importedRows = try #require(activation.first(where: {
            $0.contains("performWipe: { await performICloudZoneAndImportedRowsWipe() }")
        }))
        #expect(importedRows.contains("halfwayWipe: .finishOnReentry"), "leído: \(importedRows)")
        for call in activation {
            #expect(!call.contains(".leaveForLateNotice"), """
                el remedio del aviso tardío es `.handover`: purgaría los grupos de quien activa
                """)
        }
    }

    /// La premisa del emparejamiento: qué borra cada closure de la activación.
    @Test("premisa: la puerta privada borra solo zona, y «Empezar desde cero» zona y filas importadas")
    func premise_theActivationScopes() throws {
        let src = try Self.code(Self.contentView)
        #expect(src.contains("performICloudZoneWipe: { await performICloudCorpusWipe(.zoneOnly) },"))
        let imported = try Self.body(of: "performICloudZoneAndImportedRowsWipe: {", in: src)
        #expect(imported.contains("await performICloudCorpusWipe(.importedRows)"))
    }

    // MARK: La activación y el arranque

    /// Ningún activador ve el «Terminar de borrar» del aviso tardío: la marca sale antes de declarar la sesión privada.
    @Test("completar la activación retira la marca antes del eje")
    func completion_retiresTheHalfwayBeforeTheAxis() throws {
        let complete = try Self.body(of: "private func completeFullActivation() {", in: try Self.code(Self.activation))
        try Self.expectOrder("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()",
                             before: "sessionState.hasPrivateSession = true", in: complete, """
            con la sesión privada declarada y la marca viva, el arranque ofrece «Terminar de borrar» (`.handover`) y
            purga los grupos que la activación conserva
            """)
    }

    /// «Restaurar» desde el Welcome se queda con lo que hay: retira la marca en su portal, antes de salir.
    @Test("«Restaurar» del Welcome retira la marca")
    func welcomeRestore_retiresTheHalfway() throws {
        let src = try Self.code(Self.container)
        let portal = try Self.body(of: "private func handleExistingOption(_ option: WelcomeAccountChoiceLogic.ExistingOption) {",
                                   in: src)
        let restore = try Self.slice(from: "case .restoreICloud:", to: "case .cloudSignIn", in: portal)
        #expect(restore.contains("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()"), "leído: \(restore)")
        let cloud = String(portal[try #require(portal.range(of: "case .cloudSignIn")).lowerBound...])
        #expect(!cloud.contains("clearICloudCorpusWipeLeftHalfway"), "la nube la retira en el arranque, no aquí")
        // Y las dos puertas que ofrecen «Traer mis datos» salen por ese portal.
        let restores = src.components(separatedBy: "handleExistingOption(.restoreICloud)").count - 1
        #expect(restores == 2)
    }

    /// En la nube la marca se retira, y ni se pregunta ni se borra.
    @Test("el arranque en la nube retira el arm y la marca sin preguntar ni borrar")
    func launch_inTheCloudRetiresTheMark() throws {
        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: try Self.code(Self.contentView))
        #expect(check.contains("storageMode: CloudSyncFlags.storageMode"))
        let retire = try Self.slice(from: "case .retireInCloud:", to: "case .askLeftHalfway:", in: check)
        #expect(retire.contains("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()"), "leído: \(retire)")
        #expect(retire.contains("StorageModePersistence.clearICloudCorpusWipeArm()"), """
            en la nube el arm se queda puesto: `lateWipeLaunch` ya no lo reanuda, pero sigue ahí para el día que el
            dispositivo vuelva a iCloud y lo reanude sobre datos que ya no son los que se pidió borrar. Leído: \(retire)
            """)
        #expect(!retire.contains("presentLateICloudMirrorNotice"))
        #expect(!retire.contains("performICloudCorpusWipe"))
    }

    /// El Welcome con espejo no mide el teléfono en la puerta: lo mide el onboarding privado. Solo la rama sin datos
    /// retira la marca; la otra pregunta y borra, y el borrado ya la retira.
    @Test("el onboarding privado que arranca con el teléfono vacío retira la marca")
    func freshPrivateStart_retiresOnlyWhenThePhoneIsEmpty() throws {
        let start = try Self.body(of: "private func startFreshPrivateOnboarding() {", in: try Self.code(Self.contentView))
        let conDatos = try Self.slice(from: "if hasLocalDataNow() {", to: "} else {", in: start)
        #expect(!conDatos.contains("clearICloudCorpusWipeLeftHalfway"), "con datos en el teléfono sigue a medias")
        let sinDatos = String(start[try #require(start.range(of: "} else {")).upperBound...])
        try Self.expectOrder("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()", before: "showOnboarding = true",
                             in: sinDatos, "el onboarding nuevo arrancaría con la marca viva")
    }
}
