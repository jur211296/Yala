//
//  SplitGroup.swift
//  Yala
//
//  Cache local del GroupMeta de CloudKit shared zone.
//  Fuente de verdad: CKRecord en zona compartida (CKSyncEngine).
//

import Foundation
import SwiftData

@Model
final class SplitGroup {
    // CloudKit: all properties must have defaults, no @Attribute(.unique)
    // `.preserveValueOnDeletion`: G2 usa `id` como sync_id local (dedup) y `cloudKitZoneID` como
    // `group_id` del wire (la identidad server-side de `split_groups`) → el history tombstone debe
    // conservarlos para emitir el borrado del grupo (metadata local; groups store `.none`, sin deploy).
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    @Attribute(.preserveValueOnDeletion) var cloudKitZoneID: String = ""       // "SplitGroup-{uuid}"
    var cloudKitZoneOwnerName: String = ""
    var name: String = ""
    var iconName: String = "person.2.fill"
    var colorHex: String = "#8B5CF6"
    var currencyCode: String = "PEN"
    var simplifyDebts: Bool = false
    var createdAt: Date = Date.now
    var isOwner: Bool = false
    var isArchived: Bool = false
    var isHiddenForAll: Bool = false      // FU-02: soft-delete invisible para todos (irreversible in-app)
    var defaultAccountID: UUID?           // ID ref, NO @Relationship (zonas distintas)
    var showDebtsInSingleCurrency: Bool = false
    var defaultSplitType: String = "equal" // "equal" | "percentage" | "exact" | "shares"
    var membersCanInvite: Bool = false
    var ckSystemFieldsData: Data?            // CKRecord system fields for conflict-free uploads
    /// Baseline del primer import de la zona (bug "Jür se unió al grupo"):
    /// seteado al INSERTAR el grupo vía fetch (applyGroupMeta rama NUEVO — invitado
    /// recién unido o reinstalación), limpiado cuando el engine completa el ciclo
    /// de fetch de la zona (`didFetchRecordZoneChanges`). Mientras esté vigente
    /// (< 15 min, auto-sana) se suprimen las notifs de membership de la zona.
    /// LOCAL-ONLY: no se mapea en CKRecordTranslator (store `.none`, sin deploy).
    var initialMemberImportStartedAt: Date?

    /// Discriminador de canal (G5-A): `true` = grupo del canal BACKEND (nace vía
    /// `GroupBackendMembershipService.createGroup` o el pull de `GroupsSyncClient.applyGroupMeta`);
    /// `false` = grupo CloudKit (CKSyncEngine). Particiona POR-GRUPO el enqueue a CKSyncEngine (C2), el
    /// drain del canal backend (C2-bis) y el routing de crear/invitar/membership (C3-C5) — con el flag
    /// `groupsBackendEnabled` OFF SIEMPRE es `false` (nadie lo pone `true`) → byte-idéntico.
    /// LOCAL-ONLY: JAMÁS en `CKRecordTranslator`/`CKConstants` (store `.none`, sin deploy CloudKit;
    /// precedente `SplitMember.userID`/`memberKey` de G3). NUNCA se emite al canal backend (no está en
    /// `GroupEntityEmissionMap.splitGroup` ni en `GroupMerkleProjection` — ambos son listas explícitas de
    /// columnas, no reflexión). CloudKit-safe: opcional-por-default `false`, sin `.unique`.
    var isBackendGroup: Bool = false

    /// G6-3 (marcador CloudKit): timestamp del CONGELAMIENTO del grupo tras la migración a backend
    /// (informativo — "cuándo se movió"; truthy-por-presencia). Lo escribe el owner en el paso 6 del
    /// `GroupMigrationUploader` y viaja por CloudKit (GroupMeta) para que los DEVICES DE LOS MIEMBROS lo
    /// reciban vía el pull normal de CKSyncEngine → derivan el estado CONGELADO (freeze + tarjeta "se movió").
    /// CloudKit-mapeado en `CKRecordTranslator` (viaja) — a diferencia de `isBackendGroup` (LOCAL-only).
    /// Freeze del MIEMBRO = `movedToBackendAt != nil && !isBackendGroup`; en el OWNER (`isBackendGroup=true`)
    /// NO congela (sus writes van al backend). CloudKit-safe: opcional.
    var movedToBackendAt: Date?

    /// G6-3: token de RE-INVITE (`create_group_invite`) que el owner minta al migrar y ESTAMPA en el marcador
    /// → viaja con `movedToBackendAt` para que el CTA "volver a entrar" del miembro tenga el token sin
    /// coordinación humana (decisión owner 2026-07-16; legible-por-members aceptable — el rebind cae en
    /// pendingApproval S1). ENCRYPTED en CloudKit (molde `name`). CloudKit-safe: opcional.
    var backendReInviteToken: String?

    /// G6-3 (C2, boot-reconciler ACOTADO): señal LOCAL-only del paso 6 del uploader — `false` mientras el
    /// marcador aún no quedó encolado a `engine.state` (durable en stateSerialization), `true` una vez
    /// encolado. El reconciler del boot re-encola SOLO `movedToBackendAt != nil && !markerEnqueuedFlag`
    /// (vacío en estado estable → sin write redundante del GroupMeta en cada boot). LOCAL-ONLY: JAMÁS en
    /// `CKRecordTranslator`/`CKConstants` (store `.none`, sin deploy). CloudKit-safe: opcional-por-default.
    var markerEnqueuedFlag: Bool = false

    /// C-3: instante en que ESTE DEVICE revocó las credenciales CloudKit-era de RE-JOIN del grupo, porque
    /// la identidad de iCloud cambió (sign-out / switch de Apple ID) y la fila se RETUVO por pertenecer al
    /// canal backend (D1). `nil` = sin revocar (todo device normal). Dos consumidores:
    /// (1) `CKRecordTranslator.update` NO re-hidrata `backendReInviteToken` desde el GroupMeta — sin esta
    ///     marca el strip local dura hasta el siguiente fetch de la zona, y D2 (reset de los change tokens)
    ///     GARANTIZA ese fetch; (2) `GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin` devuelve `nil`
    ///     — corta la OTRA credencial (el `cloudKitUserRecordID` del `SplitMember` con `isCurrentUser`, que
    ///     es hijo de un grupo retenido y por tanto sobrevive, y su fallback `cachedRecordName`).
    /// LOCAL-ONLY: JAMÁS en `CKRecordTranslator`/`CKConstants` (store `.none`, sin deploy CloudKit) ni en
    /// `GroupEntityEmissionMap`/`GroupMerkleProjection` (listas explícitas de columnas, no reflexión) —
    /// molde EXACTO de `isBackendGroup`/`markerEnqueuedFlag`. CloudKit-safe: opcional, sin `.unique`.
    var rejoinRevokedAt: Date?

    init(
        name: String = "",
        iconName: String = "person.2.fill",
        colorHex: String = "#8B5CF6",
        currencyCode: String = "PEN",
        simplifyDebts: Bool = false,
        isOwner: Bool = false,
        defaultAccountID: UUID? = nil,
        showDebtsInSingleCurrency: Bool = false,
        defaultSplitType: String = "equal",
        membersCanInvite: Bool = false
    ) {
        self.id = UUID()
        self.cloudKitZoneID = "\(CKConstants.zonePrefix)\(self.id.uuidString)"
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.currencyCode = currencyCode
        self.simplifyDebts = simplifyDebts
        self.createdAt = Date.now
        self.isOwner = isOwner
        self.defaultAccountID = defaultAccountID
        self.showDebtsInSingleCurrency = showDebtsInSingleCurrency
        self.defaultSplitType = defaultSplitType
        self.membersCanInvite = membersCanInvite
    }
}
