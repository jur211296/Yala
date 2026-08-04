//
//  GroupBackendMembershipService.swift
//  Yala
//
//  Materializador de membresía del canal Grupos → backend (incremento G3). @MainActor final class que
//  compone `GroupsMembershipClient` (RPCs) + `ModelContext` (store de Grupos).
//
//  **Este header decía «NADIE lo llama en producción … el cableado a la UI real llega en G4+» y llevaba
//  meses siendo FALSO** — `GroupFormView.swift:293` lo invoca por `GroupCreateRoutingLogic.route(.backend)`,
//  con `groupsBackendCompiledDefault = true` (`CloudSyncFlags.swift:285`) y `GROUPS_BACKEND_ROLLOUT_PERCENT`
//  al 100 % en producción (`gateway/wrangler.toml:133`). La frase costó tiempo de diagnóstico al medir la
//  ventana del `await` de abajo, porque invitaba a archivar el defecto como inalcanzable. Es la misma
//  familia que el docblock de `SplitGroupDeduplicationService` («other devices observe the delete and
//  converge»): cierto cuando se escribió, destructivo después. ⇒ al encender un canal, releer los headers
//  de los servicios que el flip pone en producción, no solo los que se tocan.
//
//  Gate en cada método público: `groupsBackendEnabled && hasSession` — sin canal o sin sesión, el método
//  lanza `sessionExpired` ANTES de tocar la red o el contexto (no-op verificable en tests).
//
//  **UNA EXCEPCIÓN, deliberada y asimétrica (D-R1 paso 2): `forgetUser()`.** Todos los demás métodos son
//  ENTRADAS —crear, unirse, invitar, revocar, aprobar, expulsar, salir, renombrarse— y el kill remoto
//  existe justo para cerrarlas. `forgetUser` es un TEARDOWN: lo invoca el borrado de cuenta para
//  anonimizar y transferir lo que el usuario YA subió, y eso sigue existiendo con el canal apagado. Si
//  compartiera el gate compuesto, un kill remoto no retendría datos «hasta que se levante»: haría fallar
//  el paso 1 del borrado y dejaría al usuario sin poder ejercer su derecho de supresión mientras durase.
//  Por eso lleva `ensureEligibleForTeardown()`. NO uniformar los dos gates sin leer esto: «restaurar» el
//  gate único aquí reintroduce la retención de PII en silencio.
//
//  DECISIÓN DE DISEÑO — `createGroup` es SERVER-FIRST: el RPC `create_group` crea el grupo Y su fila owner
//  server-side; SOLO a éxito se materializa el `SplitGroup` + `SplitMember` locales. Garantiza que el grupo
//  existe server-side ANTES de cualquier delta de meta del drain (cierra por diseño el residual de b86dbf1c:
//  la purga del noop `group_not_found` en `applyResults` SE MANTIENE — protege del retry-storm de meta de
//  grupos CloudKit legacy no migrados cuando el flag encienda). El save local va bajo
//  `GroupsSyncClient.outboxSaveAuthor` (echo-suppression: el server YA tiene meta+member vía el RPC → el
//  drain NO re-emite la meta inicial; el próximo pull reconcilia PATCH idempotente).
//
//  ── Y el corolario de ser server-first: la materialización va DESPUÉS del `await`, así que es del PULL ──
//  Server-first significa que entre «el servidor ya tiene el grupo» y «este device lo inserta» hay un punto
//  de suspensión. `createGroup` es `@MainActor` y el ciclo de sync de Grupos corre en el MISMO actor, así que
//  un pull puede aterrizar ahí y ver un grupo que server-side ya existe: `GroupsSyncClient.applyGroupMeta`
//  resuelve por ZONA, la encuentra VACÍA (la fila local todavía no se ha insertado) e inserta una born-remote
//  del mismo `group_id`. Insertar a ciegas al reanudar dejaba una SEGUNDA fila de la misma zona — duplicado
//  de canal HOMOGÉNEO (las dos con `isBackendGroup = true`), que los gates ANY-row toleran pero que el
//  usuario VE (`fetchAllGroups` no lleva predicado) hasta el dedup del siguiente arranque.
//
//  ⇒ **toda materialización local de este service resuelve por la identidad de su entidad DESPUÉS del
//  `await`, nunca antes**: la ZONA para el `SplitGroup`, `(zona, member_key)` para el `SplitMember`. Es el
//  mismo molde que `GroupService.ensureCurrentUserMemberExists`, cuyo fetch de members va detrás de su
//  propio `await` y por eso nunca tuvo este defecto.
//
//  **NO se reserva la fila ANTES del RPC**, que es la otra forma de cerrar la ventana: rompería el
//  invariante «RPC falla ⇒ cero inserts» (pinneado por `createGroup_rpcError_leavesContextUntouched`) y
//  dejaría un grupo FANTASMA —local, `isBackendGroup = true`, inexistente server-side, cuyos gastos el push
//  rechazaría— si el RPC es rechazado o el proceso muere entre el insert y la respuesta. Un fantasma no se
//  recupera solo; un duplicado sí lo colapsa el dedup. Se elige el fallo reversible.
//

import Foundation
import OSLog
import SwiftData

@MainActor
final class GroupBackendMembershipService {

    private let client: GroupsMembershipClient
    private let sessionCheck: @MainActor () -> Bool
    private let logger = Logger(subsystem: "com.yala.app", category: "GroupsMembership")

    init(
        client: GroupsMembershipClient,
        sessionCheck: @escaping @MainActor () -> Bool = { CloudAuthService.shared.hasSession }
    ) {
        self.client = client
        self.sessionCheck = sessionCheck
    }

    /// Gate compartido de las ENTRADAS: sin canal O sin sesión → `sessionExpired` sin request ni
    /// mutación. Lee el getter COMPUESTO a propósito — es lo que el kill-switch remoto debe cortar.
    private func ensureEligible() throws {
        guard CloudSyncFlags.groupsBackendEnabled, sessionCheck() else {
            throw GroupsRPCError.sessionExpired
        }
    }

    /// Gate del TEARDOWN (`forgetUser`, ver la excepción del header): capacidad COMPILADA + sesión.
    /// El `sessionCheck()` NO es opcional aquí — sin él se perdería el invariante «ni red ni contexto
    /// antes del gate» y la llamada entraría a la red para morir en el guard del `tokenProvider`.
    private func ensureEligibleForTeardown() throws {
        guard CloudSyncFlags.groupsBackendCompiledCapability, sessionCheck() else {
            throw GroupsRPCError.sessionExpired
        }
    }

    // MARK: - create_group (SERVER-FIRST)

    /// Crea el grupo server-side vía RPC y, SOLO a éxito, materializa el `SplitGroup` (isOwner) + su
    /// `SplitMember` owner localmente. RPC falla → throw SIN tocar el contexto (cero inserts). El save va bajo
    /// `outboxSaveAuthor` (el server ya tiene el grupo+owner; el drain no debe re-emitir la meta inicial).
    ///
    /// La materialización es IDEMPOTENTE por identidad y se resuelve tras el `await` del RPC: si un pull
    /// aterrizó en esa ventana y ya materializó la zona (y/o el member owner), se ADOPTAN esas filas en vez
    /// de insertar gemelas. Ver el bloque del header sobre la ventana del `await`.
    func createGroup(
        name: String,
        iconName: String = "person.2.fill",
        colorHex: String = "#8B5CF6",
        currencyCode: String,
        displayName: String,
        defaultSplitType: String = "equal",
        simplifyDebts: Bool = false,
        showDebtsInSingleCurrency: Bool = false,
        membersCanInvite: Bool = false,
        context: ModelContext
    ) async throws -> SplitGroup {
        try ensureEligible()

        // Grupo local CONSTRUIDO pero NO insertado: su `init` genera `cloudKitZoneID` ("SplitGroup-{uuid}")
        // = la identidad server-side (`p_group_id`).
        let group = SplitGroup(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            currencyCode: currencyCode,
            simplifyDebts: simplifyDebts,
            isOwner: true,
            showDebtsInSingleCurrency: showDebtsInSingleCurrency,
            defaultSplitType: defaultSplitType,
            membersCanInvite: membersCanInvite
        )
        // C1 write-site (1): grupo del canal BACKEND → particiona enqueue/drain/routing (C2-C5).
        group.isBackendGroup = true
        let zoneID = group.cloudKitZoneID

        // RPC PRIMERO. Un throw aquí NO ha tocado el contexto todavía.
        let result = try await client.createGroup(
            groupID: zoneID,
            name: name,
            currencyCode: currencyCode,
            iconName: iconName,
            colorHex: colorHex,
            displayName: displayName,
            defaultSplitType: defaultSplitType,
            simplifyDebts: simplifyDebts,
            showDebtsInSingleCurrency: showDebtsInSingleCurrency,
            membersCanInvite: membersCanInvite
        )

        // A partir de aquí el pull PUDO correr (ver el header). Todo lo que sigue resuelve por identidad
        // antes de insertar, y va entero dentro del mismo `saveUnderOutboxAuthor`.
        return try saveUnderOutboxAuthor(context) {
            // GRUPO — identidad = la ZONA. Con filas ya presentes (born-remote del pull) se adoptan TODAS,
            // criterio ANY-row de la familia; la que se devuelve es la CANÓNICA (más antigua por `createdAt`,
            // el mismo criterio de `GroupService.group(for:)` y de `GroupsSyncClient.fetchSplitGroupRows`, o
            // el deep-link aterrizaría en una fila distinta de la que muestra la UI).
            let zoneRows = try Self.groupRows(zoneID: zoneID, context: context)
            if zoneRows.isEmpty {
                context.insert(group)
            }
            let groupRows = zoneRows.isEmpty ? [group] : zoneRows
            for row in groupRows {
                // Lo que el pull NO escribe y por eso hay que escribir aquí: `applyGroupMeta` deja `isOwner`
                // intacto A PROPÓSITO (es por fila, default `false`) ⇒ adoptar sin ponerlo dejaba al creador
                // sin poder invitar, renombrar ni transferir su propio grupo. `isBackendGroup` ya viene `true`
                // del born-remote; se reafirma porque la rama de inserción también pasa por aquí.
                row.isOwner = true
                row.isBackendGroup = true
                // La rama born-remote de `applyGroupMeta` arma la ventana de supresión de notificaciones de
                // membresía («los miembros preexistentes de esta zona vienen detrás»). Para el creador eso es
                // FALSO —es el único miembro— y el camino sin carrera deja el campo `nil`. Limpiarlo es lo
                // que hace que el resultado no dependa de quién ganó la carrera; de paso desbloquea el
                // `zoneIsSettled` de `OrphanedBridgedTxSweeper`, que exige `nil` como evidencia de zona
                // asentada. La meta del wire (nombre, icono, divisa…) NO se pisa: su autoridad es el
                // servidor y el pull acaba de escribir exactamente lo que este RPC le mandó.
                row.initialMemberImportStartedAt = nil
            }

            // OWNER MEMBER — identidad = (zona, `member_key`), la misma que usa el apply del pull
            // (`GroupsSyncClient.fetchSplitMember`). El born-remote deriva su `id` del MISMO
            // `deterministicMemberID`, así que adoptarlo conserva la identidad local; reescribir el `id` de
            // una fila existente rompería las referencias que ya cuelguen de ella.
            let memberRows = try Self.memberRows(
                zoneID: zoneID, memberKey: result.memberKey, context: context)
            if memberRows.isEmpty {
                // Identidad del namespace BACKEND; `memberKey`/`userID` = el `member_key` del server (= sub);
                // `cloudKitUserRecordID` se queda "" (separación de canales — el sub jamás contamina CloudKit).
                let owner = SplitMember(
                    groupZoneID: zoneID,
                    displayName: displayName,
                    cloudKitUserRecordID: "",
                    role: "admin",
                    status: .active,
                    isGroupOwner: true,
                    isCurrentUser: true
                )
                owner.id = GroupBackendIdentityLogic.deterministicMemberID(
                    groupID: zoneID, memberKey: result.memberKey)
                owner.memberKey = result.memberKey
                owner.userID = result.memberKey
                context.insert(owner)
            } else {
                // `isCurrentUser`/`isGroupOwner` son DEVICE-LOCAL: `applyMember` no los escribe nunca (el
                // wire no los lleva), así que una fila born-remote adoptada sin esto deja al creador sin su
                // propio balance y fuera de `eligibleGroupsForExpense`. `displayName`, `role`, `status` y
                // `userID` sí los manda el servidor y son suyos: no se pisan.
                for row in memberRows {
                    row.isCurrentUser = true
                    row.isGroupOwner = true
                }
            }
            // La CANÓNICA de la zona, o la recién insertada si la zona no existía.
            return zoneRows.first ?? group
        }
    }

    // MARK: - Resolución por identidad (post-`await`)

    /// TODAS las filas de la zona, `createdAt` ASC. SIN truncar a una: existen `SplitGroup` distintos con el
    /// mismo `cloudKitZoneID` (`SplitGroupDeduplicationService`) y elegir una arbitraria es justo el molde
    /// que esta familia de fixes retiró. Gemelo de `GroupsSyncClient.fetchSplitGroupRows`.
    private static func groupRows(zoneID: String, context: ModelContext) throws -> [SplitGroup] {
        try context.fetch(FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
    }

    /// Filas del member por (zona, `member_key`). Igualdad exacta sobre el opcional — patrón seguro de la
    /// regla `#Predicate` (nada de coalesce ni `localizedStandardContains` sobre opcionales). SIN el
    /// fallback legacy por `cloudKitUserRecordID` que hace el apply del pull: el creador de un grupo NUEVO
    /// no puede tener filas CloudKit preexistentes en una zona que acaba de nacer.
    private static func memberRows(
        zoneID: String, memberKey: String, context: ModelContext
    ) throws -> [SplitMember] {
        try context.fetch(FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.memberKey == memberKey }))
    }

    // MARK: - RPC passthrough (no materializan localmente — el pull reconcilia)

    /// RPC only: el pull trae grupo + members (join síncrono server-side); NO materializa nada local.
    func join(token: String, displayName: String, legacyMemberKey: String?) async throws -> JoinGroupResult {
        try ensureEligible()
        return try await client.joinGroup(
            token: token, displayName: displayName, legacyMemberKey: legacyMemberKey)
    }

    func approve(groupID: String, memberKey: String) async throws -> MemberActionResult {
        try ensureEligible()
        return try await client.approveMember(groupID: groupID, memberKey: memberKey)
    }

    func remove(groupID: String, memberKey: String) async throws -> MemberActionResult {
        try ensureEligible()
        return try await client.removeMember(groupID: groupID, memberKey: memberKey)
    }

    func leave(groupID: String) async throws -> MemberActionResult {
        try ensureEligible()
        return try await client.leaveGroup(groupID: groupID)
    }

    func createInvite(groupID: String, ttlSeconds: Int, maxUses: Int?) async throws -> String {
        try ensureEligible()
        return try await client.createInvite(groupID: groupID, ttlSeconds: ttlSeconds, maxUses: maxUses)
    }

    func revokeInvite(token: String) async throws {
        try ensureEligible()
        try await client.revokeInvite(token: token)
    }

    func updateDisplayName(groupID: String, displayName: String) async throws -> UpdateDisplayNameResult {
        try ensureEligible()
        return try await client.updateMemberDisplayName(groupID: groupID, displayName: displayName)
    }

    /// TEARDOWN del borrado de cuenta (GDPR): anonimiza al caller en los grupos donde es miembro y
    /// transfiere o tombstonea los que posee. Gate por capacidad COMPILADA — es el único método de este
    /// service que NO se apaga con el kill remoto, y el header explica por qué.
    func forgetUser() async throws -> ForgetResult {
        try ensureEligibleForTeardown()
        return try await client.forgetUser()
    }

    /// D10: RPC only (transfiere el ownership al co-member elegible más antiguo). El pull reconcilia el nuevo
    /// owner/role local; el caller (orquestador batch) sale del grupo justo después.
    func transferOwnership(groupID: String) async throws -> TransferOwnershipResult {
        try ensureEligible()
        return try await client.transferOwnership(groupID: groupID)
    }

    // MARK: - Save helper

    /// Ejecuta `body` y hace `context.save()` bajo `GroupsSyncClient.outboxSaveAuthor`, restaurando el autor
    /// previo (echo-suppression: el drain descarta las transacciones con este autor).
    private func saveUnderOutboxAuthor<T>(_ context: ModelContext, _ body: () throws -> T) throws -> T {
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        defer { context.author = previous }
        let value = try body()
        try context.save()
        return value
    }
}
