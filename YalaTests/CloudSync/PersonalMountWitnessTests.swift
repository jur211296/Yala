//
//  PersonalMountWitnessTests.swift
//  YalaTests / CloudSync
//
//  R1 del relanzamiento cero · los DOS testigos que colapsaban, y el contrato que impide que vuelvan a
//  colapsar. Cuatro mitades y ninguna cubre a las otras:
//
//   (A) La TABLA: las 4 decisiones de mount × lo que cada consumidor ve. Va por `allCases`, así que una
//       decisión nueva (el mount neutro de R2) entra sola y OBLIGA a declarar de qué lado cae.
//   (B) BYTE-IDENTIDAD: el mapeo nuevo reproduce EXACTAMENTE el testigo colapsado que sustituye. La
//       fórmula vieja se conserva aquí escrita como ORÁCULO — es la única forma de que el pin siga
//       comparando contra algo cuando el código viejo ya no existe.
//   (C) EL AVISO «monté sin CloudKit y ahora hay iCloud», que hasta R1 no tenía NI UN test pese a ser el
//       único lector del testigo durable.
//   (D) CABLEADO (source-scan): quién llama y con qué. La lógica puede estar perfecta y sus tablas verdes
//       mientras el call-site sigue pasando la disponibilidad de iCloud — familia de `AttestWiringTests`.
//
//  DARK: R1 no habilita ningún mount nuevo. Todo lo que estos tests fijan es que el testigo PUEDA decir lo
//  que antes no podía, sin mover una sola decisión de las de hoy.
//

import Foundation
import Testing

@testable import Yala

private typealias Decision = SwiftDataConfiguration.PersonalStoreDecision

// MARK: - (A) La tabla: 4 decisiones × los consumidores

@Suite("R1 · testigo de mount — la tabla de decisiones")
struct PersonalMountWitnessTableTests {

    @Test("las 4 decisiones de hoy, con su eje A (mirror adjunto) y su eje B (mirror espejando)")
    func table_ofTodaysFourDecisions() {
        // Eje A lo consumen los cuatro lectores del testigo de mount (`isMirrorConfirmedOff`/`On`, el gate
        // del motor y el deriver de la UI); eje B, el testigo durable del aviso. `localNoMirror` es la fila
        // que los separa: su `.automatic` ADJUNTA mirror (MEDIDO 2026-08-10) pero no espeja nada sin cuenta.
        let expected: [Decision: (attaches: Bool, mirrors: Bool)] = [
            .iCloudMirror:          (attaches: true,  mirrors: true),
            .localNoMirror:         (attaches: true,  mirrors: false),
            .cloudMirrorOff:        (attaches: false, mirrors: false),
            .secondaryCloudSession: (attaches: false, mirrors: false),
            // R2 · el mount neutro: `.none` EXPLÍCITO ⇒ no adjunta y no espeja. Que el eje B sea `false`
            // es lo que deja vivo el aviso de iCloud para un fresh install con cuenta disponible.
            .neutralNoMirror:       (attaches: false, mirrors: false),
        ]
        // Exhaustividad: si mañana entra una decisión y nadie la declara, esto cae antes que nada.
        #expect(Set(expected.keys) == Set(Decision.allCases),
                "toda decisión de mount tiene que declarar sus dos ejes en esta tabla")

        for decision in Decision.allCases {
            guard let row = expected[decision] else { continue }
            #expect(decision.attachesCloudKitMirror == row.attaches, "eje A de \(decision)")
            #expect(decision.mirrorsToICloud == row.mirrors, "eje B de \(decision)")
        }
    }

    @Test("eje C (R9): qué mounts son de MODO NUBE")
    func axisC_cloudModeMounts() {
        let expected: [Decision: Bool] = [
            .cloudMirrorOff: true, .secondaryCloudSession: true,
            .iCloudMirror: false, .localNoMirror: false,
            // R2 · el neutro NO es un mount de modo nube: es la AUSENCIA de elección. Decisión heredada de
            // R1 y la que hace que el aviso de iCloud le hable (§1.3 del spec).
            .neutralNoMirror: false,
        ]
        #expect(Set(expected.keys) == Set(Decision.allCases))
        for decision in Decision.allCases {
            #expect(decision.isCloudModeMount == expected[decision], "eje C de \(decision)")
        }
        // Y el eje C no es el eje A negado: `localNoMirror` no espeja, no es modo nube, y ADJUNTA mirror.
        #expect(Decision.localNoMirror.isCloudModeMount == false)
        #expect(Decision.localNoMirror.attachesCloudKitMirror == true)
    }

    @Test("los dos ejes NO son el mismo booleano — `localNoMirror` los separa")
    func theTwoAxesAreNotOneBoolean() {
        // Si alguien los colapsara en uno, esta aserción es la que lo dice. Con un solo booleano, o el aviso
        // queda mudo para el device sin iCloud (si gana el eje A) o el gate del motor deja arrancar con un
        // mirror adjunto (si gana el eje B).
        #expect(Decision.localNoMirror.attachesCloudKitMirror != Decision.localNoMirror.mirrorsToICloud)
    }

    @Test("consumidor · gate del motor: bloquea exactamente donde hay mirror adjunto en modo nube")
    func consumer_engineGate() {
        for decision in Decision.allCases {
            #expect(MigrationRuntimeGate.isPersonalMountMismatch(persistedMode: .cloud,
                                                                 mountedDecision: decision)
                    == decision.attachesCloudKitMirror, "montado=\(decision)")
        }
    }

    @Test("consumidor · deriver de la UI: los dos términos de relanzamiento leen el eje A")
    func consumer_uiStateDeriver() {
        for decision in Decision.allCases {
            // Término 1 (ida/adopt): armado + mirror todavía adjunto ⇒ hay que relanzar para apagarlo.
            let toCloud = CloudMigrationUIStateDeriver.derive(
                storageMode: .cloud, phase: .notStarted, mirrorOffArmed: true, mountedDecision: decision)
            #expect((toCloud == .needsRelaunch(.toCloud)) == decision.attachesCloudKitMirror,
                    "ida, montado=\(decision)")

            // Término 2 (reversa): la máquina pide mirror y este proceso montó SIN él ⇒ relanzar.
            let toICloud = CloudMigrationUIStateDeriver.derive(
                storageMode: .cloud, phase: .reverseMountMirror, mirrorOffArmed: false,
                mountedDecision: decision)
            #expect((toICloud == .needsRelaunch(.toICloud)) == !decision.attachesCloudKitMirror,
                    "reversa, montado=\(decision)")
        }
    }

    @Test("consumidor · testigo durable: escribe el eje B, y su default sigue siendo `true`")
    func consumer_durableWitness() {
        let defaults = makeIsolatedDefaults(prefix: "mountwitness")

        // Key ausente ⇒ `true` (usuario existente pre-update). Esa rama no la toca R1 y se pinnea para que
        // nadie la "limpie" al tocar el escritor.
        #expect(SwiftDataConfiguration.containerWasCreatedWithCloudKit(defaults) == true)

        for decision in Decision.allCases {
            SwiftDataConfiguration.markContainerCloudKitState(decision: decision, defaults: defaults)
            #expect(SwiftDataConfiguration.containerWasCreatedWithCloudKit(defaults) == decision.mirrorsToICloud,
                    "montado=\(decision)")
        }
    }
}

// MARK: - (B) Byte-identidad con el testigo colapsado que R1 sustituye

@Suite("R1 · byte-identidad con el testigo viejo")
struct PersonalMountWitnessParityTests {

    /// El colapso EXACTO que `capturePersonalStoreMountedModeOnce` hacía antes de R1, conservado aquí como
    /// oráculo. Copiarlo al test es deliberado: comparar el mapeo nuevo contra el código nuevo no probaría
    /// nada, y el viejo ya no existe en el árbol.
    private func legacyCollapsedWitness(_ decision: Decision) -> StorageMode {
        decision == .cloudMirrorOff || decision == .secondaryCloudSession ? .cloud : .icloud
    }

    /// Las cuatro decisiones que EXISTÍAN antes de R2 — las únicas para las que el testigo colapsado es un
    /// oráculo válido. `neutralNoMirror` queda fuera A PROPÓSITO y no por comodidad: el colapso viejo lo
    /// habría clasificado como `.icloud` (= mirror vivo), que es exactamente la mentira que R1 documentó y
    /// que dejaría al motor sin arrancar tras el alta. Que esta lista NO sea `allCases` es la afirmación.
    private static let preR2Decisions: [Decision] = [
        .iCloudMirror, .localNoMirror, .cloudMirrorOff, .secondaryCloudSession,
    ]

    @Test("el eje A reproduce el testigo colapsado para las 4 decisiones PRE-R2")
    func axisA_matchesLegacyWitness() {
        // Los cuatro consumidores del testigo de mount comparaban contra `.icloud` (= mirror vivo) o contra
        // `.cloud` (= mirror apagado). El eje A tiene que dar exactamente eso, decisión por decisión: para
        // los mounts que ya existían, R1+R2 no mueven una sola celda.
        for decision in Self.preR2Decisions {
            #expect(decision.attachesCloudKitMirror == (legacyCollapsedWitness(decision) == .icloud),
                    "montado=\(decision)")
        }
        // Y la lista de exclusión es exacta: si mañana entra una decisión más, nadie puede olvidarse de
        // decidir si es comparable con el oráculo viejo o no.
        #expect(Set(Decision.allCases).subtracting(Self.preR2Decisions) == [.neutralNoMirror])
    }

    @Test("el mount NEUTRO es justo lo que el testigo colapsado no podía expresar")
    func neutralMount_isWhatTheLegacyWitnessCouldNotSay() {
        // El colapso viejo lo habría llamado `.icloud` —el valor que los consumidores leen como «hay un
        // mirror escribiendo este store»— mientras el mount real es `.none` explícito. Esa distancia entre
        // el oráculo y la verdad ES el chip: con el testigo viejo, escribir el par `.cloud` tras el alta
        // daría `isPersonalMountMismatch == true` y el motor no arrancaría nunca.
        #expect(legacyCollapsedWitness(.neutralNoMirror) == .icloud)
        #expect(Decision.neutralNoMirror.attachesCloudKitMirror == false)
        #expect(MigrationRuntimeGate.isPersonalMountMismatch(
            persistedMode: .cloud, mountedDecision: .neutralNoMirror) == false,
            "el par .cloud sobre un mount neutro NO es mismatch — es el punto entero de R2")
    }

    @Test("el eje B reproduce la DISPONIBILIDAD en las celdas que su lector puede alcanzar")
    func axisB_matchesLegacyAvailability_onReachableCells() {
        // El escritor viejo guardaba `isICloudAvailable()`. Las dos decisiones donde su lector NO corta
        // (`checkForICloudMismatch` sale en `storageMode == .cloud`) son `.iCloudMirror` y `.localNoMirror`,
        // y en ellas la disponibilidad está DETERMINADA por la propia decisión: `.iCloudMirror` solo se
        // elige con iCloud disponible y `.localNoMirror` solo sin él (`personalStoreDecision`). Por eso el
        // cambio de escritor no mueve el aviso de ningún device de hoy.
        #expect(Decision.iCloudMirror.mirrorsToICloud == true)     // disponibilidad vieja: true
        #expect(Decision.localNoMirror.mirrorsToICloud == false)   // disponibilidad vieja: false

        // Y la premisa que lo sostiene, medida contra la función real y no asumida.
        for available in [true, false] {
            let decision = SwiftDataConfiguration.personalStoreDecision(
                storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: available,
                freshInstall: false, neutralDurable: false)
            #expect(decision == (available ? .iCloudMirror : .localNoMirror))
            #expect(decision.mirrorsToICloud == available,
                    "el eje B y la disponibilidad coinciden en las celdas alcanzables")
        }
    }

    @Test("con `freshInstall: false` la tabla de `personalStoreDecision` es la de siempre")
    func mountDecisionTable_unchangedForNonFreshDevices() {
        // Red de no-regresión: R2 añade UNA salida y la gatea por un predicado que TODO device con archivo
        // de store falla. Con el término apagado, las cuatro decisiones de siempre salen intactas.
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            secondarySessionActive: true, freshInstall: false, neutralDurable: false) == .secondaryCloudSession)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: true, iCloudAvailable: true,
            freshInstall: false, neutralDurable: false) == .cloudMirrorOff)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: false, iCloudAvailable: true,
            freshInstall: false, neutralDurable: false) == .iCloudMirror)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: false,
            freshInstall: false, neutralDurable: false) == .localNoMirror)
        #expect(Decision.allCases.count == 5, "R2 añade el mount neutro, y ninguna más")
    }
}

// MARK: - (C) El aviso «monté sin CloudKit y ahora hay iCloud»

@Suite("R1 · el aviso de mismatch de iCloud")
struct ICloudRestartAdviceTests {

    @Test("un mount SIN espejo por falta de cuenta + iCloud disponible ahora ⇒ se ofrece el reinicio")
    func warns_whenMountedWithoutMirroring_andICloudAppears() {
        #expect(SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: .localNoMirror, mountedWithMirroring: false, iCloudAvailableNow: true))
    }

    @Test("si el mount YA espejaba, no hay nada que avisar")
    func silent_whenMountedWithMirroring() {
        #expect(!SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: .iCloudMirror, mountedWithMirroring: true, iCloudAvailableNow: true))
    }

    @Test("sin iCloud ahora, no hay aviso aunque el mount no espejara")
    func silent_whenICloudStillAbsent() {
        #expect(!SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: .localNoMirror, mountedWithMirroring: false, iCloudAvailableNow: false))
    }

    @Test("R9: un mount de MODO NUBE es INERTE — tener iCloud no es un mismatch")
    func inert_onCloudModeMounts() {
        for decision in [Decision.cloudMirrorOff, .secondaryCloudSession] {
            for mirroring in [true, false] {
                for available in [true, false] {
                    #expect(!SwiftDataConfiguration.shouldOfferICloudRestart(
                        mountedDecision: decision, mountedWithMirroring: mirroring,
                        iCloudAvailableNow: available), "montado=\(decision)")
                }
            }
        }
    }

    @Test("R9 se decide por el MOUNT, no por el modo de AHORA (la ventana en caliente de la reversa)")
    func r9_decidedByTheMount_notByTheCurrentMode() {
        // La reversa persiste `.icloud` EN CALIENTE sobre un proceso montado en `.cloudMirrorOff`, y este
        // aviso corre en CADA vuelta a primer plano (`AppBootstrapper.handleBecameActive`), no solo cuando
        // cambia la cuenta de iCloud. Si el término R9 leyera el modo de ahora, esa ventana pediría un
        // «reinicia la app» encima del que la propia tarjeta de reversa ya está pidiendo.
        #expect(!SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: .cloudMirrorOff, mountedWithMirroring: false, iCloudAvailableNow: true))
    }

    @Test("EL PIN DEL CHIP: el aviso se decide por lo que se MONTÓ, no por si había iCloud al arrancar")
    func advice_readsTheMountDecision_notAvailability() {
        // Recorrido completo testigo→lector, que es donde muerde la mutación: si `markContainerCloudKitState`
        // volviera a guardar la DISPONIBILIDAD, un mount sin espejo hecho con cuenta iCloud presente
        // registraría `true` y este aviso quedaría MUDO — que es exactamente el device que se queda sin
        // mirror y sin forma de enterarse (§1.3 del spec del relanzamiento cero). Se usa `.localNoMirror`
        // porque es el ÚNICO mount de hoy que no espeja y no es de modo nube; el mount neutro de R2 entrará
        // por esta misma puerta.
        let defaults = makeIsolatedDefaults(prefix: "icloudadvice")

        SwiftDataConfiguration.markContainerCloudKitState(decision: .localNoMirror, defaults: defaults)
        #expect(SwiftDataConfiguration.containerWasCreatedWithCloudKit(defaults) == false,
                "un mount sin espejo tiene que quedar registrado como tal, hubiera o no cuenta iCloud")

        #expect(SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: .localNoMirror,
            mountedWithMirroring: SwiftDataConfiguration.containerWasCreatedWithCloudKit(defaults),
            iCloudAvailableNow: true))
    }
}

// MARK: - (D) Cableado (source-scan)

/// Por qué además de las tablas: el mapeo puede ser perfecto y sus tests verdes mientras el call-site sigue
/// pasando `isICloudAvailable()`, o mientras un consumidor se compara a mano contra un `StorageMode` que ya
/// no existe como testigo. Lo que decide aquí es QUIÉN llama y CON QUÉ, y eso solo lo ve un escáner.
@Suite("R1 · cableado de los dos testigos (source-scan)")
struct PersonalMountWitnessWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo entre llaves balanceadas a partir de un marcador, SIN líneas de comentario. Acotar al cuerpo
    /// no es cosmético: un rango ancho comprobaría que el símbolo EXISTE en el fichero, no que se use aquí,
    /// y contar la prosa haría que documentar el invariante lo "cumpliera" (lección de `TestProcessGuardTests`).
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

    /// **R4 movió el constructor del container de `YalaApp` a `PersonalContainerHost.makeContainer()`** —
    /// el swap de persona necesita poder remontar con el proceso vivo, y un `struct App` no da dónde
    /// hacerlo. El cuerpo se movió ENTERO y sin partirlo justamente para que estos dos escáneres sigan
    /// midiendo lo mismo: el testigo se registra con la DECISIÓN, y después de evaluarla.
    private static let containerBuilder = "static func makeContainer() throws -> ModelContainer {"
    private static let containerBuilderPath = "Yala/Services/CloudSync/PersonalContainerSwap.swift"

    @Test("el constructor del container registra el testigo durable con la DECISIÓN, no con la disponibilidad de iCloud")
    func containerBuilder_marksWithTheMountDecision() throws {
        let src = try Self.source(Self.containerBuilderPath)
        let container = try Self.body(of: Self.containerBuilder, in: src)

        #expect(container.contains("markContainerCloudKitState(") &&
                container.contains("decision: SwiftDataConfiguration.personalStoreMountedDecision"), """
            el testigo durable tiene que recibir la DECISIÓN de mount. Pasarle `isICloudAvailable()` es el
            estado anterior a R1: deja el aviso de mismatch mudo en cuanto exista un mount sin mirror con
            cuenta iCloud presente.
            """)
        #expect(!container.contains("markContainerCloudKitState(isICloudAvailable"), """
            la disponibilidad de iCloud NO puede volver al escritor del testigo durable.
            """)
    }

    @Test("el registro va DESPUÉS de evaluar `personalConfiguration` (si no, registra el default)")
    func containerBuilder_evaluatesTheMountBeforeRecordingIt() throws {
        // El testigo lo captura `personalConfiguration` en su primera evaluación. Invertir estas dos líneas
        // deja `personalStoreMountedDecision` en su default `.iCloudMirror` en el instante del registro ⇒ el
        // testigo durable diría "monté con espejo" SIEMPRE, y ninguna tabla de las de arriba lo notaría.
        let src = try Self.source(Self.containerBuilderPath)
        let container = try Self.body(of: Self.containerBuilder, in: src)
        let mount = try #require(container.range(of: "SwiftDataConfiguration.personalConfiguration"))
        let mark = try #require(container.range(of: "markContainerCloudKitState("))
        #expect(mount.lowerBound < mark.lowerBound)
    }

    @Test("las dos observaciones del executor leen el EJE del mirror, no un `StorageMode`")
    func executor_observationsReadTheMirrorAxis() throws {
        let src = try Self.source("Yala/Services/CloudSync/MigrationWorkExecutor.swift")
        let off = try Self.body(of: "func isMirrorConfirmedOff() -> Bool {", in: src)
        let on = try Self.body(of: "func isMirrorConfirmedOn() -> Bool {", in: src)
        // Comparar contra un modo de dos valores es justo el colapso que R1 retira.
        #expect(off.contains("personalStoreMountedDecision.attachesCloudKitMirror"),
                "isMirrorConfirmedOff tiene que preguntar por el eje del mirror")
        #expect(on.contains("personalStoreMountedDecision.attachesCloudKitMirror"),
                "isMirrorConfirmedOn tiene que preguntar por el eje del mirror")
        // Y siguen siendo INVERSAS la una de la otra: si las dos afirmaran lo mismo, el cutover y la reversa
        // podrían avanzar a la vez sobre el mismo store.
        #expect(off.contains("!SwiftDataConfiguration") && !on.contains("!SwiftDataConfiguration"))
    }

    @Test("el aviso de iCloud consume el predicado puro y el testigo durable")
    func bootstrapper_wiresTheAdvicePredicate() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        let check = try Self.body(of: "private func checkForICloudMismatch() {", in: src)
        #expect(check.contains("SwiftDataConfiguration.shouldOfferICloudRestart("), """
            la decisión tiene que salir de la lógica pura: escrita a mano aquí, el aviso vuelve a quedarse
            sin un solo test.
            """)
        #expect(check.contains("containerWasCreatedWithCloudKit("),
                "el input tiene que ser el testigo durable de lo que se MONTÓ")
        #expect(check.contains("isICloudAvailableNow") || check.contains("isICloudAvailable()"),
                "y el otro input, la disponibilidad de AHORA")
        #expect(check.contains("mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision"), """
            el término R9 tiene que decidirse por el TESTIGO DEL MOUNT. Pasarle `CloudSyncFlags.storageMode`
            (el modo de AHORA, que es lo que leía el guard antes de R1) enciende el aviso en la ventana en
            caliente de la reversa, y esta función corre en cada vuelta a primer plano.
            """)
        #expect(!check.contains("CloudSyncFlags.storageMode"), """
            el modo de ahora no puede volver al aviso: cambia sin remontar y este predicado habla de mounts.
            """)
    }
}
