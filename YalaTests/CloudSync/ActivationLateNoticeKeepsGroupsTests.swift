//
//  ActivationLateNoticeKeepsGroupsTests.swift
//  YalaTests / CloudSync
//
//  Ticket `activation-private-gate-leaves-a-late-notice-that-purges-groups`.
//
//  Quien activa Yala completo desde solo-grupos sin poder preguntarle a iCloud sigue adelante con el testigo del espejo
//  tardío, y así debe ser: la validación se aplaza, no se tira. Pero el borrado de ese aviso era `.handover`, y días
//  después «Empezar de cero» le purgaba los grupos que la activación existía para conservar.
//
//  El arreglo: la activación apunta en `PrivateSessionMark` que la sesión nace de ella, y el aviso —con su «Terminar de
//  borrar» y la reanudación del arranque— borra con el alcance que eso decide (`ICloudWipeScope.lateNotice`).
//
//  Mutantes que estos tests matan (medidos, ver el PR):
//   (1) `lateNotice` devolviendo siempre `.handover` → la tabla.
//   (2) `set(false)` / `clear` sin retirar la marca → su vida.
//   (3) `completeFullActivation` sin escribir la marca, o escribiéndola DESPUÉS del eje → el cableado.
//   (4) el aviso o la reanudación con `.handover` escrito a mano → el cableado.
//   (5) sin pedir la convergencia del bridge tras conservar los grupos → el cableado.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct ActivationLateNoticeKeepsGroupsTests {

    // MARK: - La tabla

    @Test("el aviso tardío de una sesión nacida de la activación conserva los grupos y las preferencias")
    func lateNotice_afterFullActivation_keepsGroups() {
        let scope = ICloudWipeScope.lateNotice(sessionBornFromFullActivation: true)
        #expect(scope == .importedRows)
        #expect(scope.purgesGroupsDomain == false, """
            el aviso tardío de quien activó Yala completo purga el dominio de Grupos: son los grupos que la activación
            existe para conservar, y el copy del aviso no los nombra.
            """)
        #expect(scope.resetsPreferences == false, "resetear preferencias devolvería al Welcome a quien ya activó")
        #expect(scope.deletesLocalRows, """
            sin borrar las filas personales, el espejo re-exporta a la zona recién vaciada lo que el aviso prometía borrar
            """)
    }

    @Test("fuera de la activación, el aviso tardío sigue siendo el handover")
    func lateNotice_otherwise_isTheHandover() {
        // El control: el aviso termina también el borrado a medias de la puerta del Welcome, que es una frontera de
        // usuario. Si esto cambiara, el dominio de Grupos de la persona anterior dejaría de sellarse.
        #expect(ICloudWipeScope.lateNotice(sessionBornFromFullActivation: false) == .handover)
    }

    // MARK: - La vida de la marca

    @Test("la marca: ausente es «no», y vive y muere con el eje")
    func bornFromFullActivation_livesAndDiesWithTheAxis() {
        let d = makeIsolatedDefaults(prefix: "test.bornFromActivation")
        #expect(!PrivateSessionMark.isBornFromFullActivation(d), "ausente ⇒ `false`: el comportamiento anterior")

        PrivateSessionMark.markBornFromFullActivation(d)
        #expect(PrivateSessionMark.isBornFromFullActivation(d))

        // Encender el eje (lo hace `completeFullActivation` justo después, y otra vez el onboarding tras el borrado)
        // no la retira: los grupos siguen siendo de la misma persona.
        PrivateSessionMark.set(true, d)
        #expect(PrivateSessionMark.isBornFromFullActivation(d), "encender el eje se llevó de dónde nació la sesión")

        // Apagarlo sí: una sesión que deja de ser privada ya no es la que nació de la activación.
        PrivateSessionMark.set(false, d)
        #expect(!PrivateSessionMark.isBornFromFullActivation(d), """
            la marca sobrevivió a que el eje se apagara: la vida siguiente heredaría un aviso tardío que no sella el
            dominio de Grupos de otra persona
            """)

        // Y el reset a «recién instalado» (cierre de sesión y relevo de «Empiezo de cero»).
        PrivateSessionMark.markBornFromFullActivation(d)
        PrivateSessionMark.clear(d)
        #expect(!PrivateSessionMark.isBornFromFullActivation(d), """
            la marca sobrevivió al cierre de sesión: la persona siguiente recibiría el borrado de quien activó
            """)
    }

    // MARK: - Los grupos sobreviven al borrado del aviso

    /// El tramo local de `performICloudCorpusWipe` purga el dominio de Grupos **solo** con `scope.purgesGroupsDomain`
    /// (lo fija `HandoverGroupsDomainTests`), y `wipeAllUserData(resetsPreferences: false)` no lo nombra (lo fija
    /// `ActivationRestoreDiscardTests`). Este test no ejecuta `performICloudCorpusWipe` —es `private` en `ContentView` y
    /// habla con CloudKit—: encadena el hecho de la sesión, leído de `UserDefaults`, hasta la purga real del dominio
    /// (marca → scope → `wipeLocalGroupsDomain`), con su control en la otra dirección.
    @Test("con la sesión nacida de la activación, el borrado del aviso tardío deja los grupos en el teléfono",
          arguments: [true, false])
    func lateWipe_groupsSurvive_onlyForTheActivation(_ bornFromActivation: Bool) throws {
        let d = makeIsolatedDefaults(prefix: "test.lateWipeGroups")
        if bornFromActivation { PrivateSessionMark.markBornFromFullActivation(d) }
        let context = try makeTestContext()
        for group in try context.fetch(FetchDescriptor<SplitGroup>()) { context.delete(group) }
        context.insert(SplitGroup(name: "Viaje a Cusco"))
        try context.save()

        let scope = ICloudWipeScope.lateNotice(
            sessionBornFromFullActivation: PrivateSessionMark.isBornFromFullActivation(d))
        if scope.purgesGroupsDomain {
            try DataWipeService.wipeLocalGroupsDomain(
                in: context, defaults: d, retireCloudSession: {}, resetSyncState: {}, witness: .quiet)
        }

        let remaining = try context.fetchCount(FetchDescriptor<SplitGroup>())
        if bornFromActivation {
            #expect(remaining == 1, "el aviso tardío de quien activó Yala completo se llevó sus grupos")
        } else {
            // El control positivo: el mismo tramo sí purga fuera de la activación, así que el caso de arriba mide algo.
            #expect(remaining == 0, "el control no purgó: el test no distingue los dos alcances")
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

    /// Entre dos delimitadores balanceados a partir de un marcador.
    private static func balanced(after marker: String, open: Character, close: Character,
                                 in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == open { depth += 1 }
            if chars[i] == close { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    private static func body(of marker: String, in source: String) throws -> String {
        try balanced(after: marker, open: "{", close: "}", in: source)
    }

    private static func expectOrder(_ first: String, before second: String, in source: String, _ porque: String,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try #require(source.range(of: first), "no encontrado: \(first)")
        let b = try #require(source.range(of: second), "no encontrado: \(second)")
        #expect(a.lowerBound < b.lowerBound, Comment(rawValue: porque), sourceLocation: sourceLocation)
    }

    @Test("la activación apunta de dónde nace la sesión, y ANTES de encender el eje")
    func completeFullActivation_writesTheOriginBeforeTheAxis() throws {
        let src = try Self.code("Yala/App/Views/Groups/FullModeActivationView.swift")
        let complete = try Self.body(of: "private func completeFullActivation() {", in: src)
        try Self.expectOrder("PrivateSessionMark.markBornFromFullActivation()",
                             before: "sessionState.hasPrivateSession = true", in: complete, """
            la marca va detrás del eje: un kill entre las dos deja una sesión privada cuyo aviso tardío purga los grupos
            """)
    }

    @Test("solo la activación escribe la marca")
    func onlyTheActivationWritesTheOrigin() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala")
        let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var writers: [String] = []
        var rawWriters: [String] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            if url.lastPathComponent != "PrivateSessionMark.swift", text.contains("markBornFromFullActivation(") {
                writers.append(url.lastPathComponent)
            }
            if text.contains("bornFromFullActivationKey") || text.contains("cloudSync.privateSessionBornFromFullActivation") {
                rawWriters.append(url.lastPathComponent)
            }
        }
        #expect(writers == ["FullModeActivationView.swift"], """
            otro sitio escribe «la sesión nació de la activación»: su aviso tardío dejaría de sellar el dominio de Grupos,
            y si es el Welcome, ese dominio puede ser de otra persona. Escritores: \(writers)
            """)
        #expect(rawWriters == ["PrivateSessionMark.swift"], """
            alguien escribe la key a mano, saltándose `markBornFromFullActivation`. Escritores: \(rawWriters)
            """)
    }

    @Test("el aviso, su «Terminar de borrar» y la reanudación pasan por el MISMO borrado tardío")
    func lateNoticeAndResume_shareOneWipe() throws {
        let src = try Self.code("Yala/App/ContentView.swift")

        let sheet = try Self.balanced(after: "LateICloudMirrorNoticeView(", open: "(", close: ")", in: src)
        #expect(sheet.contains("performWipe: { await performLateICloudWipe() }"), "Tramo leído: \(sheet)")
        #expect(sheet.contains("onWiped: { settleAfterLateICloudWipe() }"), "Tramo leído: \(sheet)")

        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: src)
        #expect(check.contains("let failure = await performLateICloudWipe()"))
        #expect(!check.contains("performICloudCorpusWipe("), """
            la reanudación del arranque volvió a escribir su scope a mano: a quien activó Yala completo, un kill durante el
            borrado le purgaría los grupos al arrancar, sin una sola pantalla.
            """)

        let scope = try Self.body(of: "private var lateICloudWipeScope: ICloudWipeScope {", in: src)
        #expect(scope.contains(
            "ICloudWipeScope.lateNotice(sessionBornFromFullActivation: PrivateSessionMark.isBornFromFullActivation())"))

        let wipe = try Self.body(of: "private func performLateICloudWipe() async -> String? {", in: src)
        #expect(wipe.contains("let scope = lateICloudWipeScope"))
        #expect(wipe.contains("await performICloudCorpusWipe(scope)"), "el borrado tardío no usa el alcance que decidió")
    }

    @Test("con los grupos conservados, sus filas puenteadas vuelven y las señales se re-miden")
    func keptGroups_reconvergeTheBridgeAndRemeasure() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wipe = try Self.body(of: "private func performLateICloudWipe() async -> String? {", in: src)
        let kept = try Self.body(of: "if !scope.purgesGroupsDomain {", in: wipe)
        #expect(kept.contains("GroupsBridgeRestoreConvergenceStore.markPending()"), """
            el borrado se lleva las `TransactionItem` puenteadas de los grupos y nadie las repone: la persona conserva sus
            grupos con el Panel y los Registros vacíos de gastos de grupo.
            """)
        try Self.expectOrder("guard failure == nil else { return failure }",
                             before: "GroupsBridgeRestoreConvergenceStore.markPending()", in: wipe, """
            la convergencia se pide también cuando el borrado falló: nada se borró y el arranque re-puentea por nada
            """)

        let settle = try Self.body(of: "private func settleAfterLateICloudWipe() {", in: src)
        // La CONDICIÓN, no solo las ramas: invertida, el `.importedRows` bajaría `hasExistingData` a `false`.
        let handover = try Self.body(of: "if lateICloudWipeScope.purgesGroupsDomain {", in: settle)
        #expect(handover.contains("hasExistingData = false"), "con el handover se fue todo: la señal baja")
        let remeasure = try Self.body(of: "} else {", in: settle)
        #expect(remeasure.contains("hasExistingData = checkHasExistingData()"), """
            con los grupos conservados, `hasExistingData` baja a `false`: cuenta también los grupos, y le mentiría a toda la app
            """)
        #expect(remeasure.contains("hasPersonalData = checkHasPersonalData()"))
        #expect(settle.contains("hasCompletedOnboarding = false"), "el corpus personal se fue: hay que volver a empezarlo")
    }

    @Test("con los grupos conservados, las liquidaciones confirmadas vuelven a puentearse")
    func keptGroups_reArmTheConfirmedSettlements() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wipe = try Self.body(of: "private func performLateICloudWipe() async -> String? {", in: src)
        let kept = try Self.body(of: "if !scope.purgesGroupsDomain {", in: wipe)
        #expect(kept.contains("armSettlementLegsAfterLateWipe()"), """
            el borrado se lleva las patas de las liquidaciones y la convergencia solo repone gastos: la cuenta de grupos
            cuenta lo prestado sin descontar lo ya cobrado o pagado
            """)
        let arm = try Self.body(of: "private func armSettlementLegsAfterLateWipe() {", in: src)
        #expect(arm.contains(".filter(\\.isConfirmed)"), "el bridge solo crea las confirmadas: el resto gastaría intentos")
        #expect(arm.contains("GroupsPendingBridgeIntent.arm(expenseIDs: [], settlementIDs: Set(confirmed), channel: .backend)"))
    }

    @Test("el borrado del Welcome retira la marca ANTES de borrar")
    func welcomeWipe_retiresTheOriginFirst() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wrapper = try Self.body(of: "performICloudCorpusWipe: {\n                cancelWipeGrace()", in: src)
        try Self.expectOrder("PrivateSessionMark.clearBornFromFullActivation()",
                             before: "await performICloudCorpusWipe(.handover)", in: wrapper, """
            el borrado del Welcome es `.handover`: con la marca viva, un corte a medias lo terminaría el aviso tardío con
            `.importedRows`, sin sellar el dominio de Grupos
            """)
    }
}
