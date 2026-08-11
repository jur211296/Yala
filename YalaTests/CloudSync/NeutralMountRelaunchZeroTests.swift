//
//  NeutralMountRelaunchZeroTests.swift
//  YalaTests / CloudSync
//
//  R2 del relanzamiento cero · el mount NEUTRO en fresh y a dónde se mueve el relanzamiento.
//
//  Cuatro mitades y ninguna cubre a las otras:
//
//   (A) EL PREDICADO de «instalación fresca». Es lo único que separa al parque actual del camino nuevo, así
//       que su tabla se recorre entera y cada término se apaga por separado.
//   (B) LA DECISIÓN de mount con el término puesto: qué sale, con qué precedencia, y que el `.none` del
//       neutro sea EXPLÍCITO (la auditoría R1(c) midió que `.automatic` adjunta el mirror igual).
//   (C) EL PORTAL del Welcome: qué destinos exigen el mirror, cuándo se interpone el relanzamiento y que la
//       intención sobreviva al proceso.
//   (D) CABLEADO (source-scan): quién pregunta, en qué orden y con qué. La lógica puede estar perfecta y
//       sus tablas verdes mientras nadie la invoca donde hace falta — familia de `AttestWiringTests`.
//
//  Lo que estos tests NO pueden declarar verificado, y va dicho aquí para que nadie lo lea de más: el alta
//  real contra producción (App Attest rechaza los builds de desarrollo por AAGUID —
//  `.claude/rules/gateway-attest.md`) y el aspecto de las dos pantallas nuevas en un device.
//

import Foundation
import Testing

@testable import Yala

private typealias Decision = SwiftDataConfiguration.PersonalStoreDecision
private typealias Destination = WelcomeMirrorRelaunchLogic.Destination

// MARK: - (A) El predicado de «instalación fresca»

@Suite("R2 · el predicado de instalación fresca")
struct NeutralMountFreshPredicateTests {

    /// Las cuatro señales en su estado de "device recién instalado". Cada test de abajo apaga UNA.
    private func fresh(
        fileExists: Bool = false,
        mode: StorageMode = .icloud,
        armed: Bool = false,
        secondary: Bool = false,
        chooserSeen: Bool = false
    ) -> Bool {
        SwiftDataConfiguration.isFreshInstallForNeutralMount(
            personalStoreFileExists: fileExists,
            persistedMode: mode,
            mirrorOffArmed: armed,
            secondarySessionActive: secondary,
            hasShownWelcomeChooser: chooserSeen)
    }

    @Test("las cuatro señales vírgenes ⇒ fresh")
    func allVirginSignals_areFresh() {
        #expect(fresh())
    }

    @Test("LA MUTACIÓN (a): con archivo de store NO es fresh — el parque actual no alcanza el camino nuevo")
    func withStoreFile_isNeverFresh() {
        // Es la protección ESTRUCTURAL del chip: todo device con datos tiene archivo, así que ensanchar el
        // predicado para aceptarlo cambiaría el mount de usuarios reales que hoy llevan mirror. Se recorre
        // el resto de combinaciones para que el término no pueda "colarse" por otra puerta.
        for mode in [StorageMode.icloud, .cloud] {
            for armed in [true, false] {
                for secondary in [true, false] {
                    for seen in [true, false] {
                        #expect(!fresh(fileExists: true, mode: mode, armed: armed,
                                       secondary: secondary, chooserSeen: seen),
                                "archivo presente ⇒ jamás fresh (mode=\(mode) armed=\(armed))")
                    }
                }
            }
        }
    }

    @Test("un par de storage no-virgen NO es fresh (el device YA eligió)")
    func nonVirginPair_isNotFresh() {
        #expect(!fresh(mode: .cloud))            // modo nube persistido
        #expect(!fresh(armed: true))             // mirror-off armado a medias
        #expect(!fresh(mode: .cloud, armed: true))
    }

    @Test("con descriptor de sesión secundaria NO es fresh")
    func secondarySession_isNotFresh() {
        #expect(!fresh(secondary: true))
    }

    @Test("con el chooser ya visto NO es fresh — el neutro dura UN arranque")
    func chooserAlreadySeen_isNotFresh() {
        // Es lo que hace imposible un bucle de relanzamiento: el portal del Welcome escribe este flag antes
        // de pedir que se reabra la app, así que el arranque siguiente cae en la tabla normal aunque el
        // archivo del store todavía no exista.
        #expect(!fresh(chooserSeen: true))
    }

    @Test("el adaptador de producción lee las cuatro señales del almacén que se le pasa")
    func productionAdapter_readsAllFourSignals() {
        // El adaptador es lo que corre en `personalConfiguration`; su término del ARCHIVO no es inyectable
        // (lo mira en disco), así que aquí se cubren los tres que sí lo son. En el host de tests el archivo
        // del store personal existe o no según la máquina, por eso se afirma sobre los términos y no sobre
        // el resultado compuesto.
        let defaults = makeIsolatedDefaults(prefix: "r2.fresh")

        // Virgen salvo el archivo: el resultado depende del disco, pero apagar CUALQUIER término tiene que
        // dar `false` de forma determinista.
        StorageModePersistence.write(.cloud, defaults: defaults)
        #expect(SwiftDataConfiguration.isFreshInstallForNeutralMount(defaults) == false)

        StorageModePersistence.write(.icloud, defaults: defaults)
        defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey)
        #expect(SwiftDataConfiguration.isFreshInstallForNeutralMount(defaults) == false)

        defaults.removeObject(forKey: StorageModePersistence.mirrorOffArmedKey)
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        #expect(SwiftDataConfiguration.isFreshInstallForNeutralMount(defaults) == false)
    }
}

// MARK: - (B) La decisión de mount con el término puesto

@Suite("R2 · la quinta salida de `personalStoreDecision`")
struct NeutralMountDecisionTests {

    @Test("fresh + sin par + sin secundaria ⇒ mount NEUTRO")
    func freshDevice_mountsNeutral() {
        for iCloud in [true, false] {
            #expect(SwiftDataConfiguration.personalStoreDecision(
                storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: iCloud,
                freshInstall: true, neutralDurable: false) == .neutralNoMirror,
                "el neutro no depende de que haya cuenta iCloud (iCloud=\(iCloud))")
        }
    }

    @Test("precedencia: la sesión secundaria y el par `.cloud` ARMADO ganan al término de fresh")
    func freshDoesNotOverrideTheHardInvariants() {
        // `isFreshInstallForNeutralMount` ya excluye los dos casos, así que esto es defensa en profundidad:
        // si alguien ensancha el predicado, las dos ramas que protegen invariantes duros (M1 y SERIO-1)
        // siguen ganando y ninguna sesión secundaria acaba montando el archivo del dueño.
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            secondarySessionActive: true, freshInstall: true, neutralDurable: false) == .secondaryCloudSession)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: true, iCloudAvailable: true,
            freshInstall: true, neutralDurable: false) == .cloudMirrorOff)
    }

    @Test("el neutro NO adjunta mirror, NO espeja y NO es modo nube")
    func neutralAxes() {
        #expect(Decision.neutralNoMirror.attachesCloudKitMirror == false)
        #expect(Decision.neutralNoMirror.mirrorsToICloud == false)
        #expect(Decision.neutralNoMirror.isCloudModeMount == false)
    }

    @Test("el aviso de iCloud SÍ le habla a un device montado neutro (§1.3)")
    func neutralMount_stillGetsTheICloudAdvice() {
        // Es la decisión que R2 hereda de R1. Si el neutro fuera `isCloudModeMount`, un fresh install con
        // cuenta iCloud disponible se quedaría sin mirror Y sin ninguna superficie que lo delatara.
        let defaults = makeIsolatedDefaults(prefix: "r2.advice")
        SwiftDataConfiguration.markContainerCloudKitState(decision: .neutralNoMirror, defaults: defaults)
        #expect(SwiftDataConfiguration.containerWasCreatedWithCloudKit(defaults) == false)
        #expect(SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: .neutralNoMirror,
            mountedWithMirroring: SwiftDataConfiguration.containerWasCreatedWithCloudKit(defaults),
            iCloudAvailableNow: true))
    }

    @Test("el gate del motor DEJA arrancar sobre un mount neutro con el par `.cloud` escrito")
    func engineGate_letsTheRuntimeStartOnNeutralMount() {
        // Es lo que hace posible el alta sin relanzar. Con el testigo colapsado de antes de R1 este mismo
        // device daba mismatch y el motor no arrancaba nunca.
        #expect(MigrationRuntimeGate.isPersonalMountMismatch(
            persistedMode: .cloud, mountedDecision: .neutralNoMirror) == false)
        #expect(MigrationRuntimeGate.canRun(phase: .notStarted, cloudWithMirrorOn: false,
                                            personalMountMismatch: false))
    }
}

// MARK: - (C) El portal del Welcome y la intención que sobrevive al relanzamiento

@Suite("R2 · el portal del Welcome (a dónde se mueve el relanzamiento)")
struct WelcomeMirrorRelaunchLogicTests {

    @Test("la tabla completa de destinos × necesidad de mirror")
    func destinationTable() {
        let expected: [Destination: Bool] = [
            .privateOnboarding: true,   // el bypass de producción: es quien paga el relanzamiento nuevo
            .restoreICloud: true,       // sin mirror, `RestoreProgressView` cuenta filas de un import que no llega
            .inviteRecovery: true,      // no lo necesita para su trabajo, pero su destino es usar la app
            .cloudAccount: false,       // el alta nube: el mount neutro YA es su store
            .cloudSignIn: false,        // la re-entrada: idem, y su relanzamiento lo decide su máquina
        ]
        #expect(Set(expected.keys) == Set(Destination.allCases),
                "toda salida del Welcome tiene que declarar si necesita el mirror")
        for destination in Destination.allCases {
            #expect(WelcomeMirrorRelaunchLogic.requiresMirror(destination) == expected[destination],
                    "destino=\(destination)")
        }
    }

    @Test("solo el mount NEUTRO abre la ventana del relanzamiento")
    func onlyTheNeutralMountTriggersIt() {
        for destination in Destination.allCases {
            for mount in Decision.allCases {
                let expected = WelcomeMirrorRelaunchLogic.requiresMirror(destination)
                    && mount == .neutralNoMirror
                #expect(WelcomeMirrorRelaunchLogic.shouldRelaunch(
                    destination: destination, mountedDecision: mount) == expected,
                    "destino=\(destination) montado=\(mount)")
            }
        }
    }

    @Test("los mounts de MODO NUBE no piden relanzar aunque tampoco lleven mirror")
    func cloudModeMounts_neverAskForIt() {
        // `cloudMirrorOff` y `secondaryCloudSession` también son `!attachesCloudKitMirror`, así que un
        // predicado escrito sobre el EJE en vez de sobre la decisión les ofrecería un «reabre la app para
        // encender iCloud» que en modo nube es sencillamente falso.
        for mount in [Decision.cloudMirrorOff, .secondaryCloudSession] {
            #expect(mount.attachesCloudKitMirror == false, "premisa del test")
            for destination in Destination.allCases {
                #expect(!WelcomeMirrorRelaunchLogic.shouldRelaunch(
                    destination: destination, mountedDecision: mount))
            }
        }
    }

    @Test("el destino sobrevive al proceso y se CONSUME al leerlo")
    func pendingDestination_isDurableAndOneShot() {
        let defaults = makeIsolatedDefaults(prefix: "r2.pending")
        #expect(WelcomePendingDestinationStore.peek(defaults) == nil)

        WelcomePendingDestinationStore.set(.restoreICloud, defaults: defaults)
        #expect(WelcomePendingDestinationStore.peek(defaults) == .restoreICloud)
        #expect(WelcomePendingDestinationStore.consume(defaults) == .restoreICloud)
        // One-shot: sin esto, un destino consumido secuestraría la pantalla inicial de TODOS los arranques
        // siguientes y el usuario no podría llegar nunca a otro sitio.
        #expect(WelcomePendingDestinationStore.consume(defaults) == nil)
    }

    @Test("los cinco destinos hacen round-trip por el almacén")
    func everyDestination_roundTrips() {
        // El rawValue es lo que viaja en `UserDefaults`: si alguien renombra un caso sin migrar, el destino
        // guardado deja de parsear y el usuario aterriza en el onboarding por defecto.
        for destination in Destination.allCases {
            let defaults = makeIsolatedDefaults(prefix: "r2.rt.\(destination.rawValue)")
            WelcomePendingDestinationStore.set(destination, defaults: defaults)
            #expect(WelcomePendingDestinationStore.consume(defaults) == destination)
        }
    }

    @Test("un rawValue que no parsea se RETIRA en vez de quedarse pudriéndose")
    func unknownRawValue_isDiscarded() {
        let defaults = makeIsolatedDefaults(prefix: "r2.garbage")
        defaults.set("destinoDeUnBuildAnterior", forKey: WelcomePendingDestinationStore.key)
        #expect(WelcomePendingDestinationStore.consume(defaults) == nil)
        #expect(defaults.string(forKey: WelcomePendingDestinationStore.key) == nil, """
            un residuo que nadie puede consumir se queda ahí para siempre; el consumo lo retira aunque no
            sepa qué era.
            """)
    }
}

// MARK: - (D) Cableado (source-scan)

/// Por qué además de las tablas: el predicado puede ser perfecto y sus tests verdes mientras
/// `personalConfiguration` no lo consulta, mientras el neutro se construye sin `cloudKitDatabase:` (que es
/// el mount CONTRARIO), o mientras el portal del Welcome deja una salida sin pasar por él. Lo que decide
/// aquí es QUIÉN llama y CON QUÉ, y eso solo lo ve un escáner.
@Suite("R2 · cableado del mount neutro y del portal (source-scan)")
struct NeutralMountWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El nombre del constructor que estos escáneres buscan, PARTIDO a propósito.
    /// `ModelConfigurationCloudKitWiringTests` barre `YalaTests/` buscando ese literal para exigirle un
    /// `cloudKitDatabase:` explícito, y no distingue una construcción real de una cadena de búsqueda: si se
    /// escribe entero aquí, este fichero aparece como infractor de una regla que en realidad está
    /// comprobando. Partirlo es lo que mantiene los dos escáneres compatibles.
    private static let configCall = "ModelConfiguration" + "("

    /// Cuerpo entre llaves balanceadas a partir de un marcador, SIN líneas de comentario. Acotar al cuerpo
    /// no es cosmético: un rango ancho comprobaría que el símbolo EXISTE en el fichero, no que se use aquí
    /// (lección de `TestProcessGuardTests`), y contar la prosa haría que documentar el invariante lo
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

    /// **LA MUTACIÓN (c) del chip.** El neutro se construye con `.none` EXPLÍCITO. Omitir el argumento cae
    /// en el default `.automatic`, y la auditoría R1(c) MIDIÓ (iPhone 17 Pro / iOS 26.5, sim sin cuenta
    /// iCloud, con control positivo `.private` y negativo `.none`) que `.automatic` **adjunta el mirror
    /// igual**: mismos eventos de `NSPersistentCloudKitContainer` que `.private`, mientras `.none` emite
    /// cero. Un neutro sin `.none` sería el mount CONTRARIO al que declara, y el alta nube volvería a
    /// necesitar el relanzamiento que este chip existe para quitar — en silencio y sin ningún rojo.
    @Test("R2 (c): el mount neutro se construye con `cloudKitDatabase: .none` EXPLÍCITO")
    func neutralMount_usesExplicitNone() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let config = try Self.body(of: "static var personalConfiguration: ModelConfiguration {", in: src)
        let neutral = try #require(config.range(of: "case .neutralNoMirror:"))
        let tail = String(config[neutral.upperBound...])
        let line = try #require(tail.split(separator: "\n").first(where: {
            $0.contains(Self.configCall)
        }))
        #expect(line.contains("cloudKitDatabase: .none"), """
            La rama del mount neutro tiene que pasar `.none` explícito. Sin el argumento cae en `.automatic`,
            que MIDIÓ adjuntar el mirror igual (auditoría R1(c)): el store dejaría de ser byte-idéntico al de
            modo nube y el alta volvería a exigir relanzamiento.
            Línea encontrada: \(line)
            """)
    }

    @Test("R2 (a): `personalConfiguration` consulta el predicado de fresh")
    func personalConfiguration_asksThePredicate() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let config = try Self.body(of: "static var personalConfiguration: ModelConfiguration {", in: src)
        #expect(config.contains("freshInstall: isFreshInstallForNeutralMount()"), """
            La decisión tiene que recibir el predicado REAL. Cablearlo a `false` deja la quinta salida como
            código muerto con sus tablas en verde; cablearlo a `true` monta neutro a TODO el parque.
            """)
    }

    @Test("R2 (a): el predicado se evalúa ANTES de capturar el testigo de mount")
    func predicateIsEvaluatedBeforeCapturingTheWitness() throws {
        // El testigo se captura UNA vez por proceso. Si la captura ocurriera antes de decidir, registraría
        // una decisión que no es la que se montó — exactamente el fallo que R1 cerró en `YalaApp`.
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let config = try Self.body(of: "static var personalConfiguration: ModelConfiguration {", in: src)
        let decide = try #require(config.range(of: "let decision = personalStoreDecision("))
        let capture = try #require(config.range(of: "capturePersonalStoreMountedDecisionOnce("))
        #expect(decide.lowerBound < capture.lowerBound)
    }

    @Test("R2 (a): el predicado NO construye un container para preguntar por el archivo")
    func predicateDerivesTheURLFromAnEphemeralConfiguration() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let probe = try Self.body(of: "private static func personalStoreFileExists() -> Bool {", in: src)
        #expect(probe.contains(Self.configCall + "databaseName"), "la URL sale de una config efímera")
        #expect(probe.contains("cloudKitDatabase: .none"), """
            incluso la configuración EFÍMERA lleva `.none`: con `.automatic` construir un
            `ModelConfiguration` sobre el schema personal (que tiene relaciones) es lo que adjunta el mirror.
            """)
        #expect(!probe.contains("personalConfiguration"), """
            preguntar por el archivo NO puede pasar por `personalConfiguration`: su primera evaluación
            CAPTURA el testigo de mount, y aquí todavía no hay ninguna decisión tomada.
            """)
    }

    /// **El portal del Welcome, y por qué el escáner es la única red.** Los destinos se producen en varios
    /// sitios distintos del container (los tres sub-choosers y el faro), varios con bypass. Una salida que
    /// se olvide de pasar por `leaveWelcome` no rompe ningún test de comportamiento: simplemente entra al
    /// restore sobre un store sin mirror y la pantalla dice que la cuenta está vacía.
    ///
    /// La salida de la rama de grupos se busca por `onSelectBranch(` y no por su argumento: G2 la movió del
    /// `.invite` del chooser a la card de unirse del step nuevo, y ahí el argumento es el literal `.invite`
    /// en vez de la variable `branch`. Buscar el prefijo cubre las dos formas y cualquier tercera — lo que
    /// el contrato exige es que la llamada esté DENTRO de una closure de `leaveWelcome`, no cómo se
    /// escriba su argumento.
    @Test("R2 (e): TODA salida del Welcome pasa por el portal del relanzamiento")
    func everyWelcomeExit_goesThroughThePortal() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let code = src.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        // Los cinco callbacks que ABANDONAN el cover. Cada uno tiene que aparecer dentro de una closure de
        // `leaveWelcome`, nunca invocado a pelo.
        for exit in ["onSelectPrivateAccount()", "onSelectCloudAccount()", "onSelectExistingOption(option)",
                     "onBeaconRoutesToCloudSignIn(provider)", "onSelectBranch("] {
            let occurrences = code.components(separatedBy: exit).count - 1
            #expect(occurrences >= 1, "salida no encontrada: \(exit) (¿renombrada?)")
            for range in code.ranges(of: exit) {
                let prefix = String(code[..<range.lowerBound])
                let line = prefix.split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
                #expect(line.contains("leaveWelcome(to:"), """
                    `\(exit)` sale del Welcome sin pasar por el portal. Con el mount neutro, ese camino
                    entra a su destino sobre un store sin espejo de iCloud y nadie se entera.
                    Línea: \(line)
                    """)
            }
        }
    }

    @Test("R2 (e): el portal decide con el testigo de mount y va al step terminal")
    func portal_decidesWithTheMountWitness() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let portal = try Self.body(
            of: "private func leaveWelcome(to destination: WelcomeMirrorRelaunchLogic.Destination,",
            in: src)
        #expect(portal.contains("WelcomeMirrorRelaunchLogic.shouldRelaunch("),
                "la decisión vive en la lógica pura, no escrita a mano aquí")
        #expect(portal.contains("mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision"),
                "y su input es el testigo de lo que ESTE proceso montó")
        #expect(portal.contains("onNeedsMirrorRelaunch(destination)"),
                "el destino tiene que persistirse ANTES de pedir que se reabra la app")
        #expect(portal.contains("goTo(.mirrorRelaunch)"))
    }

    @Test("R2 (e): el arranque consume el destino pendiente ANTES de decidir la pantalla inicial")
    func startup_consumesThePendingDestinationFirst() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let present = try Self.body(of: "private func presentNextOnboardingScreen() {", in: src)
        let consume = try #require(present.range(of: "WelcomePendingDestinationStore.consume()"), """
            sin este consumo, quien pidió restaurar reabre la app y aterriza en el onboarding normal: su
            elección se pierde y no hay forma obvia de repetirla (el chooser ya no vuelve a salir).
            """)
        let chooser = try #require(present.range(of: "!hasShownWelcomeChooser"))
        #expect(consume.lowerBound < chooser.lowerBound, """
            el destino retenido es MÁS específico que el chooser y que el onboarding: si se leyera después,
            los dos ya habrían decidido.
            """)
    }

    @Test("R2 (e): el terminal del Welcome usa copy PROPIO, no el de la migración")
    func mirrorRelaunchScreen_hasItsOwnCopy() throws {
        let src = try Self.source("Yala/App/Views/Onboarding/WelcomeMirrorRelaunchView.swift")
        #expect(src.contains("L10n.Welcome.MirrorRelaunch.title"))
        #expect(src.contains("L10n.Welcome.MirrorRelaunch.body"))
        #expect(!src.contains("L10n.Storage.Relaunch"), """
            `Storage.Relaunch.*` describe una migración de un corpus que ya existe. Aquí el usuario acaba de
            elegir dónde quiere sus datos y todavía no tiene ninguno: reusar aquel copy le miente.
            """)
        // Y no mata el proceso: el auto-exit en background es R0, y ampliarlo aquí sin su tabla dejaría un
        // `exit(0)` sin ningún test que lo acote.
        for killer in ["exit(0)", "abort()", "kill(", "SIGKILL"] {
            #expect(!src.contains(killer))
        }
    }
}
