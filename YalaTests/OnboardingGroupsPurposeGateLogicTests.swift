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
//  A6 DE D-A7 añade la segunda suite del fichero: la VISIBILIDAD de la card, que es una decisión
//  distinta del bloqueo al tap. Mismo reparto de mitades (tabla + source-scan) y misma razón para
//  que el XCUITest no baste: bajo `-uitest` no hay launch arg que ponga el device en `.cloud`
//  (`CloudSyncFlags.storageMode` cae en `StorageModePersistence.read()`, que sin la key es
//  `.icloud`), así que el determinista solo puede ejercitar la columna `.icloud` —la
//  no-regresión— y la celda que carga el peso vive aquí.
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

/// A6 de D-A7 · la card «Dividir gastos con amigos» desaparece del selector cuando el alta es
/// nube. Suite aparte de la del muro porque son decisiones distintas sobre la misma card: aquélla
/// dice si el TAP se bloquea, ésta si la card llega a PINTARSE.
@Suite("OnboardingGroupsPurposeGateLogic · visibilidad de la card de grupos (A6)")
struct OnboardingGroupsPurposeCardVisibilityTests {

    struct Caso: Sendable {
        let flujoInicial: Bool
        let modo: StorageMode
        let esperado: Bool
        let porque: String
    }

    /// Las 4 celdas. Las dos de `.icloud` son la NO-REGRESIÓN del 99 % del parque: la card sigue
    /// exactamente donde estaba, con el mismo término de siempre (`mode == .initial`).
    static let tabla: [Caso] = [
        // — `.icloud`: byte-idéntico al comportamiento de siempre —
        Caso(flujoInicial: true, modo: .icloud, esperado: true,
             porque: "onboarding inicial en iCloud: la card es la de siempre"),
        Caso(flujoInicial: false, modo: .icloud, esperado: false,
             porque: "FullModeActivation nunca ofrece volver a «solo grupos» (término preexistente)"),

        // — `.cloud`: la card desaparece —
        Caso(flujoInicial: true, modo: .cloud, esperado: false,
             porque: "LA CELDA DE A6: en modo nube «solo grupos» dejaría el backend recién estrenado vacío"),
        Caso(flujoInicial: false, modo: .cloud, esperado: false,
             porque: "los dos motivos concurren; ninguno rescata a la card"),
    ]

    @Test(arguments: tabla)
    func tablaCompleta(_ caso: Caso) {
        #expect(
            OnboardingGroupsPurposeGateLogic.shouldShowGroupsCard(
                isInitialFlow: caso.flujoInicial,
                storageMode: caso.modo
            ) == caso.esperado,
            """
            flujoInicial=\(caso.flujoInicial) modo=\(caso.modo.rawValue) \
            → se esperaba \(caso.esperado): \(caso.porque)
            """
        )
    }

    /// La aserción que carga el peso, nombrada aparte: es la ÚNICA celda que cambia de valor si
    /// alguien quita el término `.cloud` del predicado. Un usuario que acaba de darse de alta en
    /// la nube (D-A7: consent → sign-in → claim → relanzamiento → ESTE onboarding) no puede
    /// elegir un propósito que no usa el store personal.
    @Test func enModoNube_laCardNoSePinta() {
        #expect(OnboardingGroupsPurposeGateLogic.shouldShowGroupsCard(
            isInitialFlow: true, storageMode: .cloud
        ) == false, "«Solo grupos» volvió a ofrecerse en un alta nube: dejaría el backend vacío.")
    }

    /// La otra dirección, que es la que protege al parque existente: en `.icloud` el predicado ES
    /// el término de siempre, sin añadidos. Si alguien invirtiera la condición del modo, aquí se
    /// vería aunque la celda de arriba siguiera dando `false` por casualidad.
    @Test func enICloud_laVisibilidadEsExactamenteLaDeHoy() {
        for flujoInicial in [true, false] {
            #expect(
                OnboardingGroupsPurposeGateLogic.shouldShowGroupsCard(
                    isInitialFlow: flujoInicial, storageMode: .icloud
                ) == flujoInicial,
                "En .icloud la visibilidad tiene que seguir siendo `mode == .initial` y nada más."
            )
        }
    }

    /// LA INVARIANTE QUE A6 NO PUEDE ROMPER, afirmada aquí y no solo en el chip: ocultar la card
    /// no toca el enum ni la SSOT de la marca. `OnboardingUsageMode` sigue con CUATRO casos y
    /// `selectedCard(for:)` sigue siendo TOTAL (una card para cada modo) y ÚNICA (una sola).
    ///
    /// No es decoración: el arreglo perezoso de «que la card no exista» sería borrar el caso
    /// `.groupsOnly` o hacer que `selectedCard` devolviera `nil`, y cualquiera de los dos deja el
    /// selector con CERO cards marcadas para un usuario que ya venía en ese modo — el bug del
    /// chip C5 reintroducido por la puerta de atrás.
    @Test func ocultarLaCardNoTocaElEnumNiLaSSOTDeLaMarca() {
        let modos: [OnboardingUsageMode] = [.expensesOnly, .dayToDay, .fullControl, .groupsOnly]
        #expect(modos.count == 4, "OnboardingUsageMode dejó de tener cuatro casos.")

        for modo in modos {
            let card = OnboardingPurposeSelectionLogic.selectedCard(for: modo)
            let marcadas = OnboardingPurposeCard.allCases.filter {
                OnboardingPurposeSelectionLogic.isSelected($0, mode: modo)
            }
            #expect(marcadas == [card],
                    "Con \(modo) se esperaba exactamente una card marcada (\(card)), hubo \(marcadas).")
        }

        #expect(OnboardingPurposeSelectionLogic.selectedCard(for: .groupsOnly) == .groups,
                "A6 oculta la card, NO reasigna el modo a otra card.")
    }

    /// El pin del CALL SITE, en el molde del de arriba y por la misma razón: el predicado vive en
    /// el `body` de `OnboardingView`, inalcanzable desde un unitario. Sin este escáner, cablear
    /// `storageMode: .icloud` fijo devolvería la card a producción con las 4 celdas en VERDE.
    ///
    /// Los conteos no son decoración: sin ellos, un método renombrado o un fichero movido dejarían
    /// al escáner sin encontrar nada y la suite pasaría en verde sin comprobar nada — la familia
    /// de "Executed 0 tests".
    @Test func onboardingViewGateaLaCardConElModoREAL() throws {
        let onboardingView = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appending(path: "Yala/App/Views/Onboarding/OnboardingView.swift")

        // Sin las líneas de comentario: el porqué del cableado se explica AHÍ nombrando la lógica
        // y el modo, y contar prosa haría que documentar el invariante lo rompiera.
        let source = try String(contentsOf: onboardingView, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        let llamadas = source.components(
            separatedBy: "OnboardingGroupsPurposeGateLogic.shouldShowGroupsCard("
        ).count - 1
        #expect(llamadas == 1, "Se esperaba exactamente 1 call-site de la visibilidad, hay \(llamadas).")

        let modo = source.components(
            separatedBy: "storageMode: CloudSyncFlags.storageMode"
        ).count - 1
        #expect(
            modo == 1,
            """
            OnboardingView ya no le pasa el modo de almacenamiento EFECTIVO a la visibilidad de la \
            card. Un literal ahí devuelve «Dividir gastos con amigos» al onboarding de un alta \
            nube —dejando vacío el backend recién estrenado— con las 4 celdas de la tabla en VERDE.
            """
        )

        let inicial = source.components(
            separatedBy: "isInitialFlow: mode == .initial"
        ).count - 1
        #expect(
            inicial == 1,
            """
            OnboardingView ya no le pasa `mode == .initial` a la visibilidad. Ese término es \
            PREEXISTENTE (FullModeActivation no debe reofrecer «solo grupos») y perderlo no lo \
            nota ninguna celda de la tabla.
            """
        )
    }
}
