//
//  EntityApplyMap.swift
//  Yala
//
//  Mapa DECLARATIVO INVERSO de `EntityEmissionMap` (Modo Nube, incremento I8f-1): por entidad CABLEADA,
//  `columna Postgres → ColumnApplier` que decodifica el valor de wire (`WireValue`) y lo ESCRIBE en el
//  `@Model` local. Es el consumidor del pull (§d.6, D-7). Cobertura: las 16 entidades de dominio (I12
//  completa) — las 6 originales por `syncID` sintético, las 10 restantes por su UUID EXISTENTE
//  (`Account.shortcutID`/`Subcategory.shortcutID`; `.id` en el resto). Solo un `entity_type` fuera del
//  manifest (drift futuro) caería en cuarentena (`isWired` → false). La tabla → `EntityApply` la resuelve
//  el dispatch de `SyncApplyEngine`, espejo invertido de `EntityEmissionMap.table(forClass:)`.
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
//     cableadas; el CSV mirror preserva). Fetchers CONCRETOS por tipo (regla inviolable `#Predicate`). Un
//     destino que NO SE DEJA LEER no es un destino que no está: la lectura lanza y la página no se aplica.
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

/// Aplicador de UNA columna: decodifica el `WireValue` y lo setea en el `@Model`. LANZA si una lectura de la que
/// depende (el destino de una ref, su registro `SyncDanglingRef`, los destinos M2M) no se deja leer: la página entera
/// no se aplica (rollback en `applyPage`/`drainQuarantineOnce`, los dos únicos llamadores) en vez de escribir un `nil`
/// o un `[]` que no es verdad.
@MainActor
struct ColumnApplier<Model: AnyObject> {
    let apply: (Model, WireValue, ModelContext) throws -> Void
    init(_ apply: @escaping (Model, WireValue, ModelContext) throws -> Void) { self.apply = apply }
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
    /// Búsqueda de la fila por su id de sync. LANZA si no se puede leer: en el apply «no pude buscar» no es
    /// «no hay fila» (un tombstone se daría por hecho; un upsert crearía un duplicado).
    let fetchBySyncID: (UUID, ModelContext) throws -> Model?
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
    /// bool → `Bool?` (columna optional, ej. `GroupBridgePreference.bridgeOverride`). `null` → `nil`.
    static func boolOpt<M>(_ kp: ReferenceWritableKeyPath<M, Bool?>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = WireValueDecoder.bool(v) }
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
    /// text[] del wire → CSV `String?` local (inverso EXACTO de `Emit.csvTextArray`). `null` → `nil`;
    /// array → `join(",")` (array vacío `[]` → `""`, distinto de `nil`). Ej. Budget.natures/alertThresholds,
    /// ScheduledPayment.selectedWeekdays.
    static func csvOpt<M>(_ kp: ReferenceWritableKeyPath<M, String?>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in
            if let arr = WireValueDecoder.stringArray(v) { m[keyPath: kp] = arr.joined(separator: ",") }
            else { m[keyPath: kp] = nil }  // null → nil (columna opcional puesta a NULL)
        }
    }
    /// text[] del wire → CSV `String` NO-opcional local. `null` → `""` (no puede ser nil; ej.
    /// ScheduledPayment.skippedDatesRaw, default `""`); array → `join(",")`.
    static func csvReq<M>(_ kp: ReferenceWritableKeyPath<M, String>) -> ColumnApplier<M> {
        ColumnApplier { m, v, _ in m[keyPath: kp] = (WireValueDecoder.stringArray(v) ?? []).joined(separator: ",") }
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
        fetchBySyncID: { try findTransactionItem(bySyncID: $0, context: $1) },
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
                m.category = try resolveRef(v, entity: "tx_items", column: "category_ref",
                                        rowSyncID: m.syncID, context: ctx) {
                    try findCategory(bySyncID: $0, context: ctx)
                }
            },
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = try resolveRef(v, entity: "tx_items", column: "subcategory_ref",
                                           rowSyncID: m.syncID, context: ctx) {
                    try findSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "account_ref": ColumnApplier { m, v, ctx in
                m.account = try resolveRef(v, entity: "tx_items", column: "account_ref",
                                       rowSyncID: m.syncID, context: ctx) {
                    try findAccount(byShortcutID: $0, context: ctx)
                }
            },
            "tag_refs": ColumnApplier { m, v, ctx in try applyTagRefs(v, into: m, setter: { m.setTags(from: $0) },
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
        fetchBySyncID: { try findInboxDraft(bySyncID: $0, context: $1) },
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
                m.account = try resolveRef(v, entity: "inbox_drafts", column: "account_ref",
                                       rowSyncID: m.syncID, context: ctx) {
                    try findAccount(byShortcutID: $0, context: ctx)
                }
            },
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = try resolveRef(v, entity: "inbox_drafts", column: "subcategory_ref",
                                           rowSyncID: m.syncID, context: ctx) {
                    try findSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "tag_refs": ColumnApplier { m, v, ctx in try applyTagRefs(v, into: m, setter: { m.setTags(from: $0) },
                                                                  csv: { m.tagIDs = $0 }, context: ctx) },
            "approved_transaction_ref": ColumnApplier { m, v, ctx in
                m.approvedTransaction = try resolveRef(v, entity: "inbox_drafts", column: "approved_transaction_ref",
                                                   rowSyncID: m.syncID, context: ctx) {
                    try findTransactionItem(bySyncID: $0, context: ctx)
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
        fetchBySyncID: { try findCategory(bySyncID: $0, context: $1) },
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
        fetchBySyncID: { try findFavoritePayment(bySyncID: $0, context: $1) },
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
                m.account = try resolveRef(v, entity: "favorite_payments", column: "account_ref",
                                       rowSyncID: m.syncID, context: ctx) {
                    try findAccount(byShortcutID: $0, context: ctx)
                }
            },
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = try resolveRef(v, entity: "favorite_payments", column: "subcategory_ref",
                                           rowSyncID: m.syncID, context: ctx) {
                    try findSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "tag_refs": ColumnApplier { m, v, ctx in try applyTagRefs(v, into: m, setter: { m.setTags(from: $0) },
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
        fetchBySyncID: { try findMerchantMemory(bySyncID: $0, context: $1) },
        anchor: { SyncContentAnchor.merchantMemory(merchantCanonical: $0.merchantCanonical) },
        groupByColumn: EntityEmissionMap.merchantMemory.groupByColumn,
        appliers: [
            "merchant_canonical": Apply.stringReq(\.merchantCanonical),
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = try resolveRef(v, entity: "merchant_memory", column: "subcategory_ref",
                                           rowSyncID: m.syncID, context: ctx) {
                    try findSubcategory(byShortcutID: $0, context: ctx)
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
        fetchBySyncID: { try findExchangeRate(bySyncID: $0, context: $1) },
        anchor: { SyncContentAnchor.exchangeRate(dateKey: $0.dateKey, base: $0.base) },
        groupByColumn: EntityEmissionMap.exchangeRate.groupByColumn,
        appliers: [
            "date_key": Apply.stringReq(\.dateKey),
            "base": Apply.stringReq(\.base),
            "rates": ColumnApplier { m, v, _ in if let d = WireValueDecoder.jsonData(v) { m.rates = d } },
            "timestamp": Apply.dateOpt(\.timestamp),
        ]
    )

    // MARK: budgets — Budget (I12; identidad = `id`)

    static let budget = EntityApply<Budget>(
        table: "budgets",
        entityTypeName: SyncEntityType.budget,
        make: { ctx in let m = Budget(currencyCode: "USD", limitAmount: 0); ctx.insert(m); return m },
        setSyncID: { $0.id = $1 },
        fetchBySyncID: { try findBudget(byID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.id) },
        groupByColumn: EntityEmissionMap.budget.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "currency_code": Apply.stringReq(\.currencyCode),
            "limit_amount": Apply.moneyReq(\.limitAmount),
            "category_id": ColumnApplier { m, v, ctx in
                m.category = try resolveRef(v, entity: "budgets", column: "category_id",
                                        rowSyncID: m.id, context: ctx) {
                    try findCategory(bySyncID: $0, context: ctx)
                }
            },
            "period_type": Apply.stringReq(\.periodType),
            "start_date": Apply.dateOpt(\.startDate),
            "end_date": Apply.dateOpt(\.endDate),
            "natures": Apply.csvOpt(\.natures),
            // uuid[] M2M mirrors: resuelve por `shortcutID` (subcat/account) o `id` (tags) → M2M para el
            // cascade .nullify + CSV = wire COMPLETO (SSOT; CSV-first auto-cura cuando el destino llegue).
            "subcategory_ids": ColumnApplier { m, v, ctx in
                try applyUUIDArrayRefs(v, fetch: { try findSubcategories(byShortcutIDs: $0, context: $1) },
                                   setM2M: { m.subcategories = $0 }, csv: { m.subcategoryIDs = $0 }, context: ctx)
            },
            "account_ids": ColumnApplier { m, v, ctx in
                try applyUUIDArrayRefs(v, fetch: { try findAccounts(byShortcutIDs: $0, context: $1) },
                                   setM2M: { m.accounts = $0 }, csv: { m.accountIDs = $0 }, context: ctx)
            },
            "tag_refs": ColumnApplier { m, v, ctx in
                try applyTagRefs(v, into: m, setter: { m.tags = $0 }, csv: { m.tagIDs = $0 }, context: ctx)
            },
            "is_active": Apply.boolReq(\.isActive),
            "created_at": Apply.dateReq(\.createdAt),
            "is_favorite": Apply.boolReq(\.isFavorite),
            "favorite_order": Apply.intReq(\.favoriteOrder),
            "alert_enabled": Apply.boolReq(\.alertEnabled),
            "alert_thresholds": Apply.csvOpt(\.alertThresholds),
            "include_shared_expenses": Apply.boolReq(\.includeSharedExpenses),
        ]
    )

    // MARK: scheduled_payments — ScheduledPayment (I12; identidad = `id`)

    static let scheduledPayment = EntityApply<ScheduledPayment>(
        table: "scheduled_payments",
        entityTypeName: SyncEntityType.scheduledPayment,
        make: { ctx in
            let m = ScheduledPayment(name: "", amount: 0, currencyCode: "USD", nextDueDate: .now)
            ctx.insert(m)
            return m
        },
        setSyncID: { $0.id = $1 },
        fetchBySyncID: { try findScheduledPayment(byID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.id) },
        groupByColumn: EntityEmissionMap.scheduledPayment.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "note": Apply.textOpt(\.note),
            "amount": Apply.moneyReq(\.amount),
            "currency_code": Apply.stringReq(\.currencyCode),
            "is_variable_amount": Apply.boolReq(\.isVariableAmount),
            "transaction_type": Apply.stringReq(\.transactionType),
            "account_ref": ColumnApplier { m, v, ctx in
                m.account = try resolveRef(v, entity: "scheduled_payments", column: "account_ref",
                                       rowSyncID: m.id, context: ctx) {
                    try findAccount(byShortcutID: $0, context: ctx)
                }
            },
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = try resolveRef(v, entity: "scheduled_payments", column: "subcategory_ref",
                                           rowSyncID: m.id, context: ctx) {
                    try findSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "tag_refs": ColumnApplier { m, v, ctx in
                try applyTagRefs(v, into: m, setter: { m.setTags(from: $0) }, csv: { m.tagIDs = $0 }, context: ctx)
            },
            "need_override": Apply.textOpt(\.needOverride),
            "is_recurring": Apply.boolReq(\.isRecurring),
            "recurrence_type": Apply.stringReq(\.recurrenceType),
            "recurrence_interval": Apply.intReq(\.recurrenceInterval),
            "next_due_date": Apply.dateReq(\.nextDueDate),
            "day_of_month": Apply.intOpt(\.dayOfMonth),
            "selected_weekdays": Apply.csvOpt(\.selectedWeekdays),
            "yearly_month": Apply.intOpt(\.yearlyMonth),
            "yearly_day": Apply.intOpt(\.yearlyDay),
            "end_date": Apply.dateOpt(\.endDate),
            "payment_category": Apply.stringReq(\.paymentCategory),
            "notify_on_due_date": Apply.boolReq(\.notifyOnDueDate),
            "notify_days_before": Apply.intReq(\.notifyDaysBefore),
            "is_active": Apply.boolReq(\.isActive),
            "created_at": Apply.dateReq(\.createdAt),
            "last_paid_date": Apply.dateOpt(\.lastPaidDate),
            "skipped_dates_raw": Apply.csvReq(\.skippedDatesRaw),
            "group_zone_id": Apply.textOpt(\.groupZoneID),
            "split_total_amount": Apply.moneyOpt(\.splitTotalAmount),
            "split_type": Apply.textOpt(\.splitType),
            "split_participant_ids_raw": Apply.textOpt(\.splitParticipantIDsRaw),
            "split_values_raw": Apply.textOpt(\.splitValuesRaw),
        ]
    )

    // MARK: accounts — Account (I12 commit B; identidad = `shortcutID`)

    static let account = EntityApply<Account>(
        table: "accounts",
        entityTypeName: SyncEntityType.account,
        make: { ctx in
            let m = Account(name: "", currencyCode: "USD", colorHex: "#6366F1",
                            iconName: "creditcard", type: "checking")
            ctx.insert(m)
            return m
        },
        setSyncID: { $0.shortcutID = $1 },
        fetchBySyncID: { try findAccount(byShortcutID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.shortcutID) },
        groupByColumn: EntityEmissionMap.account.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "currency_code": Apply.stringReq(\.currencyCode),
            "color_hex": Apply.stringReq(\.colorHex),
            "icon_name": Apply.stringReq(\.iconName),
            "type": Apply.stringReq(\.type),
            "account_number": Apply.textOpt(\.accountNumber),
            "adjustment_mode": Apply.stringReq(\.adjustmentMode),
            "exclude_from_statistics": Apply.boolReq(\.excludeFromStatistics),
            "is_archived": Apply.boolReq(\.isArchived),
            "is_system_account": Apply.boolReq(\.isSystemAccount),
            "credit_card_payment_reminder": Apply.boolReq(\.creditCardPaymentReminder),
            "credit_card_payment_day": Apply.intReq(\.creditCardPaymentDay),
        ]
    )

    // MARK: subcategories — Subcategory (I12 commit B; identidad = `shortcutID`)

    static let subcategory = EntityApply<Subcategory>(
        table: "subcategories",
        entityTypeName: SyncEntityType.subcategory,
        make: { ctx in let m = Subcategory(name: "", category: nil); ctx.insert(m); return m },
        setSyncID: { $0.shortcutID = $1 },
        fetchBySyncID: { try findSubcategory(byShortcutID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.shortcutID) },
        groupByColumn: EntityEmissionMap.subcategory.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "color_hex": Apply.textOpt(\.colorHex),
            "is_default_seed": Apply.boolReq(\.isDefaultSeed),
            "is_visible": Apply.boolReq(\.isVisible),
            "sort_order": Apply.intReq(\.sortOrder),
            "nature_raw_value": Apply.textOpt(\.natureRawValue),
            "icon_name": Apply.textOpt(\.iconName),
            "is_system": Apply.boolReq(\.isSystem),
            "category_ref": ColumnApplier { m, v, ctx in
                m.category = try resolveRef(v, entity: "subcategories", column: "category_ref",
                                        rowSyncID: m.shortcutID, context: ctx) {
                    try findCategory(bySyncID: $0, context: ctx)
                }
            },
        ]
    )

    // MARK: tags — Tag (I12 commit B; identidad = `id`)

    static let tag = EntityApply<Tag>(
        table: "tags",
        entityTypeName: SyncEntityType.tag,
        make: { ctx in let m = Tag(name: ""); ctx.insert(m); return m },
        setSyncID: { $0.id = $1 },
        fetchBySyncID: { try findTag(byID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.id) },
        groupByColumn: EntityEmissionMap.tag.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "color_hex": Apply.stringReq(\.colorHex),
            "icon_name": Apply.stringReq(\.iconName),
            "is_active": Apply.boolReq(\.isActive),
            "created_at": Apply.dateReq(\.createdAt),
        ]
    )

    // MARK: notification_items — NotificationItem (I12 commit B; identidad = `id`)

    static let notificationItem = EntityApply<NotificationItem>(
        table: "notification_items",
        entityTypeName: SyncEntityType.notificationItem,
        make: { ctx in
            let m = NotificationItem(name: "", text: "", hour: 12, minute: 0, type: .custom)
            ctx.insert(m)
            return m
        },
        setSyncID: { $0.id = $1 },
        fetchBySyncID: { try findNotificationItem(byID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.id) },
        groupByColumn: EntityEmissionMap.notificationItem.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "text": Apply.stringReq(\.text),
            "hour": Apply.intReq(\.hour),
            "minute": Apply.intReq(\.minute),
            "type_raw": Apply.stringReq(\.typeRaw),
            "is_active": Apply.boolReq(\.isActive),
            "icon_name": Apply.stringReq(\.iconName),
            "color_hex": Apply.stringReq(\.colorHex),
            "created_at": Apply.dateReq(\.createdAt),
            "sort_order": Apply.intReq(\.sortOrder),
            // report_data_type / report_day_preference: el STORAGE es `configurationData` (JSON). Se
            // reconstruye con read-modify-write DIRECTO del blob (NO vía el computed `reportConfig`, cuyo
            // getter se cierra por `isReportType` — order-independiente frente al orden no determinista de
            // `delta.fields`). null → no-op (ambos campos viajan juntos, gateados por `isReportType`; el
            // wire ignora `configurationData` para tipos no-reporte → round-trip fiel; ver header + emit).
            "report_data_type": ColumnApplier { m, v, _ in
                applyReportField(m, v) { $0.dataType = ReportDataType(rawValue: $1) ?? $0.dataType }
            },
            "report_day_preference": ColumnApplier { m, v, _ in
                applyReportField(m, v) { $0.dayPreference = ReportDayPreference(rawValue: $1) ?? $0.dayPreference }
            },
            "weekdays_raw": Apply.csvOpt(\.weekdaysRaw),
        ]
    )

    // MARK: cashflow_plans — CashFlowPlan (I12 commit B; identidad = `id`)

    static let cashFlowPlan = EntityApply<CashFlowPlan>(
        table: "cashflow_plans",
        entityTypeName: SyncEntityType.cashFlowPlan,
        make: { ctx in let m = CashFlowPlan(); ctx.insert(m); return m },
        setSyncID: { $0.id = $1 },
        fetchBySyncID: { try findCashFlowPlan(byID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.id) },
        groupByColumn: EntityEmissionMap.cashFlowPlan.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "starting_balance": Apply.moneyReq(\.startingBalance),
            "default_months_ahead": Apply.intReq(\.defaultMonthsAhead),
            "default_months_back": Apply.intReq(\.defaultMonthsBack),
            "show_other_expenses": Apply.boolReq(\.showOtherExpenses),
            "show_accumulated_balance": Apply.boolReq(\.showAccumulatedBalance),
            "starting_balance_date": Apply.dateOpt(\.startingBalanceDate),
            "created_at": Apply.dateReq(\.createdAt),
            "updated_at_domain": Apply.dateReq(\.updatedAt),
        ]
    )

    // MARK: cashflow_lines — CashFlowLine (I12 commit B; identidad = `id`)

    static let cashFlowLine = EntityApply<CashFlowLine>(
        table: "cashflow_lines",
        entityTypeName: SyncEntityType.cashFlowLine,
        make: { ctx in let m = CashFlowLine(name: ""); ctx.insert(m); return m },
        setSyncID: { $0.id = $1 },
        fetchBySyncID: { try findCashFlowLine(byID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.id) },
        groupByColumn: EntityEmissionMap.cashFlowLine.groupByColumn,
        appliers: [
            "name": Apply.stringReq(\.name),
            "is_income": Apply.boolReq(\.isIncome),
            "sort_order": Apply.intReq(\.sortOrder),
            "is_enabled": Apply.boolReq(\.isEnabled),
            "estimation_method": Apply.stringReq(\.estimationMethod),
            "manual_amount": Apply.moneyOpt(\.manualAmount),
            "custom_months_raw": Apply.csvOpt(\.customMonthsRaw),
            "category_ref": ColumnApplier { m, v, ctx in
                m.category = try resolveRef(v, entity: "cashflow_lines", column: "category_ref",
                                        rowSyncID: m.id, context: ctx) {
                    try findCategory(bySyncID: $0, context: ctx)
                }
            },
            "subcategory_ref": ColumnApplier { m, v, ctx in
                m.subcategory = try resolveRef(v, entity: "cashflow_lines", column: "subcategory_ref",
                                           rowSyncID: m.id, context: ctx) {
                    try findSubcategory(byShortcutID: $0, context: ctx)
                }
            },
            "scheduled_payment_ref": ColumnApplier { m, v, ctx in
                m.scheduledPayment = try resolveRef(v, entity: "cashflow_lines", column: "scheduled_payment_ref",
                                                rowSyncID: m.id, context: ctx) {
                    try findScheduledPayment(byID: $0, context: ctx)
                }
            },
            "plan_ref": ColumnApplier { m, v, ctx in
                m.plan = try resolveRef(v, entity: "cashflow_lines", column: "plan_ref",
                                    rowSyncID: m.id, context: ctx) {
                    try findCashFlowPlan(byID: $0, context: ctx)
                }
            },
        ]
    )

    // MARK: cashflow_overrides — CashFlowOverride (I12 commit B; identidad = `id`)

    static let cashFlowOverride = EntityApply<CashFlowOverride>(
        table: "cashflow_overrides",
        entityTypeName: SyncEntityType.cashFlowOverride,
        make: { ctx in let m = CashFlowOverride(monthKey: "", amount: 0); ctx.insert(m); return m },
        setSyncID: { $0.id = $1 },
        fetchBySyncID: { try findCashFlowOverride(byID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.id) },
        groupByColumn: EntityEmissionMap.cashFlowOverride.groupByColumn,
        appliers: [
            "month_key": Apply.stringReq(\.monthKey),
            "amount": Apply.moneyReq(\.amount),
            "note": Apply.stringReq(\.note),
            "line_ref": ColumnApplier { m, v, ctx in
                m.line = try resolveRef(v, entity: "cashflow_overrides", column: "line_ref",
                                    rowSyncID: m.id, context: ctx) {
                    try findCashFlowLine(byID: $0, context: ctx)
                }
            },
        ]
    )

    // MARK: group_bridge_prefs — GroupBridgePreference (I12 commit B; identidad = `id`)
    // D6: entidad del store PERSONAL por diseño (manifest/DDL). group_zone_id es TEXT opaco cross-store
    // (FK a SplitGroup.cloudKitZoneID) → se copia byte a byte, NUNCA se remapea.

    static let groupBridgePreference = EntityApply<GroupBridgePreference>(
        table: "group_bridge_prefs",
        entityTypeName: SyncEntityType.groupBridgePreference,
        make: { ctx in let m = GroupBridgePreference(); ctx.insert(m); return m },
        setSyncID: { $0.id = $1 },
        fetchBySyncID: { try findGroupBridgePreference(byID: $0, context: $1) },
        anchor: { SyncContentAnchor.stableID($0.id) },
        groupByColumn: EntityEmissionMap.groupBridgePreference.groupByColumn,
        appliers: [
            "group_zone_id": Apply.stringReq(\.groupZoneID),
            "bridge_override": Apply.boolOpt(\.bridgeOverride),
            "created_at": Apply.dateReq(\.createdAt),
        ]
    )

    // MARK: - Resolución de un `_ref` (dangling → nil + breadcrumb + registro durable F-2)

    /// Decodifica un `WireValue` FK y lo resuelve con `fetch`. `null` → `nil` SIN breadcrumb (borrado
    /// legítimo del vínculo). `uuid` presente que NO resuelve (destino aún no sincronizado / no cableado)
    /// → `nil` + `applyDanglingRef` + **registro durable `SyncDanglingRef`** (F-2): con materialized-rows
    /// el orden por `server_seq` NO es causal (el destino puede llegar en una página POSTERIOR — una
    /// Category editada re-estampa un seq MAYOR que la TX que la referencia) y un crash entre páginas
    /// haría el huérfano PERMANENTE. El pase de re-resolución al final de `pullAndApplyOnce` lo cura.
    ///
    /// LANZA si no se deja leer el destino o el registro del dangler (ticket
    /// `dangling-ref-repair-is-lost-when-its-row-cannot-be-read`). «No pude leer el destino» no es «no está»: leído
    /// como `nil`, pisaba una ref local buena y registraba un dangler que no hacía falta. Y «no pude leer el
    /// registro» no es «no hay registro»: tragado, perdía la nota nueva (la fila se quedaba sin ref y sin rastro del
    /// destino) o dejaba viva la vieja, que al llegar su destino re-adjuntaba una relación que el wire ya había
    /// cambiado. El throw cae en el rollback de la página: cursor quieto y reintento.
    private static func resolveRef<T>(
        _ value: WireValue, entity: String, column: String, rowSyncID: UUID?,
        context: ModelContext, fetch: (UUID) throws -> T?
    ) throws -> T? {
        switch value {
        case .null:
            // El wire puso el vínculo a NULL → un dangler previo de esta (fila, columna) queda OBSOLETO
            // y DEBE borrarse (dejarlo re-adjuntaría una relación stale en la re-resolución y el Merkle
            // usaría un target que el server ya no tiene).
            if let rowSyncID { try clearDangler(rowSyncID: rowSyncID, column: column, context: context) }
            return nil
        case .string(let s):
            guard let id = UUID(uuidString: s) else { return nil }
            let resolved = try fetch(id)
            if resolved == nil {
                CloudSyncBreadcrumb.applyDanglingRef(entity: entity, column: column)
                if let rowSyncID {
                    try registerDangler(entityTable: entity, rowSyncID: rowSyncID, column: column,
                                        targetUUID: id, context: context)
                }
            } else if let rowSyncID {
                // Resolvió en caliente → un dangler previo queda obsoleto (higiene simétrica).
                try clearDangler(rowSyncID: rowSyncID, column: column, context: context)
            }
            return resolved
        default:
            return nil
        }
    }

    /// El dangler de una (fila, columna), si existe. LANZA si no se puede leer: el que llama decide sobre ese
    /// registro (borrarlo, reapuntarlo o crear uno), y un `nil` por avería sería un duplicado o una nota perdida.
    private static func findDangler(rowSyncID: UUID, column: String, context: ModelContext) throws -> SyncDanglingRef? {
        try fetchFirstOrThrow(FetchDescriptor<SyncDanglingRef>(
            predicate: #Predicate { $0.rowSyncID == rowSyncID && $0.column == column }
        ), context)
    }

    /// Borra el dangler de una (fila, columna) si existe — el wire lo dejó obsoleto (NULL explícito o
    /// resolución en caliente). No-op si no hay. LANZA si no se puede leer (ver `resolveRef`).
    private static func clearDangler(rowSyncID: UUID, column: String, context: ModelContext) throws {
        if let existing = try findDangler(rowSyncID: rowSyncID, column: column, context: context) {
            context.delete(existing)
        }
    }

    /// Inserta/actualiza el registro durable de un ref colgado. Dedup por `(rowSyncID, column)`: si ya
    /// existe, REEMPLAZA el `targetUUID` (el delta más nuevo manda). El insert ocurre dentro del save de
    /// página del apply (autor del motor) → atómico con el cursor. LANZA si no se puede leer (ver `resolveRef`).
    private static func registerDangler(
        entityTable: String, rowSyncID: UUID, column: String, targetUUID: UUID, context: ModelContext
    ) throws {
        if let existing = try findDangler(rowSyncID: rowSyncID, column: column, context: context) {
            existing.targetUUID = targetUUID
        } else {
            context.insert(SyncDanglingRef(entityTable: entityTable, rowSyncID: rowSyncID,
                                           column: column, targetUUID: targetUUID))
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
        /// La fila origen o el destino NO se dejaron leer → conservar el dangler (reintento en el próximo ciclo).
        /// No es `.rowGone`: el dangler es el ÚNICO sitio con el UUID del destino (las refs singulares no tienen
        /// espejo CSV), así que borrarlo por una avería dejaba la fila sin su categoría o su cuenta para siempre
        /// (ticket `dangling-ref-repair-is-lost-when-its-row-cannot-be-read`).
        case unreadable
    }

    /// Intenta re-resolver UNA referencia colgada: fetch de la fila origen (dispatch concreto por tabla)
    /// + fetch del destino (por el tipo de la columna) + set de la relación. Cubre los `_ref` SINGULARES
    /// de las 16 entidades cableadas (`tag_refs`/`subcategory_ids`/`account_ids` se auto-curan vía CSV
    /// mirror y NUNCA se registran). Matiz `scheduled_payment_ref`: en TX/InboxDraft es String plano
    /// (sin relación que colgar, no se registra); en `cashflow_lines` SÍ es `@Relationship` → tiene caso.
    ///
    /// Las dos lecturas son ESTRICTAS (`find*`): una que lanza devuelve `.unreadable`, nunca `.rowGone` ni
    /// `.targetMissing` — «no pude leer la fila» no es «la fila ya no existe».
    static func reresolveDangler(_ dangler: SyncDanglingRef, context: ModelContext) -> DanglerOutcome {
        do {
            return try reresolveDanglerReadingStrictly(dangler, context: context)
        } catch {
            #if DEBUG
            print("EntityApplyMap.reresolveDangler: lectura ilegible (\(dangler.entityTable).\(dangler.column)): \(error)")
            #endif
            return .unreadable
        }
    }

    private static func reresolveDanglerReadingStrictly(
        _ dangler: SyncDanglingRef, context: ModelContext
    ) throws -> DanglerOutcome {
        let target = dangler.targetUUID
        switch (dangler.entityTable, dangler.column) {
        case (transactionItem.table, "category_ref"):
            guard let row = try findTransactionItem(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findCategory(bySyncID: target, context: context) else { return .targetMissing }
            row.category = t
            return .resolved
        case (transactionItem.table, "subcategory_ref"):
            guard let row = try findTransactionItem(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        case (transactionItem.table, "account_ref"):
            guard let row = try findTransactionItem(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findAccount(byShortcutID: target, context: context) else { return .targetMissing }
            row.account = t
            return .resolved
        case (inboxDraft.table, "account_ref"):
            guard let row = try findInboxDraft(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findAccount(byShortcutID: target, context: context) else { return .targetMissing }
            row.account = t
            return .resolved
        case (inboxDraft.table, "subcategory_ref"):
            guard let row = try findInboxDraft(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        case (inboxDraft.table, "approved_transaction_ref"):
            guard let row = try findInboxDraft(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findTransactionItem(bySyncID: target, context: context) else { return .targetMissing }
            row.approvedTransaction = t
            return .resolved
        case (favoritePayment.table, "account_ref"):
            guard let row = try findFavoritePayment(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findAccount(byShortcutID: target, context: context) else { return .targetMissing }
            row.account = t
            return .resolved
        case (favoritePayment.table, "subcategory_ref"):
            guard let row = try findFavoritePayment(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        case (merchantMemory.table, "subcategory_ref"):
            guard let row = try findMerchantMemory(bySyncID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        case (budget.table, "category_id"):
            guard let row = try findBudget(byID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findCategory(bySyncID: target, context: context) else { return .targetMissing }
            row.category = t
            return .resolved
        case (scheduledPayment.table, "account_ref"):
            guard let row = try findScheduledPayment(byID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findAccount(byShortcutID: target, context: context) else { return .targetMissing }
            row.account = t
            return .resolved
        case (scheduledPayment.table, "subcategory_ref"):
            guard let row = try findScheduledPayment(byID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        // I12 commit B: refs singulares de las nuevas entidades.
        case (subcategory.table, "category_ref"):
            guard let row = try findSubcategory(byShortcutID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findCategory(bySyncID: target, context: context) else { return .targetMissing }
            row.category = t
            return .resolved
        case (cashFlowLine.table, "category_ref"):
            guard let row = try findCashFlowLine(byID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findCategory(bySyncID: target, context: context) else { return .targetMissing }
            row.category = t
            return .resolved
        case (cashFlowLine.table, "subcategory_ref"):
            guard let row = try findCashFlowLine(byID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findSubcategory(byShortcutID: target, context: context) else { return .targetMissing }
            row.subcategory = t
            return .resolved
        case (cashFlowLine.table, "scheduled_payment_ref"):
            guard let row = try findCashFlowLine(byID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findScheduledPayment(byID: target, context: context) else { return .targetMissing }
            row.scheduledPayment = t
            return .resolved
        case (cashFlowLine.table, "plan_ref"):
            guard let row = try findCashFlowLine(byID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findCashFlowPlan(byID: target, context: context) else { return .targetMissing }
            row.plan = t
            return .resolved
        case (cashFlowOverride.table, "line_ref"):
            guard let row = try findCashFlowOverride(byID: dangler.rowSyncID, context: context) else { return .rowGone }
            guard let t = try findCashFlowLine(byID: target, context: context) else { return .targetMissing }
            row.line = t
            return .resolved
        default:
            // Combinación desconocida (drift futuro) → tratar como obsoleto para no acumular basura.
            return .rowGone
        }
    }

    /// Aplica `tag_refs`: resuelve los `[UUID]` del wire a `[Tag]` locales (dual-write M2M+CSV vía
    /// `setter`) y LUEGO sobrescribe el CSV mirror con los UUIDs del WIRE COMPLETOS (`csv`) — preserva
    /// refs a tags aún no locales (CSV-first auto-cura; gotcha CSV-stale). `null` → sin tags. LANZA si la tabla de
    /// tags no se deja leer: un `[]` por avería vaciaba la relación de una fila que sí tenía sus tags.
    private static func applyTagRefs<M>(
        _ value: WireValue, into _: M, setter: ([Tag]) -> Void, csv: (String?) -> Void, context: ModelContext
    ) throws {
        let wireUUIDs = WireValueDecoder.uuidArray(value) ?? []
        let tags = try findTags(byIDs: wireUUIDs, context: context)
        setter(tags)                                   // dual-write M2M + CSV (subset resuelto)
        csv(CSVMirrorCodec.encode(wireUUIDs))          // CSV = wire COMPLETO (SSOT; preserva no-locales)
    }

    /// Generalización de `applyTagRefs` a cualquier columna `uuid[]` de refs M2M (Budget
    /// subcategory_ids/account_ids/tag_refs): resuelve los `[UUID]` del wire a `[T]` locales
    /// (`setM2M`, para el cascade `.nullify`) y sobrescribe el CSV mirror con los UUIDs del WIRE
    /// COMPLETOS (`csv`) — preserva refs a destinos aún no locales (CSV-first auto-cura; gotcha
    /// CSV-stale). `null` → sin refs (`[]`/`""`). El orden del CSV lo canonicaliza `CSVMirrorCodec`.
    private static func applyUUIDArrayRefs<T: PersistentModel>(
        _ value: WireValue,
        fetch: ([UUID], ModelContext) throws -> [T],
        setM2M: ([T]) -> Void, csv: (String?) -> Void, context: ModelContext
    ) throws {
        let wireUUIDs = WireValueDecoder.uuidArray(value) ?? []
        setM2M(try fetch(wireUUIDs, context))
        csv(CSVMirrorCodec.encode(wireUUIDs))
    }

    /// Reconstruye UNO de los dos campos de `reportConfig` (`report_data_type`/`report_day_preference`)
    /// en `configurationData` de un `NotificationItem`, sin pasar por el computed `reportConfig` (cuyo
    /// getter se cierra por `isReportType`). Read-modify-write DIRECTO del blob JSON → order-independiente
    /// (los dos campos llegan en el mismo delta pero en orden no determinista). `null` → no-op (los dos
    /// campos viajan juntos gateados por `isReportType`; el wire ignora `configurationData` para tipos no
    /// reporte → el blob stale es inofensivo, round-trip fiel).
    private static func applyReportField(
        _ m: NotificationItem, _ value: WireValue, mutate: (inout ReportConfig, String) -> Void
    ) {
        guard case .string(let s) = value else { return }  // null/otro → no-op
        var config = m.configurationData.flatMap(ReportConfig.fromData) ?? .default
        mutate(&config, s)
        m.configurationData = config.toData()
    }

    // MARK: - Dispatch tabla → EntityApply (invierte EntityEmissionMap.table(forClass:))

    /// Las 6 tablas cableadas al apply (las que el cliente MATERIALIZA en v1). Consumidas también por
    /// la verificación Merkle (I8f-3, regla 5: solo estos entityHash se comparan).
    static var wiredTables: Set<String> {
        [transactionItem.table, inboxDraft.table, category.table,
         favoritePayment.table, merchantMemory.table, exchangeRate.table,
         budget.table, scheduledPayment.table,
         account.table, subcategory.table, tag.table, notificationItem.table,
         cashFlowPlan.table, cashFlowLine.table, cashFlowOverride.table, groupBridgePreference.table]
    }

    /// `true` si la tabla está cableada al apply. El apply consulta esto para decidir materializar vs
    /// cuarentenar; el dispatch concreto por tipo lo hace `SyncApplyEngine`. I12 completa: las 16 de las
    /// 16 tablas de dominio están cableadas → `isWired` es `true` para toda tabla de dominio (solo un
    /// `entity_type` NO presente en el manifest [drift futuro] caería en el `default` = cuarentena).
    static func isWired(table: String) -> Bool {
        switch table {
        case transactionItem.table, inboxDraft.table, category.table,
             favoritePayment.table, merchantMemory.table, exchangeRate.table,
             budget.table, scheduledPayment.table,
             account.table, subcategory.table, tag.table, notificationItem.table,
             cashFlowPlan.table, cashFlowLine.table, cashFlowOverride.table, groupBridgePreference.table:
            return true
        default:
            return false
        }
    }

    // MARK: - Barrido de la reversa (§h.3, I11-2) — reuso del mapa tabla→tipo concreto

    /// Barrido de zombies (§h.3): para una TABLA Postgres y un conjunto de `syncIDs` tombstoneados por el
    /// backend, BORRA las filas VIVAS que los porten. UN fetch por tabla (dispatch CONCRETO por tipo — regla
    /// inviolable `#Predicate`) + match EN MEMORIA; JAMÁS un fetch por tombstone. El `context.save()` lo hace
    /// el caller (bajo `outboxSaveAuthor` — el barrido ES semánticamente un apply de tombstones del backend →
    /// sin eco al outbox). Devuelve el nº de filas borradas. Tabla desconocida → 0. LANZA si una tabla no se
    /// puede leer: «no pude borrar» no es «no había nada que borrar», y el caller debe hacer rollback.
    static func deleteLiveRows(table: String, syncIDs: Set<UUID>, context: ModelContext) throws -> Int {
        guard !syncIDs.isEmpty else { return 0 }
        switch table {
        case transactionItem.table:   return try deleteMatching(TransactionItem.self, id: { $0.syncID }, syncIDs, context)
        case inboxDraft.table:        return try deleteMatching(InboxDraft.self, id: { $0.syncID }, syncIDs, context)
        case category.table:          return try deleteMatching(Category.self, id: { $0.syncID }, syncIDs, context)
        case favoritePayment.table:   return try deleteMatching(FavoritePayment.self, id: { $0.syncID }, syncIDs, context)
        case merchantMemory.table:    return try deleteMatching(MerchantMemory.self, id: { $0.syncID }, syncIDs, context)
        case exchangeRate.table:      return try deleteMatching(ExchangeRate.self, id: { $0.syncID }, syncIDs, context)
        case budget.table:            return try deleteMatching(Budget.self, id: { $0.id }, syncIDs, context)
        case scheduledPayment.table:  return try deleteMatching(ScheduledPayment.self, id: { $0.id }, syncIDs, context)
        case account.table:           return try deleteMatching(Account.self, id: { $0.shortcutID }, syncIDs, context)
        case subcategory.table:       return try deleteMatching(Subcategory.self, id: { $0.shortcutID }, syncIDs, context)
        case tag.table:               return try deleteMatching(Tag.self, id: { $0.id }, syncIDs, context)
        case notificationItem.table:  return try deleteMatching(NotificationItem.self, id: { $0.id }, syncIDs, context)
        case cashFlowPlan.table:      return try deleteMatching(CashFlowPlan.self, id: { $0.id }, syncIDs, context)
        case cashFlowLine.table:      return try deleteMatching(CashFlowLine.self, id: { $0.id }, syncIDs, context)
        case cashFlowOverride.table:  return try deleteMatching(CashFlowOverride.self, id: { $0.id }, syncIDs, context)
        case groupBridgePreference.table: return try deleteMatching(GroupBridgePreference.self, id: { $0.id }, syncIDs, context)
        default:                      return 0
        }
    }

    /// Fetch CONCRETO de TODAS las filas del tipo + delete de las que portan un `syncID` tombstoneado (match
    /// en memoria). El caller saveea (bajo `outboxSaveAuthor`). Fetch fallido → LANZA (antes devolvía `0`,
    /// indistinguible de «no había nada» → el barrido se daba por hecho con los zombies vivos).
    private static func deleteMatching<M: PersistentModel>(
        _ type: M.Type, id identity: (M) -> UUID?, _ syncIDs: Set<UUID>, _ context: ModelContext
    ) throws -> Int {
        let models: [M]
        do {
            if _testThrowOnFetchOf.contains(String(describing: M.self)) { throw EntityApplyFetchError.unreadable(String(describing: M.self)) }
            models = try context.fetch(FetchDescriptor<M>())
        } catch {
            #if DEBUG
            print("EntityApplyMap.deleteMatching<\(M.self)> error: \(error)")
            #endif
            throw error
        }
        var deleted = 0
        for model in models {
            guard let sid = identity(model), syncIDs.contains(sid) else { continue }
            context.delete(model)
            deleted += 1
        }
        return deleted
    }

    /// §h.3 `rebindingUUIDs`: ¿existe una fila VIVA que porte `syncID` para el `entityTypeName` (nombre de
    /// clase, `SyncEntityType.*`)? Reusa los fetchers concretos por tipo. Tipo desconocido → false.
    static func liveRowExists(entityTypeName: String, syncID: UUID, context: ModelContext) -> Bool {
        switch entityTypeName {
        case SyncEntityType.transactionItem:      return fetchTransactionItem(bySyncID: syncID, context: context) != nil
        case SyncEntityType.inboxDraft:           return fetchInboxDraft(bySyncID: syncID, context: context) != nil
        case SyncEntityType.category:             return fetchCategory(bySyncID: syncID, context: context) != nil
        case SyncEntityType.favoritePayment:      return fetchFavoritePayment(bySyncID: syncID, context: context) != nil
        case SyncEntityType.merchantMemory:       return fetchMerchantMemory(bySyncID: syncID, context: context) != nil
        case SyncEntityType.exchangeRate:         return fetchExchangeRate(bySyncID: syncID, context: context) != nil
        case SyncEntityType.budget:               return fetchBudget(byID: syncID, context: context) != nil
        case SyncEntityType.scheduledPayment:     return fetchScheduledPayment(byID: syncID, context: context) != nil
        case SyncEntityType.account:              return fetchAccount(byShortcutID: syncID, context: context) != nil
        case SyncEntityType.subcategory:          return fetchSubcategory(byShortcutID: syncID, context: context) != nil
        case SyncEntityType.tag:                  return fetchTag(byID: syncID, context: context) != nil
        case SyncEntityType.notificationItem:     return fetchNotificationItem(byID: syncID, context: context) != nil
        case SyncEntityType.cashFlowPlan:         return fetchCashFlowPlan(byID: syncID, context: context) != nil
        case SyncEntityType.cashFlowLine:         return fetchCashFlowLine(byID: syncID, context: context) != nil
        case SyncEntityType.cashFlowOverride:     return fetchCashFlowOverride(byID: syncID, context: context) != nil
        case SyncEntityType.groupBridgePreference: return fetchGroupBridgePreference(byID: syncID, context: context) != nil
        default:                                  return false
        }
    }

    // MARK: - Fetchers CONCRETOS por tipo (regla inviolable `#Predicate`: nunca genérico por protocolo)

    static func fetchTransactionItem(bySyncID id: UUID, context: ModelContext) -> TransactionItem? {
        lenient("TransactionItem") { try findTransactionItem(bySyncID: id, context: context) }
    }
    static func findTransactionItem(bySyncID id: UUID, context: ModelContext) throws -> TransactionItem? {
        try fetchFirstOrThrow(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchInboxDraft(bySyncID id: UUID, context: ModelContext) -> InboxDraft? {
        lenient("InboxDraft") { try findInboxDraft(bySyncID: id, context: context) }
    }
    static func findInboxDraft(bySyncID id: UUID, context: ModelContext) throws -> InboxDraft? {
        try fetchFirstOrThrow(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchCategory(bySyncID id: UUID, context: ModelContext) -> Category? {
        lenient("Category") { try findCategory(bySyncID: id, context: context) }
    }
    static func findCategory(bySyncID id: UUID, context: ModelContext) throws -> Category? {
        try fetchFirstOrThrow(FetchDescriptor<Category>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchFavoritePayment(bySyncID id: UUID, context: ModelContext) -> FavoritePayment? {
        lenient("FavoritePayment") { try findFavoritePayment(bySyncID: id, context: context) }
    }
    static func findFavoritePayment(bySyncID id: UUID, context: ModelContext) throws -> FavoritePayment? {
        try fetchFirstOrThrow(FetchDescriptor<FavoritePayment>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchMerchantMemory(bySyncID id: UUID, context: ModelContext) -> MerchantMemory? {
        lenient("MerchantMemory") { try findMerchantMemory(bySyncID: id, context: context) }
    }
    static func findMerchantMemory(bySyncID id: UUID, context: ModelContext) throws -> MerchantMemory? {
        try fetchFirstOrThrow(FetchDescriptor<MerchantMemory>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchExchangeRate(bySyncID id: UUID, context: ModelContext) -> ExchangeRate? {
        lenient("ExchangeRate") { try findExchangeRate(bySyncID: id, context: context) }
    }
    static func findExchangeRate(bySyncID id: UUID, context: ModelContext) throws -> ExchangeRate? {
        try fetchFirstOrThrow(FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.syncID == id }), context)
    }
    static func fetchAccount(byShortcutID id: UUID, context: ModelContext) -> Account? {
        lenient("Account") { try findAccount(byShortcutID: id, context: context) }
    }
    static func findAccount(byShortcutID id: UUID, context: ModelContext) throws -> Account? {
        try fetchFirstOrThrow(FetchDescriptor<Account>(predicate: #Predicate { $0.shortcutID == id }), context)
    }
    static func fetchSubcategory(byShortcutID id: UUID, context: ModelContext) -> Subcategory? {
        lenient("Subcategory") { try findSubcategory(byShortcutID: id, context: context) }
    }
    static func findSubcategory(byShortcutID id: UUID, context: ModelContext) throws -> Subcategory? {
        try fetchFirstOrThrow(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.shortcutID == id }), context)
    }
    static func fetchBudget(byID id: UUID, context: ModelContext) -> Budget? {
        lenient("Budget") { try findBudget(byID: id, context: context) }
    }
    static func findBudget(byID id: UUID, context: ModelContext) throws -> Budget? {
        try fetchFirstOrThrow(FetchDescriptor<Budget>(predicate: #Predicate { $0.id == id }), context)
    }
    static func fetchScheduledPayment(byID id: UUID, context: ModelContext) -> ScheduledPayment? {
        lenient("ScheduledPayment") { try findScheduledPayment(byID: id, context: context) }
    }
    static func findScheduledPayment(byID id: UUID, context: ModelContext) throws -> ScheduledPayment? {
        try fetchFirstOrThrow(FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id }), context)
    }
    static func fetchTag(byID id: UUID, context: ModelContext) -> Tag? {
        lenient("Tag") { try findTag(byID: id, context: context) }
    }
    static func findTag(byID id: UUID, context: ModelContext) throws -> Tag? {
        try fetchFirstOrThrow(FetchDescriptor<Tag>(predicate: #Predicate { $0.id == id }), context)
    }
    static func fetchNotificationItem(byID id: UUID, context: ModelContext) -> NotificationItem? {
        lenient("NotificationItem") { try findNotificationItem(byID: id, context: context) }
    }
    static func findNotificationItem(byID id: UUID, context: ModelContext) throws -> NotificationItem? {
        try fetchFirstOrThrow(FetchDescriptor<NotificationItem>(predicate: #Predicate { $0.id == id }), context)
    }
    static func fetchCashFlowPlan(byID id: UUID, context: ModelContext) -> CashFlowPlan? {
        lenient("CashFlowPlan") { try findCashFlowPlan(byID: id, context: context) }
    }
    static func findCashFlowPlan(byID id: UUID, context: ModelContext) throws -> CashFlowPlan? {
        try fetchFirstOrThrow(FetchDescriptor<CashFlowPlan>(predicate: #Predicate { $0.id == id }), context)
    }
    static func fetchCashFlowLine(byID id: UUID, context: ModelContext) -> CashFlowLine? {
        lenient("CashFlowLine") { try findCashFlowLine(byID: id, context: context) }
    }
    static func findCashFlowLine(byID id: UUID, context: ModelContext) throws -> CashFlowLine? {
        try fetchFirstOrThrow(FetchDescriptor<CashFlowLine>(predicate: #Predicate { $0.id == id }), context)
    }
    static func fetchCashFlowOverride(byID id: UUID, context: ModelContext) -> CashFlowOverride? {
        lenient("CashFlowOverride") { try findCashFlowOverride(byID: id, context: context) }
    }
    static func findCashFlowOverride(byID id: UUID, context: ModelContext) throws -> CashFlowOverride? {
        try fetchFirstOrThrow(FetchDescriptor<CashFlowOverride>(predicate: #Predicate { $0.id == id }), context)
    }
    static func fetchGroupBridgePreference(byID id: UUID, context: ModelContext) -> GroupBridgePreference? {
        lenient("GroupBridgePreference") { try findGroupBridgePreference(byID: id, context: context) }
    }
    static func findGroupBridgePreference(byID id: UUID, context: ModelContext) throws -> GroupBridgePreference? {
        try fetchFirstOrThrow(FetchDescriptor<GroupBridgePreference>(predicate: #Predicate { $0.id == id }), context)
    }

    /// `[Subcategory]` por sus `shortcutID` (CSV mirror de Budget). Fetch de TODAS + lookup en memoria
    /// (patrón `findTags`; tolera ids duplicados quedándose con la primera). Orden = el de `ids` (wire).
    /// LANZA si no se puede leer (solo la llaman los appliers, que tiran la página).
    static func findSubcategories(byShortcutIDs ids: [UUID], context: ModelContext) throws -> [Subcategory] {
        guard !ids.isEmpty else { return [] }
        var lookup: [UUID: Subcategory] = [:]
        for s in try fetchAllOrThrow(FetchDescriptor<Subcategory>(), context) where lookup[s.shortcutID] == nil {
            lookup[s.shortcutID] = s
        }
        return ids.compactMap { lookup[$0] }
    }

    /// `[Account]` por sus `shortcutID` (CSV mirror de Budget). LANZA si no se puede leer.
    static func findAccounts(byShortcutIDs ids: [UUID], context: ModelContext) throws -> [Account] {
        guard !ids.isEmpty else { return [] }
        var lookup: [UUID: Account] = [:]
        for a in try fetchAllOrThrow(FetchDescriptor<Account>(), context) where lookup[a.shortcutID] == nil {
            lookup[a.shortcutID] = a
        }
        return ids.compactMap { lookup[$0] }
    }

    /// `SyncIdentity` de un `syncID` (para el born-remote insert y el tombstone delete). Store sync-meta.
    static func fetchSyncIdentity(bySyncID id: UUID, context: ModelContext) -> SyncIdentity? {
        lenient("SyncIdentity") { try findSyncIdentity(bySyncID: id, context: context) }
    }
    static func findSyncIdentity(bySyncID id: UUID, context: ModelContext) throws -> SyncIdentity? {
        try fetchFirstOrThrow(FetchDescriptor<SyncIdentity>(predicate: #Predicate { $0.syncID == id }), context)
    }

    /// `[Tag]` por sus `id` (CSV mirror). Fetch de TODOS + lookup en memoria (los Tags son pocos; evita
    /// las esquinas de `Array.contains` en `#Predicate`). Tolera ids duplicados (`Tag.byIDLookup`). LANZA si no se
    /// puede leer.
    static func findTags(byIDs ids: [UUID], context: ModelContext) throws -> [Tag] {
        guard !ids.isEmpty else { return [] }
        let lookup = Tag.byIDLookup(try fetchAllOrThrow(FetchDescriptor<Tag>(), context))
        return ids.compactMap { lookup[$0] }
    }

    /// Primera fila del descriptor. LANZA si el fetch falla: el que decide qué significa un fallo es el
    /// llamador (`find*` lo propaga; `fetch*` lo convierte en `nil` con `lenient`).
    private static func fetchFirstOrThrow<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>, _ context: ModelContext
    ) throws -> T? {
        if _testThrowOnFetchOf.contains(String(describing: T.self)) { throw EntityApplyFetchError.unreadable(String(describing: T.self)) }
        var d = descriptor
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    /// Todas las filas del descriptor, con el mismo seam que `fetchFirstOrThrow`. LANZA si el fetch falla.
    private static func fetchAllOrThrow<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>, _ context: ModelContext
    ) throws -> [T] {
        if _testThrowOnFetchOf.contains(String(describing: T.self)) { throw EntityApplyFetchError.unreadable(String(describing: T.self)) }
        return try context.fetch(descriptor)
    }

    /// Semántica HISTÓRICA de los `fetch*`: un fetch fallido se lee `nil`. La conservan los llamadores que leen una
    /// señal y no deciden sobre ningún dato (`liveRowExists`). La resolución de refs y el pase de danglers usan
    /// `find*` desde el ticket `dangling-ref-repair-is-lost-when-its-row-cannot-be-read`.
    private static func lenient<T>(_ site: String, _ body: () throws -> T?) -> T? {
        do {
            return try body()
        } catch {
            #if DEBUG
            print("EntityApplyMap.fetch\(site) error: \(error)")
            #endif
            return nil
        }
    }

    /// Tipos (nombre de clase) cuyas lecturas estrictas (`find*`, `fetchAllOrThrow` de los M2M, el registro
    /// `SyncDanglingRef`) y cuyo barrido `deleteLiveRows` LANZAN como si la base no se dejara leer. Vacío = nunca.
    /// SOLO tests (tickets `apply-overwrites-a-pending-local-write-without-its-guards` y
    /// `dangling-ref-repair-is-lost-when-its-row-cannot-be-read`).
    static var _testThrowOnFetchOf: Set<String> = []
}

/// Una lectura de la que depende el apply (búsqueda de fila, barrido) lanzó. El payload es el tipo, sin PII.
enum EntityApplyFetchError: Error { case unreadable(String) }
