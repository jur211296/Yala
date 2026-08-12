//
//  GroupsOnboardingLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `GroupsOnboardingLogic.shouldShow`:
//  verifica el AND-gating de los 3 blockers (flag persistida, modo `.groupInvite`,
//  deeplink a grupo específico pendiente).
//
//  Sin SwiftUI, sin SwiftData, sin singletons, sin `makeTestContext()` — evita
//  flake R8 conocido.
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
struct GroupsOnboardingLogicTests {

    @Test func shouldShow_freshUserNoBlockersReturnsTrue() {
        #expect(GroupsOnboardingLogic.shouldShow(
            hasSeenEducational: false, hasPendingGroupDeeplink: false) == true)
    }

    @Test func shouldShow_alreadySeenReturnsFalse() {
        #expect(GroupsOnboardingLogic.shouldShow(
            hasSeenEducational: true, hasPendingGroupDeeplink: false) == false)
    }

    @Test func shouldShow_pendingGroupDeeplinkReturnsFalse() {
        #expect(GroupsOnboardingLogic.shouldShow(
            hasSeenEducational: false, hasPendingGroupDeeplink: true) == false)
    }

    /// Regression: ambos blockers presentes simultáneamente. Confirma AND-gating
    /// sin race entre evaluaciones (cualquier blocker bloquea independientemente).
    @Test func shouldShow_bothBlockersReturnsFalse() {
        #expect(GroupsOnboardingLogic.shouldShow(
            hasSeenEducational: true, hasPendingGroupDeeplink: true) == false)
    }
}

// MARK: - C2 · el hecho REAL que sustituye al corte por `.groupInvite`

/// **La tabla que cierra el punto 2 del chip.** El corte `onboardingMode == .groupInvite` era un proxy y
/// estaba mal en la dirección cara: `.groupInvite` es también lo que escribía la card «Solo grupos», así
/// que suprimía el educativo justo para quien entraba por la puerta que menos contexto daba — y que además
/// no pedía ni sesión ni consent. Son dos estados distintos y estaban colapsados en uno falso.
@Suite("GroupsOnboardingLogic · «ya vio un educativo de Grupos» (C2)")
struct GroupsEducationalSeenTests {

    private func seen(_ shown: Bool, _ mode: OnboardingMode, _ setup: Bool) -> Bool {
        GroupsOnboardingLogic.hasSeenAnyGroupsEducational(
            hasShownOnboarding: shown, onboardingMode: mode, hasCompletedSetup: setup)
    }

    /// La marca directa manda, en cualquier modo. La ponen los DOS educativos: el general
    /// (`GroupsOnboardingView`) y el del invitado (`GroupInviteOnboardingView`).
    @Test func laMarcaDirectaManda() {
        for mode in [OnboardingMode.full, .groupInvite, .completed] {
            for setup in [false, true] {
                #expect(seen(true, mode, setup) == true)
            }
        }
    }

    /// **LA CELDA DEL CHIP.** Modo Grupos pero SIN alta completada: es exactamente el estado en el que la
    /// card «Solo grupos» dejaba al usuario antes de C2, y donde el corte viejo le tapaba el educativo. Hoy
    /// ese estado ya no lo produce nadie —la card no escribe el modo hasta el final— pero la tabla lo fija:
    /// si alguien devuelve el corte por modo, esta celda cae.
    @Test func modoGruposSinAlta_noEsEvidenciaDeHaberVistoNada() {
        #expect(seen(false, .groupInvite, false) == false, """
            volvió el corte por `onboardingMode == .groupInvite`: suprime el educativo a quien está en modo \
            Grupos sin haber completado ningún alta, que es justo quien menos contexto tiene.
            """)
    }

    /// El término LEGACY, y su única razón de existir: quien completó su alta en modo Grupos ANTES de C2
    /// vio su educativo y no dejó marca. Sin esto, actualizar la app se lo volvería a presentar.
    @Test func modoGruposConAltaCompletada_esElParqueAnteriorAC2() {
        #expect(seen(false, .groupInvite, true) == true)
    }

    /// Los modos que no son Grupos no derivan nada del alta: un usuario de Yala completo que nunca abrió
    /// el tab tiene que ver el educativo la primera vez.
    @Test func otrosModos_noDerivanNadaDelAlta() {
        for mode in [OnboardingMode.full, .completed] {
            #expect(seen(false, mode, true) == false)
            #expect(seen(false, mode, false) == false)
        }
    }
}

// MARK: - A1 (D-A7) · CTA de sign-in del cierre

/// Tabla de `shouldShowSignInCTA`. Dos mitades y ninguna cubre a la otra:
///   1. La DECISIÓN — las 8 celdas (step × canal × sesión).
///   2. El CABLEADO — source-scan (suite de abajo) de que la vista pasa los valores REALES.
///      Sin él, un `hasSession: false` hardcodeado en el call-site devolvería el CTA a
///      "siempre visible" con las 8 celdas en VERDE.
///
/// Y por qué el cableado necesita escáner y no un test de comportamiento: el call-site vive
/// en el `body` de `GroupsOnboardingView`, inalcanzable desde un unitario; y bajo `-uitest`
/// el educativo NO se monta (`GroupsContainerView.evaluateGroupsOnboarding` hace early-return
/// con `UITestHooks.isActive`), así que tampoco hay XCUITest posible. El área es `agentic`.
@Suite("GroupsOnboardingLogic · CTA de sign-in del cierre (A1)")
struct GroupsOnboardingSignInCTATests {

    struct Caso: Sendable {
        let ultimoStep: Bool
        let canalBackend: Bool
        let sesion: Bool
        let esperado: Bool
        let porque: String
    }

    /// Las 8 celdas. Las 4 de `canalBackend: false` son la NO-REGRESIÓN: con el canal apagado
    /// (kill remoto, o producción antes del primer fetch de `/config`) Grupos sigue en CloudKit
    /// y no hay sesión Yala que pedir ⇒ el educativo queda byte-idéntico al de siempre.
    static let tabla: [Caso] = [
        // — Canal OFF: byte-idéntico al recorrido CloudKit-era —
        Caso(ultimoStep: true, canalBackend: false, sesion: false, esperado: false,
             porque: "sin canal no hay sesión Yala que pedir: el cierre sigue siendo solo «Ir a Grupos»"),
        Caso(ultimoStep: true, canalBackend: false, sesion: true, esperado: false,
             porque: "canal OFF nunca ofrece el CTA, tenga o no sesión"),
        Caso(ultimoStep: false, canalBackend: false, sesion: false, esperado: false,
             porque: "los steps intermedios siguen con «Continuar»"),
        Caso(ultimoStep: false, canalBackend: false, sesion: true, esperado: false,
             porque: "los steps intermedios nunca ofrecen sign-in"),

        // — Canal ON: el cierre convierte, pero solo sin sesión —
        Caso(ultimoStep: true, canalBackend: true, sesion: false, esperado: true,
             porque: "LA CELDA DEL CHIP: canal encendido y sin sesión ⇒ el cierre ofrece iniciar sesión"),
        Caso(ultimoStep: true, canalBackend: true, sesion: true, esperado: false,
             porque: "con sesión viva pedir sign-in sería un prompt sin sentido"),
        Caso(ultimoStep: false, canalBackend: true, sesion: false, esperado: false,
             porque: "el CTA es del CIERRE: un step intermedio no lo ofrece ni con el canal ON"),
        Caso(ultimoStep: false, canalBackend: true, sesion: true, esperado: false,
             porque: "ni step intermedio ni sesión viva"),
    ]

    @Test(arguments: tabla)
    func tablaCompleta(_ caso: Caso) {
        #expect(
            GroupsOnboardingLogic.shouldShowSignInCTA(
                isLastStep: caso.ultimoStep,
                flagOn: caso.canalBackend,
                hasSession: caso.sesion
            ) == caso.esperado,
            """
            ultimoStep=\(caso.ultimoStep) canal=\(caso.canalBackend) sesion=\(caso.sesion) \
            → se esperaba \(caso.esperado): \(caso.porque)
            """
        )
    }

    /// La aserción que carga el peso, nombrada aparte: es la celda que cambia si alguien
    /// devuelve el predicado a "siempre visible" (quitando el término `!hasSession`). Con
    /// sesión viva el educativo NO puede terminar pidiendo iniciar sesión — el usuario ya la
    /// tiene, y el prompt lo mandaría a una pantalla que no le pide nada.
    @Test func conSesionViva_elCierreNoOfreceSignIn() {
        #expect(GroupsOnboardingLogic.shouldShowSignInCTA(
            isLastStep: true, flagOn: true, hasSession: true
        ) == false, "El CTA de sign-in volvió a ser incondicional: aparece con sesión viva.")
    }

    /// La otra dirección de la misma mutación: sin el término `!hasSession` esta celda también
    /// seguiría verde, así que hace falta la de arriba; sin ESTA, un predicado degenerado a
    /// `false` pasaría desapercibido y el chip no habría construido nada.
    @Test func sinSesion_conCanalON_elCierreOfreceSignIn() {
        #expect(GroupsOnboardingLogic.shouldShowSignInCTA(
            isLastStep: true, flagOn: true, hasSession: false
        ) == true, "El CTA de sign-in del cierre desapareció para la población que lo necesita.")
    }
}

/// El pin del CABLEADO. Los conteos no son decoración: sin ellos, un método renombrado o un
/// fichero movido dejarían al escáner sin encontrar nada y la suite pasaría en verde sin
/// comprobar nada — la familia de "Executed 0 tests". Molde:
/// `OnboardingGroupsPurposeGateLogicTests.onboardingViewLePasaElFlagReal_yNoUnLiteral`.
@Suite("A1 · cableado del CTA de sign-in (source-scan)")
struct GroupsOnboardingSignInCTAWiringTests {

    /// Fuente sin líneas de comentario: el porqué del cableado se explica AHÍ nombrando la
    /// lógica y las señales, y contar prosa haría que documentar el invariante lo rompiera.
    private func source(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appending(path: relativePath)
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private func count(_ needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    @Test func laVistaPasaLasSenalesReales_yNoLiterales() throws {
        let view = try source("Yala/App/Views/Groups/Onboarding/GroupsOnboardingView.swift")

        let llamadas = count("GroupsOnboardingLogic.shouldShowSignInCTA(", in: view)
        #expect(llamadas == 1, "Se esperaba exactamente 1 call-site del predicado, hay \(llamadas).")

        let canal = count("flagOn: CloudSyncFlags.groupsBackendEnabled", in: view)
        #expect(
            canal == 1,
            """
            GroupsOnboardingView ya no le pasa `CloudSyncFlags.groupsBackendEnabled` al CTA. Un \
            literal ahí ofrece (o esconde) el sign-in con independencia del canal, y las 8 celdas \
            de la tabla siguen en VERDE.
            """
        )

        let sesion = count("hasSession: CloudAuthService.shared.hasSession", in: view)
        #expect(
            sesion == 1,
            """
            GroupsOnboardingView ya no le pasa la sesión VIVA al CTA. Con un `false` literal el \
            predicado vuelve a ser "siempre visible" —la mutación exacta que este chip existe \
            para impedir— sin que ninguna celda de la tabla se entere. Y la señal es la MISMA que \
            lee `GroupsContainerView` para `GroupsEmptyStateLogic.decide`: no se inventa otra.
            """
        )

        let emite = count("onResult(.completeAndSignIn)", in: view)
        #expect(emite == 1, "El CTA de sign-in ya no emite `.completeAndSignIn` (hay \(emite)).")
    }

    @Test func elSheetPideElSignInConLaPresentacionYaDesmontada() throws {
        let modifiers = try source("Yala/App/Theme/ViewModifiers.swift")

        #expect(
            count("case .completeAndSignIn:", in: modifiers) == 1,
            "El modifier del onboarding de Grupos ya no maneja `.completeAndSignIn`."
        )
        #expect(
            count("onDismiss:", in: modifiers) >= 1 && count("onRequestSignIn()", in: modifiers) == 1,
            """
            La petición de sign-in ya no sale del `onDismiss`. Emitirla con el sheet todavía \
            montado deja el intent RETENIDO por peek-first (o apila dos anchors presentando a la \
            vez, regla (4) de Presentaciones) ⇒ el CTA no hace NADA visible y ningún test de \
            comportamiento lo caza.
            """
        )
    }

    @Test func elContenedorReusaElIntentDelEmptyState() throws {
        let container = try source("Yala/App/Views/Groups/GroupsContainerView.swift")

        #expect(
            count("onRequestSignIn: { requestGroupsSignIn() }", in: container) == 1,
            """
            GroupsContainerView ya no cablea el CTA del educativo a `requestGroupsSignIn()`. El \
            chip A1 exige REUSAR el intent del empty state (`.presentGroupsSignIn`), no montar \
            una presentación nueva: un segundo productor duplicaría el dueño de esa cadena.
            """
        )
        // Un solo productor del intent en esta vista: el del empty state. Si aparece otro
        // `submit(.presentGroupsSignIn` de más, el CTA se montó por su cuenta.
        #expect(
            count("RouterEntryGate.shared.submit(.presentGroupsSignIn", in: container) == 2,
            "Cambió el nº de productores de `.presentGroupsSignIn` en GroupsContainerView."
        )
    }
}
