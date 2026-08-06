//
//  OnboardingGroupsPurposeGateLogicTests.swift
//  YalaTests
//
//  Tabla del muro iCloud del selector de propósito del onboarding (molde
//  GroupsICloudAvailabilityGateLogicTests, que es el resultado de `965a4d86`).
//
//  Dos mitades y ninguna cubre a la otra:
//    1. La DECISIÓN — tabla de las 4 celdas (iCloud × canal backend).
//    2. El CABLEADO — source-scan de que `OnboardingView` le pasa el flag REAL. Sin él, un
//       `isBackendChannelEnabled: false` hardcodeado en el call-site devolvería el muro a
//       producción con las 4 celdas en VERDE.
//
//  Por qué el cableado necesita un escáner y no un test de comportamiento: el call-site vive
//  en el closure de acción de una `binaryCard` dentro del `body` de `OnboardingView`,
//  inalcanzable desde un unitario. Es la misma forma que el pin del call-site de
//  `applyUITestProTier` en UITestProTierIsolationTests.
//
//  Y por qué tampoco basta el XCUITest del área (`OnboardingGroupsOnlyGuardUITests`): bajo
//  `-uitest` el canal está SIEMPRE ON, así que ese test solo puede ejercitar la columna
//  `canalBackend: true`. Las dos celdas de canal OFF —la no-regresión del muro legítimo— solo
//  existen aquí.
//

import Foundation
import Testing

@testable import Yala

@Suite("OnboardingGroupsPurposeGateLogic · muro iCloud del selector de propósito")
struct OnboardingGroupsPurposeGateLogicTests {

    struct Caso: Sendable {
        let icloudDisponible: Bool
        let canalBackend: Bool
        let esperado: Bool
        let porque: String
    }

    /// Las 4 celdas. Las dos de `canalBackend: false` son la NO-REGRESIÓN: con el canal apagado
    /// (kill remoto, o producción antes del primer fetch de `/config`) los grupos siguen
    /// viviendo en CloudKit y el aviso sigue diciendo la verdad.
    static let tabla: [Caso] = [
        // — Canal OFF: comportamiento CloudKit-era, byte-idéntico al de siempre —
        Caso(icloudDisponible: false, canalBackend: false, esperado: true,
             porque: "sin iCloud y sin canal, Grupos vive en CloudKit ⇒ el muro es la verdad"),
        Caso(icloudDisponible: true, canalBackend: false, esperado: false,
             porque: "con cuenta iCloud la elección nunca se bloquea"),

        // — Canal ON: el muro se retira ENTERO, iCloud deja de ser requisito —
        Caso(icloudDisponible: false, canalBackend: true, esperado: false,
             porque: "LA CELDA DEL BUG: born-cloud sin iCloud con el canal ON tiene que poder elegir «Dividir gastos con amigos»"),
        Caso(icloudDisponible: true, canalBackend: true, esperado: false,
             porque: "con canal ON nada bloquea, ni teniendo cuenta"),
    ]

    @Test(arguments: tabla)
    func tablaCompleta(_ caso: Caso) {
        #expect(
            OnboardingGroupsPurposeGateLogic.shouldBlockSelection(
                isAccountAvailable: caso.icloudDisponible,
                isBackendChannelEnabled: caso.canalBackend
            ) == caso.esperado,
            """
            iCloud=\(caso.icloudDisponible) canal=\(caso.canalBackend) \
            → se esperaba \(caso.esperado): \(caso.porque)
            """
        )
    }

    /// La aserción que carga el peso, nombrada aparte a propósito: es la ÚNICA celda que cambia
    /// de valor si alguien devuelve el predicado a mirar solo `isAccountAvailable`. Un usuario
    /// born-cloud (sin cuenta iCloud del OS) con el canal de Grupos encendido —producción hoy:
    /// `groupsBackendCompiledDefault = true` en `CloudSyncFlags.swift:285` y
    /// `GROUPS_BACKEND_ROLLOUT_PERCENT = "100"` en `gateway/wrangler.toml:163`— tiene que poder
    /// elegir el propósito «Dividir gastos con amigos», que es la ÚNICA ruta del onboarding a
    /// `.groupsOnly`. Bloqueada, se queda sin salida salvo entrar por invitación.
    @Test func sinICloud_conCanalBackend_noBloqueaLaEleccion() {
        #expect(OnboardingGroupsPurposeGateLogic.shouldBlockSelection(
            isAccountAvailable: false, isBackendChannelEnabled: true
        ) == false, "El muro CloudKit-era volvió a bloquear el onboarding de la población born-cloud.")
    }

    /// El pin del CALL SITE. Los conteos no son decoración: sin ellos, un método renombrado o un
    /// fichero movido dejarían al escáner sin encontrar nada y la suite pasaría en verde sin
    /// comprobar nada — la familia de "Executed 0 tests".
    @Test func onboardingViewLePasaElFlagReal_yNoUnLiteral() throws {
        let onboardingView = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appending(path: "Yala/App/Views/Onboarding/OnboardingView.swift")

        // Sin las líneas de comentario: el porqué del cableado se explica AHÍ nombrando la
        // lógica y el flag, y contar prosa haría que documentar el invariante lo rompiera.
        let source = try String(contentsOf: onboardingView, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        let llamadas = source.components(
            separatedBy: "OnboardingGroupsPurposeGateLogic.shouldBlockSelection("
        ).count - 1
        #expect(llamadas == 1, "Se esperaba exactamente 1 call-site del muro, hay \(llamadas).")

        let canal = source.components(
            separatedBy: "isBackendChannelEnabled: CloudSyncFlags.groupsBackendEnabled"
        ).count - 1
        #expect(
            canal == 1,
            """
            OnboardingView ya no le pasa `CloudSyncFlags.groupsBackendEnabled` al muro. Un literal \
            ahí bloquea «Dividir gastos con amigos» a todo usuario sin cuenta iCloud del OS —con el \
            canal encendido en producción— y las 4 celdas de la tabla siguen en VERDE.
            """
        )

        let icloud = source.components(
            separatedBy: "isAccountAvailable: iCloudSyncService.shared.isAccountAvailable"
        ).count - 1
        #expect(
            icloud == 1,
            """
            OnboardingView ya no le pasa el token de ubiquity VIVO al muro. Un literal ahí rompe la \
            otra dirección: con el canal apagado el muro dejaría de proteger (o bloquearía siempre) \
            sin que ninguna celda de la tabla se entere.
            """
        )
    }
}
