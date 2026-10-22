//
//  GroupsOnlyNeutralMountTests.swift
//  YalaTests
//
//  Paso 5 del rediseño de sesiones · el neutro durable de una sesión SOLO-GRUPOS.
//
//  Lo que se fija aquí es el bug del ticket `groups-only-second-launch-mounts-icloud-mirror`: instalas,
//  entras por «Vengo por un grupo», haces el alta, y al REABRIR la app el store personal adjuntaba el
//  espejo de iCloud y se traía el contenedor privado del Apple ID del teléfono.
//
//  La suite tiene tres mitades y las tres hacen falta:
//   (A) la tabla del predicado — que el término nuevo diga que sí, y que NO caduque con el chooser;
//   (B) los dos NO-debe: el restore que conserva su espejo y el anti-bucle;
//   (C) el cableado — que las dos altas armen y las dos salidas levanten. Sin (C), (A) puede estar
//       perfecta y el bug seguir vivo porque nadie escribe la marca (era el estado del árbol antes).
//

import Testing
import Foundation
@testable import Yala

// MARK: - (A) La tabla del predicado

@Suite("R5 · el neutro durable de solo-grupos")
struct GroupsOnlyNeutralDurableTests {

    @Test("la marca de solo-grupos monta neutro, con el chooser visto o sin ver")
    func groupsOnlyArmed_mountsNeutralRegardlessOfChooser() {
        for chooserSeen in [true, false] {
            #expect(SwiftDataConfiguration.shouldMountNeutralDurable(
                neutralMountArmed: false,
                hasShownWelcomeChooser: chooserSeen,
                groupsOnlySessionArmed: true,
            persistedMode: .icloud, mirrorOffArmed: false), """
                el chooser visto NO puede apagar el neutro de solo-grupos: quien elige «Primera vez →
                privado» (flag `true` en el acto) y luego entra por la card «Solo grupos» del propio
                onboarding llega al alta con `true` — y ahí es donde el bug del ticket revive.
                """)
        }
    }

    /// El caso EXACTO del ticket, escrito como lo vive el usuario: segundo arranque, el archivo del store
    /// ya existe (⇒ `freshInstall == false`), hay cuenta iCloud en el teléfono. Sin el término nuevo esto
    /// devuelve `.iCloudMirror` y baja datos ajenos.
    @Test("segundo arranque de una sesión solo-grupos con iCloud disponible ⇒ SIN espejo")
    func secondLaunchOfGroupsOnlySession_doesNotAttachMirror() {
        let neutral = SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: false, hasShownWelcomeChooser: true, groupsOnlySessionArmed: true,
            persistedMode: .icloud, mirrorOffArmed: false)

        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            freshInstall: false,
            neutralDurable: neutral) == .neutralNoMirror, """
            con iCloud disponible y sin este término la decisión sería `.iCloudMirror`, que es
            literalmente el bug: el espejo importa el contenedor privado del Apple ID sobre una sesión
            que solo pidió grupos.
            """)
    }

    @Test("sin ninguna de las dos marcas no hay neutro durable")
    func neitherMark_isNeverNeutral() {
        for chooserSeen in [true, false] {
            #expect(SwiftDataConfiguration.shouldMountNeutralDurable(
                neutralMountArmed: false,
                hasShownWelcomeChooser: chooserSeen,
                groupsOnlySessionArmed: false,
            persistedMode: .icloud, mirrorOffArmed: false) == false)
        }
    }

    /// La marca hermana conserva su caducidad: este término se AÑADE, no la sustituye.
    @Test("el término nuevo no relaja la caducidad del neutro hermano")
    func siblingMarkKeepsItsExpiry() {
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: true, hasShownWelcomeChooser: true,
            groupsOnlySessionArmed: false,
            persistedMode: .icloud, mirrorOffArmed: false) == false, """
            si esto pasa a `true`, el anti-bucle del restore se ha perdido por el camino.
            """)
    }

    @Test("la precedencia dura no se toca: el par .cloud sigue ganando")
    func hardPrecedenceSurvives() {
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: true, iCloudAvailable: true,
            freshInstall: false, neutralDurable: true) == .cloudMirrorOff)
    }
}

// MARK: - (A-bis) El ADAPTADOR de producción, que es el cable que enciende la feature

/// **Sin esto la feature entera se apaga en una línea sin un solo rojo.** `shouldMountNeutralDurable(_
/// defaults:)` es el ÚNICO sitio que lee la key persistida y la mete en el predicado, y el único que
/// producción llama. Los tests de la tabla de arriba pasan el `Bool` ya resuelto, así que ninguno
/// recorre este cable: cambiar aquí `isGroupsOnlyNeutralMountArmed` por `false`, por su hermana
/// `isNeutralMountArmed`, o escribir mal la key, deja la suite verde y el bug del ticket vivo al 100 %.
/// Es la «pasarela que nadie vigila» de `.claude/rules/testing.md`.
@Suite("R5 · el adaptador de producción del neutro solo-grupos")
struct GroupsOnlyNeutralMountAdapterTests {

    @Test("con la key ARMADA, el adaptador de producción dice neutro")
    func adapterReadsTheArmedKey() {
        let d = makeIsolatedDefaults(prefix: "r5.adapter.armed")
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(d) == false, "control negativo: sin marca, no")
        StorageModePersistence.armGroupsOnlyNeutralMount(d)
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(d), """
            el adaptador no está leyendo `isGroupsOnlyNeutralMountArmed`: la marca se escribe pero el \
            mount la ignora, que es exactamente el bug del ticket con el arreglo puesto.
            """)
    }

    /// El literal `"hasShownWelcomeChooser"` va crudo en el adaptador; esto lo fija de paso.
    @Test("el chooser visto NO apaga el neutro de solo-grupos, leído del store real")
    func adapterIgnoresTheChooserForGroupsOnly() {
        let d = makeIsolatedDefaults(prefix: "r5.adapter.chooser")
        StorageModePersistence.armGroupsOnlyNeutralMount(d)
        d.set(true, forKey: "hasShownWelcomeChooser")
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(d))
    }

    /// El confinamiento a `.icloud` sin armar, leído del store real. Sin él la marca revive tras la
    /// reversa y apaga el espejo para siempre, y rompe la ventana del cutover.
    @Test("la marca es INERTE fuera de `.icloud` virgen")
    func adapterConfinesTheMarkToVirginICloud() {
        let cloud = makeIsolatedDefaults(prefix: "r5.adapter.cloud")
        StorageModePersistence.armGroupsOnlyNeutralMount(cloud)
        StorageModePersistence.write(.cloud, defaults: cloud)
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(cloud) == false, """
            en modo nube la marca tiene que ser inerte: si no, sobrevive al viaje y revive en la reversa.
            """)

        let armado = makeIsolatedDefaults(prefix: "r5.adapter.armed.mirroroff")
        StorageModePersistence.armGroupsOnlyNeutralMount(armado)
        armado.set(true, forKey: StorageModePersistence.mirrorOffArmedKey)
        #expect(SwiftDataConfiguration.shouldMountNeutralDurable(armado) == false, """
            con `mirrorOffArmed` puesto el device está a mitad del cutover: el mirror TIENE que remontar \
            para que el marcador exporte.
            """)
    }
}

// MARK: - (B) Los dos NO-debe

@Suite("R5 · a quién NO debe alcanzar el neutro de solo-grupos")
struct GroupsOnlyNeutralMountBoundariesTests {

    /// **El daño CONTRARIO, y es el que casi cuesta el diseño equivocado.** Quien restaura de iCloud
    /// puede acabar en una sesión solo-grupos con el mirror ya adjunto y su histórico bajado. Si el
    /// neutro se DERIVARA de eso, a esa persona se le apagaría el espejo en el arranque siguiente.
    @Test("restaurar de iCloud en una sesión solo-grupos CONSERVA su espejo")
    func restoredGroupsOnlyUser_keepsMirror() {
        // Lo que lo salva es que la marca es un hecho de ESTE device y el restore no la arma nunca.
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true,
            freshInstall: false,
            neutralDurable: SwiftDataConfiguration.shouldMountNeutralDurable(
                neutralMountArmed: false,
                hasShownWelcomeChooser: true,
                groupsOnlySessionArmed: false,
            persistedMode: .icloud, mirrorOffArmed: false)) == .iCloudMirror, """
            quien restauró su cuenta de iCloud tiene que seguir espejando: apagarle el mirror le congela
            el histórico que acaba de bajar.
            """)
    }

    /// **La tesis de `restoredGroupsOnlyUser_keepsMirror` deja de ser un literal escrito a mano.** Aquel
    /// test clava `groupsOnlySessionArmed: false` para representar «el restore no la arma», y eso es una
    /// PREMISA, no una medición: meter un arm en el camino de restore lo dejaba verde. Esto la mide.
    @Test("solo DOS ficheros de producción arman la marca, y son las dos altas")
    func onlyTheTwoSignupsArmTheMark() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var armadores: [String] = []
        let enumerador = FileManager.default.enumerator(at: root.appending(path: "Yala"),
                                                        includingPropertiesForKeys: nil)
        while let url = enumerador?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let code = (try? String(contentsOf: url, encoding: .utf8))?
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n") ?? ""
            if code.contains("armGroupsOnlyNeutralMount") { armadores.append(url.lastPathComponent) }
        }
        // Paso 8 · `FullModeActivationView` RE-arma la marca, y solo en un sitio: cancelar una activación que
        // ya relanzó para adjuntar el espejo es volver a solo-grupos, y la marca es lo que su rama privada
        // había levantado. No es un alta nueva ni un restore: es deshacer el primer paso de la activación. Que
        // ocurra SOLO ahí lo fija `FullModeActivationWiringTests.cancel_afterRelaunch_reArmsTheNeutralMount`.
        #expect(Set(armadores) == ["GroupsOrganizerOnboarding.swift", "GroupInviteOnboardingView.swift",
                                   "CloudSyncFlags.swift", "FullModeActivationView.swift"], """
            cambió quién ARMA el neutro de solo-grupos: \(armadores.sorted()). Si el camino nuevo es un \
            restore, una adopción o un cutover, le estás apagando el espejo a alguien que sí lo necesita \
            — que es el daño CONTRARIO al de este ticket. `CloudSyncFlags` es la definición.
            """)
    }

    @Test("la marca en sí no cambia de valor sola: armar y desarmar son simétricos")
    func armAndClearAreSymmetric() {
        let d = makeIsolatedDefaults(prefix: "groupsOnlyNeutral")
        #expect(StorageModePersistence.isGroupsOnlyNeutralMountArmed(d) == false)
        StorageModePersistence.armGroupsOnlyNeutralMount(d)
        #expect(StorageModePersistence.isGroupsOnlyNeutralMountArmed(d))
        StorageModePersistence.clearGroupsOnlyNeutralMount(d)
        #expect(StorageModePersistence.isGroupsOnlyNeutralMountArmed(d) == false)
    }

    /// La marca es LOCAL y no viaja: describe cómo monta este teléfono, no qué eligió la cuenta.
    /// Propagarla apagaría el espejo en el otro device del mismo usuario, que puede tener sesión privada.
    @Test("armar en un device no arma en otro")
    func markIsPerDevice() {
        let a = makeIsolatedDefaults(prefix: "groupsOnlyNeutral.A")
        let b = makeIsolatedDefaults(prefix: "groupsOnlyNeutral.B")
        StorageModePersistence.armGroupsOnlyNeutralMount(a)
        #expect(StorageModePersistence.isGroupsOnlyNeutralMountArmed(b) == false)
    }
}

// MARK: - (C) El cableado (source-scan)

/// **Por qué además de las tablas.** El predicado puede estar perfecto y su suite verde mientras nadie
/// escribe la marca — que es EXACTAMENTE el estado del árbol antes de este ticket: `armNeutralMount`
/// existía, `shouldMountNeutralDurable` la leía, y el alta solo-grupos no la armaba. La tabla no lo veía.
///
/// Se comprueba por fuente porque los call-sites reales son una vista SwiftUI y un método `@MainActor`
/// con `SessionState.shared` y `ModelContext` dentro: instanciarlos desde la suite pide un container y un
/// árbol de vistas, y lo que hay que fijar aquí es QUIÉN llama, que es justo lo que el source-scan ve.
@Suite("R5 · cableado del neutro solo-grupos (source-scan)")
struct GroupsOnlyNeutralMountWiringTests {

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync
            .deletingLastPathComponent()  // YalaTests
            .deletingLastPathComponent()  // repo
        let url = root.appending(path: relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("el alta del ORGANIZADOR arma la marca")
    func organizerSetupArmsTheMark() throws {
        let src = try source("Yala/Services/Groups/GroupsOrganizerOnboarding.swift")
        #expect(src.contains("StorageModePersistence.armGroupsOnlyNeutralMount("), """
            sin esta llamada el arranque siguiente adjunta el espejo — es el bug del ticket, entero.
            """)
    }

    @Test("el alta por INVITACIÓN arma la marca, y solo en la rama del alta")
    func inviteSetupArmsTheMark() throws {
        let src = try source("Yala/App/Views/Groups/GroupInviteOnboardingView.swift")
        #expect(src.contains("StorageModePersistence.armGroupsOnlyNeutralMount("))

        // `performJoinOnlySetup` es la otra rama de `handleJoinTap()`: corre cuando el device YA tiene
        // onboarding, o sea el caso «privada + grupos asociados» del ADR §2, donde el espejo se queda.
        let joinOnly = try #require(src.range(of: "private func performJoinOnlySetup()"))
        let after = String(src[joinOnly.upperBound...])
        let closing = try #require(after.range(of: "\n    }"))
        let body = String(after[..<closing.lowerBound])

        #expect(!body.contains("armGroupsOnlyNeutralMount"), """
            armar aquí apagaría iCloud a quien acepta una invitación desde su Yala de siempre.
            """)
        #expect(body.contains("PendingJoinStore.updateDisplayName"), """
            control positivo del recorte: si esto falla, el rango medido no es el cuerpo de
            `performJoinOnlySetup` y la aserción de arriba pasaría sobre un texto vacío.
            """)
    }

    @Test("«Activar Yala completo» LEVANTA la marca")
    func fullActivationClearsTheMark() throws {
        let src = try source("Yala/App/Views/Groups/FullModeActivationView.swift")
        #expect(src.contains("StorageModePersistence.clearGroupsOnlyNeutralMount("), """
            sin esto el device se queda montando neutro para siempre y quien acaba de activar Yala
            completo no sincroniza nada.
            """)
    }

    /// El anti-bucle. Va en el MISMO callback que pone `hasShownWelcomeChooser`, que es lo que cierra el
    /// bucle para la marca hermana.
    @Test("el callback de relanzamiento por espejo LEVANTA la marca")
    func mirrorRelaunchClearsTheMark() throws {
        let src = try source("Yala/App/ContentView.swift")
        let callback = try #require(src.range(of: "onNeedsMirrorRelaunch: { destination in"))
        let after = String(src[callback.upperBound...])
        let end = try #require(after.range(of: "WelcomePendingDestinationStore.set(destination)"))
        let body = String(after[..<end.upperBound])

        #expect(body.contains("StorageModePersistence.clearGroupsOnlyNeutralMount("), """
            sin el desarme aquí, un device solo-grupos que pide restaurar gira para siempre: marca puesta
            ⇒ mount neutro ⇒ «reabre Yala» ⇒ mount neutro otra vez.
            """)
        #expect(body.contains("hasShownWelcomeChooser = true"), """
            control positivo del recorte: si esto falla, el rango medido no es el callback y la aserción
            de arriba no estaba mirando nada.
            """)
    }
}
