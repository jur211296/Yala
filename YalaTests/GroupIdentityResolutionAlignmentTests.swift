//
//  GroupIdentityResolutionAlignmentTests.swift
//  YalaTests
//
//  Tests de la ALINEACIÓN de identidad de miembro (2026-09-04): los consumidores que resolvían con
//  `first { $0.isCurrentUser }` pasan a usar la resolución canónica de
//  `GroupExpenseService.selectCurrentUserMember`.
//
//  Por qué existe este fichero, y no basta con `GroupExpenseServiceCurrentMemberTests`: aquél pinnea
//  el RESOLVEDOR, que ya era correcto. Lo que estaba roto eran sus CONSUMIDORES. El caso que motivó
//  la tanda no lo veía ningún test porque `DevSeedGroups` siembra `isCurrentUser: true` a mano
//  (:46, :121, :302), así que ninguna suite ejercitaba jamás el estado real del canal backend: «mi
//  member llegó por el pull y el flag NO está puesto».
//
//  El mecanismo, medido: `GroupsSyncClient.applyMember` NUNCA escribe `isCurrentUser`, y el único
//  call-site de producción de `refreshCurrentUserFlags` está en el arranque (`AppBootstrapper:526`).
//  ⇒ quien se une por el canal backend en sesión viva no tiene identidad local hasta reiniciar.
//
//  @Model directo sin contexto (regla R8), mismo molde que el fichero hermano.
//

import Foundation
import Testing

@testable import Yala

struct GroupIdentityResolutionAlignmentTests {

    @MainActor
    private func member(
        id: UUID = UUID(), current: Bool = false, joined: Date = Date(timeIntervalSince1970: 100),
        recordName: String = "", userID: String? = nil, memberKey: String? = nil,
        status: SplitMemberStatus = .active, role: String = "member"
    ) -> SplitMember {
        let m = SplitMember(cloudKitUserRecordID: recordName, isCurrentUser: current)
        m.id = id
        m.joinedAt = joined
        m.userID = userID
        m.memberKey = memberKey
        m.memberStatus = status
        m.role = role
        return m
    }

    private static let sub = "11111111-1111-1111-1111-111111111111"
    private static let otroSub = "22222222-2222-2222-2222-222222222222"

    // MARK: - La primitiva y su variante `...ID` no pueden divergir

    /// `selectCurrentUserMemberID` delega en `selectCurrentUserMember`. Si alguien reimplementa uno
    /// de los dos, este test lo caza: son el mismo criterio o no son nada.
    @Test @MainActor func idVariant_delegatesToMemberVariant_neverDiverges() {
        let flagged = UUID()
        let members = [
            member(id: UUID(), joined: Date(timeIntervalSince1970: 50), userID: Self.sub),
            member(id: flagged, current: true, joined: Date(timeIntervalSince1970: 200)),
        ]
        let porMiembro = GroupExpenseService.selectCurrentUserMember(
            from: members, cachedRecordName: nil, currentUserID: Self.sub)
        let porID = GroupExpenseService.selectCurrentUserMemberID(
            from: members, cachedRecordName: nil, currentUserID: Self.sub)
        #expect(porMiembro?.id.uuidString == porID)
        // Y el flag conserva la PRIMERA posición aunque el match por `sub` tenga joinedAt anterior.
        #expect(porID == flagged.uuidString)
    }

    // MARK: - El caso que motivó la tanda: el joiner del canal backend

    /// EL BUG. Member materializado por el pull: sin `isCurrentUser`, con `userID == sub`.
    /// `first { $0.isCurrentUser }` daba nil ⇒ ni banner, ni chip, ni salida.
    @Test @MainActor func backendJoiner_withoutFlag_resolvesBySub_whereRawFlagReturnedNil() {
        let mio = UUID()
        let members = [
            member(id: UUID(), userID: Self.otroSub, memberKey: "otro"),
            member(id: mio, userID: Self.sub, memberKey: "yo", status: .pendingApproval),
        ]
        // El comportamiento VIEJO, replicado aquí para que el test explique qué se arregló.
        #expect(members.first(where: { $0.isCurrentUser }) == nil)

        let resuelto = GroupExpenseService.selectCurrentUserMember(
            from: members, cachedRecordName: nil, currentUserID: Self.sub)
        #expect(resuelto?.id == mio)
        #expect(resuelto?.memberStatus == .pendingApproval)
    }

    /// La mitad que se quedaba sin salida: el rechazado. Su `memberStatus` es lo que alimenta el
    /// banner de `GroupDetailView:138` y, en la lista, el `onRejectedTap` que abre la confirmación
    /// de salir (`GroupCardView:275` → `GroupsContainerView:396`). Sin resolverlo, el grupo quedaba
    /// en la lista sin cartel y sin forma de quitárselo de encima.
    @Test @MainActor func rejectedJoiner_withoutFlag_resolvesWithRejectedStatus() {
        let mio = UUID()
        let members = [
            member(id: mio, userID: Self.sub, status: .rejected),
            member(id: UUID(), userID: Self.otroSub, status: .active),
        ]
        let resuelto = GroupExpenseService.selectCurrentUserMember(
            from: members, cachedRecordName: nil, currentUserID: Self.sub)
        #expect(resuelto?.memberStatus == .rejected)
    }

    // MARK: - Que no resuelva de MÁS (la mitad cara del cambio)

    /// Identidad de OTRO humano no resuelve. Si esto se rompe, alguien ve el balance de otra
    /// persona: es el único modo de fallo de esta tanda que sería peor que el bug que arregla.
    @Test @MainActor func otherPersonsMember_neverResolvesAsMine() {
        let members = [member(id: UUID(), userID: Self.otroSub, memberKey: "otro")]
        #expect(GroupExpenseService.selectCurrentUserMember(
            from: members, cachedRecordName: nil, currentUserID: Self.sub) == nil)
    }

    /// Sin sesión backend (`currentUserID` nil, que es lo que pasa con el flag de canal apagado) el
    /// resolvedor es byte-idéntico al comportamiento viejo: solo el flag. Ninguna corrida existente
    /// cambia de resultado por este trabajo.
    @Test @MainActor func withoutBackendSession_behavesExactlyLikeTheRawFlag() {
        let flagged = UUID()
        let members = [
            member(id: UUID(), userID: Self.sub),
            member(id: flagged, current: true),
        ]
        let resuelto = GroupExpenseService.selectCurrentUserMember(
            from: members, cachedRecordName: nil, currentUserID: nil)
        #expect(resuelto?.id == flagged)

        let soloOtros = [member(id: UUID(), userID: Self.sub)]
        #expect(GroupExpenseService.selectCurrentUserMember(
            from: soloOtros, cachedRecordName: nil, currentUserID: nil) == nil)
    }

    /// Cache de iCloud vacía no debe casar con las filas born-remote, que dejan
    /// `cloudKitUserRecordID` vacío POR DISEÑO. Sin este guard, `"" == ""` haría que el primer
    /// miembro del array fuese «yo» — y ahí sí se ve la perspectiva de otro.
    @Test @MainActor func emptyRecordName_doesNotMatchEmptyBornRemoteRows() {
        let members = [
            member(id: UUID(), recordName: "", userID: Self.otroSub),
            member(id: UUID(), recordName: "", userID: "33333333-3333-3333-3333-333333333333"),
        ]
        #expect(GroupExpenseService.selectCurrentUserMember(
            from: members, cachedRecordName: "", currentUserID: Self.sub) == nil)
    }

    // MARK: - Auto-expulsión: la regresión que este trabajo NO debe introducir

    /// El vector que la review adversarial destapó. `GroupMemberRow` decidía si ocultar las acciones
    /// de admin sobre una fila con el flag CRUDO (`!member.isCurrentUser`). Al resolver identidad,
    /// un admin sin flag —2º device, reinstalación, aprobación en vivo— pasaba a tener
    /// `isCurrentUserAdmin == true` mientras su propia fila seguía con el flag apagado: su fila
    /// mostraba «quitar» y «cambiar rol», y esos botones llaman al RPC. Se podía echar de su propio
    /// grupo.
    ///
    /// El arreglo es que la fila reciba `isSelf` calculado como la UNIÓN del flag y la identidad
    /// resuelta (`GroupMembersView`: `member.isCurrentUser || member.id.uuidString ==
    /// viewModel.currentMemberID`).
    /// Este test pinnea la propiedad de la que depende: el miembro resuelto es el propio aunque su
    /// flag esté apagado, así que `member.id.uuidString == currentMemberID` distingue tu fila.
    @Test @MainActor func adminWithoutFlag_resolvesToOwnRow_soSelfExclusionStillWorks() {
        let mio = UUID()
        let members = [
            member(id: mio, userID: Self.sub, role: "admin"),
            member(id: UUID(), userID: Self.otroSub, role: "member"),
        ]
        let resuelto = GroupExpenseService.selectCurrentUserMember(
            from: members, cachedRecordName: nil, currentUserID: Self.sub)
        let currentMemberID = resuelto?.id.uuidString
        #expect(currentMemberID == mio.uuidString)
        // La fila propia se reconoce por id, no por flag — que es lo que impide la auto-expulsión.
        #expect(members.first(where: { $0.id.uuidString == currentMemberID })?.isCurrentUser == false)
    }

    /// LA REGRESIÓN QUE LA REVIEW ADVERSARIAL DESTAPÓ, y por la que `isSelf` es una UNIÓN y no una
    /// igualdad. En una zona MIGRADA puede haber DOS filas del mismo humano con el flag puesto:
    /// `refreshCurrentUserFlags` conserva el de la fila legacy CloudKit (`GroupService:1136`, rama
    /// `memberIsInBackendChannel`) y enciende el de la born-backend por `sub`; sus `id` vienen de
    /// namespaces distintos, así que no se deduplican.
    ///
    /// El resolvedor devuelve UNA sola (la de `min(joinedAt)`). Comparar solo contra ella habría
    /// dejado la otra fila propia mostrando «quitar» y «cambiar rol» — donde la condición vieja
    /// `!member.isCurrentUser` las ocultaba las dos. Y el daño no es cosmético: `removeMember`
    /// (`GroupService:326-332`) llama al RPC ANTES de `removeMemberLocal`, cuyo guard anti-self es
    /// el flag crudo (`:345`), así que el servidor te quita y el guard local lanza después.
    @Test @MainActor func twoOwnFlaggedRows_resolverReturnsOne_soSelfExclusionMustBeTheUnion() {
        let legacy = UUID()
        let backend = UUID()
        let members = [
            member(id: legacy, current: true, joined: Date(timeIntervalSince1970: 100),
                   recordName: "_me", role: "admin"),
            member(id: backend, current: true, joined: Date(timeIntervalSince1970: 300),
                   userID: Self.sub, role: "admin"),
        ]
        let resuelto = GroupExpenseService.selectCurrentUserMember(
            from: members, cachedRecordName: "_me", currentUserID: Self.sub)
        // El resolvedor elige UNA: la de joinedAt más antiguo.
        #expect(resuelto?.id == legacy)

        // Con la igualdad sola, la fila backend quedaría expuesta.
        let soloIdentidad = members.filter { $0.id.uuidString == resuelto?.id.uuidString }
        #expect(soloIdentidad.count == 1)

        // Con la UNIÓN, las dos filas propias quedan cubiertas — que es la propiedad que impide
        // ofrecer acciones de admin sobre una fila mía.
        let union = members.filter { $0.isCurrentUser || $0.id.uuidString == resuelto?.id.uuidString }
        #expect(union.count == 2)
    }
}
