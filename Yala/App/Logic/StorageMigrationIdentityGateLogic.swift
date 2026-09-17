//
//  StorageMigrationIdentityGateLogic.swift
//  Yala
//
//  La puerta de identidad de «Migrar a la nube» (Ajustes → «Dónde viven tus datos»): decide si una migración sigue
//  hacia el claim o se para, y con qué aviso, antes de escribir nada.
//
//  POR QUÉ EXISTE. Hasta el 2026-09-16 esta puerta no preguntaba al backend. Con una cuenta que ya tenía finanzas
//  personales el claim contestaba `existing_stable`, la máquina lo enrutaba al adopt, y el adopt subía a esa cuenta todo
//  lo que el backend no conocía (`MigrationWorkExecutor.runAdoptOrphanReconcile`): en un iPhone que nunca migró, el
//  corpus entero. La persona pedía migrar y acababa con sus datos mezclados en otra cuenta, sin ningún aviso. Ticket
//  `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`.
//
//  ## Dos capas, y cada una ve algo que la otra no
//
//  · **La comprobación** (`check`) pregunta `/account/exists` antes del claim y aplica la fila de Ajustes de la tabla
//    [I]. Es la única que sabe si el dispositivo usa OTRA cuenta para sus grupos: el claim promueve cualquier cuenta
//    solo-grupos.
//  · **El claim** (`ForwardClaimIntent`, en `MigrationRunner`) es el único que sabe que una cuenta `groups_only` ya
//    volvió a iCloud, o que otro dispositivo la está migrando: `/account/exists` solo da `exists` + `kind`, y
//    `claim_account` contesta `existing_stable` o `claiming_in_progress` (`qa/cloud/g15_01_account_kind.sql`).
//    `blockForClaimRefusal` elige el aviso de esa segunda parada.
//
//  Pura a propósito: el controller resuelve los hechos vivos —qué contestó el backend, qué cuenta está asociada— y
//  ejecuta el veredicto.
//

import Foundation

nonisolated enum StorageMigrationIdentityGateLogic {

    /// Lo que contestó `CloudIdentityDiscovery`, sin su tipo `@MainActor`.
    enum Answer: Equatable {
        case discovered(CloudIdentityRoutingLogic.Discovery)
        /// Sin sesión, sin JWT, o la red y el gateway no contestaron.
        case unavailable
    }

    /// Por qué no se migra. Un caso por aviso: cada uno le dice a la persona algo que los otros no.
    enum Block: Equatable, CaseIterable {
        /// La cuenta ya guarda finanzas personales. Migrar encima sería fusionar dos datasets personales, que el ADR del
        /// 2026-09-09 descartó.
        case accountHasPersonalData
        /// Este dispositivo ya usa OTRA cuenta para sus grupos, y solo puede haber una cuenta en la nube (ADR §2). Vale para
        /// una cuenta solo-grupos y para una nueva (Jürgen, 2026-09-16).
        case anotherGroupsAccountAssociated
        /// La cuenta volvió a iCloud: sigue congelada en el backend y volver a la nube con ella es el re-cutover, que
        /// todavía no existe.
        case accountReturnedToICloud

        /// Nombre estable para el canario y el breadcrumb (`cloudMigrationExistingAccountBlocked`). No se renombra: parte
        /// la serie del dashboard.
        var slug: String {
            switch self {
            case .accountHasPersonalData:         return "personal_data"
            case .anotherGroupsAccountAssociated: return "other_groups_account"
            case .accountReturnedToICloud:        return "returned_to_icloud"
            }
        }
    }

    enum Check: Equatable {
        /// La cuenta es nueva, o solo-grupos y promovible: sigue al claim.
        case proceed
        case blocked(Block)
        /// No se pudo preguntar. Tampoco se migra: sin la respuesta no se sabe si sería una fusión.
        case couldNotCheck
    }

    /// La comprobación previa al claim.
    ///
    /// - Parameters:
    ///   - deviceState: el eje de la tabla. La fila de Ajustes no lo lee (`ejeNoDecideEnLasPuertasQueNoLoUsan`), pero la
    ///     tabla no tiene default y aquí no se inventa.
    ///   - isAssociatedGroupsAccount: `GroupsAccountAssociation.isAssociated(sub:)` con el `userID` que devolvió el
    ///     descubrimiento. `nil` = no hay ninguna asociada (Jürgen, 2026-09-16: se promueve una solo-grupos y la nueva
    ///     recibe el cutover); `false` = hay otra asociada, y entonces no se migra.
    ///   - claimedForMigrationHere: este dispositivo ya reclamó esta cuenta para migrar (sello `.proceedMigration` de
    ///     `CloudClaimActionStore`). **Es lo que deja «Reintentar» tras un fallo**: el claim de un intento anterior dejó la
    ///     cuenta `complete` y con este dispositivo de líder, y el servidor se la devuelve como `created`. Sin esto, la
    ///     comprobación la tomaba por una cuenta con datos ajenos y la migración no podía terminar nunca (lo cazaron dos
    ///     lentes de la review). No abre nada más: si el claim contesta `existing_stable`, lo para la intención de migrar
    ///     (`ForwardClaimIntent`), y otra cuenta asociada sigue mandando. Tampoco vale para siempre: al confirmar `complete`,
    ///     el líder cambia el sello por `.routeReturningUser` (`MigrationWorkExecutor`, efecto
    ///     `.runLeaderReconcileFromFrozenCloudKit`), así que la cuenta de una migración TERMINADA se para aquí.
    static func check(
        answer: Answer,
        deviceState: CloudIdentityRoutingLogic.DeviceSessionState,
        isAssociatedGroupsAccount: Bool?,
        claimedForMigrationHere: Bool
    ) -> Check {
        guard case let .discovered(discovery) = answer else { return .couldNotCheck }
        if discovery == .complete, claimedForMigrationHere {
            return isAssociatedGroupsAccount == false ? .blocked(.anotherGroupsAccountAssociated) : .proceed
        }
        let destination = CloudIdentityRoutingLogic.destination(
            gate: .settingsMigrateToCloud,
            discovery: discovery,
            deviceState: deviceState,
            isAssociatedGroupsAccount: isAssociatedGroupsAccount)
        switch destination {
        case .cutoverPrivateToCloud, .promoteAssociatedAccountThenCutover:
            return .proceed
        case .blockedAccountIsComplete:
            return .blocked(.accountHasPersonalData)
        case .blockedAnotherGroupsAccountAssociated:
            return .blocked(.anotherGroupsAccountAssociated)
        case .createCompleteAccountThenPersonalOnboarding, .adoptAsComplete, .adoptAsCompleteAndOpenGroups,
             .enterGroupsOnly, .enterGroupsOnlyOfferingFullActivation, .continueGroupsSetup,
             .associateGroupsAccount, .offerSignUpNoAccountFound:
            // Destinos de otras puertas: la tabla no los da para Ajustes. Si algún día los diera, aquí no se migra.
            return .blocked(.accountHasPersonalData)
        }
    }

    /// El aviso cuando la comprobación dejó pasar y el claim devolvió el intento al inicio.
    ///
    /// `claiming_in_progress` es otro dispositivo migrando esa cuenta: ya tiene, o está recibiendo, finanzas personales
    /// (Jürgen, 2026-09-16: parar y avisar, sin seguirle). Con `existing_stable` lo elige lo que contestó la comprobación,
    /// porque el cliente no lee el `kind` de la respuesta del claim: `claim_account` promociona toda cuenta solo-grupos sin
    /// lo personal reclamado, así que una `groupsOnly` que llega a `existing_stable` es la que volvió a iCloud. Cualquier
    /// otra se completó entre la comprobación y el claim. Queda un caso que recibe el aviso equivocado, y se acepta: una
    /// solo-grupos cuya migración entera, en OTRO dispositivo, empieza y termina en ese rato oye «volvió a iCloud».
    ///
    /// - Parameters:
    ///   - checkedDiscovery: lo que contestó la comprobación de este intento; `nil` si no hay constancia.
    ///   - claimState: lo que contestó el claim devuelto.
    static func blockForClaimRefusal(
        checkedDiscovery: CloudIdentityRoutingLogic.Discovery?,
        claimState: AccountClaimDecision.ClaimState
    ) -> Block {
        guard claimState == .existingStable else { return .accountHasPersonalData }
        return checkedDiscovery == .groupsOnly ? .accountReturnedToICloud : .accountHasPersonalData
    }
}
