//
//  GroupsEntryKeptGroupsTests.swift
//  YalaTests
//
//  Quien entra con una cuenta de solo grupos y deja el alta a medias no ve sus propios grupos como «datos de otra
//  persona» en la puerta privada del Welcome. Ticket `groups-entry-left-half-done-reaches-the-private-gate-with-group-rows`.
//
//  El camino real no se puede conducir en el simulador (bajo XCUITest el montaje nunca es neutro y la puerta no mide sin
//  el seam, que finge la lectura entera), así que se reproduce aquí la cadena de decisiones con las piezas de producción.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Alta de Grupos a medias · la puerta privada", .serialized)
struct GroupsEntryKeptGroupsTests {

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    /// Lo que la puerta lee del teléfono cuando el canal ya bajó los grupos de la persona: con la marca que lee hoy.
    private func gateReading(_ d: UserDefaults, sessionSub: String?) -> WelcomePrivateICloudGateLogic.DeviceDataReading {
        WelcomePrivateICloudGateLogic.deviceDataReading(
            personal: false, groups: true,
            groupsKeptForThisPerson: LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: sessionSub, d))
    }

    private func insertGroup(_ context: ModelContext, zone: String) {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = zone
        group.isBackendGroup = true
        context.insert(group)
    }

    /// REPRODUCCIÓN del ticket con la marca de antes (nadie la escribía al entrar): la persona entra, el canal baja sus
    /// grupos y la puerta privada los lee como de otra persona.
    @Test func sinMarca_laPuertaVeSusPropiosGruposComoAjenos() {
        let d = defaults()
        #expect(gateReading(d, sessionSub: "sub-ana") == .present)
    }

    /// El arreglo: al entrar, con el teléfono sin grupos, se apunta la marca atada a su sesión; lo que baja después es de
    /// ella y la puerta deja de verlo como datos ajenos.
    @Test func alEntrarSinGrupos_seApunta_yLaPuertaYaNoLosCuenta() throws {
        let context = try makeTestContext()
        let d = defaults()
        let previous = LateNoticeKeptGroupsMark.currentSessionSubProvider
        LateNoticeKeptGroupsMark.currentSessionSubProvider = { "sub-ana" }
        defer { LateNoticeKeptGroupsMark.currentSessionSubProvider = previous }

        LateNoticeKeptGroupsMark.recordAtGroupsEntryIfNoGroupsYet(context: context, d)
        insertGroup(context, zone: "zona-de-ana")   // el canal baja sus grupos
        try context.save()

        #expect(gateReading(d, sessionSub: "sub-ana") == .none)
        // Otra cuenta abierta después la invalida: con la sesión de otra persona, sus grupos vuelven a ser ajenos.
        #expect(gateReading(d, sessionSub: "sub-beto") == .present)
    }

    /// Con grupos YA en el teléfono al entrar (una sesión de la persona anterior que sobrevivió a una reinstalación pudo
    /// bajarlos en el arranque) no se apunta nada: el Welcome hace lo de siempre.
    @Test func alEntrarConGruposYaPresentes_noSeApunta() throws {
        let context = try makeTestContext()
        let d = defaults()
        insertGroup(context, zone: "zona-anterior")
        try context.save()
        let previous = LateNoticeKeptGroupsMark.currentSessionSubProvider
        LateNoticeKeptGroupsMark.currentSessionSubProvider = { "sub-ana" }
        defer { LateNoticeKeptGroupsMark.currentSessionSubProvider = previous }

        LateNoticeKeptGroupsMark.recordAtGroupsEntryIfNoGroupsYet(context: context, d)

        #expect(d.string(forKey: LateNoticeKeptGroupsMark.key) == nil)
        #expect(gateReading(d, sessionSub: "sub-ana") == .present)
    }

    @Test("Solo con cero grupos contados; sin poder contar, no", arguments: [
        (0 as Int?, true), (1, false), (3, false), (nil, false),
    ])
    func shouldRecordAtGroupsEntry(_ count: Int?, _ expected: Bool) {
        #expect(LateNoticeKeptGroupsMark.shouldRecordAtGroupsEntry(localGroupCount: count) == expected)
    }

    /// Con la marca, los demás lectores también los tratan como suyos: el borrado del teléfono no purga Grupos ni
    /// retira la sesión (el alcance del traspaso sellaba el dominio de la propia persona).
    @Test func conLaMarca_elBorradoDelTelefonoNoPurgaSusGrupos() {
        #expect(!WelcomeKeptGroupsLogic.deviceWipePurgesTheGroupsDomain(groupsKeptForThisPerson: true))
        #expect(!WelcomeKeptGroupsLogic.freshStartRetiresThePreviousPerson(groupsKeptForThisPerson: true))
        #expect(WelcomeKeptGroupsLogic.welcomeICloudWipeScope(groupsKeptForThisPerson: true) == .importedRows)
    }

    // MARK: - El cableado

    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
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

    /// `onEnterGroupsOnly` apunta la marca SOLO con la sesión abierta en este intento, y antes de abrir la puerta de
    /// Grupos (que es donde el canal empieza a bajar).
    @Test func onEnterGroupsOnly_apuntaLaMarca_soloConSesionAbiertaAqui_antesDeAbrirLaPuerta() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let entry = try Self.body(of: "onEnterGroupsOnly: { offersFullActivation, sessionOpenedHere in", in: src)
        let guarded = try Self.body(of: "if sessionOpenedHere {", in: entry)
        #expect(guarded.contains("LateNoticeKeptGroupsMark.recordAtGroupsEntryIfNoGroupsYet(context: modelContext)"),
                "la entrada a Grupos no apunta la marca: la puerta privada vería sus grupos como ajenos")
        #expect(entry.components(separatedBy: "LateNoticeKeptGroupsMark.").count == 2,
                "la marca se apunta fuera de la condición: una sesión del llavero de la persona anterior la ganaría")
        let mark = try #require(entry.range(of: "if sessionOpenedHere {"))
        let gate = try #require(entry.range(of: "welcomeFlowInitialStep = .groupsGate(purpose: .createGroup)"))
        #expect(mark.upperBound <= gate.lowerBound)
        // Y la vista que firma pasa el testigo real, no una constante.
        let welcome = try Self.code("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        #expect(welcome.contains("onEnterGroupsOnly(destino == .enterGroupsOnlyOfferingFullActivation, sessionOpenedHere)"))
    }
}
