//
//  GroupOwnerExitLogicTests.swift
//  YalaTests
//
//  Tabla completa de `GroupOwnerExitLogic`: qué salida se le ofrece al dueño en Ajustes, y quién
//  hereda el grupo. El heredero es un ESPEJO del `order by` de `transfer_group_ownership`, así que
//  los casos de orden están escritos contra el SQL medido en producción, no contra la intuición.
//

import Foundation
import Testing

@testable import Yala

struct GroupOwnerExitLogicTests {

    typealias L = GroupOwnerExitLogic

    private func facts(
        isOwner: Bool = true,
        backend: Bool = true,
        coMembers: Int = 2,
        heirs: Int = 2,
        debt: Bool = false,
        refused: Bool = false,
        archived: Bool = false
    ) -> L.Facts {
        L.Facts(isOwner: isOwner, isBackendChannel: backend, activeCoMemberCount: coMembers,
                eligibleHeirCount: heirs, groupHasOutstandingDebt: debt,
                serverRefusedTransfer: refused, isArchived: archived)
    }

    // MARK: - No soy el dueño

    @Test func nonOwner_onlyLeaves_regardlessOfDebt() {
        for debt in [false, true] {
            let o = L.offer(facts(isOwner: false, debt: debt))
            #expect(o.showsLeave)
            #expect(!o.showsTransferAndLeave)
            // «Eliminar» nunca fue del no-dueño: el servidor lo rechazaría igual.
            #expect(!o.showsDelete)
            #expect(o.deleteHint == nil)
        }
    }

    // MARK: - El caso del ticket: dueño CON deuda y con heredero

    @Test func owner_withDebtAndHeir_isOfferedTransfer_andDeleteStaysBlocked() {
        let o = L.offer(facts(debt: true))
        // El callejón sin salida que cierra este ticket.
        #expect(o.showsTransferAndLeave)
        // La decisión del owner es explícita: eliminar NO se desbloquea con deuda.
        #expect(o.showsDelete)
        #expect(!o.deleteEnabled)
        // Y el copy del bloqueo apunta a transferir, no a liquidar deudas ajenas.
        #expect(o.deleteHint == .debtTransferInstead)
        // Sigue sin ofrecerse «Salir»: el servidor lo rechaza con `yala_owner_cannot_leave`.
        #expect(!o.showsLeave)
    }

    @Test func owner_withDebtWithoutHeir_getsHonestHint_notTransfer() {
        // Sin heredero no hay a quién mandar al usuario: el hint no puede apuntar a un botón ausente.
        let o = L.offer(facts(coMembers: 1, heirs: 0, debt: true))
        #expect(!o.showsTransferAndLeave)
        #expect(!o.deleteEnabled)
        // Desde el 2026-09-08 apunta a «Archivar», que sí existe y sí funciona con deuda. Hasta
        // entonces era `.debtNoTransferAvailable`: honesto, y callándose la salida que tenía delante.
        #expect(o.deleteHint == .debtArchiveInstead)
    }

    // MARK: - AC: único miembro activo → eliminar, nunca transferir

    @Test func owner_alone_isNeverOfferedTransfer() {
        let o = L.offer(facts(coMembers: 0, heirs: 0))
        #expect(!o.showsTransferAndLeave)
        #expect(o.showsDelete)
        #expect(o.deleteEnabled)          // sin deuda, el borrado es la salida y ya existía
        #expect(o.deleteHint == nil)
    }

    // MARK: - CloudKit-legacy: la transferencia no existe en ese canal

    @Test func owner_onCloudKitChannel_isNeverOfferedTransfer() {
        // CKShare no sabe ceder ownership; ofrecerlo sería un botón que no puede funcionar.
        let o = L.offer(facts(backend: false, coMembers: 3, heirs: 3, debt: true))
        #expect(!o.showsTransferAndLeave)
        // En CloudKit hay herederos de sobra y lo que falta es el canal, pero la salida ofrecida es la
        // misma: archivar no depende del canal.
        #expect(o.deleteHint == .debtArchiveInstead)
    }

    // MARK: - Co-members sin cuenta (placeholders `user_id NULL`)

    @Test func owner_withCoMembersButNoEligibleHeir_isNotOfferedTransfer() {
        // Grupo legacy migrado y no reclamado: hay filas de miembro, pero ningún `auth.user` al que
        // ceder. El servidor devolvería `no_eligible_owner`, así que la app no lo ofrece.
        let o = L.offer(facts(coMembers: 3, heirs: 0))
        #expect(!o.showsTransferAndLeave)
        #expect(o.showsDelete)
    }

    @Test func owner_heirCountWithoutCoMembers_doesNotOfferTransfer() {
        // Defensa del desajuste entre los dos conteos: sin co-members activos no hay transferencia
        // posible aunque el contador de herederos venga alto.
        #expect(!L.offer(facts(coMembers: 0, heirs: 2)).showsTransferAndLeave)
    }

    // MARK: - Sin deuda no hay hint, con deuda siempre lo hay

    @Test func deleteHint_existsExactlyWhenDeleteIsBlocked() {
        for backend in [true, false] {
            for heirs in [0, 1] {
                for debt in [false, true] {
                    let o = L.offer(facts(backend: backend, coMembers: 2, heirs: heirs, debt: debt))
                    #expect(o.deleteEnabled == !debt)
                    #expect((o.deleteHint != nil) == debt)
                }
            }
        }
    }

    // MARK: - El rechazo del servidor gana al cache local

    @Test func serverRefusal_withdrawsTheOffer_evenWithLocalHeirs() {
        // Los conteos locales siguen diciendo que hay heredero —el rechazo del RPC no toca ninguna
        // fila—, así que sin este fact la pantalla volvería a ofrecer la transferencia, a nombrar al
        // mismo heredero fantasma y a fallar igual, en bucle y con «Eliminar» en gris.
        let o = L.offer(facts(coMembers: 3, heirs: 3, debt: true, refused: true))
        #expect(!o.showsTransferAndLeave)
        // Y el hint deja de mandar a un botón que ya no está: pasa a la salida que sí queda.
        #expect(o.deleteHint == .debtArchiveInstead)
    }

    @Test func serverRefusal_doesNotHideTheOtherExits() {
        // Retirar la transferencia no puede llevarse por delante «Eliminar»: sin deuda sigue siendo
        // la salida buena.
        let o = L.offer(facts(coMembers: 3, heirs: 3, debt: false, refused: true))
        #expect(o.showsDelete)
        #expect(o.deleteEnabled)
    }

    @Test func serverRefusal_isIrrelevantForNonOwners() {
        #expect(L.offer(facts(isOwner: false, refused: true)).showsLeave)
    }

    // MARK: - Heredero: espejo del `order by` del servidor

    private func heir(_ key: String, admin: Bool = false, joined: TimeInterval) -> L.HeirCandidate {
        L.HeirCandidate(memberKey: key, displayName: key, isAdmin: admin,
                        joinedAt: Date(timeIntervalSince1970: joined))
    }

    @Test func designatedHeir_isNilWhenNoCandidates() {
        #expect(L.designatedHeir(from: []) == nil)
    }

    @Test func designatedHeir_prefersAdminOverOlderMember() {
        // `(coalesce(role,'') = 'admin') desc` va ANTES que `joined_at asc`: un admin recién llegado
        // gana a un miembro antiguo. Si esto se invirtiera, la app nombraría a quien el servidor
        // no corona.
        let out = L.designatedHeir(from: [
            heir("b", admin: false, joined: 100),   // el más antiguo, pero no admin
            heir("a", admin: true, joined: 900),
        ])
        #expect(out?.memberKey == "a")
    }

    @Test func designatedHeir_amongAdmins_takesTheOldest() {
        let out = L.designatedHeir(from: [
            heir("z", admin: true, joined: 500),
            heir("y", admin: true, joined: 200),
            heir("x", admin: false, joined: 1),
        ])
        #expect(out?.memberKey == "y")
    }

    @Test func designatedHeir_amongMembers_takesTheOldest() {
        // Las claves van a CONTRAPELO de la antigüedad a propósito: el más antiguo (`m9`) es el
        // último alfabéticamente. Con `m1/m2/m3` ordenados igual por ambos criterios, un espejo que
        // ignorase `joined_at asc` por completo daba el mismo ganador y pasaba en verde — medido
        // ejecutando ese mutante, que la versión anterior de este test NO cazaba.
        let out = L.designatedHeir(from: [
            heir("m2", joined: 300),
            heir("m9", joined: 150),
            heir("m3", joined: 900),
        ])
        #expect(out?.memberKey == "m9")
    }

    @Test func designatedHeir_amongAdmins_oldestWinsEvenWithLaterKey() {
        // El mismo control para el segundo nivel dentro del grupo de admins.
        let out = L.designatedHeir(from: [
            heir("aaa", admin: true, joined: 900),
            heir("zzz", admin: true, joined: 100),
        ])
        #expect(out?.memberKey == "zzz")
    }

    @Test func designatedHeir_tiesBreakByMemberKey_notByArrayOrder() {
        // Un import de migración sella el MISMO `joined_at` en todo el lote. Sin el desempate por
        // `member_key`, el resultado dependería del orden del array —que es el del fetch— y la app
        // podría nombrar a uno mientras el servidor corona a otro.
        let ascending = L.designatedHeir(from: [
            heir("aaa", joined: 500), heir("bbb", joined: 500), heir("ccc", joined: 500),
        ])
        let shuffled = L.designatedHeir(from: [
            heir("ccc", joined: 500), heir("aaa", joined: 500), heir("bbb", joined: 500),
        ])
        #expect(ascending?.memberKey == "aaa")
        // El mismo conjunto en otro orden da el MISMO heredero: la elección no depende del fetch.
        #expect(shuffled?.memberKey == "aaa")
    }

    @Test func designatedHeir_singleCandidate_isThatCandidate() {
        #expect(L.designatedHeir(from: [heir("solo", joined: 42)])?.memberKey == "solo")
    }

    // MARK: - Archivar como salida (decisión 2026-09-08)

    @Test("Con el grupo YA archivado no se ofrece archivar: no queda nada que ofrecer")
    func owner_withDebtNoHeir_alreadyArchived_getsPlainHint() {
        let o = L.offer(facts(coMembers: 1, heirs: 0, debt: true, archived: true))
        #expect(!o.showsTransferAndLeave)
        #expect(!o.deleteEnabled)
        // Éste es el único camino que queda para `.debtNoTransferAvailable`, y por eso el caso sigue
        // existiendo: mandar a archivar un grupo archivado sería mandarlo a un botón que ya pulsó.
        #expect(o.deleteHint == .debtNoTransferAvailable)
    }

    @Test("Con heredero manda la transferencia, archivado o no: es la salida que de verdad le saca")
    func owner_withHeir_prefersTransfer_overArchive() {
        for archived in [false, true] {
            let o = L.offer(facts(debt: true, archived: archived))
            #expect(o.showsTransferAndLeave)
            #expect(o.deleteHint == .debtTransferInstead)
        }
    }

    @Test("Sin deuda no hay hint, esté archivado o no")
    func owner_withoutDebt_hasNoHint_regardlessOfArchive() {
        for archived in [false, true] {
            let o = L.offer(facts(coMembers: 1, heirs: 0, archived: archived))
            #expect(o.deleteEnabled)
            #expect(o.deleteHint == nil)
        }
    }

    @Test("Archivar NO desbloquea «Eliminar»: la deuda sigue protegida")
    func archiveHint_doesNotUnlockDelete() {
        let o = L.offer(facts(coMembers: 1, heirs: 0, debt: true))
        #expect(o.deleteHint == .debtArchiveInstead)
        // El principio que la decisión del 6-sep protegió: no se borra un grupo con saldos vivos.
        // Ofrecer archivar es una salida para el dueño, no una puerta trasera al borrado.
        #expect(!o.deleteEnabled)
        #expect(o.showsDelete)
    }

}
