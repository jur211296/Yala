//
//  PersonalSwapReleaseTests.swift
//  YalaTests / CloudSync
//
//  R4 del relanzamiento cero · el swap de persona SIN relanzar.
//
//  Cuatro mitades, y ninguna cubre a las otras:
//
//   (A) EL CANARIO. «Release verificado» = sentinel `nil` **Y** cero descriptores. Es la mitad que el spike
//       R3 tuvo que medir para poder escribirla, y la que decide si se borra un store o no.
//   (B) EL ALCANCE. Qué mounts admiten swap: solo los que NO llevan mirror adjunto, que es exactamente lo
//       que la Opción C aprueba y lo único que el spike midió sin residuales.
//   (C) EL NEUTRO DURABLE. Dónde queda el device tras el wipe, y por qué su segundo término es lo que hace
//       imposible el bucle de relanzamiento.
//   (D) CABLEADO Y ORDEN (source-scan). Quién llama, en qué orden, y qué NO se desarma. La lógica puede
//       estar perfecta y sus tablas verdes mientras el swap corre antes de armar la red — familia de
//       `AttestWiringTests`.
//
//  **Lo que estos tests NO pueden declarar verificado, y va dicho para que nadie lo lea de más:** el swap
//  REAL en un device (soltar el container de verdad, con la jerarquía de vistas real montada, y ver si el
//  release verifica) no es unit-asertable — el host de tests no monta la jerarquía y su
//  `personalConfiguration` corta en `isRunningTests` antes de tocar el archivo real. Lo que se prueba aquí
//  es la DECISIÓN y el CABLEADO; que el container muera de verdad lo midió el spike R3 (ejes 1, 2 y 4a) y
//  el e2e de las dos personas lo corre el owner.
//

import Foundation
import Testing

@testable import Yala

private typealias Decision = SwiftDataConfiguration.PersonalStoreDecision
private typealias Verdict = PersonalSwapReleaseLogic.Verdict

// MARK: - (A) El canario: «release verificado»

@Suite("R4 · el release verificado (sentinel Y descriptores)")
struct PersonalSwapReleaseVerdictTests {

    @Test("los dos instrumentos en verde ⇒ released")
    func deadAndClosed_isReleased() {
        #expect(PersonalSwapReleaseLogic.verdict(sentinelAlive: false, openDescriptors: 0) == .released)
    }

    /// **LA MUTACIÓN (a) del chip: quitar la comprobación del SENTINEL.**
    ///
    /// Ésta es la celda que cae. Un container VIVO cuyos descriptores todavía no se han contado —o que
    /// simplemente no aparecen— pasaría a `.released` y el orquestador borraría los archivos por debajo de
    /// un container que sigue leyendo y escribiendo. El eje 4b del spike midió qué pasa entonces, y no es
    /// un crash: el fetch devuelve **0 filas sin lanzar** (SQLite grita `vnode unlinked while in use` y
    /// Core Data se lo traga) y el superviviente **ESCRIBE y RESUCITA** el archivo que el wipe borró. La
    /// app se ve vacía, en silencio, y el wipe se deshace solo.
    @Test("LA MUTACIÓN (a): el objeto VIVO nunca autoriza el wipe, ni con cero descriptores")
    func aliveObject_neverAuthorizes_evenWithZeroDescriptors() {
        for descriptors in [0, 1, 3, 5] {
            let verdict = PersonalSwapReleaseLogic.verdict(
                sentinelAlive: true, openDescriptors: descriptors)
            #expect(verdict == .abortObjectAlive, """
                Con el sentinel VIVO la respuesta es siempre el mismo aborto, y su causa es el objeto: sus
                descriptores lo están por una razón conocida. Descriptores probados: \(descriptors).
                """)
            #expect(PersonalSwapReleaseLogic.authorizesWipe(verdict) == false)
        }
    }

    /// La mitad que el `weak` sentinel NO cubre, y por la que el spike tuvo que cambiar de instrumento a
    /// mitad de la corrida: el objeto Swift puede morir con la pila de Core Data viva. El primer
    /// instrumento elegido —«al cerrarse la última conexión SQLite borra `-wal`/`-shm`»— **no discrimina**,
    /// porque Core Data activa el WAL persistente y los dos sidecars siguen en disco con la conexión ya
    /// cerrada (MEDIDO, spec §11.1).
    @Test("objeto muerto pero conexión VIVA ⇒ aborta, y el conteo viaja en el veredicto")
    func deadObjectWithOpenDescriptors_aborts() {
        for descriptors in [1, 3, 7] {
            let verdict = PersonalSwapReleaseLogic.verdict(
                sentinelAlive: false, openDescriptors: descriptors)
            #expect(verdict == .abortDescriptorsOpen(count: descriptors))
            #expect(PersonalSwapReleaseLogic.authorizesWipe(verdict) == false, """
                Sin este término, «release verificado» sería solo el sentinel — que es exactamente lo que el
                spike R3 refutó como suficiente.
                """)
        }
    }

    /// **LA MUTACIÓN (b) del chip, en su mitad pura: hacer que un fallo del release SIGA ADELANTE.**
    /// `authorizesWipe` es el único punto que traduce veredicto → permiso, y solo `.released` lo concede.
    @Test("LA MUTACIÓN (b): solo `.released` autoriza el wipe — barrido exhaustivo")
    func onlyReleasedAuthorizes() {
        let all: [Verdict] = [
            .released, .abortObjectAlive,
            .abortDescriptorsOpen(count: 1), .abortDescriptorsOpen(count: 42),
        ]
        for verdict in all {
            #expect(PersonalSwapReleaseLogic.authorizesWipe(verdict) == (verdict == .released))
        }
    }
}

// MARK: - (B) El alcance: qué mounts admiten swap

@Suite("R4 · el guard de alcance (solo transiciones SIN mirror)")
struct PersonalSwapScopeTests {

    /// Se recorre por `allCases` a propósito: una decisión de mount NUEVA no puede colarse sin declarar de
    /// qué lado cae, que es el mismo mecanismo con el que R1 dejó las tablas de los tres ejes.
    @Test("el alcance se DERIVA del eje de mirror, para las cinco decisiones")
    func scopeFollowsTheMirrorAxis() {
        for decision in Decision.allCases {
            #expect(
                PersonalSwapReleaseLogic.mountAdmitsSwap(mountedDecision: decision)
                    == !decision.attachesCloudKitMirror,
                """
                El swap solo se intenta donde NINGUNO de los dos extremos tiene mirror. Ensancharlo metería
                a `NSPersistentCloudKitContainer` en la transición, que es la pieza cuyo release el eje 3
                del spike dejó VERDE PERO CON RESIDUAL: el trabajo en vuelo de CloudKit sobrevive al
                container (5 eventos en los 10 s posteriores). Decisión que falla: \(decision).
                """)
        }
    }

    @Test("los dos mounts de modo nube y el neutro admiten swap; los dos con mirror NO")
    func explicitTable() {
        #expect(PersonalSwapReleaseLogic.mountAdmitsSwap(mountedDecision: .cloudMirrorOff))
        #expect(PersonalSwapReleaseLogic.mountAdmitsSwap(mountedDecision: .secondaryCloudSession))
        #expect(PersonalSwapReleaseLogic.mountAdmitsSwap(mountedDecision: .neutralNoMirror))
        #expect(PersonalSwapReleaseLogic.mountAdmitsSwap(mountedDecision: .iCloudMirror) == false)
        // `localNoMirror` cae del lado NO por una medición y no por su nombre: la auditoría R1(c) midió
        // que su `.automatic` adjunta el mirror igual sin cuenta iCloud.
        #expect(PersonalSwapReleaseLogic.mountAdmitsSwap(mountedDecision: .localNoMirror) == false)
    }
}

// MARK: - (C) El neutro durable

@Suite("R4 · el neutro DURABLE y su caducidad")
struct NeutralDurableMountTests {

    @Test("armado y sin chooser visto ⇒ el device monta neutro")
    func armedAndUnchosen_mountsNeutral() {
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: true, hasShownWelcomeChooser: false))
    }

    /// **El segundo término es lo que hace IMPOSIBLE el bucle**, y por eso tiene test propio. Sin él, un
    /// usuario que eligiera «Restaurar de iCloud» —destino que SÍ necesita el mirror— recibiría la pantalla
    /// de «reabre la app», y el arranque siguiente volvería a montar neutro: mismo cover, misma elección,
    /// para siempre, y la cuenta nunca se restaura.
    @Test("con el chooser YA visto la marca queda INERTE — sin esto, relanzamiento en bucle")
    func chooserSeen_makesTheMarkInert() {
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: true, hasShownWelcomeChooser: true) == false)
    }

    @Test("sin marca no hay neutro durable, se haya visto el chooser o no")
    func unarmed_isNeverNeutral() {
        for chooserSeen in [true, false] {
            #expect(SwiftDataConfiguration.shouldMountNeutralDurable(
                neutralMountArmed: false, hasShownWelcomeChooser: chooserSeen) == false)
        }
    }

    @Test("el término entra en la decisión de mount y da la MISMA salida que `freshInstall`")
    func neutralDurableFeedsTheMountDecision() {
        for iCloud in [true, false] {
            #expect(SwiftDataConfiguration.personalStoreDecision(
                storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: iCloud,
                freshInstall: false, neutralDurable: true) == .neutralNoMirror,
                "el neutro no depende de que haya cuenta iCloud (iCloud=\(iCloud))")
        }
    }

    /// Defensa en profundidad, igual que su gemelo de R2: los dos invariantes duros (M1 y SERIO-1) ganan al
    /// término nuevo aunque alguien deje la marca puesta por descuido. En particular, un device a mitad del
    /// cutover —`.cloud` + armado— jamás cae en la rama neutra.
    @Test("precedencia: la sesión secundaria y el par `.cloud` ARMADO ganan al neutro durable")
    func hardInvariantsWinOverNeutralDurable() {
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            secondarySessionActive: true,
            freshInstall: false, neutralDurable: true) == .secondaryCloudSession)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: true, iCloudAvailable: true,
            freshInstall: false, neutralDurable: true) == .cloudMirrorOff)
    }

    @Test("con el término apagado la tabla de R2 sigue intacta")
    func neutralDurableOff_leavesR2TableIntact() {
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            freshInstall: false, neutralDurable: false) == .iCloudMirror)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: false,
            freshInstall: false, neutralDurable: false) == .localNoMirror)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            freshInstall: true, neutralDurable: false) == .neutralNoMirror)
    }

    // MARK: El wipe lo arma — comportamiento, con `UserDefaults` aislado

    /// **R4(a): el sign-out deja el device en neutro DURABLE, y lo hace el wipe.** Es un estado EXPLÍCITO
    /// —la key existe con `true`— y no una ausencia: la ausencia de `cloudSync.storageMode` significa
    /// `.icloud` por contrato, así que «neutro» no se puede decir borrando nada.
    @Test("el boot-cleanup arma el neutro durable junto al par `.icloud`")
    func wipeArmsTheNeutralMark() {
        let defaults = makeIsolatedDefaults(prefix: "r4.wipe.arms")
        StorageModePersistence.write(.cloud, defaults: defaults)
        defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey)
        StorageModePersistence.armSignOutWipe(defaults)
        #expect(StorageModePersistence.isNeutralMountArmed(defaults) == false, "precondición")

        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: {},
            cancelNotifications: {},
            purgeInboundSurfaces: {})

        #expect(StorageModePersistence.read(defaults) == .icloud)
        #expect(StorageModePersistence.isMirrorOffArmed(defaults) == false)
        #expect(StorageModePersistence.isNeutralMountArmed(defaults), """
            Sin la marca, un device que remontara in-process y muriera antes de que el usuario eligiera
            volvería a `.iCloudMirror` en el arranque siguiente —el archivo del store YA existe, así que el
            predicado de R2 no lo cubre— adjuntando el mirror al store vaciado del humano que se fue.
            """)
    }

    /// El guard S3 protege el backup de iCloud abortando el wipe si el archivo BASE no se pudo borrar. La
    /// marca del neutro va DESPUÉS de ese guard: con el store vivo, montar neutro en el arranque siguiente
    /// dejaría al usuario con sus datos intactos y sin espejo.
    @Test("si el wipe ABORTA por el guard S3, el neutro NO se arma")
    func abortedWipe_doesNotArmTheNeutralMark() {
        let defaults = makeIsolatedDefaults(prefix: "r4.wipe.abort")
        StorageModePersistence.write(.cloud, defaults: defaults)
        defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey)
        StorageModePersistence.armSignOutWipe(defaults)

        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in false },   // el BASE no se pudo borrar
            resetPrefs: {},
            cancelNotifications: {},
            purgeInboundSurfaces: {})

        #expect(StorageModePersistence.isNeutralMountArmed(defaults) == false)
        #expect(StorageModePersistence.isSignOutWipeArmed(defaults), "el arm persiste: el boot reintenta")
        #expect(StorageModePersistence.read(defaults) == .cloud, "el par SERIO-1 queda intacto")
    }

    @Test("re-entrar al wipe es idempotente y la marca sigue puesta")
    func wipeIsIdempotent_forTheNeutralMark() {
        let defaults = makeIsolatedDefaults(prefix: "r4.wipe.idem")
        StorageModePersistence.write(.cloud, defaults: defaults)
        StorageModePersistence.armSignOutWipe(defaults)
        for _ in 0..<2 {
            SwiftDataConfiguration.performSignOutWipeIfArmed(
                defaults: defaults,
                deleteFiles: { _, _ in true },
                resetPrefs: {},
                cancelNotifications: {},
                purgeInboundSurfaces: {})
        }
        // El segundo pase no hace nada (el arm se limpió al final del primero) y la marca sobrevive.
        #expect(StorageModePersistence.isNeutralMountArmed(defaults))
        #expect(StorageModePersistence.isSignOutWipeArmed(defaults) == false)
    }
}

// MARK: - (D) Cableado y ORDEN (source-scan)

/// **Por qué aquí el escáner carga el peso y las tablas no.** Todo lo de arriba puede estar en verde con el
/// swap corriendo ANTES de armar el wipe de boot (⇒ un kill a mitad deja el device con el store vivo y sin
/// red), o con el aborto ejecutando el wipe igual (⇒ el modo de fallo del §1.10), o con el testigo del
/// mount sin recapturar (⇒ «Restaurar de iCloud» no pide reabrir y el usuario espera un import que nadie va
/// a arrancar). Lo que decide es QUIÉN llama y EN QUÉ ORDEN, y eso solo lo ve un escáner.
@Suite("R4 · cableado y orden del swap (source-scan)")
struct PersonalSwapWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El fichero SIN líneas de comentario. Un escáner que barra el fichero entero cuenta la prosa, y en un
    /// repo donde los docblocks nombran a propósito los símbolos vecinos eso convierte «documentar el
    /// invariante» en «violarlo».
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas a partir de un marcador, SIN líneas de comentario. Acotar al cuerpo
    /// no es cosmético: un rango ancho comprobaría que el símbolo EXISTE en el fichero, no que se use aquí,
    /// y contar la prosa haría que documentar el invariante lo "cumpliera".
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

    /// **LA MUTACIÓN (b) del chip, en su mitad de cableado: la RED SE CONSERVA.** El wipe de boot se arma
    /// ANTES de intentar el swap, así que cualquier fallo —mount con mirror, release no verificado, kill
    /// del proceso a mitad— degrada exactamente a la pantalla de relanzamiento de hoy. Mover el
    /// `attemptSignOutSwap` por encima del `armSignOutWipe` deja una ventana en la que el store sigue vivo
    /// y no hay nada armado que lo limpie después.
    @Test("R4(c): el wipe de boot se ARMA antes de intentar el swap")
    func bootWipeIsArmedBeforeAttemptingTheSwap() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let flow = try Self.body(
            of: "private func performCloudSecureSignOut(context: ModelContext) async {", in: src)
        let arm = try #require(flow.range(of: "StorageModePersistence.armSignOutWipe()"))
        let swap = try #require(flow.range(of: "PersonalContainerSwap.attemptSignOutSwap()"), """
            El sign-out `.cloud` tiene que INTENTAR el swap. Sin este call-site, toda la lógica de R4 es
            código muerto con sus tablas en verde — la familia de `AppAttestClient.ensureRegistered()`.
            """)
        #expect(arm.lowerBound < swap.lowerBound)
    }

    /// La fase terminal es lo que sostiene el cover y el `exit(0)` en background. Bajarla a `.idle` antes de
    /// saber si el swap salió deja al usuario, en el camino degradado, con el wipe armado y SIN pantalla que
    /// se lo diga.
    @Test("R4(d): la fase solo vuelve a `.idle` si el swap se CONSUMÓ")
    func phaseReturnsToIdleOnlyOnSwapped() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let flow = try Self.body(
            of: "private func performCloudSecureSignOut(context: ModelContext) async {", in: src)
        #expect(flow.contains("attemptSignOutSwap() == .swapped"), """
            El retorno a `.idle` va condicionado al outcome `.swapped`, no al hecho de haber llamado.
            """)
    }

    /// **LA MUTACIÓN (a) del chip, en su mitad de cableado: NO se monta el container nuevo con el viejo
    /// vivo.** El `guard` del veredicto va ANTES del wipe y ANTES de construir nada; sin él, el orquestador
    /// borraría los archivos bajo un container vivo y montaría el segundo encima — que es literalmente el
    /// estado del §1.10 (dos conexiones sobre el mismo archivo, app que se ve vacía, cero errores).
    @Test("R4(b): el guard del release va ANTES del wipe y del remonte")
    func releaseGuardPrecedesWipeAndRemount() throws {
        let src = try Self.source("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        let flow = try Self.body(of: "static func attemptSignOutSwap() async -> Outcome {", in: src)
        let guardRange = try #require(flow.range(of: "PersonalSwapReleaseLogic.authorizesWipe(verdict)"))
        let wipe = try #require(flow.range(of: "SwiftDataConfiguration.performSignOutWipeIfArmed()"))
        let build = try #require(flow.range(of: "PersonalContainerHost.makeContainer()"))
        #expect(guardRange.lowerBound < wipe.lowerBound)
        #expect(guardRange.lowerBound < build.lowerBound)
        #expect(wipe.lowerBound < build.lowerBound, """
            El wipe va antes del remonte: montar primero recrearía el archivo y el borrado posterior caería
            bajo un container VIVO — el eje 4b del spike, otra vez.
            """)
    }

    /// El aborto tiene que ser REVERSIBLE. Sin la reposición, un solo retenedor olvidado dejaría al usuario
    /// en una pantalla sin container y sin camino de vuelta: peor que el relanzamiento que este chip quita.
    @Test("R4(c): el aborto REPONE el container superviviente")
    func abortRestoresTheSurvivor() throws {
        let src = try Self.source("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        let flow = try Self.body(of: "static func attemptSignOutSwap() async -> Outcome {", in: src)
        let guardRange = try #require(flow.range(of: "guard PersonalSwapReleaseLogic.authorizesWipe(verdict)"))
        let tail = String(flow[guardRange.upperBound...])
        let restore = try #require(tail.range(of: "restoreAfterFailedSwap("))
        let wipe = try #require(tail.range(of: "performSignOutWipeIfArmed()"))
        #expect(restore.lowerBound < wipe.lowerBound, """
            La reposición vive DENTRO de la rama del aborto, antes de cualquier borrado.
            """)
    }

    /// **El swap jamás desarma la red por su cuenta.** Quien limpia `signOutWipeArmed` es el propio wipe al
    /// ejecutarse (en el boot o aquí), y ese orden ya es kill-safe. Un `clearSignOutWipeArm` en el
    /// orquestador abriría la ventana exacta que el chip promete cerrar: red retirada, store todavía vivo.
    @Test("R4(c): el orquestador del swap NO desarma el wipe de boot")
    func swapNeverDisarmsTheBootWipe() throws {
        let src = try Self.source("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        #expect(src.contains("clearSignOutWipeArm") == false)
        #expect(src.contains("clearNeutralMountArm") == false)
    }

    /// Sin recapturar el testigo, `WelcomeMirrorRelaunchLogic.shouldRelaunch` seguiría comparando contra el
    /// mount del ARRANQUE (`.cloudMirrorOff`) y «Restaurar de iCloud» NO pediría reabrir la app: el usuario
    /// esperaría 90 s a un import que nadie va a arrancar y la pantalla le diría que su cuenta está vacía.
    @Test("R4(b): el testigo del mount se RECAPTURA antes de construir el container nuevo")
    func mountWitnessIsRecapturedBeforeRemount() throws {
        let src = try Self.source("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        let flow = try Self.body(of: "static func attemptSignOutSwap() async -> Outcome {", in: src)
        let reopen = try #require(
            flow.range(of: "reopenPersonalStoreMountedDecisionCaptureForSwap()"))
        let build = try #require(flow.range(of: "PersonalContainerHost.makeContainer()"))
        #expect(reopen.lowerBound < build.lowerBound)
    }

    /// La jerarquía se suelta ANTES de la fase de quiesce y ANTES de medir. Medir con el árbol montado sería
    /// medir 37 ViewModels y 67 `@Query` reteniendo filas — y el eje 1c del spike midió que **una sola fila
    /// `@Model` retenida mantiene vivo el container**.
    @Test("R4(b): la jerarquía se colapsa antes de soltar los servicios y antes de medir")
    func hierarchyIsCollapsedFirst() throws {
        let src = try Self.source("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        let flow = try Self.body(of: "static func attemptSignOutSwap() async -> Outcome {", in: src)
        let release = try #require(flow.range(of: "PersonalContainerHost.shared.releaseForSwap()"))
        let quiesce = try #require(flow.range(of: "releaseModelContextsForSwap()"))
        let await_ = try #require(flow.range(of: "awaitVerifiedRelease(sentinel:"))
        #expect(release.lowerBound < quiesce.lowerBound)
        #expect(quiesce.lowerBound < await_.lowerBound)
    }

    /// El `App` no puede volver a tener el container como constante: sin la ventana `nil` la jerarquía nunca
    /// se desmonta y el release no verifica NUNCA — el swap quedaría cableado y siempre degradando, en
    /// verde y sin que nadie lo notara salvo por el canario.
    @Test("R4(d): `YalaApp` monta la jerarquía SOLO cuando el host tiene container")
    func appCollapsesTheHierarchyWithoutContainer() throws {
        let src = try Self.source("Yala/App/YalaApp.swift")
        #expect(src.contains("if let container = containerHost.container {"))
        #expect(src.contains(".id(containerHost.generation)"), """
            El remonte cambia de container: sin `id` SwiftUI reusaría vistas cuyo estado interno conserva
            filas del store anterior — que siguen legibles en memoria tras morir su store (eje 1c).
            """)
    }

    /// El wipe del swap es EL MISMO que corre al boot. Una copia podría divergir, y entonces el camino
    /// degradado y el camino feliz dejarían el device en estados distintos — la peor clase de bug de esta
    /// familia, porque solo se ve en el que no se probó.
    @Test("R4(c): el swap reusa el boot-cleanup, no una copia")
    func swapReusesTheBootCleanup() throws {
        // Sin comentarios: el docblock del instrumento CITA `deleteStoreFiles` para explicar de qué patrón
        // sale la URL efímera, y contar la prosa haría que documentar el invariante lo violara.
        let src = try Self.code("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        #expect(src.contains("SwiftDataConfiguration.performSignOutWipeIfArmed()"))
        #expect(src.contains("deleteStoreFiles") == false, """
            El orquestador no borra archivos por su cuenta: se lo pide al hook, que ya tiene el guard S3,
            el orden kill-safe y el desarme al final.
            """)
    }

    /// El neutro se arma dentro del hook y pegado al `write(.icloud)`, no en el coordinador de sign-out: es
    /// lo que hace que el camino del boot y el del swap terminen en el MISMO estado.
    @Test("R4(a): el neutro se arma en el hook, tras `write(.icloud)` y antes de `resetPrefs`")
    func neutralMarkIsArmedInsideTheHook_inOrder() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let hook = try Self.body(of: "static func performSignOutWipeIfArmed(\n        defaults: UserDefaults,", in: src)
        let write = try #require(hook.range(of: "StorageModePersistence.write(.icloud, defaults: defaults)"))
        let arm = try #require(hook.range(of: "StorageModePersistence.armNeutralMount(defaults)"))
        let reset = try #require(hook.range(of: "resetPrefs()"))
        #expect(write.lowerBound < arm.lowerBound)
        #expect(arm.lowerBound < reset.lowerBound, """
            Antes de `resetPrefs()` a propósito: depender de que `removeUserPreferenceKeys` excluya
            `cloudSync.*` sería apoyar un invariante de MOUNT en la lista de exclusiones de un barrido de
            preferencias.
            """)
    }

    /// El instrumento del canario es el mismo que decidió el spike, adaptado al store real. Si alguien lo
    /// "simplificara" al trío de archivos, el veredicto pasaría a medir nada: `-wal`/`-shm` siguen en disco
    /// con la conexión ya cerrada porque Core Data activa el WAL persistente (MEDIDO, spec §11.1).
    @Test("R4(b): el conteo de descriptores usa `fcntl(F_GETPATH)` sobre el store personal")
    func descriptorProbeUsesFcntl() throws {
        let src = try Self.source("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        let probe = try Self.body(
            of: "static func openDescriptorCountForPersonalStore() -> Int {", in: src)
        #expect(probe.contains("F_GETPATH"))
        #expect(probe.contains("SwiftDataConfiguration.databaseName"), "mide el store REAL, no el del spike")
        #expect(probe.contains("personalConfiguration") == false, """
            preguntar por el path NO puede pasar por `personalConfiguration`: su evaluación CAPTURA el
            testigo del mount.
            """)
    }
}
