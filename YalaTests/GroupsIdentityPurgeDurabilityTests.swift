//
//  GroupsIdentityPurgeDurabilityTests.swift
//  YalaTests
//
//  La purga de un cambio de Apple ID NO se puede perder — ni cuando llega en la ventana export-only, ni
//  cuando el proceso muere antes de la promoción.
//
//  El defecto que estas celdas cierran: `performAccountSwitchCleanup` tiene tres mitades con gates
//  distintos. `clearAllLocalGroupData()` se AUTO-DIFIERE (un `save()` sobre el `mainContext` compartido
//  mientras el store personal se importa a medias es el crash-loop de restore, builds 29-32), pero
//  `resetLocalGroupsSyncState()` corría igual y se llevaba por delante la identidad iCloud cacheada.
//  Resultado: filas VIVAS + credenciales de re-join intactas + la ÚNICA evidencia del cambio de Apple ID
//  destruida. Y el diferido vivía en un `private var` en memoria drenado solo por `enableAutoSync()`: si el
//  usuario (o iOS) mataba la app antes de la promoción, la purga no ocurría JAMÁS — el evento de cuenta del
//  OS llega una sola vez y nadie lo re-entrega, a diferencia de los eventos de CloudKit que CKSyncEngine sí
//  re-entrega desde su cola persistida.
//
//  Por qué se ejercita el singleton REAL y no una extracción: sin `initialize()`, `SplitSyncManager.shared`
//  no tiene container ni engines (`recreateEnginesAfterIdentityChange` hace early-return) y `autoSyncActive`
//  es `false` — o sea, la ventana export-only exacta, sin una sola llamada a CloudKit. Testear una copia de
//  la secuencia dejaría el cableado real sin cubrir, que es justo donde vivía el bug.
//
//  Serializado: toca `SplitSyncManager.shared`, `GroupUserIdentityService.shared` y ≥2 `makeTestContext()`.
//  Deja el `modelContext` del manager apuntando al contexto in-memory de la suite (no hay getter que
//  permita restaurarlo); es inocuo porque ninguna otra suite ejercita el manager, y en la app real
//  `AppBootstrapper.setContext` lo re-establece en cada arranque.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Purga de identidad · durable y sin romper el par", .serialized)
struct GroupsIdentityPurgeDurabilityTests {

    private let appleIDviejo = "_appleIDviejo"

    // MARK: - Fixtures

    /// Aísla TODO lo que la secuencia toca fuera de SwiftData y devuelve el cleanup.
    /// Nunca `UserDefaults.standard`: el host de los unit tests es la propia app, así que un intent escrito
    /// ahí sobreviviría a la corrida y contaminaría al simulador (la trampa que ya costó 14 tests del
    /// bridge en rojo, ver `HandoverGroupsDomainTests`).
    private func makeIsolatedIdentityWorld() -> () -> Void {
        let previousIntent = GroupsIdentityPurgeIntent.defaults
        let previousJoin = PendingJoinStore.defaults
        let previousCache = GroupUserIdentityService.shared.cachedRecordName

        GroupsIdentityPurgeIntent.defaults = makeIsolatedDefaults(prefix: "identitypurge")
        PendingJoinStore.defaults = makeIsolatedDefaults(prefix: "identitypurge.join")
        GroupICloudIdentitySeed.defaults = makeIsolatedDefaults(prefix: "identitypurge.seed")
        // Siembra la identidad del Apple ID que se va por el camino REAL (cache in-memory + persistido).
        GroupICloudIdentitySeed.adopt(appleIDviejo)

        return {
            GroupsIdentityPurgeIntent.defaults = previousIntent
            PendingJoinStore.defaults = previousJoin
            GroupICloudIdentitySeed._testReset()
            GroupUserIdentityService.shared._testSetCachedRecordName(previousCache)
            SplitSyncManager.shared._testForgetInMemoryDeferredPurge()
        }
    }

    private func makeContext() throws -> ModelContext {
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        return try makeTestContext()
    }

    /// Grupo del canal CloudKit PURO con un hijo de cada tipo. Su destino es `.deleteLocalRows` **haya o no
    /// sesión de nube** (`GroupsIdentityPurgeGate.decideForZone`), así que el caso es determinista sin poder
    /// inyectar `CloudAuthService.shared.hasSession` en este camino.
    @discardableResult
    private func seedCloudKitGroup(in context: ModelContext, name: String = "Piso") throws -> SplitGroup {
        let group = SplitGroup(name: name)
        group.isOwner = true
        context.insert(group)
        let zone = group.cloudKitZoneID

        let member = SplitMember(groupZoneID: zone, displayName: "Jür")
        member.isCurrentUser = true
        member.cloudKitUserRecordID = appleIDviejo
        context.insert(member)
        let expense = SplitExpense(
            groupZoneID: zone, amount: 40, expenseDescription: "Luz",
            paidByMemberID: member.id.uuidString)
        context.insert(expense)
        try context.save()
        return group
    }

    /// Copia CONGELADA de un grupo migrado, con su credencial portadora viva. Molde
    /// `GroupsIdentityPurgeGateTests` / `GroupBackendInviteEntryHandlerLegacyKeyTests`.
    @discardableResult
    private func seedFrozenBackendGroup(in context: ModelContext, name: String = "Viaje") throws -> SplitGroup {
        let group = SplitGroup(name: name)
        group.movedToBackendAt = Date(timeIntervalSince1970: 1_800_000_000)
        group.backendReInviteToken = "tok"
        context.insert(group)
        try context.save()
        return group
    }

    private func groupCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<SplitGroup>())
    }

    // MARK: - El par no se rompe mientras la purga está diferida

    @Test("Diferir la purga NO puede borrar la identidad cacheada: es la única evidencia del cambio")
    func deferredPurge_keepsTheIdentityEvidenceAlive() throws {
        let cleanup = makeIsolatedIdentityWorld()
        defer { cleanup() }
        let context = try makeContext()
        try seedCloudKitGroup(in: context)
        SplitSyncManager.shared.setContext(context)

        SplitSyncManager.shared.performAccountSwitchCleanup()

        // Precondición del escenario: sin `initialize()` el manager está en ventana export-only, así que la
        // purga se difirió. Si esto falla, el resto del test no está midiendo lo que cree.
        #expect(try groupCount(context) == 1, "El diferido tiene que seguir difiriendo — el crash-loop de restore no se negocia.")

        #expect(GroupUserIdentityService.shared.cachedRecordName == appleIDviejo,
                """
                Se borró la identidad del Apple ID anterior con sus filas todavía vivas. Es la mitad del par \
                C-3 que empareja «filas retenidas» con «credenciales revocadas», y además la ÚNICA evidencia \
                que le queda al dispositivo del cambio de cuenta.
                """)
        #expect(GroupICloudIdentitySeed.persistedRecordName == appleIDviejo,
                """
                Lo persistido es la mitad que sobrevive al proceso: es lo que `runIdentityBootGuard` compara \
                en el arranque siguiente. Borrado aquí, el próximo boot hace early-return («cache limpio: \
                nada que comparar») o ve `cached == fresh` tras el re-seed ⇒ el cambio de Apple ID se vuelve \
                indetectable PARA SIEMPRE por esa vía.
                """)
    }

    @Test("Diferir la purga ARMA un intent que sobrevive al proceso")
    func deferredPurge_armsADurableIntent() throws {
        let cleanup = makeIsolatedIdentityWorld()
        defer { cleanup() }
        let context = try makeContext()
        try seedCloudKitGroup(in: context)
        SplitSyncManager.shared.setContext(context)

        SplitSyncManager.shared.performAccountSwitchCleanup()

        #expect(GroupsIdentityPurgeIntent.isArmed,
                """
                La purga quedó anotada SOLO en memoria. El evento de cuenta del OS llega una vez y nadie lo \
                re-entrega (no es un evento de CloudKit): matar la app antes de la promoción la perdía para \
                siempre, y el humano nuevo se quedaba con los grupos del anterior.
                """)
        #expect(GroupsIdentityPurgeIntent.armedAt != nil)
    }

    // MARK: - Un proceso NUEVO la recupera

    @Test("Proceso nuevo sin promoción: el retome del boot ejecuta la purga que se difirió")
    func newProcess_resumesTheDeferredPurge() throws {
        let cleanup = makeIsolatedIdentityWorld()
        defer { cleanup() }
        let context = try makeContext()
        try seedCloudKitGroup(in: context)
        try seedFrozenBackendGroup(in: context)
        SplitSyncManager.shared.setContext(context)

        // 1. El evento del OS llega en la ventana export-only → se difiere.
        SplitSyncManager.shared.performAccountSwitchCleanup()
        #expect(try groupCount(context) == 2)

        // 2. «Proceso nuevo»: lo único que puede cruzar un reinicio es lo persistido. Se olvida el camino
        //    rápido en memoria y NO se promueve a auto-sync — el escenario exacto del bug.
        SplitSyncManager.shared._testForgetInMemoryDeferredPurge()
        #expect(!SplitSyncManager.shared.autoSyncActive, "El retome no puede depender de la promoción.")

        // 3. El arranque siguiente, tras la quiescencia del import personal (lo que prueba
        //    `awaitPersonalStoreReady` en el paso 16.4.4 del bootstrapper).
        SplitSyncManager.shared.resumeDeferredIdentityPurgeIfNeeded()

        #expect(try context.fetchCount(
            FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.movedToBackendAt == nil })) == 0,
                """
                Las filas del canal CloudKit del Apple ID anterior siguen en el dispositivo del humano nuevo. \
                Es la fuga de privacidad del commit 31dded30, reabierta por el diferido no durable.
                """)
        #expect(try context.fetchCount(FetchDescriptor<SplitMember>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0)

        // La zona del canal BACKEND se retiene o se borra según haya sesión de nube viva (D4), pero en
        // NINGUNA de las dos ramas puede sobrevivir con sus credenciales de re-join: con una sola viva, el
        // humano nuevo entra COMO el anterior, con permiso de editar y borrar.
        let survivors = try context.fetch(FetchDescriptor<SplitGroup>())
        #expect(survivors.allSatisfy { $0.backendReInviteToken == nil && $0.rejoinRevokedAt != nil },
                """
                Quedó una copia congelada con su credencial portadora intacta. `rejoinRevokedAt` es lo que \
                hace la revocación DURABLE: sin ella `CKRecordTranslator.update` re-hidrata el token en el \
                siguiente fetch, y el reset de los change tokens GARANTIZA ese fetch.
                """)

        #expect(GroupUserIdentityService.shared.cachedRecordName == nil,
                "Purgadas las filas, la identidad del Apple ID que se fue se olvida con ellas.")
        #expect(GroupICloudIdentitySeed.persistedRecordName == nil)
        #expect(!GroupsIdentityPurgeIntent.isArmed,
                "El intent solo se desarma cuando la purga se completó de verdad; aquí ya está hecha.")
    }

    @Test("El retome es no-op cuando no hay nada armado (el 99,99 % de los arranques)")
    func resume_isNoOp_withoutAnArmedIntent() throws {
        let cleanup = makeIsolatedIdentityWorld()
        defer { cleanup() }
        let context = try makeContext()
        try seedCloudKitGroup(in: context)
        SplitSyncManager.shared.setContext(context)

        SplitSyncManager.shared.resumeDeferredIdentityPurgeIfNeeded()

        #expect(try groupCount(context) == 1, "Un arranque normal no puede borrar los grupos de nadie.")
        #expect(GroupUserIdentityService.shared.cachedRecordName == appleIDviejo)
    }

    // MARK: - El intent en sí

    @Test("El intent no caduca: caducar significaría no purgar")
    func intent_neverExpires_andKeepsItsOriginalStamp() {
        let cleanup = makeIsolatedIdentityWorld()
        defer { cleanup() }
        let armed = Date(timeIntervalSince1970: 1_700_000_000)

        GroupsIdentityPurgeIntent.arm(at: armed)
        #expect(GroupsIdentityPurgeIntent.armedAt == armed)

        // Re-armar (otro evento de cuenta, u otro arranque que vuelve a diferir) conserva el sello
        // original: el dato accionable es desde cuándo se arrastra la purga.
        GroupsIdentityPurgeIntent.arm(at: armed.addingTimeInterval(86_400 * 30))
        #expect(GroupsIdentityPurgeIntent.armedAt == armed)
        #expect(GroupsIdentityPurgeIntent.isArmed,
                "30 días después sigue armado: no hay TTL, porque caducar el intent es dejar los datos del anterior.")

        GroupsIdentityPurgeIntent.disarm()
        #expect(!GroupsIdentityPurgeIntent.isArmed)
        #expect(GroupsIdentityPurgeIntent.armedAt == nil)
    }

    // MARK: - Lo que no puede cambiar del handover

    @Test("El handover «empiezo de cero» sigue olvidando la identidad: su default no cambia")
    func handoverPath_stillClearsTheIdentityCache() {
        let cleanup = makeIsolatedIdentityWorld()
        defer { cleanup() }

        // El camino de `DataWipeService.wipeLocalGroupsDomain` llama sin argumento: ahí el relevo es
        // declarado, el dominio se borra entero en el acto y no hay purga diferida con la que emparejarse.
        SplitSyncManager.shared.resetLocalGroupsSyncState()

        #expect(GroupUserIdentityService.shared.cachedRecordName == nil)
        #expect(GroupICloudIdentitySeed.persistedRecordName == nil)
    }
}
