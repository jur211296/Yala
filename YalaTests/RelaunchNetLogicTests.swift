//
//  RelaunchNetLogicTests.swift
//  YalaTests
//
//  Tabla de la decisión pura de las redes de relaunch terminal (fix carrera de anchors
//  2026-07-14): verify loop de presentación efectiva + exit-on-background.
//
//  R0 (2026-08-10) añade el TERCER término del exit-on-background —el terminal del Welcome— y con él
//  la tabla EXHAUSTIVA de los tres: hasta el chip cada término tenía su test suelto, así que un cuarto
//  podía entrar sin que nadie comprobara sus combinaciones.
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

@Suite("Relaunch net — veredicto del verify loop (presentación efectiva)")
struct RelaunchNetVerdictTests {

    @Test
    func notArmed_standsDown_regardlessOfEverything() {
        #expect(RelaunchNetLogic.verdict(armed: false, coverDidAppear: false, attempt: 0) == .standDown)
        // Desarmado gana incluso con cover vivo o intentos agotados.
        #expect(RelaunchNetLogic.verdict(armed: false, coverDidAppear: true, attempt: 0) == .standDown)
        #expect(RelaunchNetLogic.verdict(armed: false, coverDidAppear: false, attempt: 99) == .standDown)
    }

    @Test
    func coverAppeared_isSatisfied_evenBeyondCap() {
        #expect(RelaunchNetLogic.verdict(armed: true, coverDidAppear: true, attempt: 0) == .satisfied)
        // El cover vivo gana SIEMPRE — jamás togglar (dismiss/re-present) un cover real,
        // ni aunque el contador haya rebasado el cap por cualquier vía.
        #expect(RelaunchNetLogic.verdict(
            armed: true, coverDidAppear: true, attempt: RelaunchNetLogic.maxAttempts + 3
        ) == .satisfied)
    }

    @Test
    func noCover_underCap_retries() {
        #expect(RelaunchNetLogic.verdict(armed: true, coverDidAppear: false, attempt: 0) == .retry)
        // Frontera: el último intento permitido es attempt == maxAttempts - 1.
        #expect(RelaunchNetLogic.verdict(
            armed: true, coverDidAppear: false, attempt: RelaunchNetLogic.maxAttempts - 1
        ) == .retry)
    }

    @Test
    func noCover_atCap_exhausts() {
        #expect(RelaunchNetLogic.verdict(
            armed: true, coverDidAppear: false, attempt: RelaunchNetLogic.maxAttempts
        ) == .exhausted)
        #expect(RelaunchNetLogic.verdict(
            armed: true, coverDidAppear: false, attempt: RelaunchNetLogic.maxAttempts + 1
        ) == .exhausted)
    }
}

@Suite("Relaunch net — exit(0) en background (decisión owner UX 2026-07-14)")
struct RelaunchExitOnBackgroundTests {

    @Test
    func background_withSignOutAwaitingRelaunch_exits() {
        #expect(RelaunchNetLogic.shouldExitOnBackground(
            scenePhase: .background, signOutPhase: .awaitingRelaunch,
            secondaryEntryArmedUnmounted: false, welcomeMirrorRelaunchArmed: false
        ))
    }

    @Test
    func background_withSecondaryEntryArmed_exits() {
        #expect(RelaunchNetLogic.shouldExitOnBackground(
            scenePhase: .background, signOutPhase: .idle,
            secondaryEntryArmedUnmounted: true, welcomeMirrorRelaunchArmed: false
        ))
    }

    /// **R0 · LA FILA NUEVA, y la MUTACIÓN del chip.** Quitar el término `welcomeMirrorRelaunchArmed` de
    /// la disyunción pone rojo este test: los otros dos están APAGADOS a propósito, así que es el único
    /// que puede sostener el `true`.
    ///
    /// Qué se pierde sin él: el usuario elige «restaurar de iCloud» en un fresh install, ve el terminal
    /// que le pide reabrir, se va al inicio… y la app sigue viva en background, así que al volver
    /// encuentra la misma pantalla pidiéndole otra vez lo mismo. Los otros dos terminales del proceso ya
    /// se cerraban solos desde 2026-07-14; este era el que quedaba pidiendo trabajo manual.
    @Test
    func background_withWelcomeMirrorRelaunchArmed_exits() {
        #expect(RelaunchNetLogic.shouldExitOnBackground(
            scenePhase: .background, signOutPhase: .idle,
            secondaryEntryArmedUnmounted: false, welcomeMirrorRelaunchArmed: true
        ))
    }

    @Test
    func background_withoutRelaunchPending_neverExits() {
        for phase: CloudSessionSignOut.Phase in [.idle, .working, .blocked(pendingCount: 3, reason: .transient)] {
            #expect(!RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: .background, signOutPhase: phase,
                secondaryEntryArmedUnmounted: false, welcomeMirrorRelaunchArmed: false
            ))
        }
    }

    /// **La tabla EXHAUSTIVA de los tres términos × las tres fases de escena.** Cada término suelto tenía
    /// su test; lo que no había era la combinatoria, y es donde viven los dos errores que un `||` invita a
    /// cometer: convertirlo en `&&` (que exigiría los tres a la vez y no dispararía casi nunca) y perder
    /// el `scenePhase == .background`, que soltaría el `exit(0)` en primer plano.
    @Test("los 3 términos × las 3 fases: solo `.background` con ALGO armado mata el proceso")
    func fullTable() {
        let signOutPhases: [CloudSessionSignOut.Phase] = [.idle, .awaitingRelaunch]
        for scene: ScenePhase in [.background, .inactive, .active] {
            for signOut in signOutPhases {
                for secondary in [false, true] {
                    for welcome in [false, true] {
                        let anythingArmed = signOut == .awaitingRelaunch || secondary || welcome
                        let expected = scene == .background && anythingArmed
                        #expect(RelaunchNetLogic.shouldExitOnBackground(
                            scenePhase: scene, signOutPhase: signOut,
                            secondaryEntryArmedUnmounted: secondary,
                            welcomeMirrorRelaunchArmed: welcome
                        ) == expected, "escena=\(scene) signOut=\(signOut) secundaria=\(secondary) welcome=\(welcome)")
                    }
                }
            }
        }
    }

    /// **El SEGUNDO pin del chip: `.inactive` JAMÁS dispara**, y ahora también con el término nuevo.
    /// `.inactive` es el app switcher y el centro de notificaciones — la app está A LA VISTA, así que
    /// matar el proceso ahí se le presenta al usuario (y a App Review) como un crash.
    @Test
    func inactiveOrActive_neverExits_evenArmed() {
        for scene: ScenePhase in [.inactive, .active] {
            #expect(!RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: scene, signOutPhase: .awaitingRelaunch,
                secondaryEntryArmedUnmounted: false, welcomeMirrorRelaunchArmed: false
            ))
            #expect(!RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: scene, signOutPhase: .idle,
                secondaryEntryArmedUnmounted: true, welcomeMirrorRelaunchArmed: false
            ))
            #expect(!RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: scene, signOutPhase: .idle,
                secondaryEntryArmedUnmounted: false, welcomeMirrorRelaunchArmed: true
            ))
            // Y con los TRES armados: ningún acúmulo de condiciones compra el permiso de matar en
            // foreground.
            #expect(!RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: scene, signOutPhase: .awaitingRelaunch,
                secondaryEntryArmedUnmounted: true, welcomeMirrorRelaunchArmed: true
            ))
        }
    }
}

// MARK: - R0 · el testigo del terminal del Welcome

/// El término nuevo no lee una fase de pantalla sino el DESTINO PENDIENTE que el portal del Welcome
/// persiste. Esta suite fija esa equivalencia por el lado del almacén: «hay destino» ≡ «el terminal está
/// puesto», que es lo que autoriza a matar el proceso.
@Suite("R0 · el testigo durable del terminal del Welcome")
struct WelcomeMirrorRelaunchArmedWitnessTests {

    @Test("armado ⇔ hay destino pendiente, para los CINCO destinos")
    func armedIffPendingDestination() {
        for destination in WelcomeMirrorRelaunchLogic.Destination.allCases {
            let defaults = makeIsolatedDefaults(prefix: "r0.armed.\(destination.rawValue)")
            #expect(WelcomePendingDestinationStore.peek(defaults) == nil, "premisa: empieza desarmado")

            WelcomePendingDestinationStore.set(destination, defaults: defaults)
            #expect(WelcomePendingDestinationStore.peek(defaults) != nil)
            #expect(RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: .background, signOutPhase: .idle,
                secondaryEntryArmedUnmounted: false,
                welcomeMirrorRelaunchArmed: WelcomePendingDestinationStore.peek(defaults) != nil
            ), "destino=\(destination)")
        }
    }

    /// **`peek` y no `consume`, y esto es lo que carga el peso.** Consumir en el call-site retiraría el
    /// destino sin honrarlo: el proceso muere, el arranque siguiente no encuentra nada que encaminar y el
    /// usuario que pidió restaurar de iCloud aterriza en el onboarding normal con su elección perdida —
    /// exactamente el daño para el que R2 lo hizo durable. Consultar el testigo NO puede tener efectos.
    @Test("consultar el testigo no consume el destino: sigue ahí para el arranque siguiente")
    func peekingDoesNotConsume() {
        let defaults = makeIsolatedDefaults(prefix: "r0.peek")
        WelcomePendingDestinationStore.set(.restoreICloud, defaults: defaults)

        // Tres consultas: una por cada vuelta a background que el usuario pueda dar antes del exit.
        for _ in 0..<3 {
            #expect(WelcomePendingDestinationStore.peek(defaults) == .restoreICloud)
        }
        #expect(WelcomePendingDestinationStore.consume(defaults) == .restoreICloud, """
            tras las consultas el destino tiene que seguir disponible para el encaminamiento del arranque.
            """)
    }

    /// El auto-exit es seguro **por construcción**: el portal escribe `hasShownWelcomeChooser = true`
    /// ANTES del destino, y ese flag es justamente el término que rompe los dos predicados de mount
    /// neutro ⇒ el arranque siguiente monta CON mirror y consume el destino. Sin esto habría bucle:
    /// neutro → terminal → exit → neutro.
    @Test("con el chooser ya visto, ningún predicado de mount neutro admite otro arranque neutro")
    func noRelaunchLoopIsPossible() {
        #expect(!SwiftDataConfiguration.isFreshInstallForNeutralMount(
            personalStoreFileExists: false, persistedMode: .icloud, mirrorOffArmed: false,
            secondarySessionActive: false, hasShownWelcomeChooser: true
        ), "R2: el chooser visto cierra la ventana del mount neutro de fresh")

        #expect(!SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: true, hasShownWelcomeChooser: true
        ), "R4: y también la del neutro durable")
    }
}

// MARK: - R0 · cableado (source-scan)

/// **Por qué además de las tablas.** El término nuevo puede estar perfecto y su tabla verde mientras
/// `YalaApp` le pasa `false`, o `consume()` en vez de `peek()`, o mientras alguien mueve el `exit(0)` a
/// `.inactive`. Lo que decide aquí es QUIÉN llama y CON QUÉ, y ningún test de comportamiento lo ve: el
/// call-site real corre en el `scenePhase` de la escena y su guard `isRunningTests` lo hace inalcanzable
/// desde la suite a propósito (jamás un `exit(0)` bajo tests).
@Suite("R0 · cableado del auto-exit del terminal del Welcome (source-scan)")
struct WelcomeRelaunchAutoExitWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo entre llaves balanceadas a partir de un marcador, SIN líneas de comentario. Acotar al cuerpo
    /// no es cosmético (lección de `TestProcessGuardTests`): un rango ancho comprobaría que el símbolo
    /// EXISTE en el fichero, no que se use aquí — y contar la prosa haría que documentar el invariante lo
    /// "cumpliera".
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
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// **LA MUTACIÓN del cableado.** Cablear el término a `false` deja el chip entero como código muerto
    /// con las cinco tablas de arriba en VERDE.
    @Test("`YalaApp` alimenta el término con el destino pendiente REAL")
    func yalaApp_feedsTheRealPendingDestination() throws {
        let src = try Self.source("Yala/App/YalaApp.swift")
        let scene = try Self.body(of: "private func handleScenePhase(_ newPhase: ScenePhase) {", in: src)
        #expect(scene.contains("welcomeMirrorRelaunchArmed: WelcomePendingDestinationStore.peek() != nil"), """
            El término tiene que recibir el testigo REAL. Con `false` el terminal del Welcome vuelve a
            pedirle al usuario que mate la app a mano, sin un solo test en rojo.
            """)
    }

    /// El gemelo del anterior, y NO es redundante: la forma correcta puede estar escrita y aun así ser
    /// destructiva si alguien "simplifica" `peek` a `consume` — el literal de arriba pasaría a fallar,
    /// sí, pero este dice por qué y falla con el mensaje que hace falta leer.
    @Test("el call-site consulta con `peek`, JAMÁS con `consume`")
    func callSiteNeverConsumes() throws {
        let src = try Self.source("Yala/App/YalaApp.swift")
        let scene = try Self.body(of: "private func handleScenePhase(_ newPhase: ScenePhase) {", in: src)
        #expect(!scene.contains("WelcomePendingDestinationStore.consume("), """
            Consumir aquí retira el destino sin honrarlo: el proceso muere y el arranque siguiente no tiene
            nada que encaminar ⇒ quien pidió restaurar de iCloud aterriza en el onboarding normal.
            """)
    }

    /// El `exit(0)` sigue colgando del veredicto y solo de él. Un `exit(0)` suelto en el cuerpo del
    /// `.background`, o movido al `.inactive`, mataría el proceso con la app a la vista.
    @Test("el `exit(0)` cuelga del veredicto de `RelaunchNetLogic`, y solo de él")
    func exitIsGatedByTheVerdict() throws {
        let src = try Self.source("Yala/App/YalaApp.swift")
        let scene = try Self.body(of: "private func handleScenePhase(_ newPhase: ScenePhase) {", in: src)
        #expect(scene.components(separatedBy: "exit(0)").count - 1 == 1, "un solo `exit(0)` en el cuerpo")
        let verdict = try #require(scene.range(of: "RelaunchNetLogic.shouldExitOnBackground("))
        let exitCall = try #require(scene.range(of: "exit(0)"))
        #expect(verdict.lowerBound < exitCall.lowerBound)
    }

    /// El copy del terminal tiene que decir la variante AUTO-EXIT. Si la pantalla se cierra sola y el
    /// texto sigue pidiendo «cierra la app del todo», la instrucción sobra y contradice lo que el usuario
    /// ve — es la misma asimetría que el chip vino a arreglar, con los papeles cambiados.
    @Test("el terminal usa su copy propio y no vuelve al `Storage.Relaunch` manual")
    func terminalKeepsItsOwnAutoExitCopy() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeMirrorRelaunchView.swift")
        #expect(src.contains("L10n.Welcome.MirrorRelaunch.body"))
        #expect(!src.contains("L10n.Storage.Relaunch."), """
            `Storage.Relaunch.body` describe una migración de un corpus que ya existe y pide matar la app:
            aquí las dos mitades serían falsas.
            """)
    }
}
