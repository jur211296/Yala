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
//    solo-grupos. Y la única que sabe si la sesión la eligió quien migra: el claim no distingue la sesión que dejó en el
//    teléfono la persona anterior.
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
        /// El teléfono empezó desde cero y la sesión viva no la abrió este intento ni está asociada: puede ser de la persona
        /// anterior. Hasta el 2026-09-17 «Empezar desde cero» no cerraba la sesión en la nube; hoy la retira
        /// (`CloudSessionRetirement`), pero el retiro es asíncrono y la reinstalación no deja sello, así que
        /// este aviso sigue siendo la red de este lado (Jürgen, 2026-09-16 y 2026-09-17). Ver
        /// `deviceSealedForFreshStart` en `check`. Va al final: añadir un caso en medio cambia el orden de `allCases`.
        case sessionFromBeforeFreshStart

        /// Nombre estable para el canario y el breadcrumb (`cloudMigrationExistingAccountBlocked`). No se renombra: parte
        /// la serie del dashboard.
        var slug: String {
            switch self {
            case .accountHasPersonalData:         return "personal_data"
            case .anotherGroupsAccountAssociated: return "other_groups_account"
            case .accountReturnedToICloud:        return "returned_to_icloud"
            case .sessionFromBeforeFreshStart:    return "fresh_start_session"
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
    ///     recibe el cutover), salvo en un teléfono que empezó desde cero (`deviceSealedForFreshStart`); `false` = hay
    ///     otra asociada, y entonces no se migra.
    ///   - claimedForMigrationHere: este dispositivo ya reclamó esta cuenta para migrar (sello `.proceedMigration` de
    ///     `CloudClaimActionStore`). **Es lo que deja «Reintentar» tras un fallo**: el claim de un intento anterior dejó la
    ///     cuenta `complete` y con este dispositivo de líder, y el servidor se la devuelve como `created`. Sin esto, la
    ///     comprobación la tomaba por una cuenta con datos ajenos y la migración no podía terminar nunca (lo cazaron dos
    ///     lentes de la review). No abre nada más: si el claim contesta `existing_stable`, lo para la intención de migrar
    ///     (`ForwardClaimIntent`), y otra cuenta asociada sigue mandando. Tampoco vale para siempre: al confirmar `complete`,
    ///     el líder cambia el sello por `.routeReturningUser` (`MigrationWorkExecutor`, efecto
    ///     `.runLeaderReconcileFromFrozenCloudKit`), así que la cuenta de una migración TERMINADA se para aquí.
    ///   - hasUnansweredMigrationClaim: este dispositivo mandó un claim de «Migrar» para esta cuenta y se quedó sin respuesta
    ///     (`CloudClaimActionStore.hasMigrationClaimAttempt`, ticket `forward-migration-steps-have-no-ceiling-and-no-exit`,
    ///     decisión de Jürgen del 2026-09-22). Ese claim pudo crear o promover la cuenta —queda `complete`, con este dispositivo
    ///     de líder— sin dejar el sello, que solo se escribe con la respuesta. Hasta ese ticket no se notaba porque el paso no
    ///     salía nunca; con techo y «Cancelar» al 22 %, el reintento se paraba aquí con un «ya tiene datos» falso. Abre lo
    ///     mismo que el sello —solo una `complete`, solo hasta el claim, que sigue decidiendo— con UNA diferencia: **no se
    ///     salta la red de «Empezar desde cero»**. Con el sello de ese caso, la sesión que no abrió este intento y no está
    ///     asociada puede ser de la persona anterior, y la marca no la ha visto contestar nunca. El sello sí se la salta, y es
    ///     el residual escrito abajo; la marca no lo amplía (lo cazaron dos lentes de la review).
    ///
    ///     **Y deja pasar un poco más que el sello, medido:** el sello solo existe si este dispositivo recibió `created`. La
    ///     marca se queda también con un `claiming_in_progress` cuya respuesta se perdió, y si ese otro dispositivo abandona
    ///     su migración más de 60 min, el claim siguiente de este hace el relevo y contesta `created`. Es la clase de hueco
    ///     que ya tiene cualquier «Migrar» sobre una cuenta nueva o solo-grupos (el relevo no se distingue desde el cliente),
    ///     y aquí pide además una carrera entre la comprobación y el claim y una respuesta perdida. **Ni se retira cuando otro
    ///     dispositivo termina la migración** (al sello lo cambia el `complete` del líder; a la marca, solo un claim de este
    ///     con respuesta): «Migrar» pasa entonces la comprobación y la para el claim, después del consentimiento. Aceptado:
    ///     pide la misma respuesta perdida, y el aviso que sale es el correcto.
    ///   - sessionOpenedByThisAttempt: la sesión la abrió este intento, en la elección de Apple o Google, así que la persona
    ///     eligió la cuenta. `false` con la sesión que ya había al tocar «Activar la nube».
    ///   - deviceSealedForFreshStart: este teléfono pasó por «Empezar desde cero» (`groupsDomainSealedForFreshStart`).
    ///     **Con el sello, `nil` en `isAssociatedGroupsAccount` no dice «no hay ninguna asociada»: dice «no se sabe de quién
    ///     es la sesión».** Desde el 2026-09-17 «Empezar desde cero» RETIRA la sesión en la nube
    ///     (`CloudSessionRetirement`, decisión de Jürgen), pero el retiro es un `Task` y este guard es lo que
    ///     cubre el hueco si no llegó a correr. Con el sello, además, `GroupsAccountAssociation` deja
    ///     de leer la asociación del Apple ID y `GroupsAssociationRegistrar` no registra la sesión viva, porque puede ser de la
    ///     persona anterior. Así que ahí una sesión que no abrió este intento y no está asociada no recibe lo personal
    ///     (Jürgen, 2026-09-16, ticket `fresh-start-keeps-a-groups-session-that-migrate-promotes`): sin esto, las finanzas
    ///     de la persona nueva acababan en la cuenta de la anterior, y le aparecían en sus dispositivos. Solo retira un
    ///     `.proceed`: lo que ya se bloqueaba conserva su aviso, y «Reintentar» sigue por el sello `.proceedMigration`.
    ///
    ///     **Sin el sello no cambia nada, y no porque no haya relevo** (lo midió la review). Tras reinstalar, la sesión anterior
    ///     sobrevive en el llavero y un «Empezar desde cero» sin filas locales no sella; el arranque la asocia y aquí llega como
    ///     `true`. Esta puerta no puede distinguirla: hace falta cerrar esa sesión, que es otra decisión
    ///     (`previous-person-cloud-session-survives-fresh-start-and-reinstall`). Dos residuales más, escritos allí: el sello
    ///     `.proceedMigration` lo deja un intento de ESTE teléfono, que tras un relevo puede ser de la persona anterior; y tras
    ///     desasociar, elegir Apple firma con el Apple ID del teléfono.
    static func check(
        answer: Answer,
        deviceState: CloudIdentityRoutingLogic.DeviceSessionState,
        isAssociatedGroupsAccount: Bool?,
        claimedForMigrationHere: Bool,
        hasUnansweredMigrationClaim: Bool,
        sessionOpenedByThisAttempt: Bool,
        deviceSealedForFreshStart: Bool
    ) -> Check {
        guard case let .discovered(discovery) = answer else { return .couldNotCheck }
        // La sesión puede ser de la persona anterior: el mismo predicado que retira el `.proceed` de más abajo.
        let sessionMayBeFromBeforeFreshStart = deviceSealedForFreshStart && isAssociatedGroupsAccount == nil
            && !sessionOpenedByThisAttempt
        let unansweredClaimCounts = hasUnansweredMigrationClaim && !sessionMayBeFromBeforeFreshStart
        if discovery == .complete, claimedForMigrationHere || unansweredClaimCounts {
            return isAssociatedGroupsAccount == false ? .blocked(.anotherGroupsAccountAssociated) : .proceed
        }
        let destination = CloudIdentityRoutingLogic.destination(
            gate: .settingsMigrateToCloud,
            discovery: discovery,
            deviceState: deviceState,
            isAssociatedGroupsAccount: isAssociatedGroupsAccount)
        switch destination {
        case .cutoverPrivateToCloud, .promoteAssociatedAccountThenCutover:
            if sessionMayBeFromBeforeFreshStart {
                return .blocked(.sessionFromBeforeFreshStart)
            }
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
