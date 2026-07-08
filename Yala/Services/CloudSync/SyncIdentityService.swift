//
//  SyncIdentityService.swift
//  Yala
//
//  Asigna y reconcilia identidades de sync (`syncID`) para las 6 entidades sincronizables
//  (Modo Nube, incremento I2). Dos responsabilidades:
//
//  1. `ensureSyncID` / `captureIfEnabled` — born-cloud: acuñar un UUIDv4 en la fila al crearse.
//     `captureIfEnabled` está gateado por `CloudSyncFlags.identityCaptureEnabled` (HOY siempre
//     `false`); es el que invocan los hubs de creación, así que es un no-op en producción actual.
//
//  2. `backfillIdentities` — la MIGRACIÓN (I10) es el llamador: recorre las filas preexistentes,
//     les asigna `syncID` y materializa la fila testigo `SyncIdentity`, con REBIND por ancla de
//     contenido (recupera el `syncID` de una fila borrada+recreada con el mismo contenido).
//     Born-cloud NO hace backfill masivo (las filas ya nacen con identidad vía el hub).
//
//  Idempotente y resumible: dos corridas producen el mismo resultado (una vez asignados los
//  `syncID`, la segunda no cambia nada). Cubre también el caso de una fila que YA tiene `syncID`
//  pero sin fila testigo (crash a mitad de una migración previa) → crea la testigo sin regenerar.
//
//  `@MainActor`: manipula `ModelContext` y `@Model` (regla inviolable del repo).
//

import Foundation
import SwiftData

// MARK: - SyncIdentifiable

/// Entidades que llevan un `syncID` de sync. `@MainActor` porque los `@Model` conformes están
/// aislados al main actor bajo `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
@MainActor
protocol SyncIdentifiable: AnyObject {
    var syncID: UUID? { get set }
}

extension TransactionItem: SyncIdentifiable {}
extension InboxDraft: SyncIdentifiable {}
extension Category: SyncIdentifiable {}
extension FavoritePayment: SyncIdentifiable {}
extension MerchantMemory: SyncIdentifiable {}
extension ExchangeRate: SyncIdentifiable {}

// MARK: - SyncIdentityService

@MainActor
enum SyncIdentityService {

    // MARK: Born-cloud (hubs de creación)

    /// Asigna un `syncID` (UUIDv4) si la fila aún no tiene. Idempotente: una segunda llamada no
    /// cambia el valor ya asignado.
    static func ensureSyncID(_ model: SyncIdentifiable) {
        if model.syncID == nil {
            model.syncID = UUID()
        }
    }

    /// Igual que `ensureSyncID` pero gateado por el flag DARK. Es lo que invocan los hubs de
    /// creación de entidades → hoy no-op (el flag es `false` en producción). Lo encenderá el Modo
    /// Nube en I12/I14.
    static func captureIfEnabled(_ model: SyncIdentifiable) {
        guard CloudSyncFlags.identityCaptureEnabled else { return }
        ensureSyncID(model)
    }

    // MARK: Backfill (migración I10)

    /// Recorre las 6 entidades sincronizables y garantiza que cada fila tenga `syncID` + su fila
    /// testigo `SyncIdentity`, con REBIND por ancla de contenido. Idempotente y resumible.
    ///
    /// - Parameters:
    ///   - context: contexto sobre el que fetchear/insertar (el mismo de la migración).
    ///   - now: inyectable para determinismo en tests (marca `createdAt`/`lastReboundAt`).
    static func backfillIdentities(context: ModelContext, now: Date = .now) {
        do {
            // Índice de identidades existentes por (entityType + ancla) para el rebind, y set de
            // syncIDs ya cubiertos por una fila testigo (para detectar filas con id pero sin testigo).
            var rowsByKey: [String: SyncIdentity] = [:]
            var knownSyncIDs: Set<UUID> = []
            let existingRows = try context.fetch(FetchDescriptor<SyncIdentity>())
            for row in existingRows {
                rowsByKey[key(row.entityType, row.localAnchor)] = row
                knownSyncIDs.insert(row.syncID)
            }

            try backfillType(
                TransactionItem.self, entityType: SyncEntityType.transactionItem,
                anchor: anchor(for:), context: context, now: now,
                rowsByKey: &rowsByKey, knownSyncIDs: &knownSyncIDs
            )
            try backfillType(
                InboxDraft.self, entityType: SyncEntityType.inboxDraft,
                anchor: anchor(for:), context: context, now: now,
                rowsByKey: &rowsByKey, knownSyncIDs: &knownSyncIDs
            )
            try backfillType(
                Category.self, entityType: SyncEntityType.category,
                anchor: anchor(for:), context: context, now: now,
                rowsByKey: &rowsByKey, knownSyncIDs: &knownSyncIDs
            )
            try backfillType(
                FavoritePayment.self, entityType: SyncEntityType.favoritePayment,
                anchor: anchor(for:), context: context, now: now,
                rowsByKey: &rowsByKey, knownSyncIDs: &knownSyncIDs
            )
            try backfillType(
                MerchantMemory.self, entityType: SyncEntityType.merchantMemory,
                anchor: anchor(for:), context: context, now: now,
                rowsByKey: &rowsByKey, knownSyncIDs: &knownSyncIDs
            )
            try backfillType(
                ExchangeRate.self, entityType: SyncEntityType.exchangeRate,
                anchor: anchor(for:), context: context, now: now,
                rowsByKey: &rowsByKey, knownSyncIDs: &knownSyncIDs
            )

            if context.hasChanges {
                try context.save()
            }
        } catch {
            #if DEBUG
            print("SyncIdentityService: backfill error: \(error)")
            #endif
        }
    }

    /// Procesa un tipo concreto. Fetch CONCRETO por tipo (nunca genérico sobre keypath de protocolo
    /// — regla inviolable de `#Predicate`): traemos TODAS las filas del tipo y partimos en Swift
    /// (evita las esquinas de `== nil` sobre `UUID?` en `#Predicate` y cubre de una los dos casos:
    /// sin `syncID` y con `syncID` pero sin testigo).
    private static func backfillType<T: PersistentModel & SyncIdentifiable>(
        _ type: T.Type,
        entityType: String,
        anchor: (T) -> String,
        context: ModelContext,
        now: Date,
        rowsByKey: inout [String: SyncIdentity],
        knownSyncIDs: inout Set<UUID>
    ) throws {
        let models = try context.fetch(FetchDescriptor<T>())
        for model in models {
            if let existingID = model.syncID {
                // Ya tiene identidad. Garantizar que exista su fila testigo (crash a mitad de una
                // migración previa dejó la fila con id pero sin testigo) — SIN regenerar el id.
                guard !knownSyncIDs.contains(existingID) else { continue }
                let contentAnchor = anchor(model)
                let row = SyncIdentity(
                    syncID: existingID, entityType: entityType,
                    localAnchor: contentAnchor, createdAt: now
                )
                context.insert(row)
                rowsByKey[key(entityType, contentAnchor)] = row
                knownSyncIDs.insert(existingID)
            } else {
                let contentAnchor = anchor(model)
                let anchorKey = key(entityType, contentAnchor)
                if let existing = rowsByKey[anchorKey] {
                    // REBIND: reusar el syncID de una identidad con el mismo (entityType, ancla).
                    model.syncID = existing.syncID
                    existing.lastReboundAt = now
                } else {
                    let newID = UUID()
                    model.syncID = newID
                    let row = SyncIdentity(
                        syncID: newID, entityType: entityType,
                        localAnchor: contentAnchor, createdAt: now
                    )
                    context.insert(row)
                    rowsByKey[anchorKey] = row
                    knownSyncIDs.insert(newID)
                }
            }
        }
    }

    // MARK: - Anclas por tipo (extracción de valores + delegación a la capa pura)

    private static func anchor(for model: TransactionItem) -> String {
        SyncContentAnchor.transactionItem(
            createdAt: model.createdAt,
            date: model.date,
            amount: model.amount,
            currencyCode: model.currencyCode,
            accountShortcutID: model.account?.shortcutID
        )
    }

    private static func anchor(for model: InboxDraft) -> String {
        SyncContentAnchor.inboxDraft(
            createdAt: model.createdAt,
            sourceTypeRaw: model.sourceTypeRaw,
            rawText: model.rawText
        )
    }

    private static func anchor(for model: Category) -> String {
        SyncContentAnchor.category(name: model.name)
    }

    private static func anchor(for model: FavoritePayment) -> String {
        SyncContentAnchor.favoritePayment(
            name: model.name,
            amount: model.amount,
            createdAt: model.createdAt,
            displayOrder: model.displayOrder
        )
    }

    private static func anchor(for model: MerchantMemory) -> String {
        SyncContentAnchor.merchantMemory(merchantCanonical: model.merchantCanonical)
    }

    private static func anchor(for model: ExchangeRate) -> String {
        SyncContentAnchor.exchangeRate(dateKey: model.dateKey, base: model.base)
    }

    // MARK: - Helpers

    /// Clave de índice (entityType + ancla). Separador U+0001 (nunca aparece en un entityType
    /// literal ni en un hex de ancla).
    private static func key(_ entityType: String, _ anchor: String) -> String {
        entityType + "\u{1}" + anchor
    }
}
