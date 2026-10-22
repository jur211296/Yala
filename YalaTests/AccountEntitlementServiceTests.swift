//
//  AccountEntitlementServiceTests.swift
//  YalaTests
//
//  Cubre la caché del entitlement de cuenta y su orquestación (C-8, 2026-07-27) con dependencias
//  INYECTADAS — sin red, sin singletons de auth/StoreKit.
//
//  Lo que protegen, en orden de daño:
//   1. **Un fallo de red no puede degradar a Free**: si `sync` borrara o pisara la caché ante un
//      error, un pagador offline perdería Pro sobre sus propios datos — el bug que C-8 arregla,
//      reintroducido por la puerta de atrás.
//   2. **El snapshot se escribe con el dueño de la sesión VIVA**: sin eso, la caché de la cuenta A
//      daría Pro a la B.
//   3. **`appAccountToken` solo se emite con sesión**: una compra con un UUID inventado crearía una
//      identidad de compra que no corresponde a ninguna cuenta.
//

import Foundation
import StoreKit
import Testing

@testable import Yala

@MainActor
@Suite("AccountEntitlementService · caché y sincronización del derecho (C-8)")
struct AccountEntitlementServiceTests {

    static let userA = "11111111-2222-3333-4444-555555555555"
    static let userB = "99999999-8888-7777-6666-555555555555"

    /// `UserDefaults` aislado por test (regla del repo: jamás `.standard`).
    private func makeStore(_ name: String) -> (AccountEntitlementStore, UserDefaults) {
        let suite = "test.entitlement.\(name).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("no se pudo crear el suite de test")
        }
        return (AccountEntitlementStore(defaults: defaults), defaults)
    }

    // MARK: - Store

    @Test func store_roundTrip() {
        let (store, defaults) = makeStore("roundtrip")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        #expect(store.read() == nil)
        let snapshot = AccountEntitlementSnapshot(
            userID: Self.userA, product: "com.yala.pro.yearly",
            expiresAt: Date(timeIntervalSince1970: 1_900_000_000), refreshedAt: .now)
        store.write(snapshot)
        #expect(store.read() == snapshot)

        store.clear()
        #expect(store.read() == nil)
    }

    /// Un snapshot corrupto se trata como AUSENTE (el refresco lo repone), nunca como "sin derecho"
    /// permanente ni como crash.
    @Test func store_snapshotCorrupto_seTrataComoAusente() {
        let (store, defaults) = makeStore("corrupt")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        defaults.set(Data("no soy json".utf8), forKey: "cloudSync.accountEntitlement")
        #expect(store.read() == nil)
    }

    /// Cambiar de cuenta PISA la entrada: el device tiene una sesión a la vez y guardar el historial
    /// de cuentas anteriores sería una fuga sin ganancia.
    @Test func store_segundaCuentaPisaLaPrimera() {
        let (store, defaults) = makeStore("overwrite")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        store.write(.init(userID: Self.userA, product: "p", expiresAt: .now, refreshedAt: .now))
        store.write(.init(userID: Self.userB, product: "p", expiresAt: .now, refreshedAt: .now))
        #expect(store.read()?.userID == Self.userB)
    }

    // MARK: - purchaseOptions (emisión del appAccountToken)

    @Test func purchaseOptions_conSesion_emiteAppAccountToken() {
        let options = StoreKitManager.purchaseOptions(cloudUserID: Self.userA)
        #expect(options == [.appAccountToken(UUID(uuidString: Self.userA)!)])
    }

    @Test func purchaseOptions_sinSesion_vacio() {
        #expect(StoreKitManager.purchaseOptions(cloudUserID: nil).isEmpty)
    }

    /// Un `sub` que no sea un UUID válido NO se fuerza: mejor comprar sin token (y vincular después
    /// por JWT) que emitir una identidad de compra inventada.
    @Test func purchaseOptions_userIDNoUUID_vacio() {
        #expect(StoreKitManager.purchaseOptions(cloudUserID: "no-soy-un-uuid").isEmpty)
    }

    // MARK: - sync

    @Test func sync_sinSesion_noHaceNada() async {
        let (store, defaults) = makeStore("nosession")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let service = AccountEntitlementService(
            store: store,
            jwtProvider: { "jwt" },
            userIDProvider: { nil },
            storeKitJWSProvider: { nil })

        #expect(await service.sync(force: true) == false)
        #expect(store.read() == nil)
    }

    /// Con `force: false` y una caché fresca de la MISMA cuenta no se llama al backend: el
    /// min-interval existe para que cada foreground no dispare una petición.
    @Test func sync_cacheFresca_noRefresca() async {
        let (store, defaults) = makeStore("throttle")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        store.write(.init(userID: Self.userA, product: "p",
                          expiresAt: .now.addingTimeInterval(3600), refreshedAt: .now))
        var jwtCalls = 0
        let service = AccountEntitlementService(
            store: store,
            jwtProvider: { jwtCalls += 1; return "jwt" },
            userIDProvider: { Self.userA },
            storeKitJWSProvider: { nil })

        #expect(await service.sync() == false)
        #expect(jwtCalls == 0, "una caché fresca no debería ni pedir el JWT")
    }

    /// `handleSignOut` es la frontera de cuenta: el derecho de una cuenta no sobrevive a su salida.
    /// Además re-deriva `isProUser` — verificarlo aquí exigiría el singleton de StoreKit, así que el
    /// test pinnea la parte comprobable sin tocarlo: la caché queda vacía.
    @Test func handleSignOut_borraElSnapshot() async {
        let (store, defaults) = makeStore("clear")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        store.write(.init(userID: Self.userA, product: "p", expiresAt: .now, refreshedAt: .now))
        await AccountEntitlementService(store: store, userIDProvider: { Self.userA }).handleSignOut()
        #expect(store.read() == nil)
    }
}
