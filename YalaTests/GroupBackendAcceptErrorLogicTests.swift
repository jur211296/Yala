//
//  GroupBackendAcceptErrorLogicTests.swift
//  YalaTests
//
//  Contrato C4 (G4-invites): los 13 casos de `GroupsRPCError` → 6 `ErrorKind` + isPermanent + slug.
//

import Foundation
import Testing

@testable import Yala

struct GroupBackendAcceptErrorLogicTests {

    typealias L = GroupBackendAcceptErrorLogic

    @Test func classify_allThirteenCases() {
        #expect(L.classify(.invalidInvite) == .invalidInvite)
        #expect(L.classify(.sessionExpired) == .sessionRequired)
        #expect(L.classify(.notAuthorized) == .notAuthorized)
        #expect(L.classify(.transient(status: 503)) == .transient)
        #expect(L.classify(.transient(status: -1)) == .transient)
        // Kill-switch server-side del canal (403 yala_groups_disabled): kind PROPIO, jamás `.generic`.
        // Colapsarlo en `.generic` limpiaría el intent y quemaría la invitación del usuario por una
        // decisión de configuración que se revierte con un deploy.
        #expect(L.classify(.channelDisabled) == .channelDisabled)
        // Resto → generic.
        #expect(L.classify(.badInput) == .generic)
        #expect(L.classify(.groupExists) == .generic)
        #expect(L.classify(.invalidGroupID) == .generic)
        #expect(L.classify(.memberNotFound) == .generic)
        #expect(L.classify(.cannotRemoveOwner) == .generic)
        #expect(L.classify(.ownerCannotLeave) == .generic)
        #expect(L.classify(.permanentRejected(code: "yala_xyz")) == .generic)
        #expect(L.classify(.decoding) == .generic)
    }

    @Test func isPermanent_onlyPermanentKinds() {
        #expect(L.isPermanent(.invalidInvite))
        #expect(L.isPermanent(.notAuthorized))
        #expect(L.isPermanent(.generic))
        // NO permanentes: el reconciler reintenta / re-presenta sign-in.
        #expect(!L.isPermanent(.transient))
        #expect(!L.isPermanent(.sessionRequired))
        // El canal apagado se LEVANTA con un deploy y sin que el usuario haga nada ⇒ el intent se
        // conserva y el join se completa solo. Si esto fuera `true`, el invitado tendría que pedir un
        // enlace nuevo que tampoco haría falta.
        #expect(!L.isPermanent(.channelDisabled))
    }

    @Test func slug_stableAndCarriesCodeForPermanentRejected() {
        #expect(L.slug(for: .invalidInvite) == "invalidInvite")
        #expect(L.slug(for: .notAuthorized) == "notAuthorized")
        #expect(L.slug(for: .sessionExpired) == "sessionRequired")
        #expect(L.slug(for: .transient(status: 500)) == "transient")
        #expect(L.slug(for: .badInput) == "generic")
        #expect(L.slug(for: .permanentRejected(code: "yala_weird")) == "generic:yala_weird")
        // Slug PROPIO (no "generic", no "transient"): en un incidente el canario tiene que decir que el
        // join se aplazó por el kill-switch y no por una red mala.
        #expect(L.slug(for: .channelDisabled) == "channelDisabled")
    }

    // MARK: - g13_03 · el grupo borrado tiene su propio camino

    /// El servidor distingue desde g13_03 «el grupo ya no existe» de «el enlace no sirve», y el cliente
    /// tiene que conservar esa distinción hasta el mensaje. Colapsarla en `.invalidInvite` devolvería el
    /// consejo imposible que motivó el ticket: «pídele al admin que regenere uno», sin admin ni grupo.
    @Test func groupDeleted_hasItsOwnKind() {
        #expect(GroupBackendAcceptErrorLogic.classify(.groupDeleted) == .groupDeleted)
        #expect(GroupBackendAcceptErrorLogic.classify(.invalidInvite) == .invalidInvite)
    }

    /// Permanente como `.invalidInvite`: el grupo no va a volver, así que reintentar es gastar batería
    /// y el intent se limpia.
    @Test func groupDeleted_isPermanent() {
        #expect(GroupBackendAcceptErrorLogic.isPermanent(.groupDeleted))
    }

    /// Slug propio en el canario: en el dashboard, «grupo borrado» y «enlace inválido» son incidencias
    /// distintas. Colapsarlas escondería cuánta gente llega por un grupo que ya no existe, que es
    /// justamente lo que este cambio hace visible.
    @Test func groupDeleted_reportsItsOwnSlug() {
        #expect(GroupBackendAcceptErrorLogic.slug(for: .groupDeleted) == "groupDeleted")
        #expect(GroupBackendAcceptErrorLogic.slug(for: .invalidInvite) == "invalidInvite")
    }

    /// El mapeo del código del servidor. Si esto se rompe, el error llega como `.permanentRejected` y el
    /// usuario ve el mensaje genérico — el fallo sería silencioso, no un rojo.
    @Test func serverCode_mapsToGroupDeleted() {
        #expect(GroupsRPCError(yalaCode: "yala_group_deleted") == .groupDeleted)
        #expect(GroupsRPCError(yalaCode: "yala_invalid_invite") == .invalidInvite)
    }

    /// Un código desconocido sigue devolviendo `nil` (→ `.permanentRejected` en el llamador, NUNCA
    /// `.transient`). Es lo que permitió aplicar g13_03 en el servidor antes de publicar la app: los
    /// clientes viejos trataron `yala_group_deleted` como rechazo permanente, igual que antes.
    @Test func unknownCode_staysUnmapped() {
        #expect(GroupsRPCError(yalaCode: "yala_algo_que_no_existe") == nil)
    }
}
