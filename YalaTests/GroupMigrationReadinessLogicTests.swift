//
//  GroupMigrationReadinessLogicTests.swift
//  YalaTests
//
//  C-10: el gate de EMISIÓN. Antes de estampar `movedToBackendAt` (que viaja por CloudKit y CONGELA el
//  grupo en el device de cada miembro), el owner comprueba que todos pueden volver a entrar.
//
//  Lo que protege: la AUSENCIA de beacon es fail-closed, y los builds ya publicados son ausentes por
//  definición — no llevan este código. Ese es el único mecanismo que los cubre sin que cooperen.
//
//  Pure-logic: sin SwiftData ni ModelContext.
//

import Foundation
import Testing

@testable import Yala

struct GroupMigrationReadinessLogicTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func member(
        key: String = "m1",
        isOwner: Bool = false,
        status: SplitMemberStatus = .active,
        hasRecordName: Bool = true,
        capability: String? = GroupCapability.rejoinV1,
        ageDays: Double? = 1
    ) -> MemberCapabilitySnapshot {
        MemberCapabilitySnapshot(
            memberKey: key,
            isGroupOwner: isOwner,
            status: status,
            hasRecordName: hasRecordName,
            capability: capability,
            capabilityAt: ageDays.map { now.addingTimeInterval(-$0 * 24 * 60 * 60) }
        )
    }

    // MARK: - Camino feliz y grupo de una sola persona

    @Test func decide_ready_whenAllMembersBeaconFresh() {
        let members = [member(key: "owner", isOwner: true, capability: nil, ageDays: nil),
                       member(key: "a"), member(key: "b")]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .ready)
    }

    @Test func decide_ready_whenOnlyOwner() {
        // Grupo de una sola persona: no hay a quién congelar, migra sin espera. El owner nunca se
        // cuenta a sí mismo (es quien está migrando).
        let members = [member(key: "owner", isOwner: true, capability: nil, ageDays: nil)]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .ready)
    }

    // MARK: - Lo que BLOQUEA

    @Test func decide_waiting_whenMemberHasNoBeacon() {
        // ESTE es el caso de todo binario ya publicado: no conoce el campo, nunca lo publica.
        let members = [member(key: "owner", isOwner: true, capability: nil, ageDays: nil),
                       member(key: "viejo", capability: nil, ageDays: nil)]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .waiting(pending: 1))
    }

    @Test func decide_waiting_whenBeaconTokenUnknown() {
        // Token de un build futuro con otra capacidad → no acredita. Fail-closed también hacia adelante,
        // y por PERTENENCIA A UN SET: nunca por comparación numérica (el historial de build numbers de
        // este repo no es monótono, un `<` heredaría ese rompe-umbral).
        let members = [member(key: "raro", capability: "rejoin.v99")]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .waiting(pending: 1))
    }

    @Test func decide_waiting_whenBeaconIsPausedToken() {
        // Binario capaz pero con el canal apagado para ESE device (kill remoto / bucket del rollout).
        // Publica beacon —el rendezvous sigue tibio— pero no acredita: migrarlo ahora lo congelaría
        // semanas. En cuanto su canal se encienda, re-publica `rejoin.v1` y el grupo se desbloquea solo.
        let members = [member(key: "pausado", capability: GroupCapability.rejoinV1Paused)]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .waiting(pending: 1))
    }

    @Test func acceptedForRejoin_excludesPausedToken() {
        #expect(GroupCapability.acceptedForRejoin.contains(GroupCapability.rejoinV1))
        #expect(!GroupCapability.acceptedForRejoin.contains(GroupCapability.rejoinV1Paused))
    }

    @Test func decide_waiting_whenBeaconExpired() {
        // Un beacon de hace 46 días no prueba capacidad VIVA (pudo haber downgrade, o la fila quedó
        // huérfana). TTL = 45 d.
        let members = [member(key: "viejo", ageDays: 46)]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .waiting(pending: 1))
    }

    @Test func decide_ready_whenBeaconJustInsideTTL() {
        let members = [member(key: "justo", ageDays: 44)]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .ready)
    }

    @Test func decide_waiting_whenMemberLacksRecordName() {
        // Sin `cloudKitUserRecordID` el payload builder lo salta igualmente: migrar lo dejaría fuera del
        // backend, o sea congelado sin cuenta a la que volver.
        let members = [member(key: "sinRecord", hasRecordName: false)]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .waiting(pending: 1))
    }

    @Test func decide_waiting_countsEveryLaggard() {
        let members = [member(key: "a", capability: nil, ageDays: nil),
                       member(key: "b", ageDays: 100),
                       member(key: "c")]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .waiting(pending: 2))
    }

    // MARK: - La salida del owner

    @Test func decide_ready_whenLaggardLeftOrWasRemovedOrRejected() {
        // La ÚNICA salida del owner ante alguien que ya no participa y no va a actualizar: quitarlo.
        // `.left` / `.removed` / `.rejected` no cuentan, así que el grupo se desbloquea solo.
        for status: SplitMemberStatus in [.left, .removed, .rejected] {
            let members = [member(key: "fuera", status: status, capability: nil, ageDays: nil)]
            #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .ready)
        }
    }

    @Test func decide_waiting_whenLaggardIsPendingApproval() {
        // Un pendiente de aprobación SÍ cuenta: todavía puede acabar dentro del grupo.
        let members = [member(key: "pendiente", status: .pendingApproval, capability: nil, ageDays: nil)]
        #expect(GroupMigrationReadinessLogic.decide(members: members, now: now) == .waiting(pending: 1))
    }

    @Test func laggards_returnsOnlyBlockingMembers() {
        // La lista que ve el owner no debe incluir a quien ya beaconeó — nombrar a alguien que hizo
        // todo bien convertiría la sección en ruido.
        let members = [member(key: "owner", isOwner: true, capability: nil, ageDays: nil),
                       member(key: "ok"),
                       member(key: "falta", capability: nil, ageDays: nil)]
        let keys = GroupMigrationReadinessLogic.laggards(members: members, now: now).map(\.memberKey)
        #expect(keys == ["falta"])
    }

    // MARK: - Bordes de reloj

    @Test func isCapable_acceptsBeaconDatedInTheFuture() {
        // Reloj del device adelantado: castigarlo bloquearía un grupo sano. La frescura solo descarta
        // beacons VIEJOS.
        #expect(GroupMigrationReadinessLogic.isCapable(
            capability: GroupCapability.rejoinV1,
            capabilityAt: now.addingTimeInterval(60 * 60 * 24),
            now: now,
            accepted: GroupCapability.acceptedForRejoin,
            ttl: GroupMigrationReadinessLogic.beaconTTL) == true)
    }

    @Test func isCapable_falseWhenCapabilityAtMissing() {
        // Token sí, fecha no → no sabemos si sigue vigente ⇒ no acredita.
        #expect(GroupMigrationReadinessLogic.isCapable(
            capability: GroupCapability.rejoinV1,
            capabilityAt: nil,
            now: now,
            accepted: GroupCapability.acceptedForRejoin,
            ttl: GroupMigrationReadinessLogic.beaconTTL) == false)
    }
}

// MARK: - C-10: refresco del beacon

struct GroupCapabilityBeaconRefreshTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let token = GroupCapability.rejoinV1

    @Test func needsRefresh_whenNeverPublished() {
        #expect(GroupCapabilityBeacon.needsRefresh(
            lastAt: nil, currentToken: nil, token: token, now: now) == true)
    }

    @Test func needsRefresh_whenTokenChanged() {
        // Build nuevo con otra capacidad → hay que re-declararla aunque la fecha sea reciente.
        #expect(GroupCapabilityBeacon.needsRefresh(
            lastAt: now.addingTimeInterval(-60), currentToken: "rejoin.v0", token: token, now: now) == true)
    }

    @Test func needsRefresh_falseWithinInterval() {
        // Anti write-amplification: no reescribir la fila del member en cada boot.
        #expect(GroupCapabilityBeacon.needsRefresh(
            lastAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            currentToken: token, token: token, now: now) == false)
    }

    @Test func needsRefresh_trueAfterInterval() {
        #expect(GroupCapabilityBeacon.needsRefresh(
            lastAt: now.addingTimeInterval(-8 * 24 * 60 * 60),
            currentToken: token, token: token, now: now) == true)
    }

    @Test func needsRefresh_trueWhenLastAtInTheFuture() {
        // Reloj torcido: sin esto el beacon quedaría congelado hasta que el reloj se corrigiera solo,
        // y el grupo bloqueado sin motivo visible.
        #expect(GroupCapabilityBeacon.needsRefresh(
            lastAt: now.addingTimeInterval(60 * 60), currentToken: token, token: token, now: now) == true)
    }

    @Test func capability_isNilInProductionToday() {
        // Prueba de DARK-ness: con el canal sin compilar y el backend sin configurar (todo build de
        // producción hoy), el beacon no publica nada ⇒ `publishIfNeeded` es no-op byte-idéntico.
        #expect(GroupCapability.current == nil)
    }
}
