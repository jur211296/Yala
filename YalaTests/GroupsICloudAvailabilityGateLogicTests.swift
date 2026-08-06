//
//  GroupsICloudAvailabilityGateLogicTests.swift
//  YalaTests
//
//  Tabla completa del gate "Grupos necesita iCloud" (molde GroupsBetaGateLogicTests).
//
//  Dos mitades y ninguna cubre a la otra:
//    1. La DECISIÓN — tabla de las 8 celdas (iCloud × canal backend × uitest).
//    2. El CABLEADO — source-scan de que `ContentView` le pasa el flag REAL. Sin él, un
//       `isBackendChannelEnabled: false` hardcodeado en el call-site devolvería el muro a
//       producción con las 8 celdas en VERDE.
//
//  Por qué el cableado necesita un escáner y no un test de comportamiento: el call-site vive
//  en el `@ViewBuilder` de `ContentView.viewForTab(.groups)`, inalcanzable desde un unitario, y
//  la exención `isUITest` deja fuera a los XCUITest POR DISEÑO (el sim no tiene cuenta iCloud;
//  sin la exención el gate interceptaría GroupsSmokeUITests y DeeplinkRoutingUITests enteros).
//  Es la misma forma que el pin del call-site de `applyUITestProTier` en
//  UITestProTierIsolationTests.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupsICloudAvailabilityGateLogic · gate por cuenta iCloud")
struct GroupsICloudAvailabilityGateLogicTests {

    struct Caso: Sendable {
        let icloudDisponible: Bool
        let canalBackend: Bool
        let esUITest: Bool
        let esperado: Bool
        let porque: String
    }

    /// Las 8 celdas. Las cuatro de `canalBackend: false` son las vigentes desde `93512d59` y
    /// están intactas: son la NO-REGRESIÓN de la rama `.icloud`, donde sigue casi todo el parque.
    static let tabla: [Caso] = [
        // — Canal OFF: comportamiento CloudKit-era, byte-idéntico al de siempre —
        Caso(icloudDisponible: false, canalBackend: false, esUITest: false, esperado: true,
             porque: "sin iCloud y sin canal, Grupos vive en CloudKit ⇒ el muro es la verdad"),
        Caso(icloudDisponible: true, canalBackend: false, esUITest: false, esperado: false,
             porque: "con cuenta iCloud el gate nunca dispara"),
        Caso(icloudDisponible: false, canalBackend: false, esUITest: true, esperado: false,
             porque: "exención uitest: el sim no tiene cuenta y los XCUITest de Grupos lanzan sin -uitest-fake-icloud"),
        Caso(icloudDisponible: true, canalBackend: false, esUITest: true, esperado: false,
             porque: "con cuenta, el uitest no cambia nada"),

        // — Canal ON: el gate se retira ENTERO, iCloud deja de ser requisito —
        Caso(icloudDisponible: false, canalBackend: true, esUITest: false, esperado: false,
             porque: "LA CELDA DEL BUG: born-cloud sin iCloud con el canal ON tiene que entrar a Grupos"),
        Caso(icloudDisponible: true, canalBackend: true, esUITest: false, esperado: false,
             porque: "con canal ON el gate no dispara ni teniendo cuenta"),
        Caso(icloudDisponible: false, canalBackend: true, esUITest: true, esperado: false,
             porque: "canal ON y exención coinciden en retirar el gate"),
        Caso(icloudDisponible: true, canalBackend: true, esUITest: true, esperado: false,
             porque: "nada dispara el gate"),
    ]

    @Test(arguments: tabla)
    func tablaCompleta(_ caso: Caso) {
        #expect(
            GroupsICloudAvailabilityGateLogic.shouldShowGate(
                isAccountAvailable: caso.icloudDisponible,
                isBackendChannelEnabled: caso.canalBackend,
                isUITest: caso.esUITest
            ) == caso.esperado,
            """
            iCloud=\(caso.icloudDisponible) canal=\(caso.canalBackend) uitest=\(caso.esUITest) \
            → se esperaba \(caso.esperado): \(caso.porque)
            """
        )
    }

    /// La aserción que carga el peso, nombrada aparte a propósito: es la ÚNICA celda que cambia
    /// de valor si alguien devuelve el predicado a `!isAccountAvailable && !isUITest`. Un usuario
    /// born-cloud (sin cuenta iCloud del OS) con el canal de Grupos encendido —producción hoy:
    /// `groupsBackendCompiledDefault = true` y rollout al 100%— tiene que llegar al tab, que es
    /// justo la dependencia que la épica Modo Nube existe para quitar.
    @Test func sinICloud_conCanalBackend_noMuestraElGate() {
        #expect(GroupsICloudAvailabilityGateLogic.shouldShowGate(
            isAccountAvailable: false, isBackendChannelEnabled: true, isUITest: false
        ) == false, "El muro CloudKit-era volvió a bloquear a la población born-cloud.")
    }

    /// El pin del CALL SITE. `expected` no es decoración: sin el conteo, un método renombrado o un
    /// fichero movido dejarían al escáner sin encontrar nada y la suite pasaría en verde sin
    /// comprobar nada — la familia de "Executed 0 tests".
    @Test func contentViewLePasaElFlagReal_yNoUnLiteral() throws {
        let contentView = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appending(path: "Yala/App/ContentView.swift")

        // Sin las líneas de comentario: el porqué del cableado se explica AHÍ nombrando el flag, y
        // contar prosa haría que documentar el invariante lo rompiera.
        let source = try String(contentsOf: contentView, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        let llamadas = source.components(separatedBy: "GroupsICloudAvailabilityGateLogic.shouldShowGate(").count - 1
        #expect(llamadas == 1, "Se esperaba exactamente 1 call-site del gate, hay \(llamadas).")

        let cableado = source.components(
            separatedBy: "isBackendChannelEnabled: CloudSyncFlags.groupsBackendEnabled"
        ).count - 1
        #expect(
            cableado == 1,
            """
            ContentView ya no le pasa `CloudSyncFlags.groupsBackendEnabled` al gate. Un literal ahí \
            devuelve el muro "Grupos necesita iCloud" a todo usuario sin cuenta iCloud del OS —con el \
            canal encendido en producción— y las 8 celdas de la tabla siguen en VERDE.
            """
        )
    }
}
