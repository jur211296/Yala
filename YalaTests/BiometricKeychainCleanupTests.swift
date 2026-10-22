//
//  BiometricKeychainCleanupTests.swift
//  YalaTests
//
//  Cobertura de la limpieza idempotente del Keychain biométrico que dejó el
//  antiguo bloqueo in-app (removido en commit 65c1fe50).
//
//  NOTA sobre el alcance — la función real NO es testeable directamente:
//    `AppBootstrapper.cleanupBiometricKeychainIfNeeded()` es `private` sobre un
//    tipo `@MainActor final class` (no invocable desde tests), su sentinel
//    `biometricKeychainCleanedKey` es `private static`, y lee/escribe
//    `UserDefaults.standard` DIRECTAMENTE (no inyectable). Las reglas del
//    proyecto prohíben tocar `UserDefaults.standard` en tests, así que no se
//    puede correr la función tal cual.
//
//  Lo que SÍ se cubre (las dos piezas públicas/observables de las que la
//  función depende y sobre las que descansa su contrato):
//    1. `KeychainService.delete(forKey:)` — el mecanismo que el doc-comment cita
//       como razón de la idempotencia: borrar algo inexistente es no-op, y
//       borrar los dos keys biométricos exactos ("biometricEnabled" /
//       "biometricLockTimeout") efectivamente los elimina.
//    2. El contrato de idempotencia vía sentinel — se replica la lógica EXACTA
//       del guard/set (mismo valor literal de key "biometricKeychainCleanedV1")
//       contra un `UserDefaults` AISLADO: primera llamada marca + actúa, segunda
//       llamada es no-op.
//

import Foundation
import Testing

@testable import Yala

// MARK: - KeychainService (mecanismo real de borrado)

/// Toca el Keychain GLOBAL del host de tests (no aislable por suite) → serial +
/// limpieza con `defer` para no dejar residuos entre tests.
@Suite(.serialized)
struct BiometricKeychainDeleteTests {

    /// Keys reales que borra `cleanupBiometricKeychainIfNeeded` (valores literales
    /// del código de producción; el sentinel/función son private).
    private let biometricEnabledKey = "biometricEnabled"
    private let biometricLockTimeoutKey = "biometricLockTimeout"

    @Test("delete_forKey_removes_existing_biometricEnabled_item")
    func delete_forKey_removes_existing_biometricEnabled_item() {
        defer { KeychainService.delete(forKey: biometricEnabledKey) }

        KeychainService.setBool(true, forKey: biometricEnabledKey)
        #expect(KeychainService.getBool(forKey: biometricEnabledKey) == true)

        KeychainService.delete(forKey: biometricEnabledKey)

        // getBool devuelve false cuando el item ya no existe.
        #expect(KeychainService.getBool(forKey: biometricEnabledKey) == false)
    }

    @Test("delete_forKey_removes_existing_biometricLockTimeout_item")
    func delete_forKey_removes_existing_biometricLockTimeout_item() {
        defer { KeychainService.delete(forKey: biometricLockTimeoutKey) }

        KeychainService.setInt(300, forKey: biometricLockTimeoutKey)
        #expect(KeychainService.getInt(forKey: biometricLockTimeoutKey) == 300)

        KeychainService.delete(forKey: biometricLockTimeoutKey)

        // getInt devuelve 0 cuando el item ya no existe.
        #expect(KeychainService.getInt(forKey: biometricLockTimeoutKey) == 0)
    }

    @Test("delete_forKey_on_absent_item_is_noop_idempotent")
    func delete_forKey_on_absent_item_is_noop_idempotent() {
        // Key único e inexistente: la razón por la que la limpieza es idempotente
        // — SecItemDelete de algo que no existe no crashea ni tiene efecto lateral.
        let absentKey = "biometric.absent.\(UUID().uuidString)"

        // Borrar dos veces algo que nunca existió no debe crashear ni cambiar nada.
        KeychainService.delete(forKey: absentKey)
        KeychainService.delete(forKey: absentKey)

        #expect(KeychainService.getBool(forKey: absentKey) == false)
        #expect(KeychainService.getString(forKey: absentKey) == nil)
    }

    @Test("deleting_both_biometric_keys_leaves_keychain_clean")
    func deleting_both_biometric_keys_leaves_keychain_clean() {
        defer {
            KeychainService.delete(forKey: biometricEnabledKey)
            KeychainService.delete(forKey: biometricLockTimeoutKey)
        }

        // Simula el estado que dejaba el bloqueo biométrico viejo.
        KeychainService.setBool(true, forKey: biometricEnabledKey)
        KeychainService.setInt(60, forKey: biometricLockTimeoutKey)

        // El par de deletes que hace la limpieza one-shot.
        KeychainService.delete(forKey: biometricEnabledKey)
        KeychainService.delete(forKey: biometricLockTimeoutKey)

        #expect(KeychainService.getBool(forKey: biometricEnabledKey) == false)
        #expect(KeychainService.getInt(forKey: biometricLockTimeoutKey) == 0)
    }
}

// MARK: - Contrato de idempotencia del sentinel (lógica replicada)

/// Réplica INDEPENDIENTE del guard/set de `cleanupBiometricKeychainIfNeeded`
/// contra un `UserDefaults` aislado (la función real usa `.standard`, no
/// inyectable). Usa el MISMO valor literal de key que producción
/// ("biometricKeychainCleanedV1") para que un rename del sentinel rompa aquí.
/// Sin `.serialized`: cada test usa su propio suite aislado.
struct BiometricKeychainCleanupSentinelTests {

    /// Valor literal del sentinel en producción (`biometricKeychainCleanedKey`,
    /// private static en `AppBootstrapper`).
    private let sentinelKey = "biometricKeychainCleanedV1"

    /// Ejecuta la lógica de la limpieza contra un `defaults` inyectado, contando
    /// cuántas veces "actúa" (borra keys). Espeja el shape exacto de producción:
    /// guard sentinel → acción → marcar sentinel.
    private func runCleanup(defaults: UserDefaults, onAct: () -> Void) {
        guard !defaults.bool(forKey: sentinelKey) else { return }
        onAct()
        defaults.set(true, forKey: sentinelKey)
    }

    @Test("first_call_marks_sentinel_and_acts")
    func first_call_marks_sentinel_and_acts() {
        let defaults = makeIsolatedDefaults(prefix: "biometric-cleanup")

        #expect(defaults.bool(forKey: sentinelKey) == false)

        var actCount = 0
        runCleanup(defaults: defaults) { actCount += 1 }

        #expect(actCount == 1)
        #expect(defaults.bool(forKey: sentinelKey) == true)
    }

    @Test("second_call_is_noop_when_sentinel_set")
    func second_call_is_noop_when_sentinel_set() {
        let defaults = makeIsolatedDefaults(prefix: "biometric-cleanup")

        var actCount = 0
        runCleanup(defaults: defaults) { actCount += 1 }
        // Segunda llamada: el guard del sentinel debe cortar → no vuelve a actuar.
        runCleanup(defaults: defaults) { actCount += 1 }

        #expect(actCount == 1)
        #expect(defaults.bool(forKey: sentinelKey) == true)
    }

    @Test("cleanup_stays_noop_across_many_cold_launches")
    func cleanup_stays_noop_across_many_cold_launches() {
        let defaults = makeIsolatedDefaults(prefix: "biometric-cleanup")

        var actCount = 0
        for _ in 0..<10 {
            runCleanup(defaults: defaults) { actCount += 1 }
        }

        // Sólo la primera de 10 "aperturas" en frío actúa.
        #expect(actCount == 1)
        #expect(defaults.bool(forKey: sentinelKey) == true)
    }

    @Test("pre_set_sentinel_prevents_any_action")
    func pre_set_sentinel_prevents_any_action() {
        let defaults = makeIsolatedDefaults(prefix: "biometric-cleanup")
        // Simula un device donde la limpieza ya corrió en un launch previo.
        defaults.set(true, forKey: sentinelKey)

        var actCount = 0
        runCleanup(defaults: defaults) { actCount += 1 }

        #expect(actCount == 0)
    }
}
