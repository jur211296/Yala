//
//  CloudSyncFlagsEffectiveModeTests.swift
//  YalaTests / CloudSync
//
//  Modo de almacenamiento EFECTIVO (M1 Inc 3): el getter `CloudSyncFlags.storageMode` deriva
//  `.cloud` con el descriptor de sesión secundaria activo, sin tocar la key PERSISTIDA del dueño.
//  `.serialized` OBLIGATORIO: toca los overrides estáticos (storageMode + SecondarySessionStore),
//  siempre con `defer { restore }`. También el guard de mount-mismatch de `canRunDomain` — el
//  test que caza la VENTANA DE ENTRADA (descriptor activo + proceso con el store del dueño).
//

import Foundation
import Testing

@testable import Yala

@Suite("CloudSyncFlags · modo efectivo + guard de mount-mismatch (M1)", .serialized)
struct CloudSyncFlagsEffectiveModeTests {

    @Test func withoutDescriptor_readsPersisted() {
        SecondarySessionStore._testSetActiveOverride(false)
        defer { SecondarySessionStore._testSetActiveOverride(nil) }
        // Sin key persistida (default) → `.icloud`, exactamente como siempre.
        #expect(CloudSyncFlags.storageMode == .icloud)
    }

    @Test func withDescriptor_derivesCloud_withoutTouchingPersistedKey() {
        SecondarySessionStore._testSetActiveOverride(true)
        defer { SecondarySessionStore._testSetActiveOverride(nil) }
        #expect(CloudSyncFlags.storageMode == .cloud)
        // La key PERSISTIDA del dueño NO se escribió (el efectivo es derivado, no persistido).
        #expect(StorageModePersistence.read() == .icloud)
    }

    @Test func testOverride_winsOverDescriptor() {
        SecondarySessionStore._testSetActiveOverride(true)
        CloudSyncFlags.storageMode = .icloud
        defer {
            SecondarySessionStore._testSetActiveOverride(nil)
            CloudSyncFlags._testResetStorageModeOverride()
        }
        #expect(CloudSyncFlags.storageMode == .icloud)
    }

    @Test @MainActor func mountMismatch_blocksCanRunDomain() {
        // VENTANA DE ENTRADA (fix crítico del /review-plan): descriptor activo pero este proceso
        // NO montó el secundario (`secondaryStoreMounted` default false en tests = el caso del
        // proceso viejo con el store del DUEÑO montado) → el runtime del dominio JAMÁS arranca,
        // aunque el modo efectivo sea `.cloud` y la fase sea estable. Sin este guard, el drain
        // pushearía la History del dueño a la cuenta entrante.
        SecondarySessionStore._testSetActiveOverride(true)
        defer { SecondarySessionStore._testSetActiveOverride(nil) }
        #expect(SwiftDataConfiguration.secondaryStoreMounted == false)
        #expect(CloudSyncRuntime.canRunDomain() == false)
    }

    @Test @MainActor func withoutDescriptor_domainGateKeepsLegacyBehavior() {
        // Regresión del dueño: sin descriptor, `.icloud` efectivo → dominio bloqueado (P0 de hoy).
        SecondarySessionStore._testSetActiveOverride(false)
        defer { SecondarySessionStore._testSetActiveOverride(nil) }
        #expect(CloudSyncRuntime.canRunDomain() == false)
    }
}
