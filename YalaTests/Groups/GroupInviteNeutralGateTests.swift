//
//  GroupInviteNeutralGateTests.swift
//  YalaTests
//
//  «Acepto una invitación en un teléfono que ya espeja el iCloud de otra persona y mis gastos del grupo
//  acaban en SU iCloud» — el bridge escribe en el store personal y el espejo lo exporta. Nadie ve nada:
//  ni error, ni aviso, ni bloqueo.
//
//  Cuatro mitades, y ninguna cubre a las otras:
//    1. LA DECISIÓN — la tabla completa de `GroupInviteNeutralGateLogic`, con los dos términos que la
//       separan de la puerta del organizador (sesión privada viva, sesión de visita).
//    2. EL ENCAMINAMIENTO — que `drive` DESVÍE en vez de seguir, y que no escriba nada por el camino.
//       Es la mitad que hay que poder poner roja quitando el desvío.
//    3. LA DURABILIDAD — que la invitación sobreviva al borrado. El intent muere en el propio wipe
//       (`AppRouter.resetAll`), así que sin esto la persona borra su teléfono para unirse a un grupo al
//       que ya no puede unirse: el camino muerto, movido un paso más adelante.
//    4. EL CABLEADO (source-scan) — los dos providers que `ContentView` instala, el destino que se
//       persiste con su token y la reposición PEGADA al reset. La decisión puede estar perfecta y sus
//       celdas verdes mientras nadie la consulta con datos reales.
//

import Foundation
import Testing

@testable import Yala

// MARK: - 1 · La decisión

@Suite("La puerta del invitado · la tabla completa")
struct GroupInviteNeutralGateLogicTests {

    private typealias Gate = GroupInviteNeutralGateLogic

    /// **El caso del ticket**: Welcome visible, store con espejo. Da igual que no haya ni una fila —es
    /// justo el medio bug que el detector de corpus no puede ver, porque todavía no hay nada que contar.
    @Test("store con espejo y sin sesión privada ⇒ vuelta al neutro, incluso vacío")
    func mirroredEmptyStore_returnsToNeutral() {
        #expect(Gate.decide(hasCompletedPersonalOnboarding: false,
                            isSecondarySession: false,
                            hasExistingData: false,
                            mountAttachesMirror: true) == .returnsToNeutral)
    }

    /// La otra mitad del OR: corpus de alguien debajo, sin espejo.
    @Test("corpus sin espejo ⇒ vuelta al neutro")
    func localCorpusWithoutMirror_returnsToNeutral() {
        #expect(Gate.decide(hasCompletedPersonalOnboarding: false,
                            isSecondarySession: false,
                            hasExistingData: true,
                            mountAttachesMirror: false) == .returnsToNeutral)
    }

    /// **Criterio nº 3 del ticket**: el invitado de una instalación fresca no paga NADA. Es la población
    /// mayoritaria, y una pantalla de más aquí se la cobra a todo el mundo para arreglarle el teléfono a
    /// unos pocos.
    @Test("teléfono neutro ⇒ sigue, sin una sola pantalla de más")
    func freshDevice_proceeds() {
        #expect(Gate.decide(hasCompletedPersonalOnboarding: false,
                            isSecondarySession: false,
                            hasExistingData: false,
                            mountAttachesMirror: false) == .proceed)
    }

    /// **El término que separa esta puerta de la del organizador**, y el que evita el daño más caro: con
    /// la sesión privada viva, el que está delante es el DUEÑO de esos datos. La matriz del ADR manda
    /// (`C · llega una invitación`): asociar y unirse, jamás borrar. Sin este término, aplicar aquí la
    /// puerta del organizador le vaciaría el teléfono a quien acaba de recibir un enlace.
    @Test("con sesión privada viva NUNCA se vuelve al neutro, mida lo que mida el resto")
    func livePrivateSession_alwaysProceeds() {
        for hasData in [true, false] {
            for mirror in [true, false] {
                #expect(Gate.decide(hasCompletedPersonalOnboarding: true,
                                    isSecondarySession: false,
                                    hasExistingData: hasData,
                                    mountAttachesMirror: mirror) == .proceed,
                        "corpus=\(hasData) espejo=\(mirror): la fila C de la matriz dice asociar, no borrar")
            }
        }
    }

    /// La sesión de VISITA queda fuera: su mount ya aísla (`YalaModel-Secondary`, sin espejo) y su celda
    /// de cierre (`.secondaryCloudSignOut`) no borra por archivos, así que interponer aquí sería mandar a
    /// la invitada a una pantalla que no puede hacer nada.
    @Test("en sesión de visita NUNCA se vuelve al neutro")
    func secondarySession_alwaysProceeds() {
        for hasData in [true, false] {
            for mirror in [true, false] {
                #expect(Gate.decide(hasCompletedPersonalOnboarding: false,
                                    isSecondarySession: true,
                                    hasExistingData: hasData,
                                    mountAttachesMirror: mirror) == .proceed,
                        "corpus=\(hasData) espejo=\(mirror)")
            }
        }
    }

    /// La tabla ENTERA, 16 celdas, contra la regla dicha de otra forma. Lo que caza que una implementación
    /// futura reordene los guards y cambie una celda sin que ninguna de las de arriba lo note.
    @Test("las 16 celdas, contra el predicado dicho al revés")
    func fullTruthTable() {
        for onboarded in [true, false] {
            for secondary in [true, false] {
                for hasData in [true, false] {
                    for mirror in [true, false] {
                        let esperado: Gate.Decision =
                            (!onboarded && !secondary && (hasData || mirror)) ? .returnsToNeutral : .proceed
                        #expect(Gate.decide(hasCompletedPersonalOnboarding: onboarded,
                                            isSecondarySession: secondary,
                                            hasExistingData: hasData,
                                            mountAttachesMirror: mirror) == esperado,
                                "onboarded=\(onboarded) secundaria=\(secondary) corpus=\(hasData) espejo=\(mirror)")
                    }
                }
            }
        }
    }
}

// MARK: - 2 · El encaminamiento

@MainActor
@Suite("La puerta del invitado · el desvío desde `drive`", .serialized)
struct GroupInviteNeutralGateRoutingTests {

    /// Molde de `GroupInviteSheetAlwaysShownTests.makeEnv`: defaults aislados, providers restaurados al
    /// salir, router observable. La diferencia es que aquí el mount se FINGE por celda, porque es lo que
    /// se está midiendo.
    private func makeEnv(mirror: Bool,
                         onboarded: Bool = false,
                         hasData: Bool = false,
                         joinSpy: @escaping @MainActor () -> Void = {}) -> () -> Void {
        let suite = "test.inviteneutral.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        PendingJoinStore.defaults = d
        GroupInviteResumeStore.defaults = d

        let savedJoin = GroupBackendInviteEntryHandler.joinProvider
        let savedSession = GroupBackendInviteEntryHandler.hasSessionProvider
        let savedConsent = GroupBackendInviteEntryHandler.isConsentedProvider
        let savedProfile = GroupBackendInviteEntryHandler.profileNameProvider
        let savedMirror = GroupBackendInviteEntryHandler.mountAttachesMirrorProvider
        let savedOnboarded = GroupBackendInviteEntryHandler.hasCompletedPersonalOnboardingProvider
        let savedSecondary = GroupBackendInviteEntryHandler.isSecondarySessionProvider
        let savedData = GroupBackendInviteEntryHandler.hasLocalDataProvider
        let savedReadiness = RouterEntryGate.shared.readinessProvider
        let savedFlag = CloudSyncFlags.groupsBackendEnabled

        GroupBackendInviteEntryHandler.hasSessionProvider = { true }
        GroupBackendInviteEntryHandler.isConsentedProvider = { true }
        GroupBackendInviteEntryHandler.profileNameProvider = { "Pia" }
        GroupBackendInviteEntryHandler.mountAttachesMirrorProvider = { mirror }
        GroupBackendInviteEntryHandler.hasCompletedPersonalOnboardingProvider = { onboarded }
        GroupBackendInviteEntryHandler.isSecondarySessionProvider = { false }
        GroupBackendInviteEntryHandler.hasLocalDataProvider = { hasData }
        GroupBackendInviteEntryHandler.joinProvider = { _, _, _ in
            joinSpy()
            return JoinGroupResult(groupID: "G1", memberKey: "sub", status: "pendingApproval", rebound: false)
        }
        RouterEntryGate.shared.readinessProvider = { (hasCompletedOnboarding: true, isBootstrapInitialized: true) }
        CloudSyncFlags.groupsBackendEnabled = true
        AppRouter.shared._testReset()
        GroupBackendInviteEntryHandler.clearInviteTapArms()
        GroupJoinIntentTracker.shared.clear()

        return {
            GroupBackendInviteEntryHandler.joinProvider = savedJoin
            GroupBackendInviteEntryHandler.hasSessionProvider = savedSession
            GroupBackendInviteEntryHandler.isConsentedProvider = savedConsent
            GroupBackendInviteEntryHandler.profileNameProvider = savedProfile
            GroupBackendInviteEntryHandler.mountAttachesMirrorProvider = savedMirror
            GroupBackendInviteEntryHandler.hasCompletedPersonalOnboardingProvider = savedOnboarded
            GroupBackendInviteEntryHandler.isSecondarySessionProvider = savedSecondary
            GroupBackendInviteEntryHandler.hasLocalDataProvider = savedData
            RouterEntryGate.shared.readinessProvider = savedReadiness
            CloudSyncFlags.groupsBackendEnabled = savedFlag
            AppRouter.shared._testReset()
            GroupBackendInviteEntryHandler.clearInviteTapArms()
            GroupJoinIntentTracker.shared.clear()
            PendingJoinStore.defaults = .standard
            GroupInviteResumeStore.defaults = .standard
            d.removePersistentDomain(forName: suite)
        }
    }

    private func queuedIDs() -> [String] {
        AppRouter.shared.queueSnapshot.map(\.id)
    }

    /// **LA REPRODUCCIÓN.** Quitando el desvío de `drive` este test se pone rojo: sin él, la invitación
    /// sigue a su terminal y el join sale sobre un store espejado.
    @Test("con espejo, `drive` desvía a la puerta y NO llega al join")
    func mirroredStore_routesToTheGate() async {
        var joins = 0
        let cleanup = makeEnv(mirror: true, joinSpy: { joins += 1 }); defer { cleanup() }
        let groupID = "SplitGroup-\(UUID().uuidString)"
        GroupBackendInviteEntryHandler.persistIntent(groupID: groupID, token: "tok")
        PendingJoinStore.markInviteConfirmed(zoneName: groupID)

        await GroupBackendInviteEntryHandler.drive(groupID: groupID, token: "tok", source: .universalLink)

        #expect(queuedIDs() == ["groupsInviteNeutralGate:\(groupID)"],
                "el desvío es lo ÚNICO que se encola. Encontrado: \(queuedIDs())")
        #expect(joins == 0, "el join salió sobre un store espejado: es el daño del ticket")
    }

    /// **Criterio nº 2 del ticket, y la razón de que la pantalla PREGUNTE.** El reconciler llama a `drive`
    /// en el trigger `.boot` sin que nadie haya tocado nada, así que el desvío tiene que poder ocurrir ahí
    /// sin borrar ni una fila. Lo que se comprueba es que el arranque encola una PRESENTACIÓN y nada más.
    @Test("en `.boot` el desvío no borra nada: solo presenta")
    func bootTrigger_onlyPresents() async {
        var joins = 0
        let cleanup = makeEnv(mirror: true, joinSpy: { joins += 1 }); defer { cleanup() }
        let groupID = "SplitGroup-\(UUID().uuidString)"
        GroupBackendInviteEntryHandler.persistIntent(groupID: groupID, token: "tok")

        await GroupBackendInviteEntryHandler.drive(groupID: groupID, token: "tok", source: .boot)

        #expect(queuedIDs() == ["groupsInviteNeutralGate:\(groupID)"])
        #expect(joins == 0)
        // El arm del cierre lo escribe la PANTALLA, nunca este camino: el `drive` no puede armar un
        // borrado que nadie ha visto. Si algún día se moviera aquí, este `#expect` es el que lo canta.
        #expect(GroupInviteResumeStore.peek() == nil,
                "`drive` guardó la invitación para un borrado que nadie ha autorizado todavía")
        // Y el intent sigue vivo: el desvío no consume nada.
        #expect(PendingJoinStore.entry(zoneName: groupID) != nil)
    }

    /// El caso mayoritario: teléfono neutro. La invitación no ve la puerta ni de lejos y llega a su join.
    @Test("sin espejo ni corpus, `drive` sigue al join de siempre")
    func neutralDevice_joinsAsBefore() async {
        var joins = 0
        let cleanup = makeEnv(mirror: false, joinSpy: { joins += 1 }); defer { cleanup() }
        let groupID = "SplitGroup-\(UUID().uuidString)"
        GroupBackendInviteEntryHandler.persistIntent(groupID: groupID, token: "tok")
        PendingJoinStore.markInviteConfirmed(zoneName: groupID)

        await GroupBackendInviteEntryHandler.drive(groupID: groupID, token: "tok", source: .userAction)

        #expect(joins == 1, "el invitado de un teléfono limpio tiene que entrar sin pantallas de más")
        #expect(!queuedIDs().contains { $0.hasPrefix("groupsInviteNeutralGate") })
    }

    /// La fila C de la matriz, por el camino real: con la sesión privada viva el enlace sigue su curso.
    @Test("con sesión privada viva el enlace no despierta la puerta")
    func livePrivateSession_neverRoutesToTheGate() async {
        var joins = 0
        let cleanup = makeEnv(mirror: true, onboarded: true, hasData: true, joinSpy: { joins += 1 })
        defer { cleanup() }
        let groupID = "SplitGroup-\(UUID().uuidString)"
        GroupBackendInviteEntryHandler.persistIntent(groupID: groupID, token: "tok")
        PendingJoinStore.markInviteConfirmed(zoneName: groupID)

        await GroupBackendInviteEntryHandler.drive(groupID: groupID, token: "tok", source: .userAction)

        #expect(joins == 1)
        #expect(!queuedIDs().contains { $0.hasPrefix("groupsInviteNeutralGate") })
    }

    /// El sello de la confirmación va DELANTE del desvío: la persona dijo que sí, y eso ya es verdad
    /// aunque el teléfono tenga que limpiarse antes. Sellarlo después haría que un desvío le borrara su
    /// propio «sí».
    @Test("el desvío conserva el sello de la confirmación")
    func theConfirmationSealSurvivesTheDetour() async {
        let cleanup = makeEnv(mirror: true); defer { cleanup() }
        let groupID = "SplitGroup-\(UUID().uuidString)"
        GroupBackendInviteEntryHandler.persistIntent(groupID: groupID, token: "tok")

        await GroupBackendInviteEntryHandler.drive(groupID: groupID, token: "tok", source: .userAction)

        #expect(PendingJoinStore.entry(zoneName: groupID)?.isInviteConfirmed == true)
    }
}

// MARK: - 3 · La durabilidad

@MainActor
@Suite("La puerta del invitado · la invitación sobrevive al borrado", .serialized)
struct GroupInviteResumeStoreTests {

    private func makeEnv() -> (UserDefaults, () -> Void) {
        let suite = "test.inviteresume.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        GroupInviteResumeStore.defaults = d
        PendingJoinStore.defaults = d
        GroupBackendInviteEntryHandler.clearInviteTapArms()
        return (d, {
            GroupInviteResumeStore.defaults = .standard
            PendingJoinStore.defaults = .standard
            GroupBackendInviteEntryHandler.clearInviteTapArms()
            d.removePersistentDomain(forName: suite)
        })
    }

    @Test("guarda, lee sin consumir, y el consumo es ONE-SHOT")
    func setPeekConsume() {
        let (_, cleanup) = makeEnv(); defer { cleanup() }

        #expect(GroupInviteResumeStore.peek() == nil)
        GroupInviteResumeStore.set(groupID: "G-7", token: "tok-7")
        #expect(GroupInviteResumeStore.peek()?.groupID == "G-7")
        #expect(GroupInviteResumeStore.peek()?.token == "tok-7")
        #expect(GroupInviteResumeStore.peek() != nil, "`peek` consumió, y no debe")
        #expect(GroupInviteResumeStore.consume()?.groupID == "G-7")
        #expect(GroupInviteResumeStore.consume() == nil, "un segundo arranque no puede volver a reponer")
    }

    /// **La caducidad, y por qué existe.** Un sobre sin fecha se queda para siempre si el borrado no llega
    /// a correr —el abort del boot-wipe desarma y nadie más lo mira—, y el siguiente cierre de sesión, que
    /// puede ser de OTRA persona, lo repondría con el tap armado: una solicitud de entrada a un grupo
    /// viejo bajo una cuenta que nunca la pidió. Siete días, el mismo TTL que la invitación que
    /// representa.
    @Test("el sobre caduca a los 7 días, y la lectura lo RETIRA")
    func envelopeExpires() {
        let (d, cleanup) = makeEnv(); defer { cleanup() }
        let ayer = Date(timeIntervalSince1970: 1_000_000)

        GroupInviteResumeStore.set(groupID: "G-1", token: "tok-1", now: ayer)
        #expect(GroupInviteResumeStore.peek(now: ayer.addingTimeInterval(6 * 24 * 3600)) != nil,
                "a los 6 días todavía vale")
        #expect(GroupInviteResumeStore.peek(now: ayer.addingTimeInterval(8 * 24 * 3600)) == nil)
        #expect(d.data(forKey: GroupInviteResumeStore.key) == nil,
                "el sobre caducado se queda en disco esperando a un wipe que no es el suyo")
    }

    /// Un reloj que va hacia atrás (cambio de zona, ajuste manual) no puede dejar un sobre inmortal.
    @Test("un sobre del FUTURO también caduca")
    func envelopeFromTheFutureExpires() {
        let (_, cleanup) = makeEnv(); defer { cleanup() }
        let ahora = Date(timeIntervalSince1970: 2_000_000)

        GroupInviteResumeStore.set(groupID: "G-2", token: "tok-2", now: ahora.addingTimeInterval(30 * 24 * 3600))
        #expect(GroupInviteResumeStore.peek(now: ahora) == nil)
    }

    /// Molde de `WelcomePendingDestinationStore.consume`: el residuo que nadie puede leer se RETIRA, o se
    /// queda ahí para siempre haciendo que cada arranque intente reponer lo que no se puede reponer.
    @Test("un contenido ilegible se retira en vez de quedarse")
    func garbageIsEvicted() {
        let (d, cleanup) = makeEnv(); defer { cleanup() }

        d.set(Data("no soy json".utf8), forKey: GroupInviteResumeStore.key)
        #expect(GroupInviteResumeStore.consume() == nil)
        #expect(d.data(forKey: GroupInviteResumeStore.key) == nil)
    }

    /// **La mitad que importa.** Reponer «la invitación» tiene que dejarla USABLE, no solo visible: sin el
    /// tap armado, `GroupJoinReconcileLogic.decideBackend` no autoriza el `join_group` de quien tiene un
    /// member residual, y la invitación repuesta se quedaría mirando.
    @Test("la reposición devuelve el intent AL STORE y con el tap armado")
    func restorePutsTheIntentBack() {
        let (_, cleanup) = makeEnv(); defer { cleanup() }

        GroupInviteResumeStore.set(groupID: "G-9", token: "tok-9")
        // El estado después del wipe: `AppRouter.resetAll()` se llevó el intent y el arm.
        PendingJoinStore.clearAll()
        GroupBackendInviteEntryHandler.clearInviteTapArms()
        #expect(PendingJoinStore.entry(zoneName: "G-9") == nil)

        #expect(GroupInviteResumeStore.restoreIntoPendingJoins())

        let repuesto = PendingJoinStore.entry(zoneName: "G-9")
        #expect(repuesto?.inviteToken == "tok-9")
        #expect(repuesto?.backendGroupID == "G-9")
        #expect(GroupBackendInviteEntryHandler.isInviteTapArmed(groupID: "G-9"),
                "repuesta pero inerte: sin el tap armado el reconciler no puede pedir la entrada")
    }

    /// **La reposición NO consume, y eso es el orden kill-safe del boot-hook.** Su docblock declara que
    /// una re-entrada tras un kill re-ejecuta el borrado entero —`resetPrefs()` incluido, que vuelve a
    /// vaciar `PendingJoinStore`—. Con un consumo aquí, la segunda pasada destruía la invitación: el
    /// destructor se re-ejecutaba y el reparador ya no.
    @Test("dos pasadas del hook reponen igual: el reparador es re-ejecutable")
    func restoreIsIdempotentAcrossReentry() {
        let (_, cleanup) = makeEnv(); defer { cleanup() }

        GroupInviteResumeStore.set(groupID: "G-K", token: "tok-K")

        // Pasada 1: el wipe vacía y repone, y muere antes de desarmar.
        PendingJoinStore.clearAll()
        #expect(GroupInviteResumeStore.restoreIntoPendingJoins())
        #expect(PendingJoinStore.entry(zoneName: "G-K") != nil)

        // Pasada 2 (el arm seguía puesto): vuelve a vaciar y TIENE que volver a reponer.
        PendingJoinStore.clearAll()
        #expect(GroupInviteResumeStore.restoreIntoPendingJoins(),
                "la re-entrada del hook destruyó la invitación que el propio hook acababa de reponer")
        #expect(PendingJoinStore.entry(zoneName: "G-K")?.inviteToken == "tok-K")

        // Y el desarme, que es donde el hook pone lo one-shot, la retira.
        GroupInviteResumeStore.clearAfterRestore()
        #expect(GroupInviteResumeStore.peek() == nil)
        #expect(!GroupInviteResumeStore.restoreIntoPendingJoins())
    }

    /// **Criterio nº 1 del ticket, segunda mitad**: «al reabrir, la hoja de unirme sale sola». Lo que NO se
    /// repone es la confirmación —`inviteConfirmedAt` no viaja en la key—, así que la persona vuelve a ver
    /// a qué grupo la invitan antes de entrar. Es el default seguro: pedir confirmación, nunca unirse sola.
    @Test("lo repuesto vuelve SIN confirmar: la hoja se presenta otra vez")
    func restoredIntentIsUnconfirmed() {
        let (_, cleanup) = makeEnv(); defer { cleanup() }

        GroupInviteResumeStore.set(groupID: "G-3", token: "tok-3")
        PendingJoinStore.clearAll()
        _ = GroupInviteResumeStore.restoreIntoPendingJoins()

        #expect(PendingJoinStore.entry(zoneName: "G-3")?.isInviteConfirmed == false)
    }

    /// Para TODOS los demás cierres de sesión esta reposición es un no-op, y eso es lo que mantiene sus
    /// caminos byte-idénticos: la key solo la escribe una pantalla.
    @Test("sin key guardada la reposición no toca nada")
    func noKey_isANoOp() {
        let (_, cleanup) = makeEnv(); defer { cleanup() }

        #expect(!GroupInviteResumeStore.restoreIntoPendingJoins())
        #expect(PendingJoinStore.all().isEmpty)
    }

    /// Sin PII: el sobre lleva DOS campos y nada más. El nombre tecleado y la marca del grupo son datos de
    /// la persona y no cruzan un borrado; el `legacyMemberKey` además es una credencial de re-bind.
    @Test("el sobre no lleva PII")
    func envelopeCarriesNoPII() throws {
        let (d, cleanup) = makeEnv(); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(
            groupID: "G-5", token: "tok-5",
            branded: InviteLinkService.BrandedMetadata(name: "Viaje a Cusco", icon: nil, color: nil, members: nil))
        PendingJoinStore.updateDisplayName("Pia la invitada")
        GroupInviteResumeStore.set(groupID: "G-5", token: "tok-5")

        let raw = try #require(d.data(forKey: GroupInviteResumeStore.key))
        let json = String(decoding: raw, as: UTF8.self)
        #expect(!json.contains("Pia"), "el nombre tecleado viajó en la key: \(json)")
        #expect(!json.contains("Cusco"), "el nombre del grupo viajó en la key: \(json)")
        let decoded = try JSONDecoder().decode([String: String].self, from: raw)
        #expect(Set(decoded.keys) == ["g", "t", "c"],
                "campos inesperados en el sobre: \(decoded.keys.sorted())")
    }
}

// MARK: - 4 · El cableado (source-scan)

@Suite("La puerta del invitado · el cableado")
struct GroupInviteNeutralGateWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Groups
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// **Los dos providers que sin cablear dejan la puerta medio ciega.** `hasLocalDataProvider` necesita
    /// un `ModelContext` que el handler no tiene, y el del onboarding tiene que leer el CAJÓN de la sesión
    /// —no el dominio del dueño— o devuelve el defecto de 2026-09-03. Los dos viven en `ContentView`, que
    /// es quien tiene las dos cosas.
    @Test("`ContentView` instala los dos providers que el handler no puede resolver solo")
    func contentViewWiresBothProviders() throws {
        let code = try Self.source("Yala/App/ContentView.swift")
        #expect(code.contains("GroupBackendInviteEntryHandler.hasLocalDataProvider = { checkHasExistingData() }"),
                "sin este cableado la puerta no ve el corpus y solo caza el caso del espejo")
        #expect(code.contains("GroupBackendInviteEntryHandler.hasCompletedPersonalOnboardingProvider"),
                "sin este cableado la puerta no sabe distinguir al dueño del recién llegado")
        #expect(code.contains("UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)"),
                "el término del onboarding tiene que salir del CAJÓN de la sesión, no del dominio del dueño")
    }

    /// La pantalla RE-MIDE, y con el MISMO veredicto que el productor. Dos composiciones de la misma
    /// decisión divergen: bastaría con que una ganara un término para que la pantalla dejara pasar lo que
    /// `drive` frenó.
    @Test("la puerta del Welcome re-mide con el veredicto del handler, no con el suyo propio")
    func theGateViewReusesTheSameVerdict() throws {
        let code = try Self.source("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        #expect(code.contains("GroupBackendInviteEntryHandler.neutralGateDecision()"))
        #expect(!code.contains("GroupInviteNeutralGateLogic.decide("),
                "la pantalla recompuso la decisión por su cuenta: es la segunda verdad que hay que evitar")
    }

    /// **El orden es el arreglo entero, y son TRES posiciones, no dos.** La reposición va DESPUÉS de
    /// `resetPrefs()` —quien mata el intent (`AppRouter.resetAll` → `PendingJoinStore.clearAll`)— y la
    /// retirada del sobre va PEGADA al desarme, no a la reposición: entre una y otra hay un tramo largo
    /// (notificaciones, colas del App Group, el barrido de sentinels) donde un kill deja el arm puesto y
    /// obliga a re-ejecutar el borrado entero. Consumir el sobre al principio de ese tramo destruía la
    /// invitación en la segunda pasada.
    @Test("el boot-wipe repone tras el reset y retira el sobre con el DESARME")
    func theWipeRestoresAfterTheReset() throws {
        let code = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let reset = try #require(code.range(of: "\n        resetPrefs()\n"),
                                 "no se encontró la llamada a `resetPrefs()` en el boot-wipe")
        let restore = try #require(code.range(of: "\n        restoreDeferredInvite()\n"),
                                   "el boot-wipe ya no repone la invitación: el camino muerto vuelve")
        let clear = try #require(
            code.range(of: "\n        clearDeferredInvite()\n        StorageModePersistence.clearSignOutWipeArm"),
            "la retirada del sobre ya no está pegada al desarme")
        #expect(reset.upperBound <= restore.lowerBound,
                "la reposición corre ANTES del reset que la borra — no-op silencioso")
        #expect(restore.upperBound <= clear.lowerBound, "el sobre se retira antes de reponerse")
        #expect(code.contains("restoreDeferredInvite: { GroupInviteResumeStore.restoreIntoPendingJoins() }"),
                "el wrapper de producción no pasa la closure real: en device no se repone nada")
        #expect(code.contains("clearDeferredInvite: { GroupInviteResumeStore.clearAfterRestore() }"))
    }

    /// **Un abort del borrado que DESARMA tiene que llevarse el sobre.** Si no, queda un residuo sin dueño
    /// que nadie retira —su único consumidor es este hook— y el siguiente cierre de sesión, que puede ser
    /// de otra persona, lo repondría con el tap armado.
    @Test("el abort que desarma también retira el sobre")
    func abortDisarmsTheEnvelopeToo() throws {
        let code = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let fin = try #require(code.range(of: "store file deletion failed — icloud, disarmed"),
                               "no se encontró la rama del abort que desarma")
        let ini = try #require(code.range(of: "if StorageModePersistence.read(defaults) == .icloud {",
                                          range: code.startIndex..<fin.lowerBound))
        #expect(code[ini.lowerBound..<fin.upperBound].contains("clearDeferredInvite()"),
                "el abort desarma el wipe y deja el sobre huérfano para siempre")
    }

    /// **El sobre lo escribe la PANTALLA, en el gesto, y no el callback del arm.** Entre `armSignOutWipe()`
    /// y la entrega del `onChange` hay una vuelta de SwiftUI, y en el camino del swap in-process la
    /// jerarquía se desmonta en la misma vuelta del arm: el teléfono se borraba y la invitación no cruzaba.
    @Test("el sobre se escribe en el gesto, no al armar")
    func theEnvelopeIsWrittenOnTheGesture() throws {
        let view = try Self.source("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        let content = try Self.source("Yala/App/ContentView.swift")
        #expect(view.contains("GroupInviteResumeStore.set(groupID: groupID, token: token)"),
                "la pantalla ya no escribe el sobre en el gesto")
        #expect(!content.contains("GroupInviteResumeStore.set("),
                "el sobre volvió al callback del arm, fuera de la ventana del swap in-process")
        #expect(content.contains("if GroupInviteResumeStore.peek()?.groupID == groupID {"))
        #expect(content.contains("WelcomePendingDestinationStore.set(.groupsInvite)"))
        #expect(content.contains("WelcomePendingDestinationStore.set(.groupsOrganizer)"),
                "la rama del organizador perdió su destino: el paso 5 se rompe")
    }

    /// **«Continuar igualmente» no se le ofrece al invitado.** Esa salida descarta lo que el espejo no
    /// llegó a exportar, y por la rama de la invitación quien la tocaría es otra persona: lo que estaría
    /// descartando no es suyo. Es el criterio nº 4 del ticket, y sin este corte dependía de a quién le
    /// dejaran el móvil.
    @Test("el invitado no puede descartar lo que el dueño no llegó a subir")
    func theGuestCannotDiscardTheOwnersUnsyncedWork() throws {
        let view = try Self.source("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        let cta = try #require(view.range(of: "L10n.Welcome.Groups.neutralStalledContinue"))
        let guardia = try #require(view.range(of: "if purpose.invitedGroupID == nil {"),
                                   "el descarte dejó de estar acotado al dueño de los datos")
        #expect(guardia.upperBound < cta.lowerBound, "el guard no cubre el botón que descarta")
    }

    /// **Sin copia en iCloud se pide un SEGUNDO gesto, igual que en la rama del organizador.** El caso
    /// irreversible es justo el que no puede perder su confirmación por ahorrarse una pantalla.
    @Test("sin copia en iCloud el invitado encadena el segundo gesto")
    func noBackupChainsTheSecondGesture() throws {
        let view = try Self.source("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        let cta = try #require(view.range(of: "L10n.Welcome.Groups.inviteNeutralCta"))
        let previo = view[view.startIndex..<cta.lowerBound]
        let rama = try #require(previo.range(of: "if withoutICloudCopy {", options: .backwards))
        #expect(previo[rama.lowerBound...].contains("phase = .confirmingNoBackup"),
                "el CTA del invitado arranca el borrado sin el segundo gesto cuando no hay copia")
    }

    /// **El propósito viaja DENTRO del step**, y eso es lo que hace imposible que un productor lo herede.
    /// Mientras vivió al lado, tres de los cinco no lo escribían: quien tapeaba «Crear mi primer grupo»
    /// tras volver atrás en una invitación acababa uniéndose al grupo de otro.
    @Test("el step lleva el propósito, y ningún productor puede heredarlo")
    func thePurposeTravelsInsideTheStep() throws {
        let container = try Self.source("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let content = try Self.source("Yala/App/ContentView.swift")
        #expect(container.contains("case groupsGate(purpose: WelcomeGroupsGateView.Purpose)"))
        #expect(!content.contains("groupsGatePurpose"),
                "volvió el estado paralelo que el propósito dentro del step vino a matar")
        let sueltos = content.components(separatedBy: "welcomeFlowInitialStep = .groupsGate")
            .dropFirst()
            .filter { !$0.hasPrefix("(purpose:") }
        #expect(sueltos.isEmpty, "hay \(sueltos.count) productores del step sin propósito")
    }

    /// **El cover obedece al step inicial aunque ya esté montado.** Sin esto, el drain del intent baja
    /// `showWelcomeFlow` y el `case` lo sube en la misma vuelta síncrona: SwiftUI no renderiza entre las
    /// dos escrituras, el cover no se desmonta y el step pedido se pierde — el invitado se quedaba en el
    /// Hero con su invitación viva y sin pantalla que la retomara.
    @Test("el container sigue al step inicial aunque no se desmonte")
    func theContainerFollowsTheInitialStep() throws {
        let container = try Self.source("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        #expect(container.contains(".onChange(of: initialStep)"),
                "el step inicial vuelve a ignorarse con el cover ya montado")
    }

    /// La CUARTA superficie de join, y la única que no muere sola: el sobre existe para sobrevivir a un
    /// borrado, así que la frontera de la visita tiene que nombrarlo. Sin esto, un sobre escrito antes de
    /// la frontera se repondría en el siguiente boot-wipe con el tap armado.
    @Test("la frontera de la sesión de visita barre también el sobre")
    func theSecondaryBoundaryClearsTheEnvelope() throws {
        let code = try Self.source("Yala/Services/CloudSync/SecondarySessionBoundaryPurge.swift")
        #expect(code.contains("GroupInviteResumeStore.clear()"),
                "el sobre cruza la frontera de la visita y se repone bajo la cuenta equivocada")
    }

    /// Bajo `-uitest` la puerta SÍ es alcanzable (el seam del mount lo permite) pero el hook que consume el
    /// sobre sale antes de tocar nada, así que la key se quedaría en el simulador para todas las suites
    /// siguientes y para cualquier arranque manual.
    @Test("bajo -uitest el sobre se purga en el arranque")
    func theEnvelopeIsPurgedUnderUITest() throws {
        let boot = try Self.source("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains("UITestEphemeralDefaults.purgeGroupInviteResumeEnvelope()"),
                "el sobre se filtra al UserDefaults real del simulador y no lo limpia nadie")
    }
}
