//
//  EntityApplyMap.swift
//  Yala
//
//  Mapa DECLARATIVO INVERSO de `EntityEmissionMap` (Modo Nube, incremento I8f-1): por entidad CABLEADA,
//  `columna Postgres → ColumnApplier` que decodifica el valor de wire (`WireValue`) y lo ESCRIBE en el
//  `@Model` local. Es el consumidor del pull (§d.6, D-7). Cobertura: SOLO las 6 entidades que hoy llevan
//  `syncID` local (TransactionItem/InboxDraft/Category/FavoritePayment/MerchantMemory/ExchangeRate); las
//  otras 10 tablas no tienen identidad local → sus deltas van a `SyncQuarantine` (las materializa el
//  apply, no este mapa). La tabla → `EntityApply` la resuelve `applyEntry(forTable:)`, espejo invertido
//  de `EntityEmissionMap.table(forClass:)`.
//
//  REGLAS (§d.7, D-7):
//   - **money/rate**: STRING decimal o número JSON → `Double` (`WireValueDecoder.double`). VERBATIM: el
//     grupo de coherencia `money` viaja entero y es AUTORITATIVO → JAMÁS `recalculatePreferredCurrency`
//     (machacaría el snapshot remoto — el "número mal convertido").
//   - **timestamps**: texto ISO → `Date` (`WireValueDecoder.date`, parse entero D-2c).
//   - **`local_day`**: derivada de `date` (no hay storage local) → NO tiene applier (se ignora).
//   - **refs**: `category_ref`/`approved_transaction_ref` → por `syncID`; `account_ref`/`subcategory_ref`
//     → por `shortcutID`; `scheduled_payment_ref` → `scheduledPaymentID` (String local, uppercase). Ref
//     que NO resuelve → `nil` + breadcrumb `applyDanglingRef` (NO canario: esperado con 6 entidades
//     cableadas; el CSV mirror preserva). Fetchers CONCRETOS por tipo (regla inviolable `#Predicate`).
//   - **tag_refs**: `[UUID]` del wire → `[Tag]` locales (`setTags`, dual-write M2M+CSV) y LUEGO el CSV se
//     sobrescribe con los UUIDs del WIRE COMPLETOS (no el subset resuelto) — CSV-first auto-cura cuando
//     el Tag llegue (gotcha CSV-stale del repo: el wire ES la verdad).
//   - **null explícito** → `nil` (columnas opcionales); **key ausente** → no se toca (el apply itera solo
//     las columnas presentes en `fields`).
//
//  `@MainActor`: los appliers/fetchers manipulan `@Model`/`ModelContext` (regla inviolable del repo).
//

import Foundation
import SwiftData

// MARK: - ColumnApplier / EntityApply

/// Aplicador de UNA columna: decodifica el `WireValue` y lo setea en el `@Model`.
@MainActor
struct ColumnApplier<Model: AnyObject> {
    let apply: (Model, WireValue, ModelContext) -> Void
    init(_ apply: @escaping (Model, WireValue, ModelContext) -> Void) { self.apply = apply }
}

/// Proyección inversa de una entidad cableada: tabla, factory born-remote, setter de `syncID`, fetch por
/// identidad, ancla de contenido (para la fila testigo `SyncIdentity`), el mapa columna→group (LWW
/// por-unidad, reusado de `EntityEmissionMap`) y los appliers por columna.
@MainActor
struct EntityApply<Model: PersistentModel> {
    let table: String
    /// NOMBRE DE CLASE (`SyncEntityType.*`, ej. `"TransactionItem"`) para la fila testigo `SyncIdentity`
    /// del born-remote (D-8). Distinto de `table` (Postgres) — invariante de rebind.
    let entityTypeName: String
    let make: (ModelContext) -> Model
    let setSyncID: (Model, UUID) -> Void
    let fetchBySyncID: (UUID, ModelContext) -> Model?
    let anchor: (Model) -> String
    let groupByColumn: [String: String]
    let appliers: [String: ColumnApplier<Model>]

    /// Unidad de coherencia de una columna = su grupo (si lo tiene) o la columna misma (singleton). Para
    /// el guard LWW por-unidad del apply (D-1).
    func unit(for column: String) -> String { groupByColumn[column] ?? column }
}

// MARK: - Factories de applier (reducen boilerplate; ReferenceWritableKeyPath concreto)

@MainActor
private enum Apply {
    /// money/rate → `Double` requerido (columna non-optional). `null`/no-parseable → no toca (default).
    static func moneyReq<M>(_ kp: ReferenceWritableKeyPath<M, Double>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in if let d = WireValueDecoder.double(v) { m[keyPath: kp] = d } }
    }
    /// money → `Double?` (columna optional). `null` → `nil`; número/string → valor.
    static func moneyOpt<M>(_ kp: ReferenceWritableKeyPath<M, Double?>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = WireValueDecoder.double(v) }
    }
    /// confidence (`Double?` almacenado, TEXT en el wire) → `Double?`.
    static func doubleTextOpt<M>(_ kp: ReferenceWritableKeyPath<M, Double?>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = WireValueDecoder.double(v) }
    }
    static func stringReq<M>(_ kp: ReferenceWritableKeyPath<M, String>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in if let s = WireValueDecoder.string(v) { m[keyPath: kp] = s } }
    }
    static func textOpt<M>(_ kp: ReferenceWritableKeyPath<M, String?>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = WireValueDecoder.string(v) }
    }
    static func boolReq<M>(_ kp: ReferenceWritableKeyPath<M, Bool>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in if let b = WireValueDecoder.bool(v) { m[keyPath: kp] = b } }
    }
    static func intReq<M>(_ kp: ReferenceWritableKeyPath<M, Int>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in if let i = WireValueDecoder.int(v) { m[keyPath: kp] = i } }
    }
    static func intOpt<M>(_ kp: ReferenceWritableKeyPath<M, Int?>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = WireValueDecoder.int(v) }
    }
    static func dateReq<M>(_ kp: ReferenceWritableKeyPath<M, Date>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in if let d = WireValueDecoder.date(v) { m[keyPath: kp] = d } }
    }
    static func dateOpt<M>(_ kp: ReferenceWritableKeyPath<M, Date?>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = WireValueDecoder.date(v) }
    }
    static func stringArrayReq<M>(_ kp: ReferenceWritableKeyPath<M, [String]>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = WireValueDecoder.stringArray(v) ?? [] }
    }
    /// FK guardada como `String?` local (`scheduledPaymentID`) — uuid del wire → uuidString (uppercase
    /// local-convention de Foundation); `null`/no-uuid → `nil`.
    static func refUUIDStringOpt<M>(_ kp: ReferenceWritableKeyPath<M, String?>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = WireValueDecoder.uuid(v)?.uuidString }
    }
}

// MARK: - EntityApplyMap

@MainActor
enum EntityApplyMap {

    // MARK: tx_items — TransactionItem

    static let transactionItem = EntityApply<TransactionItem>(
        table: "tx_items",
        entityTypeName: SyncEntityType.transactionItem,
        make: { ctx in
            let m = TransactionItem(date: .now, amount: 0, currencyCode: "USD")
            ctx.insert(m)
            return m
        },
        setSyncID: { $0.syncID = $1 },
        fetchBySyncID: { fetchTransactionItem(bySyncID: $0, context: $1) },
        anchor: { m in
            SyncContentAnchor.transactionItem(
                createdAt: m.createdAt, date: m.date, amount: m.amount,
                currencyCode: m.currencyCode, accountShortcutID: m.account?.shortcutID
            )
        },
        groupByColumn: EntityEmissionMap.transactionItem.groupByColumn,
        appliers: [
            "date": Apply.dateReq(\.date),
            // "local_day" → derivada de `date`, sin storage local (D-7): sin applier → se ignora.
            "amount": Apply.moneyReq(\.amount),
            "currency_code": Apply.stringReq(\.currencyCode),
            "note": Apply.textOpt(\.note),
            "category_ref": ColumnApplier { m, v, ctx in
                m.category = resolveRef(v, entity: "tx_items", column: "category_ref",
                                        rowSyncID: m.syncID, context: ctx) {
                    fetchCategory(bySyncID: $0, context: ctx)
                }
            },
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = resolveRef(v, entity: "tx_items", column: "subcategory_ref",
                                           rowSyncID: m.syncID, context: ctx) {
                    fetchSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "account_ref": ColumnApplier { m, v, ctx in
                m.account = resolveRef(v, entity: "tx_items", column: "account_ref",
                                       rowSyncID: m.syncID, context: ctx) {
                    fetchAccount(byShortcutID: $0, context: ctx)
                }
            },
            "tag_refs": ColumnApplier { m, v, ctx in applyTagRefs(v, into: m, setter: { m.setTags(from: $0) },
                                                                  csv: { m.tagIDs = $0 }, context: ctx) },
            "amount_in_preferred_currency": Apply.moneyReq(\.amountInPreferredCurrency),
            "preferred_currency_code": Apply.stringReq(\.preferredCurrencyCode),
            "exchange_rate": Apply.moneyReq(\.exchangeRate),
            "is_exchange_rate_provisional": Apply.boolReq(\.isExchangeRateProvisional),
            "need_override": Apply.textOpt(\.needOverride),
            "scheduled_payment_ref": Apply.refUUIDStringOpt(\.scheduledPaymentID),
            "balance_adjustment_type": Apply.textOpt(\.balanceAdjustmentType),
            "transfer_pair_id": Apply.textOpt(\.transferPairID),
            "split_expense_id": Apply.textOpt(\.splitExpenseID),
            "split_group_zone_id": Apply.textOpt(\.splitGroupZoneID),
            "split_settlement_id": Apply.textOpt(\.splitSettlementID),
            "split_total_amount": Apply.moneyOpt(\.splitTotalAmount),
            "split_type": Apply.textOpt(\.splitType),
            "split_my_value": Apply.moneyOpt(\.splitMyValue),
            "split_divisor": Apply.moneyOpt(\.splitDivisor),
            "created_at": Apply.dateReq(\.createdAt),
        ]
    )

    // MARK: inbox_drafts — InboxDraft

    static let inboxDraft = EntityApply<InboxDraft>(
        table: "inbox_drafts",
        entityTypeName: SyncEntityType.inboxDraft,
        make: { ctx in let m = InboxDraft(); ctx.insert(m); return m },
        setSyncID: { $0.syncID = $1 },
        fetchBySyncID: { fetchInboxDraft(bySyncID: $0, context: $1) },
        anchor: { m in
            SyncContentAnchor.inboxDraft(
                createdAt: m.createdAt, sourceTypeRaw: m.sourceTypeRaw, rawText: m.rawText
            )
        },
        groupByColumn: EntityEmissionMap.inboxDraft.groupByColumn,
        appliers: [
            "note": Apply.stringReq(\.note),
            "amount": Apply.moneyOpt(\.amount),
            "date": Apply.dateOpt(\.date),
            "account_ref": ColumnApplier { m, v, ctx in
                m.account = resolveRef(v, entity: "inbox_drafts", column: "account_ref",
                                       rowSyncID: m.syncID, context: ctx) {
                    fetchAccount(byShortcutID: $0, context: ctx)
                }
            },
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = resolveRef(v, entity: "inbox_drafts", column: "subcategory_ref",
                                           rowSyncID: m.syncID, context: ctx) {
                    fetchSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "tag_refs": ColumnApplier { m, v, ctx in applyTagRefs(v, into: m, setter: { m.setTags(from: $0) },
                                                                  csv: { m.tagIDs = $0 }, context: ctx) },
            "approved_transaction_ref": ColumnApplier { m, v, ctx in
                m.approvedTransaction = resolveRef(v, entity: "inbox_drafts", column: "approved_transaction_ref",
                                                   rowSyncID: m.syncID, context: ctx) {
                    fetchTransactionItem(bySyncID: $0, context: ctx)
                }
            },
            "source_type_raw": Apply.stringReq(\.sourceTypeRaw),
            "raw_text": Apply.textOpt(\.rawText),
            "evidence": Apply.textOpt(\.evidence),
            "confidence_amount": Apply.doubleTextOpt(\.confidenceAmount),
            "confidence_date": Apply.doubleTextOpt(\.confidenceDate),
            "confidence_merchant": Apply.doubleTextOpt(\.confidenceMerchant),
            "confidence_subcategory": Apply.doubleTextOpt(\.confidenceSubcategory),
            "needs_user_input": Apply.stringArrayReq(\.needsUserInput),
            "newly_created_tag_names": Apply.stringArrayReq(\.newlyCreatedTagNames),
            "status_raw": Apply.stringReq(\.statusRaw),
            "cached_account_name": Apply.textOpt(\.cachedAccountName),
            "cached_subcategory_name": Apply.textOpt(\.cachedSubcategoryName),
            "cached_category_color_hex": Apply.textOpt(\.cachedCategoryColorHex),
            "cached_subcategory_icon": Apply.textOpt(\.cachedSubcategoryIcon),
            "cached_currency_code": Apply.textOpt(\.cachedCurrencyCode),
            "source_scheduled_payment_ref": Apply.refUUIDStringOpt(\.sourceScheduledPaymentID),
            "split_expense_id": Apply.textOpt(\.splitExpenseID),
            "split_group_zone_id": Apply.textOpt(\.splitGroupZoneID),
            "split_settlement_id": Apply.textOpt(\.splitSettlementID),
            "opt_in_personal_only": Apply.boolReq(\.optInPersonalOnly),
            "origin_reason_key": Apply.textOpt(\.originReasonKey),
            "origin_actor_name": Apply.textOpt(\.originActorName),
            "origin_group_name": Apply.textOpt(\.originGroupName),
            "created_at": Apply.dateReq(\.createdAt),
            "updated_at_domain": Apply.dateReq(\.updatedAt),
        ]
    )

    // MARK: categories — Category

    static let category = EntityApply<Category>(
        table: "categories",
        entityTypeName: SyncEntityType.category,
        make: { ctx in
            let m = Category(name: "", colorHex: "#6366F1", isIncome: false, isDefaultSeed: false)
            ctx.insert(m)
            return m
        },
        setSyncID: { $0.syncID = $1 },
        fetchBySyncID: { fetchCategory(bySyncID: $0, context: $1) },
        anchor: { SyncContentAnchor.category(name: $0.name) },
        groupByColumn: EntityEmissionMap.category.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "color_hex": Apply.stringReq(\.colorHex),
            "is_income": Apply.boolReq(\.isIncome),
            "is_default_seed": Apply.boolReq(\.isDefaultSeed),
            "is_visible": Apply.boolReq(\.isVisible),
            "sort_order": Apply.intReq(\.sortOrder),
            "icon_name": Apply.textOpt(\.iconName),
            "is_system": Apply.boolReq(\.isSystem),
        ]
    )

    // MARK: favorite_payments — FavoritePayment

    static let favoritePayment = EntityApply<FavoritePayment>(
        table: "favorite_payments",
        entityTypeName: SyncEntityType.favoritePayment,
        make: { ctx in let m = FavoritePayment(name: ""); ctx.insert(m); return m },
        setSyncID: { $0.syncID = $1 },
        fetchBySyncID: { fetchFavoritePayment(bySyncID: $0, context: $1) },
        anchor: { m in
            SyncContentAnchor.favoritePayment(
                name: m.name, amount: m.amount, createdAt: m.createdAt, displayOrder: m.displayOrder
            )
        },
        groupByColumn: EntityEmissionMap.favoritePayment.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "transaction_type": Apply.stringReq(\.transactionType),
            "amount": Apply.moneyOpt(\.amount),
            "note": Apply.textOpt(\.note),
            "account_ref": ColumnApplier { m, v, ctx in
                m.account = resolveRef(v, entity: "favorite_payments", column: "account_ref",
                                       rowSyncID: m.syncID, context: ctx) {
                    fetchAccount(byShortcutID: $0, context: ctx)
                }
            },
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = resolveRef(v, entity: "favorite_payments", column: "subcategory_ref",
                                           rowSyncID: m.syncID, context: ctx) {
                    fetchSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "tag_refs": ColumnApplier { m, v, ctx in applyTagRefs(v, into: m, setter: { m.setTags(from: $0) },
                                                                  csv: { m.tagIDs = $0 }, context: ctx) },
            "need_override": Apply.textOpt(\.needOverride),
            "currency_code": Apply.textOpt(\.currencyCode),
            "created_at": Apply.dateReq(\.createdAt),
            "display_order": Apply.intReq(\.displayOrder),
        ]
    )

    // MARK: merchant_memory — MerchantMemory

    static let merchantMemory = EntityApply<MerchantMemory>(
        table: "merchant_memory",
        entityTypeName: SyncEntityType.merchantMemory,
        make: { ctx in let m = MerchantMemory(merchantCanonical: ""); ctx.insert(m); return m },
        setSyncID: { $0.syncID = $1 },
        fetchBySyncID: { fetchMerchantMemory(bySyncID: $0, context: $1) },
        anchor: { SyncContentAnchor.merchantMemory(merchantCanonical: $0.merchantCanonical) },
        groupByColumn: EntityEmissionMap.merchantMemory.groupByColumn,
        appliers: [
            "merchant_canonical": Apply.stringReq(\.merchantCanonical),
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = resolveRef(v, entity: "merchant_memory", column: "subcategory_ref",
                                           rowSyncID: m.syncID, context: ctx) {
                    fetchSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "count_approved": Apply.intReq(\.countApproved),
            "count_corrected": Apply.intReq(\.countCorrected),
            "last_approved_at": Apply.dateReq(\.lastApprovedAt),
            "aliases": Apply.stringArrayReq(\.aliases),
        ]
    )

    // MARK: exchange_rates — ExchangeRate

    static let exchangeRate = EntityApply<ExchangeRate>(
        table: "exchange_rates",
        entityTypeName: SyncEntityType.exchangeRate,
        make: { ctx in let m = ExchangeRate(dateKey: "", base: "USD", rates: Data()); ctx.insert(m); return m },
        setSyncID: { $0.syncID = $1 },
        fetchBySyncID: { fetchExchangeRate(bySyncID: $0, context: $1) },
        anchor: { SyncContentAnchor.exchangeRate(dateKey: $0.dateKey, base: $0.base) },
        groupByColumn: EntityEmissionMap.exchangeRate.groupByColumn,
        appliers: [
            "date_key": Apply.stringReq(\.dateKey),
            "base": Apply.stringReq(\.base),
            "rates": ColumnApplier { m, v, _ in if let d = WireValueDecoder.jsonData(v) { m.rates = d } },
            "timestamp": Apply.dateOpt(\.timestamp),
        ]
    )

    // MARK: - Resolución de un `_ref` (dangling → nil + breadcrumb + registro durable F-2)

    /// Decodifica un `WireValue` FK y lo resuelve con `fetch`. `null` → `nil` SIN breadcrumb (borrado
    /// legítimo del vínculo). `uuid` presente que NO resuelve (destino aún no sincronizado / no cableado)
    /// → `nil` + `applyDanglingRef` + **registro durable `SyncDanglingRef`** (F-2): con materialized-rows
    /// el orden por `server_seq` NO es causal (el destino puede llegar en una página POSTERIOR — una
    /// Category editada re-estampa un seq MAYOR que la TX que la referencia) y un crash entre páginas
    /// haría el huérfano PERMANENTE. El pase de re-resolución al final de `pullAndApplyOnce` lo cura.
    private static func resolveRef<T>(
        _ value: WireValue, entity: String, column: String, rowSyncID: UUID?,
        context: ModelContext, fetch: (UUID) -> T?
    ) -> T? {
        switch value {
        case .null:
            // El wire puso el vínculo a NULL → un dangler previo de esta (fila, columna) queda OBSOLETO
            // y DEBE borrarse (dejarlo re-adjuntaría una relación stale en la re-resolución y el Merkle
            // usaría un target que el server ya no tiene).
            if let rowSyncID { clearDangler(rowSyncID: rowSyncID, column: column, context: context) }
            return nil
        case .string(let s):
            guard let id = UUID(uuidString: s) else { return nil }
            let resolved = fetch(id)
            if resolved == nil {
                CloudSyncBreadcrumb.applyDanglingRef(entity: entity, column: column)
                if let rowSyncID {
                    registerDangler(entityTable: entity, rowSyncID: rowSyncID, column: column,
                                    targetUUID: id, context: context)
                }
            } else if let rowSyncID {
                // Resolvió en caliente → un dangler previo queda obsoleto (higiene simétrica).
                clearDangler(rowSyncID: rowSyncID, column: column, context: context)
            }
            return resolved
        default:
            return nil
        }
    }

    /// Borra el dangler de una (fila, columna) si existe — el wire lo dejó obsoleto (NULL explícito o
    /// resolución en caliente). No-op si no hay.
    private static func clearDangler(rowSyncID: UUID, column: String, context: ModelContext) {
        do {
            var d = FetchDescriptor<SyncDanglingRef>(
                predicate: #Predicate { $0.rowSyncID == rowSyncID && $0.column == column }
            )
            d.fetchLimit = 1
            if let existing = try context.fetch(d).first {
                context.delete(existing)
            }
        } catch {
            #if DEBUG
            print("EntityApplyMap.clearDangler error: \(error)")
            #endif
        }
    }

    /// Inserta/actualiza el registro durable de un ref colgado. Dedup por `(rowSyncID, column)`: si ya
    /// existe, REEMPLAZA el `targetUUID` (el delta más nuevo manda). El insert ocurre dentro del save de
    /// página del apply (autor del motor) → atómico con el cursor.
    private static func registerDangler(
        entityTable: String, rowSyncID: UUID, column: String, targetUUID: UUID, context: ModelContext
    ) {
        do {
            var d = FetchDescriptor<SyncDanglingRef>(
                predicate: #Predicate { $0.rowSyncID == rowSyncID && $0.column == column }
            )
            d.fetchLimit = 1
            if let existing = try context.fetch(d).first {
                existing.targetUUID = targetUUID
            } else {
                context.insert(SyncDanglingRef(entityTable: entityTable, rowSyncID: rowSyncID,
                                               column: column, targetUUID: targetUUID))
            }
        } catch {
            #if DEBUG
            print("EntityApplyMap.registerDangler error: \(error)")
            #endif
        }
    }

    // MARK: - Re-resolución de danglers (F-2, pase final de pullAndApplyOnce)

    /// Resultado del intento de re-resolver un dangler.
    enum DanglerOutcome {
        /// El destino ya es local → relación seteada. Borrar el dangler.
        case resolved
        /// La fila ORIGEN ya no existe (borrada/nunca llegó) → dangler obsoleto. Borrar.
        case rowGone
        /// El destino sigue sin existir → conservar el dangler (reintento en el próximo ciclo).
        case targetMissing
    }

    /// Intenta re-resolver UNA referencia colgada: fetch de la fila origen (dispatch concreto por tabla)
    /// + fetch del destino (por el tipo de la columna) + set de la relación. Solo cubre los `_ref`
    /// SINGULARES de las 6 entidades cableadas (`tag_refs` se auto-cura vía CSV mirror y NUNCA se
    /// registra; `scheduled_payment_ref`/`source_scheduled_payment_ref` tampoco — son String plano, sin
    /// relación que colgar).
    static func reresolveDangler(_ dangler: SyncDanglingRef, context: ModelContext) -> DanglerOutcome {
        let target = dangler.targetUUID
        switch (dangler.entityTable, dangler.column) {
        case (transactionItem.table, "category_ref"):
            guard let row = fetchTransactionItem(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchCategory(bySyncID: target, context: context) else { return .targetMissing }
            row.category = t
            return .resolved
        case (transactionItem.table, "subcategory_ref"):
            guard let row = fetchTransactionItem(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        case (transactionItem.table, "account_ref"):
            guard let row = fetchTransactionItem(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchAccount(byShortcutID: target, context: context) else { return .targetMissing }
            row.account = t
            return .resolved
        case (inboxDraft.table, "account_ref"):
            guard let row = fetchInboxDraft(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchAccount(byShortcutID: target, context: context) else { return .targetMissing }
            row.account = t
            return .resolved
        case (inboxDraft.table, "subcategory_ref"):
            guard let row = fetchInboxDraft(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        case (inboxDraft.table, "approved_transaction_ref"):
            guard let row = fetchInboxDraft(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchTransactionItem(bySyncID: target, context: context) else { return .targetMissing }
            row.approvedTransaction = t
            return .resolved
        case (favoritePayment.table, "account_ref"):
            guard let row = fetchFavoritePayment(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchAccount(byShortcutID: target, context: context) else { return .targetMissing }
            row.account = t
            return .resolved
        case (favoritePayment.table, "subcategory_ref"):
            guard let row = fetchFavoritePayment(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        case (merchantMemory.table, "subcategory_ref"):
            guard let row = fetchMerchantMemory(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = fetchSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        default:
            // Combinación desconocida (drift futuro) → tratar como obsoleto para no acumular basura.
            return .rowGone
        }
    }

    /// Aplica `tag_refs`: resuelve los `[UUID]` del wire a `[Tag]` locales (dual-write M2M+CSV vía
    /// `setter`) y LUEGO sobrescribe el CSV mirror con los UUIDs del WIRE COMPLETOS (`csv`) — preserva
    /// refs a tags aún no locales (CSV-first auto-cura; gotcha CSV-stale). `null` → sin tags.
    private static func applyTagRefs<M>(
        _ value: WireValue, into _: M, setter: ([Tag]) -> Void, csv: (String?) -> Void, context: ModelContext
    ) {
        let wireUUIDs = WireValueDecoder.uuidArray(value) ?? []
        let tags = fetchTags(byIDs: wireUUIDs, context: context)
        setter(tags)                                   // dual-write M2M + CSV (subset resuelto)
        csv(CSVMirrorCodec.encode(wireUUIDs))          // CSV = wire COMPLETO (SSOT; preserva no-locales)
    }

    // MARK: - Dispatch tabla → EntityApply (invierte EntityEmissionMap.table(forClass:))

    /// Las 6 tablas cableadas al apply (las que el cliente MATERIALIZA en v1). Consumidas también por
    /// la verificación Merkle (I8f-3, regla 5: solo estos entityHash se comparan).
    static var wiredTables: Set<String> {
        [transactionItem.table, inboxDraft.table, category.table,
         favoritePayment.table, merchantMemory.table, exchangeRate.table]
    }

    /// `true` si la tabla está cableada al apply (una de las 6). El apply consulta esto para decidir
    /// materializar vs cuarentenar; el dispatch concreto por tipo lo hace `SyncApplyEngine`.
    static func isWired(table: String) -> Bool {
        switch table {
        case transactionItem.table, inboxDraft.table, category.table,
             favoritePayment.table, merchantMemory.table, exchangeRate.table:
            return true
        default:
            return false
        }
    }

    // MARK: - Fetchers CONCRETOS por tipo (regla inviolable `#Predicate`: nunca genérico por protocolo)

    static func fetchTransactionItem(bySyncID id: UUID, context: ModelContext) -> TransactionItem? {
        fetchFirst(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchInboxDraft(bySyncID id: UUID, context: ModelContext) -> InboxDraft? {
        fetchFirst(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchCategory(bySyncID id: UUID, context: ModelContext) -> Category? {
        fetchFirst(FetchDescriptor<Category>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchFavoritePayment(bySyncID id: UUID, context: ModelContext) -> FavoritePayment? {
        fetchFirst(FetchDescriptor<FavoritePayment>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchMerchantMemory(bySyncID id: UUID, context: ModelContext) -> MerchantMemory? {
        fetchFirst(FetchDescriptor<MerchantMemory>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchExchangeRate(bySyncID id: UUID, context: ModelContext) -> ExchangeRate? {
        fetchFirst(FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchAccount(byShortcutID id: UUID, context: ModelContext) -> Account? {
        fetchFirst(FetchDescriptor<Account>(predicate: #Predicate { $0.shortcutID == id }), context)
    }
    static func fetchSubcategory(byShortcutID id: UUID, context: ModelContext) -> Subcategory? {
        fetchFirst(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.shortcutID == id }), context)
    }

    /// `SyncIdentity` de un `syncID` (para el born-remote insert y el tombstone delete). Store sync-meta.
    static func fetchSyncIdentity(bySyncID id: UUID, context: ModelContext) -> SyncIdentity? {
        fetchFirst(FetchDescriptor<SyncIdentity>(predicate: #Predicate { $0.syncID == id }), context)
    }

    /// `[Tag]` por sus `id` (CSV mirror). Fetch de TODOS + lookup en memoria (los Tags son pocos; evita
    /// las esquinas de `Array.contains` en `#Predicate`). Tolera ids duplicados (`Tag.byIDLookup`).
    static func fetchTags(byIDs ids: [UUID], context: ModelContext) -> [Tag] {
        guard !ids.isEmpty else { return [] }
        do {
            let all = try context.fetch(FetchDescriptor<Tag>())
            let lookup = Tag.byIDLookup(all)
            return ids.compactMap { lookup[$0] }
        } catch {
            #if DEBUG
            print("EntityApplyMap.fetchTags error: \(error)")
            #endif
            return []
        }
    }

    private static func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>, _ context: ModelContext
    ) -> T? {
        var d = descriptor
        d.fetchLimit = 1
        do {
            return try context.fetch(d).first
        } catch {
            #if DEBUG
            print("EntityApplyMap.fetchFirst<\(T.self)> error: \(error)")
            #endif
            return nil
        }
    }
}
