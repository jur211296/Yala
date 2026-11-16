//
//  SignOutPreferenceHoldTests.swift
//  YalaTests
//
//  Card ij0i (2026-11-05): tras cerrar la sesión, el iCloud-KV del Apple ID no se aplica hasta que alguien restaure o
//  termine un onboarding (decisión A de Jürgen del 2026-10-08; en los tres cierres, decisión del bot).
//

import Foundation
import Testing
@testable import Yala

@Suite("Cierre de sesión · el iCloud-KV del dueño queda retenido")
struct SignOutPreferenceHoldTests {

    @Test("armar, leer y soltar; soltar dice si había algo que soltar")
    func armAndRelease() {
        let defaults = makeIsolatedDefaults(prefix: "SignOutPreferenceHoldTests.marca")
        #expect(!SignOutPreferenceHold.isArmed(defaults))
        #expect(!SignOutPreferenceHold.release(defaults), "sin retención, soltar no aplica nada")
        SignOutPreferenceHold.arm(defaults)
        #expect(SignOutPreferenceHold.isArmed(defaults))
        #expect(SignOutPreferenceHold.release(defaults))
        #expect(!SignOutPreferenceHold.isArmed(defaults))
    }

    @Test("la clave vive bajo `cloudSync.`, que el barrido de preferencias del cierre no toca")
    func keySurvivesTheSignOutPreferenceSweep() {
        #expect(SignOutPreferenceHold.key.hasPrefix("cloudSync."))
    }

    @Test("el borrado del cierre la arma, en `.cloud` y en `.icloud`")
    func signOutWipeArmsIt() {
        for mode in [StorageMode.cloud, .icloud] {
            let defaults = makeIsolatedDefaults(prefix: "SignOutPreferenceHoldTests.cierre.\(mode)")
            StorageModePersistence.write(mode, defaults: defaults)
            if mode == .cloud { defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey) }
            StorageModePersistence.armSignOutWipe(defaults)
            SwiftDataConfiguration.performSignOutWipeIfArmed(
                defaults: defaults,
                deleteFiles: { _, _ in true },
                resetPrefs: {},
                cancelNotifications: {})
            #expect(SignOutPreferenceHold.isArmed(defaults), "\(mode)")
        }
    }

    @Test("control: sin cierre armado, el hook no la arma")
    func noSignOut_noHold() {
        let defaults = makeIsolatedDefaults(prefix: "SignOutPreferenceHoldTests.sinCierre")
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true }, resetPrefs: {}, cancelNotifications: {})
        #expect(!SignOutPreferenceHold.isArmed(defaults))
    }

    @Test("si el borrado del archivo falla, el cierre no ocurrió y no hay retención")
    func abortedWipe_noHold() {
        let defaults = makeIsolatedDefaults(prefix: "SignOutPreferenceHoldTests.abort")
        StorageModePersistence.write(.icloud, defaults: defaults)
        StorageModePersistence.armSignOutWipe(defaults)
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in false }, resetPrefs: {}, cancelNotifications: {})
        #expect(!SignOutPreferenceHold.isArmed(defaults))
    }
}

/// El cableado: quién mira la retención y quién la suelta. Los caminos son métodos del singleton sobre
/// `UserDefaults.standard` y el iCloud-KV real, así que se fija por el código.
@Suite("Cierre de sesión · la retención del iCloud-KV, cableado")
struct SignOutPreferenceHoldWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// El código en una línea, sin comentarios.
    private static func normalized(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
            .joined(separator: " ")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    @Test("los DOS sitios que aplican el iCloud-KV en `.icloud` miran antes la retención")
    func bothAppliersAreHeld() throws {
        let service = try Self.normalized("Yala/App/Services/PreferenceSyncService.swift")
        #expect(service.contains("case .icloudKeyValue: iKV.synchronize() if !holdsAppleIDPreferences() { applyRemoteValues() }"),
                "el arranque vuelve a aplicar las preferencias del dueño a quien entra tras un cierre")
        #expect(service.contains("case .icloudKeyValue: if !self.holdsAppleIDPreferences() { self.applyRemoteValues() } self.checkForRemoteWipeSignal()"),
                "un cambio externo del KV las aplica igual con la retención puesta; y la señal de vaciado tiene que seguir leyéndose")
        // `applyRemoteValues()` se llama en exactamente esos dos sitios y en la suelta de Restaurar.
        #expect(Self.count("applyRemoteValues()", in: service) == 4, "declaración + tres llamadas: un aplicador nuevo mira la retención")
    }

    @Test("con el onboarding ya hecho, la retención se suelta sola: ninguna sesión la arrastra para siempre")
    func completedOnboardingReleasesTheHold() throws {
        let service = try Self.normalized("Yala/App/Services/PreferenceSyncService.swift")
        #expect(service.contains("""
            private func holdsAppleIDPreferences() -> Bool { guard SignOutPreferenceHold.isArmed(local) else { return false } \
            guard !local.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) else { SignOutPreferenceHold.release(local) \
            return false } return true }
            """), "un adopt que sale antes de arrancar en la nube dejaría la sesión sin recibir lo de sus otros dispositivos")
    }

    @Test("se suelta al terminar un onboarding, en la nube, al nacer la sesión privada y al abrir Restaurar")
    func releasePoints() throws {
        let service = try Self.normalized("Yala/App/Services/PreferenceSyncService.swift")
        #expect(service.contains("func signalOnboardingCompleted() { SignOutPreferenceHold.release(local)"))
        #expect(service.contains("case .cloudOutbox: SignOutPreferenceHold.release(local)"))
        #expect(service.contains("func releaseSignOutPreferenceHoldForRestore() { guard SignOutPreferenceHold.release(local), behavior == .icloudKeyValue else { return } iKV.synchronize() applyRemoteValues() }"))

        let content = try Self.normalized("Yala/App/ContentView.swift")
        #expect(content.contains(") .onAppear { PreferenceSyncService.shared.releaseSignOutPreferenceHoldForRestore() } .environment(SessionState.shared) }"),
                "Restaurar desde el Welcome resumiría sin el nombre del dueño y lo mandaría al onboarding")
        let activation = try Self.normalized("Yala/App/Views/Groups/FullModeActivationView.swift")
        #expect(activation.contains("onBack: { backFromRestore() }) .onAppear { PreferenceSyncService.shared.releaseSignOutPreferenceHoldForRestore() }"))
        #expect(activation.contains("PrivateBirthKeyValueHandover.consumeIfArmed() SignOutPreferenceHold.release()"),
                "la sesión privada que nace de «Activar Yala completo» no recibiría nunca los cambios de sus otros dispositivos")
    }

    @Test("el hook del cierre la arma pegada al neutro, antes del barrido de preferencias")
    func armedByTheSignOutHook() throws {
        let config = try Self.normalized("Yala/Utils/SwiftDataConfiguration.swift")
        #expect(config.contains("StorageModePersistence.armNeutralMount(defaults) SignOutPreferenceHold.arm(defaults)"))
        #expect(Self.count("SignOutPreferenceHold.arm(", in: config) == 1)
    }
}
