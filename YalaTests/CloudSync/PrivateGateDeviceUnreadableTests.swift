//
//  PrivateGateDeviceUnreadableTests.swift
//  YalaTests / CloudSync
//
//  Ticket `private-gate-device-notice-has-no-forward-exit` (decisión de Jürgen del 2026-10-12: «solo lo alcanzable»).
//  En «Es mi primera vez → privado», la lectura de lo que ya hay en el teléfono fallaba CERRADA: un error de lectura
//  era «hay datos», y la persona veía «Ya hay datos en este teléfono» con dos salidas, borrar o volver, sin un solo dato
//  detrás. Ahora «no se pudo leer» es su propio desenlace (`.deviceUnreadable`), con «Reintentar» y «Volver».
//
//  Tres suites: la regla de la lectura con sus dos mitades, la tabla de la decisión y el cableado de la puerta.
//

import Foundation
import Testing
@testable import Yala

private typealias Gate = WelcomePrivateICloudGateLogic

@Suite("La puerta privada · la lectura del teléfono")
struct PrivateGateDeviceReadingTests {

    /// La tabla entera: cada mitad puede contestar sí, no o «no se pudo leer», con y sin los grupos que conservó el aviso
    /// tardío. Lo leído que cuenta gana; lo que no se pudo leer solo pesa si podría contar.
    @Test(arguments: [Bool?.some(true), .some(false), .none], [Bool?.some(true), .some(false), .none])
    func reading_fullTable(personal: Bool?, groups: Bool?) {
        for kept in [false, true] {
            let got = Gate.deviceDataReading(personal: personal, groups: groups, groupsKeptForThisPerson: kept)
            let expected: Gate.DeviceDataReading
            if personal == true || (!kept && groups == true) {
                expected = .present
            } else if personal == nil || (!kept && groups == nil) {
                expected = .unreadable
            } else {
                expected = .none
            }
            #expect(got == expected, "personal=\(String(describing: personal)) groups=\(String(describing: groups)) kept=\(kept)")
        }
    }

    /// **EL PIN DEL TICKET por la lectura.** Que no se pueda leer NO es «hay datos»: era el fallo cerrado que enseñaba el
    /// aviso de borrar sin datos detrás.
    @Test func bothHalvesUnreadable_isUnreadable_notPresent() {
        #expect(Gate.deviceDataReading(personal: nil, groups: nil, groupsKeptForThisPerson: false) == .unreadable)
    }

    /// Lo que SÍ se leyó manda: con datos personales a la vista, una mitad ilegible no esconde el aviso de siempre.
    @Test func whatWasRead_wins() {
        #expect(Gate.deviceDataReading(personal: true, groups: nil, groupsKeptForThisPerson: false) == .present)
        #expect(Gate.deviceDataReading(personal: nil, groups: true, groupsKeptForThisPerson: false) == .present)
    }

    /// Los grupos que conservó el aviso tardío son de quien está delante: ni cuentan como datos ni, ilegibles, frenan.
    @Test func keptGroups_neitherCountNorBlock() {
        #expect(Gate.deviceDataReading(personal: false, groups: true, groupsKeptForThisPerson: true) == .none)
        #expect(Gate.deviceDataReading(personal: false, groups: nil, groupsKeptForThisPerson: true) == .none)
    }
}

@Suite("La puerta privada · la decisión con el teléfono ilegible")
struct PrivateGateDeviceUnreadableDecisionTests {

    private static let someCorpus = ICloudPersonalCorpus(transactions: 3, accounts: 1, categories: 0, budgets: 0,
                                                         oldestTransactionDate: nil, truncated: false)

    /// **EL PIN DEL TICKET por la decisión.** Sin nada en iCloud que avisar —vacío, sin cuenta o sin red— y el teléfono
    /// ilegible, la puerta ya no enseña «Ya hay datos»: dice que no pudo revisarlo. Antes la lectura llegaba aquí como
    /// `true` y la salida era `.foundDeviceData`.
    @Test(arguments: [ICloudProbeOutcome.noAccount, .failed("boom"), .measured(.empty)])
    func unreadablePhone_withNothingInICloud_saysSo(outcome: ICloudProbeOutcome) {
        #expect(Gate.decide(skipValidation: false, outcome: outcome, deviceData: .unreadable) == .deviceUnreadable)
    }

    /// El corpus de iCloud sigue ganando: su aviso es el único con «traer mis datos», la salida que no destruye nada.
    @Test func iCloudCorpus_stillWins() {
        #expect(Gate.decide(skipValidation: false, outcome: .measured(Self.someCorpus), deviceData: .unreadable)
                == .foundData(Self.someCorpus))
    }

    /// Bajo XCUITest la puerta sigue de largo con cualquier lectura, también la ilegible.
    @Test func skipValidation_proceedsAlsoWhenUnreadable() {
        #expect(Gate.decide(skipValidation: true, outcome: .noAccount, deviceData: .unreadable) == .proceed)
    }

    /// Control: con la lectura buena, lo de siempre (el aviso del teléfono existe y sigue saliendo).
    @Test func readablePhone_keepsTheUsualOutcomes() {
        #expect(Gate.decide(skipValidation: false, outcome: .noAccount, deviceData: .present)
                == .foundDeviceData(iCloudUnverified: true))
        #expect(Gate.decide(skipValidation: false, outcome: .measured(.empty), deviceData: .none) == .proceed)
        #expect(Gate.decide(skipValidation: false, outcome: .noAccount, deviceData: .none) == .noICloud)
    }
}

@Suite("La puerta privada · el cableado del teléfono ilegible")
struct PrivateGateDeviceUnreadableWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

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
        let b = try #require(source.range(of: end, range: a.upperBound..<source.endIndex), "no está: \(end)")
        return String(source[a.upperBound..<b.lowerBound])
    }

    private static let gatePath = "Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift"

    /// La decisión nueva se pinta: sin el `case`, `.deviceUnreadable` se decidiría bien y no saldría nada.
    @Test func measure_paintsTheUnreadablePhase() throws {
        let measure = try Self.body(of: "private func measure() async {", in: try Self.code(Self.gatePath))
        #expect(measure.contains("case .deviceUnreadable:\n            phase = .deviceUnreadable"))
    }

    /// **El par botón ↔ acción**: «Reintentar» vuelve a medir y «Volver» sale por `leaveGate`. Ningún borrado cuelga de
    /// esta pantalla: no hay nada que se haya visto para borrar.
    @Test func unreadableScreen_retriesOrLeaves_andNeverWipes() throws {
        let src = try Self.code(Self.gatePath)
        let screen = try Self.slice(from: "case .deviceUnreadable:\n            twoWayNoticeContent(",
                                    to: "case .wipeFailed(let zoneGone):", in: src)
        #expect(screen.contains("primaryAction: { phase = .checking }"), "«Reintentar» tiene que volver a medir")
        #expect(screen.contains("secondaryAction: { leaveGate() }"), "«Volver» sale de la puerta, como el aviso hermano")
        #expect(!screen.contains("wip") && !screen.contains("Wipe"), "de esta pantalla no sale ningún borrado")
        #expect(screen.contains("identifier: \"welcome_private_icloud_device_unreadable\""))
    }

    /// La puerta del Welcome lee la versión con «no se pudo leer»; el resto de consumidores conserva el detector que
    /// falla cerrado (el alert de «Es mi primera vez» y las puertas de organizador e invitado).
    @Test func welcome_feedsTheGateReading_andKeepsTheFailClosedDetectorElsewhere() throws {
        let cv = try Self.code("Yala/App/ContentView.swift")
        #expect(cv.contains("welcomeDeviceDataReading: { readWelcomeDeviceDataForTheGate() },"))
        #expect(cv.contains("welcomeDeviceDataNow: { checkHasWelcomeDeviceData() },"))
        let reader = try Self.body(
            of: "private func readWelcomeDeviceDataForTheGate() -> WelcomePrivateICloudGateLogic.DeviceDataReading {",
            in: cv)
        #expect(reader.contains("groupsKeptForThisPerson: LateNoticeKeptGroupsMark.vouchesNow())"),
                "sin la marca del aviso tardío, los grupos conservados volverían a contar como datos de otro")
        #expect(!reader.contains("return true") && !reader.contains("= true"),
                "un fetch que lanza no puede volver a leerse como «hay datos»")
        // Y tampoco como «no hay» (review adversarial del 2026-10-12): un `groups = false` en el `catch` daría `.none` y
        // la puerta seguiría al onboarding encima de unos grupos que no se pudieron contar. Las dos mitades nacen `nil`
        // y solo las escribe una lectura que terminó.
        #expect(reader.contains("var personal: Bool?") && reader.contains("var groups: Bool?"))
        #expect(reader.components(separatedBy: "personal = ").count == 2
                && reader.components(separatedBy: "groups = ").count == 2,
                "cada mitad se escribe UNA vez, con la lectura que terminó: un `catch` que escriba un valor finge la lectura")
        #expect(reader.contains("personal = accounts > 0 || categories > 0")
                && reader.contains("groups = groupRows > 0 || bridged > 0"))
    }

    /// El seam finge la LECTURA y nada más: lo que se pinta lo decide la tabla de producción.
    @Test func seam_fakesTheReadingOnly() throws {
        let hooks = try Self.code("Yala/App/UITestHooks.swift")
        #expect(hooks.contains("\"-uitest-private-gate-device-reading\""))
        let measure = try Self.body(of: "private func measure() async {", in: try Self.code(Self.gatePath))
        #expect(measure.contains("let forcedDeviceReading = UITestHooks.privateGateDeviceReading"))
        #expect(measure.contains("WelcomePrivateICloudGateLogic.decide(skipValidation: false,"))
    }
}
