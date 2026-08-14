//
//  SessionDefaultsTests.swift
//  YalaTests / CloudSync
//
//  La puerta de dominio de preferencias por sesión (M1) y su ciclo de vida completo.
//
//  Cubre las tres cláusulas del contrato de `SessionDefaults` —instancia cacheada, resolución por
//  llamada, degradación observable— y los dos anclajes del ciclo de vida: la siembra de la ENTRADA
//  (aditiva, con sentinel leído DEL CAJÓN) y la destrucción de la SALIDA (antes de que `clear` se
//  lleve el `sub` con el que se compone el nombre).
//
//  **Suite serializada a propósito**: `SessionDefaults` cachea instancias en estado estático, y dos
//  tests concurrentes sobre el mismo nombre de suite se pisarían.
//

import Foundation
import Testing

@testable import Yala

/// Un `sub` distinto por test — los suites son ARCHIVOS reales en disco y un nombre compartido
/// arrastra el estado de un test al siguiente.
private func freshUserID(_ label: String) -> String {
    "\(label)-\(UUID().uuidString)"
}

/// La siembra y la destrucción REALES. Bajo tests las dos son no-op por defecto —igual que la
/// resolución— para que ningún hook de frontera deje cajones en el disco del simulador; ejercitarlas
/// exige pedirlo, que es exactamente lo que hacen estos tests.
private let liveSeed: (UserDefaults, String) -> Void = {
    SessionDefaults.seedDeviceKeysIfNeeded(from: $0, forUserID: $1, isTestEnvironment: false)
}
private let liveDestroy: (String) -> Void = {
    SessionDefaults.destroySuite(forUserID: $0, isTestEnvironment: false)
}

/// Crea el cajón, ejecuta el cuerpo y lo destruye pase lo que pase.
private func withSessionSuite(_ userID: String, _ body: (UserDefaults) throws -> Void) rethrows {
    defer { liveDestroy(userID) }
    guard let name = SessionDefaults.suiteName(forUserID: userID),
          let suite = SessionDefaults.suite(named: name) else {
        Issue.record("no se pudo abrir el cajón de \(userID)")
        return
    }
    try body(suite)
}

// MARK: - La puerta

@Suite("SessionDefaults · la puerta", .serialized)
struct SessionDefaultsGateTests {

    @Test("sin sesión secundaria, el dominio es el del dueño")
    func ownerWhenNoSecondary() {
        let owner = makeIsolatedDefaults(prefix: "sd.owner")
        #expect(SessionDefaults.resolve(owner: owner, isTestEnvironment: false) === owner)
    }

    @Test("con sesión secundaria, el dominio es el cajón de la visita")
    func suiteWhenSecondary() {
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.guest")
        SecondarySessionStore.activate(userID: userID, owner)
        defer { liveDestroy(userID) }

        let resolved = SessionDefaults.resolve(owner: owner, isTestEnvironment: false)
        #expect(resolved !== owner)
        // Y es EL cajón, no uno cualquiera: lo escrito por la puerta se lee por el nombre.
        resolved.set("Ana", forKey: "userName")
        let name = try! #require(SessionDefaults.suiteName(forUserID: userID))
        #expect(name == "yala.session.\(userID)")
        #expect(UserDefaults(suiteName: name)?.string(forKey: "userName") == "Ana")
        // Y el dueño NO se enteró.
        #expect(owner.string(forKey: "userName") == nil)
    }

    @Test("en entorno de test la puerta devuelve el dominio del dueño aunque haya descriptor")
    func testEnvironmentBypassesSuite() {
        // Ver la cabecera de `SessionDefaults`: bajo XCUITest el descriptor se planta en el dominio
        // VOLÁTIL, pero un suite persistiría en disco y ninguno de los dos anclajes del ciclo de vida
        // corre ahí (`SwiftDataConfiguration:811` y `:888`) ⇒ cajón huérfano que ninguna purga
        // alcanza. Es el precedente `groupsDomainSealedForFreshStart`.
        let owner = makeIsolatedDefaults(prefix: "sd.testenv")
        SecondarySessionStore.activate(userID: freshUserID("guest"), owner)
        #expect(SessionDefaults.resolve(owner: owner, isTestEnvironment: true) === owner)
    }

    @Test("un userID sin caracteres utilizables DEGRADA al dueño, no brickea")
    func unusableUserIDDegrades() {
        let owner = makeIsolatedDefaults(prefix: "sd.bad")
        // `activate` rechaza el vacío, así que el caso llega por un sub de solo símbolos.
        SecondarySessionStore.activate(userID: "///", owner)
        #expect(SessionDefaults.suiteName(forUserID: "///") == nil)
        #expect(SessionDefaults.resolve(owner: owner, isTestEnvironment: false) === owner)
    }

    @Test("en entorno de test la SIEMBRA y la DESTRUCCIÓN también son no-op")
    func testEnvironmentBypassesLifecycle() {
        // La excepción cubre las TRES operaciones. Sembrar mientras la puerta resuelve a `.standard`
        // deja en el disco del simulador un cajón que nadie lee y nadie destruye, con su sentinel
        // dentro sobreviviendo entre corridas — la misma basura, por la puerta de al lado.
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.lifecycle.testenv")
        owner.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        defer { liveDestroy(userID) }

        SessionDefaults.seedDeviceKeysIfNeeded(from: owner, forUserID: userID)
        let name = try! #require(SessionDefaults.suiteName(forUserID: userID))
        #expect(UserDefaults.standard.persistentDomain(forName: name) == nil)
        #expect(SessionDefaults.destroySuite(forUserID: userID) == false)
    }

    // MARK: Cláusula 1 — instancia cacheada

    @Test("dos resoluciones del mismo cajón devuelven LA MISMA instancia")
    func suiteInstanceIsCached() {
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.cache")
        SecondarySessionStore.activate(userID: userID, owner)
        defer { liveDestroy(userID) }

        let a = SessionDefaults.resolve(owner: owner, isTestEnvironment: false)
        let b = SessionDefaults.resolve(owner: owner, isTestEnvironment: false)
        #expect(a === b)
    }

    @Test("un observer con `object:` sobre el cajón VE las escrituras de la puerta")
    func cachedInstanceKeepsObserversAlive() async {
        // La prueba que un source-scan no puede ver, y el porqué de la cláusula 1:
        // `NotificationCenter.addObserver(object:)` filtra por IDENTIDAD del emisor. Con la puerta
        // construyendo el suite inline, este observer no dispararía nunca y `AppPreferences`
        // (`:894` registra con `object: defaults`) se quedaría sin recargar en silencio durante toda
        // la sesión secundaria.
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.observer")
        SecondarySessionStore.activate(userID: userID, owner)
        defer { liveDestroy(userID) }

        // El handle se RETIENE en una `let` a propósito, y sin eso este test no es un pin:
        // `addObserver(forName:object:queue:)` NO retiene su `object`, así que con la puerta
        // construyendo suites inline la primera instancia se desaloja al instante y la segunda puede
        // aterrizar en la MISMA dirección ⇒ el filtro por identidad casa por accidente y el mutante
        // pasa en verde. Medido con sonda: con las dos instancias vivas, un observer sobre A NO ve
        // la escritura de B (y el control positivo, A→A, sí dispara).
        let observedStore = SessionDefaults.resolve(owner: owner, isTestEnvironment: false)
        let observed = Fired()
        let token = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: observedStore,
            queue: nil) { _ in observed.fire() }
        defer { NotificationCenter.default.removeObserver(token) }

        SessionDefaults.resolve(owner: owner, isTestEnvironment: false).set("Ana", forKey: "userName")
        // La notificación se entrega en el runloop; un tick basta.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(observed.value)
    }

    // MARK: Cláusula 2 — resolución POR LLAMADA

    @Test("activar el descriptor con el proceso vivo cambia el dominio en la SIGUIENTE llamada")
    func resolutionHappensPerCall() {
        // La ventana de entrada: `SecondaryEntryLogic.begin` activa el descriptor con el proceso del
        // DUEÑO todavía vivo (`WelcomeCloudSignInView:801-805`) y el relanzamiento llega después
        // (`:812`). En esos segundos se escribe el consentimiento RGPD de la invitada (`:810`). Con
        // la resolución capturada en un `let`, ese registro caería en el cajón del dueño.
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.percall")
        defer { liveDestroy(userID) }

        #expect(SessionDefaults.resolve(owner: owner, isTestEnvironment: false) === owner)
        SecondarySessionStore.activate(userID: userID, owner)
        #expect(SessionDefaults.resolve(owner: owner, isTestEnvironment: false) !== owner)
    }
}

/// Caja mutable para el observer (el closure no puede capturar un `var` local de forma segura).
private final class Fired: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func fire() { lock.lock(); fired = true; lock.unlock() }
    var value: Bool { lock.lock(); defer { lock.unlock() }; return fired }
}

// MARK: - Ciclo de vida · ENTRADA (siembra)

@Suite("SessionDefaults · siembra de la entrada", .serialized)
struct SessionDefaultsSeedTests {

    @Test("la siembra copia el VALOR del dueño, no escribe `true` a ciegas")
    func seedCopiesOwnerValue() {
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.seed.value")
        owner.set(false, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        owner.set(true, forKey: "hasShownWelcomeChooser")

        withSessionSuite(userID) { _ in
            liveSeed(owner, userID)
            let name = SessionDefaults.suiteName(forUserID: userID)!
            let cajon = SessionDefaults.suite(named: name)!
            #expect(cajon.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) == false)
            #expect(cajon.bool(forKey: "hasShownWelcomeChooser") == true)
        }
    }

    @Test("la siembra es ADITIVA: no pisa lo que la ventana de entrada ya guardó")
    func seedIsAdditive() {
        // Entre que la visita confirma y que el proceso muere, su sesión ya está activa y se escribe
        // su registro de consentimiento. Un borrar-y-reescribir aquí lo perdería.
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.seed.additive")
        owner.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)

        withSessionSuite(userID) { cajon in
            cajon.set("2026-08-13T00:00:00Z", forKey: "cloudConsentAcceptedAt")
            cajon.set(false, forKey: AppPreferences.Keys.hasCompletedOnboarding)

            liveSeed(owner, userID)

            #expect(cajon.string(forKey: "cloudConsentAcceptedAt") == "2026-08-13T00:00:00Z")
            // La key que la ventana ya escribió NO se sobrescribe con la del dueño.
            #expect(cajon.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) == false)
        }
    }

    @Test("el guard de idempotencia lee DEL CAJÓN, no del dueño")
    func seedSentinelLivesInTheSuite() {
        // Si el guard leyera `.standard` —donde el dueño tiene el flag a `true`— concluiría «ya
        // sembrado» y el cajón no se sembraría NUNCA: el brick del Welcome pasaría de raro a normal.
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.seed.sentinel")
        owner.set(true, forKey: SessionDefaults.seedSentinelKey)
        owner.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)

        withSessionSuite(userID) { cajon in
            liveSeed(owner, userID)
            #expect(cajon.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) == true)
            #expect(cajon.bool(forKey: SessionDefaults.seedSentinelKey) == true)
        }
    }

    @Test("sembrar dos veces no re-escribe: el sentinel corta")
    func seedIsIdempotent() {
        let userID = freshUserID("guest")
        let owner = makeIsolatedDefaults(prefix: "sd.seed.twice")
        owner.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)

        withSessionSuite(userID) { cajon in
            liveSeed(owner, userID)
            cajon.set(false, forKey: AppPreferences.Keys.hasCompletedOnboarding)
            liveSeed(owner, userID)
            #expect(cajon.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) == false)
        }
    }

    @Test("el hook de ENTRADA siembra el cajón de la visita")
    func entryHookSeedsTheSuite() {
        let userID = freshUserID("guest")
        let defaults = makeIsolatedDefaults(prefix: "sd.seed.hook")
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        SecondarySessionStore.activate(userID: userID, defaults)
        defer { liveDestroy(userID) }

        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults, purge: {}, cancelNotifications: {}, seedSessionDomain: liveSeed)

        let name = try! #require(SessionDefaults.suiteName(forUserID: userID))
        let cajon = try! #require(SessionDefaults.suite(named: name))
        #expect(cajon.bool(forKey: SessionDefaults.seedSentinelKey) == true)
        #expect(cajon.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) == true)
        #expect(cajon.bool(forKey: "hasShownWelcomeChooser") == true)
    }

    @Test("la siembra NO se cuelga de `entryPurgeDone`")
    func seedRunsEvenAfterEntryPurgeMark() {
        // D3: con el cajón, la siembra deja de ser kill-recovery y pasa a ser camino normal. Si
        // colgara del marker one-shot, un kill entre la purga y la siembra dejaría el cajón vacío
        // para siempre.
        let userID = freshUserID("guest")
        let defaults = makeIsolatedDefaults(prefix: "sd.seed.afterpurge")
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        SecondarySessionStore.activate(userID: userID, defaults)
        SecondarySessionStore.markEntryPurgeDone(defaults)
        defer { liveDestroy(userID) }

        var purged = false
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults, purge: { purged = true }, cancelNotifications: {},
            seedSessionDomain: liveSeed)

        #expect(purged == false)   // el one-shot sigue siendo one-shot
        let cajon = SessionDefaults.suite(named: SessionDefaults.suiteName(forUserID: userID)!)!
        #expect(cajon.bool(forKey: SessionDefaults.seedSentinelKey) == true)
    }
}

// MARK: - Ciclo de vida · SALIDA (destrucción)

@Suite("SessionDefaults · destrucción de la salida", .serialized)
struct SessionDefaultsDestroyTests {

    private func armedDefaults(prefix: String, userID: String) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: prefix)
        SecondarySessionStore.activate(userID: userID, defaults)
        SecondarySessionStore.markEntryPurgeDone(defaults)
        SecondarySessionStore.armWipe(defaults)
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        return defaults
    }

    @Test("el wipe de SALIDA destruye el cajón de la visita")
    func wipeDestroysTheSuite() {
        let userID = freshUserID("guest")
        let defaults = armedDefaults(prefix: "sd.destroy", userID: userID)
        let name = try! #require(SessionDefaults.suiteName(forUserID: userID))
        SessionDefaults.suite(named: name)!.set("Ana", forKey: "userName")
        #expect(UserDefaults.standard.persistentDomain(forName: name)?["userName"] != nil)

        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true }, purge: {},
            destroySessionDomain: liveDestroy)

        // Aserción gemela: sin ella la prueba pasa en verde con la destrucción rota.
        let domain = UserDefaults.standard.persistentDomain(forName: name)
        #expect(domain == nil || domain?.isEmpty == true)
        #expect(UserDefaults(suiteName: name)?.string(forKey: "userName") == nil)
    }

    @Test("el wipe NO deja el cajón huérfano aunque `clear` se lleve el descriptor")
    func suiteIsDestroyedBeforeDescriptorIsCleared() {
        // `SecondarySessionStore.clear` está a una línea de la destrucción y borra el `userIDKey`:
        // después de él ya no hay `sub` con el que componer el nombre. Este test es el pin del ORDEN.
        let userID = freshUserID("guest")
        let defaults = armedDefaults(prefix: "sd.order", userID: userID)
        let name = try! #require(SessionDefaults.suiteName(forUserID: userID))
        SessionDefaults.suite(named: name)!.set("Ana", forKey: "userName")

        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true }, purge: {},
            destroySessionDomain: liveDestroy)

        #expect(SecondarySessionStore.activeUserID(defaults) == nil)   // el descriptor SÍ se limpió
        #expect(UserDefaults(suiteName: name)?.string(forKey: "userName") == nil)
    }

    @Test("un wipe abortado NO destruye el cajón: el reintento todavía lo necesita")
    func abortedWipeKeepsTheSuite() {
        let userID = freshUserID("guest")
        let defaults = armedDefaults(prefix: "sd.abort", userID: userID)
        let name = try! #require(SessionDefaults.suiteName(forUserID: userID))
        SessionDefaults.suite(named: name)!.set("Ana", forKey: "userName")
        defer { liveDestroy(userID) }

        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in false }, purge: {},
            destroySessionDomain: liveDestroy)

        #expect(SecondarySessionStore.activeUserID(defaults) == userID)
        #expect(UserDefaults(suiteName: name)?.string(forKey: "userName") == "Ana")
    }

    @Test("el wipe NO toca el dominio del dueño")
    func wipeLeavesOwnerDomainAlone() {
        // La variante peor de este fix: resolver la puerta en el punto de destrucción y llamar
        // `removePersistentDomain` sobre lo que devuelva borraría el `UserDefaults` ENTERO del dueño.
        let userID = freshUserID("guest")
        let defaults = armedDefaults(prefix: "sd.ownersafe", userID: userID)
        defaults.set("Jur", forKey: "userName")
        defaults.set("PEN", forKey: "defaultCurrencyCode")

        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true }, purge: {},
            destroySessionDomain: liveDestroy)

        #expect(defaults.string(forKey: "userName") == "Jur")
        #expect(defaults.string(forKey: "defaultCurrencyCode") == "PEN")
    }

    @Test("sin `sub` utilizable, la destrucción falla CERRADA y no toca nada")
    func destroyFailsClosedWithoutUsableID() {
        #expect(SessionDefaults.destroySuite(forUserID: "///", isTestEnvironment: false) == false)
        #expect(SessionDefaults.destroySuite(forUserID: "", isTestEnvironment: false) == false)
    }

    @Test("destruir suelta también la instancia cacheada")
    func destroyForgetsTheCachedInstance() {
        let userID = freshUserID("guest")
        let name = try! #require(SessionDefaults.suiteName(forUserID: userID))
        let before = try! #require(SessionDefaults.suite(named: name))
        liveDestroy(userID)
        let after = try! #require(SessionDefaults.suite(named: name))
        defer { liveDestroy(userID) }
        #expect(before !== after)
    }
}
