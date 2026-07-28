//
//  GroupsIdentityPurgeGate.swift
//  Yala
//
//  C-3: qué se BORRA y qué se RETIENE del dominio Grupos cuando cambia la identidad de iCloud
//  (sign-out del Apple ID o switch de cuenta). Decisión PURA (`decide`/`decideForZone`) + adaptador de
//  filas (`apply`), molde `SplitSyncStartGate` / `GroupFreezeLogic` / `SplitGroupDeduplicationService`.
//
//  RACIONAL (decisión owner D1): la identidad de un grupo del canal BACKEND es el `sub` de la cuenta
//  Yala, NO el Apple ID del OS ⇒ cambiar de Apple ID no debe destruirlo. Borrarlo localmente es
//  PÉRDIDA PERMANENTE en este device: el cursor por-grupo del pull backend NO vive en el estado de
//  CKSyncEngine sino en `GroupSyncCursor.groupCursorsJSON` (GroupSyncCursor.swift:50), sobrevive a esta
//  limpieza, y el server solo manda deltas con `server_seq > cursor` (GroupsSyncClient.swift:1542-1574)
//  ⇒ nadie re-entrega las filas borradas. El cursor NO se toca a propósito: resetearlo reabriría el bug
//  del commit 31dded30 (la sesión Yala del usuario ANTERIOR sobrevive en su Keychain y su corpus
//  backend entero bajaría al device del nuevo). Filas retenidas + cursor vivo es el par COHERENTE.
//
//  DECIDE POR ZONA, NO POR FILA (crítico). Existen `SplitGroup` DISTINTOS con el MISMO `cloudKitZoneID`
//  — fenómeno documentado con servicio de limpieza en boot (`SplitGroupDeduplicationService`, invocado
//  en AppBootstrapper.swift:334) y canario en runtime (`SplitSyncManager.group(for:)`). El flip de canal
//  solo marca UNA fila de la zona (`GroupsSyncClient.fetchSplitGroup` usa `fetchLimit = 1`; el marcador
//  aterriza por `id == modelID`), así que un par MIXTO (una fila backend + su duplicado sin marcar) es
//  alcanzable. Los hijos se vinculan por `groupZoneID` (no `@Relationship`), de modo que borrar el
//  duplicado «por zona» vaciaría el grupo backend recién RETENIDO: la pérdida exacta que este gate
//  existe para cerrar, causada por el gate. Por eso: una ZONA pertenece al canal backend si CUALQUIERA
//  de sus filas cumple el predicado, y de una zona retenida no se borra NADA (los duplicados de fila los
//  resuelve `SplitGroupDeduplicationService` en el próximo boot, que es su trabajo).
//
//  D4 — la retención se ATA A LA SESIÓN DE NUBE. Retener solo tiene sentido si sigue viva la identidad
//  Yala que ancla esas filas: sin sesión no hay `sub` que las reclame, ni refresco, ni camino de vuelta
//  ⇒ el device borra como hoy. El seam es inyectable (`hasCloudSession`), molde
//  `GroupMigrationUploader.swift:57` / `GroupBackendMembershipService.swift:35`.
//
//  D4 · RESIDUAL RATIFICADO POR EL OWNER, dicho sin adornos: `hasSession` prueba que hay una sesión Yala
//  ALMACENADA, no que siga siendo el mismo humano — vive en el Keychain propio y sobrevive a un cambio
//  de Apple ID del OS. Si B toma el device por la vía del OS SIN pasar por «empiezo de cero» del Welcome
//  (el único camino que escribe el sello `groupsDomainSealedForFreshStart` y purga vía
//  `DataWipeService.wipeLocalGroupsDomain`), los grupos del canal backend de A quedan RETENIDOS y
//  visibles hasta que alguien cierre esa sesión. La barrera del handover sigue siendo «empiezo de cero»,
//  que borra el dominio ENTERO y NO pasa por este gate. Cerrarlo del todo exigiría persistir el `sub`
//  dueño del corpus y exigir que coincida con la sesión viva — fuera del alcance de C-3.
//
//  D1 — lo que la fila retenida PIERDE: TODA credencial de re-join.
//  - `backendReInviteToken`: credencial PORTADORA (TTL 1 año, `maxUses` nil). Se pone a nil.
//  - `rejoinRevokedAt`: la marca LOCAL-only que hace la revocación DURABLE. Sin ella el strip no dura:
//    `CKRecordTranslator.update` (:152) re-hidrata el token en el siguiente fetch del GroupMeta, y D2
//    (reset de los change tokens) GARANTIZA ese fetch. La misma marca corta la OTRA credencial:
//    `GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin` lee el `SplitMember` con `isCurrentUser`
//    de la zona (hijo de un grupo retenido ⇒ sobrevive) y cae al `cachedRecordName`; con la marca
//    devuelve nil y el re-join entra como member NUEVO (residual §9.3b ya documentado).
//  Coste aceptado: el CTA «vuelve a entrar» cae al alert genérico (`GroupsContainerView.swift:370-374`
//  y `GroupDetailView.swift:471-477` ya fallan cerrado con token nil). El camino de vuelta es una
//  invitación nueva del owner.
//
//  La revocación es LOCAL, no server-side: el invite sigue vivo en el backend (RPC con TTL 1 año y
//  `maxUses` nil) y en el `GroupMeta` cifrado de la zona CloudKit del owner. Lo que este gate garantiza
//  es que ESTE device no lo vuelve a ofrecer. Revocarlo de verdad exige un RPC de expiración — G4-invites.
//
//  Lo que NO se toca de la fila retenida, a propósito:
//  - `ckSystemFieldsData`: limpiarlo pondría `SplitSyncStartGate.needsZoneRecovery` en `true` y el
//    recovery del boot RE-CREARÍA la zona en el iCloud del Apple ID NUEVO — la fuga contraria.
//  - `isBackendGroup` / `movedToBackendAt`: son los discriminadores de canal; borrarlos volvería la
//    fila indistinguible de un grupo CloudKit y re-elegible para el borrado del próximo evento.
//
//  `markerEnqueuedFlag` SÍ se re-arma (`false`) en las filas de OWNER migrado: D2 recrea los engines
//  con `state: nil`, o sea que el pending change del marcador se va con el estado viejo. Dejar el flag
//  en `true` sería afirmar «ya está encolado» sobre una cola que ya no existe ⇒ los devices de los
//  members NUNCA reciben el marcador, no congelan y siguen escribiendo en una zona CloudKit cuya verdad
//  se mudó al backend (pérdida silenciosa y PERMANENTE). El coste opuesto está acotado: bajo un Apple ID
//  nuevo el re-encolado falla con `zoneNotFound` y `SplitSyncManager.handleZoneNotFound` (:2048-2052) ya
//  salta los grupos backend y purga el pending save, sin tocar datos.
//
//  NO lee `CloudSyncFlags.groupsBackendEnabled` a propósito: un kill remoto del flag no puede volver
//  borrable un corpus ya migrado. Y NO es cierto que «con el flag OFF esto sea no-op»:
//  `movedToBackendAt` viaja por CloudKit y `CKRecordTranslator` (:127 y :151) lo aplica SIN consultar
//  el flag, así que en cuanto un solo owner migre, devices con el flag OFF tendrán copias congeladas.
//  Lo que lo hace inocuo HOY es otra cosa: `groupsBackendCompiledDefault = false` (CloudSyncFlags
//  .swift:239) en TODO device ⇒ nadie puede mintar el marcador. Con D4, el enunciado correcto es:
//  «sin sesión de nube el device se comporta como hoy».
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum GroupsIdentityPurgeGate {

    #if DEBUG
    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")
    #endif

    // MARK: - Decisión PURA

    enum Outcome: Equatable {
        /// Zona del canal CloudKit puro (o sin sesión de nube): sus datos viven en la private/shared DB
        /// del Apple ID que se va ⇒ se borran enteros (privacidad — es lo que arregló 31dded30).
        case deleteLocalRows
        /// Zona del canal BACKEND con sesión de nube viva: su verdad vive en el backend bajo el `sub` de
        /// la cuenta Yala ⇒ se conserva, SIN ninguna credencial de re-join (D1).
        case retainRevokingRejoinCredentials
    }

    /// Pertenencia al canal BACKEND en sentido AMPLIO: `isBackendGroup` (dueño backend, born-remote o
    /// adoptado) **o** `movedToBackendAt != nil` (copia CONGELADA — el marcador viajó por CloudKit y el
    /// miembro aún no re-joineó). D1 nombra AMBAS formas.
    ///
    /// OJO: este predicado es el de RETENCIÓN. NO es el predicado correcto para decidir si un grupo
    /// puede escribir a CKSyncEngine: ahí hay que usar `isBackendGroup || isMigratedFrozen`
    /// (`GroupFreezeLogic.isFrozen`), porque su mitigación #9 trata a propósito como NO congelado al
    /// owner tras un reinstall (`movedToBackendAt != nil && ckSystemFieldsData != nil`) y ampliar el
    /// predicado crudo le quitaría su último camino de subida.
    static func belongsToBackendChannel(isBackendGroup: Bool, movedToBackendAt: Date?) -> Bool {
        isBackendGroup || movedToBackendAt != nil
    }

    /// Decisión de una ZONA (la unidad real: los hijos se vinculan por `groupZoneID`). Una zona con
    /// duplicados pertenece al canal backend si CUALQUIERA de sus filas lo hace.
    static func decideForZone(
        rowsInZone: [(isBackendGroup: Bool, movedToBackendAt: Date?)],
        hasCloudSession: Bool
    ) -> Outcome {
        // D4: sin identidad Yala viva no hay nada que ancle la retención ⇒ se borra como hoy.
        guard hasCloudSession else { return .deleteLocalRows }
        let anyBackendRow = rowsInZone.contains {
            belongsToBackendChannel(isBackendGroup: $0.isBackendGroup, movedToBackendAt: $0.movedToBackendAt)
        }
        return anyBackendRow ? .retainRevokingRejoinCredentials : .deleteLocalRows
    }

    /// Conveniencia de una sola fila (zona sin duplicados).
    static func decide(isBackendGroup: Bool, movedToBackendAt: Date?, hasCloudSession: Bool) -> Outcome {
        decideForZone(
            rowsInZone: [(isBackendGroup: isBackendGroup, movedToBackendAt: movedToBackendAt)],
            hasCloudSession: hasCloudSession)
    }

    // MARK: - Adaptador de filas

    /// Los CUATRO primeros campos cuentan ZONAS (la unidad de la decisión);
    /// `credentialsRevoked` / `markersReQueued` / `pendingJoinsRevoked` cuentan FILAS e intents
    /// afectados — una zona con duplicado puede aportar más de uno.
    struct Result: Equatable {
        /// Zonas retenidas con alguna fila `isBackendGroup` (dueño backend).
        var retainedOwnedZones = 0
        /// Zonas retenidas que son copia CONGELADA de miembro (`movedToBackendAt != nil`, sin fila backend).
        var retainedFrozenZones = 0
        var deletedZones = 0
        /// Zonas del canal CloudKit cuyo borrado de hijos falló (borrado PARCIAL: el `SplitGroup` sí se fue).
        var failedZones = 0
        var credentialsRevoked = 0
        var markersReQueued = 0
        var pendingJoinsRevoked = 0
    }

    /// Barrido de FILAS del cambio de identidad. Separado del primitivo del manager para poder testearse
    /// con un `ModelContext` in-memory (molde `DataWipeService.wipeLocalGroupsDomain`) sin instanciar
    /// `SplitSyncManager` ni CloudKit. NO salva: el caller hace UN `save()` con su `SaveBreadcrumb`.
    ///
    /// Los seams llevan `@MainActor` en el TIPO del parámetro y no solo en la función porque los valores
    /// por defecto se evalúan en el contexto del CALLER (misma razón que documenta
    /// `DataWipeService.wipeLocalGroupsDomain`).
    static func apply(
        in context: ModelContext,
        now: () -> Date = { .now },
        hasCloudSession: @MainActor () -> Bool = { CloudAuthService.shared.hasSession },
        revokePendingJoinCredential: @MainActor (String) -> Int = {
            PendingJoinStore.revokeLegacyMemberKey(zoneName: $0)
        }
    ) throws -> Result {
        var result = Result()
        // UNA sola lectura: la decisión no puede cambiar a mitad del barrido.
        let session = hasCloudSession()
        let revokedAt = now()
        let byZone = Dictionary(
            grouping: try context.fetch(FetchDescriptor<SplitGroup>()), by: \.cloudKitZoneID)

        for (zoneName, rows) in byZone {
            let outcome = decideForZone(
                rowsInZone: rows.map {
                    (isBackendGroup: $0.isBackendGroup, movedToBackendAt: $0.movedToBackendAt)
                },
                hasCloudSession: session)

            switch outcome {
            case .retainRevokingRejoinCredentials:
                if rows.contains(where: \.isBackendGroup) {
                    result.retainedOwnedZones += 1
                } else {
                    result.retainedFrozenZones += 1
                }
                for row in rows {
                    // Sobre TODAS las filas de la zona: si solo se revocara la marcada, el duplicado
                    // conservaría el token y el pull lo re-hidrataría por ahí.
                    row.backendReInviteToken = nil
                    if row.rejoinRevokedAt == nil {
                        row.rejoinRevokedAt = revokedAt
                        result.credentialsRevoked += 1
                    }
                    // Solo el OWNER migrado: su marcador vivía en `engine.state`, que D2 tira.
                    if row.isBackendGroup, row.movedToBackendAt != nil, row.markerEnqueuedFlag {
                        row.markerEnqueuedFlag = false
                        result.markersReQueued += 1
                    }
                }
                // El intent de join pendiente de esta zona pierde su `legacyMemberKey` (rebind
                // server-side de la membresía CloudKit-era) pero conserva el `inviteToken`: un join en
                // vuelo se completa igual, entrando como member NUEVO.
                result.pendingJoinsRevoked += revokePendingJoinCredential(zoneName)

            case .deleteLocalRows:
                if deleteRows(inZone: zoneName, groups: rows, context: context) {
                    result.deletedZones += 1
                } else {
                    result.failedZones += 1
                }
            }
        }
        return result
    }

    /// Borra las filas de la zona y sus 4 tipos hijos. La zona sale de `cloudKitZoneID` (el valor REAL de
    /// la fila), NO de `CKConstants.zoneName(for: group.id)`: esa derivación solo vale para los grupos
    /// nacidos en CloudKit — un born-remote del pull backend se inserta con `SplitGroup()` (id nuevo) y se
    /// le PISA el `cloudKitZoneID` con el `group_id` del server (`GroupsSyncClient.applyGroupMeta`), así
    /// que derivar dejaría huérfanos a todos sus hijos (el bug colateral de hoy).
    ///
    /// El `SplitGroup` se borra PRIMERO (paridad exacta con `deleteGroupCache`, :2079-2082): si un fetch
    /// de hijos lanza, lo que queda son huérfanos invisibles — JAMÁS un grupo del usuario anterior
    /// visible en la lista, que es el fix de 31dded30. Devuelve `false` en ese caso para que el caller lo
    /// cuente aparte y el breadcrumb delate el borrado parcial en campo.
    private static func deleteRows(
        inZone zoneName: String, groups: [SplitGroup], context: ModelContext
    ) -> Bool {
        for group in groups { context.delete(group) }
        do {
            for member in try context.fetch(
                FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                context.delete(member)
            }
            for share in try context.fetch(
                FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                context.delete(share)
            }
            for expense in try context.fetch(
                FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                context.delete(expense)
            }
            for settlement in try context.fetch(
                FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                context.delete(settlement)
            }
            return true
        } catch {
            // Paridad con `deleteGroupCache`: log DENTRO de `#if DEBUG` y sin `localizedDescription`
            // público. El rastro de campo lo da el breadcrumb del caller (counts, sin PII).
            #if DEBUG
            logger.error("GroupsIdentityPurgeGate: borrado de hijos falló en una zona: \(error)")
            #endif
            return false
        }
    }
}
