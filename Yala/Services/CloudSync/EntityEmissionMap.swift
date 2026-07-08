//
//  EntityEmissionMap.swift
//  Yala
//
//  Mapa DECLARATIVO por entidad del Modo Nube (incremento I8c): `propiedad Swift → (columna Postgres,
//  builder de CanonValue)`. Es la SSOT de la proyección de DOMINIO LIMPIO (§d.1) que consume
//  `DeltaEmitter` para producir el `fields` canónico c1 del cable de sync. Una entrada por columna del
//  `capability_manifest.json` (cruzado por `EntityEmissionParityTests`), NUNCA columnas server-authored
//  ni de identidad (`sync_id`/`hlc`/… — esas las gobierna el backend / el propio outbox).
//
//  Principios (§d.1 + §d.4bis):
//  - **Dominio LIMPIO**: los CSV mirrors CRUDOS no viajan. Las columnas `uuid[]` (`tag_refs`,
//    `subcategory_ids`, `account_ids`) se emiten RESUELTAS a los syncIDs del destino vía los helpers
//    `resolvedXIDs()`/`resolvedTagIDs()` (leen el CSV mirror SSOT, no la relación M2M lazy cruda —
//    gotcha del repo). El lowercase de los UUID lo hace el codec (aquí se pasa `.uuid`/`.uuidArray`).
//    Los `split_participant_ids_raw`/`split_values_raw` de `scheduled_payments` SÍ son TEXT opaco en la
//    DDL (config de split ordenada, pares uuid:value) → viajan como `.string`.
//  - **`sync_id_source` del destino**: un `_ref` apunta a la IDENTIDAD de sync del destino, que varía por
//    entidad (Category/TX/InboxDraft/… = `syncID` sintético; Account/Subcategory = `shortcutID`;
//    Tag/ScheduledPayment/Budget/CashFlow*/… = `id`). Ver `capability_manifest.json:sync_id_source`.
//  - **Grupos de coherencia** (`group` en cada `ColumnEmitter`): money/split/budget/tx_split. Membresía
//    CONGELADA (espeja `capability_manifest.json:coherence_groups`) — la expansión al grupo entero
//    (invariante de emisión) la hace `DeltaEmitter`, no este mapa.
//
//  Cobertura: las 16 entidades de dominio. De ellas, SOLO 6 llevan `syncID` y las cablea hoy el
//  `CloudSyncEngine` (TransactionItem/InboxDraft/Category/FavoritePayment/MerchantMemory/ExchangeRate);
//  esas 6 declaran además `columnKeyPaths` (mapping keypath→columna para el PATCH parcial del path de
//  UPDATE). Las otras 10 son declarativas (parity + cuando ganen identidad en incrementos futuros).
//
//  `@MainActor`: los builders leen `@Model`/relaciones (aislados al main actor bajo
//  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
//

import Foundation

// MARK: - Builders puros de CanonValue (extracción de valor ya desreferenciado → CanonValue)

/// Helpers puros que envuelven un valor Swift YA extraído del modelo en su `CanonValue` canónico.
/// `nonisolated`: no tocan el actor (reciben escalares/arrays, no `@Model`). La tri-estado de opcionales
/// se resuelve aquí: opcional-a-nil → `.null` (columna tocada-y-puesta-a-NULL, ≠ columna ausente §d.1).
nonisolated enum Emit {

    /// Texto opcional: nil → `.null`.
    static func text(_ s: String?) -> CanonValue { s.map(CanonValue.string) ?? .null }

    /// Dinero opcional (escala 4): nil → `.null`.
    static func money(_ d: Double?) -> CanonValue { d.map(CanonValue.money) ?? .null }

    /// Tasa opcional (escala 8): nil → `.null`.
    static func rate(_ d: Double?) -> CanonValue { d.map(CanonValue.rate) ?? .null }

    /// Entero opcional: nil → `.null`.
    static func int(_ n: Int?) -> CanonValue { n.map(CanonValue.int) ?? .null }

    /// Timestamp opcional: nil → `.null`.
    static func timestamp(_ d: Date?) -> CanonValue { d.map(CanonValue.timestamp) ?? .null }

    /// FK opcional a un `UUID` (identidad de sync del destino): nil → `.null`.
    static func ref(_ id: UUID?) -> CanonValue { id.map(CanonValue.uuid) ?? .null }

    /// FK opcional guardada como `String` (p.ej. `scheduledPaymentID`): parsea a UUID o `.null`.
    static func refFromString(_ s: String?) -> CanonValue {
        guard let s, let id = UUID(uuidString: s) else { return .null }
        return .uuid(id)
    }

    /// Array `uuid[]` resuelto (tag_refs/subcategory_ids/…): vacío/nil → `.uuidArray([])`. Con esa array
    /// vacía el codec OMITE la key si la columna es SINGLETON ("sin filtro", ≠ null ≠ []) y emite `[]`
    /// explícito si pertenece a un grupo de coherencia (DIFERIDOS #25 opción 1). El orden/dedup/lowercase
    /// los aplica el codec.
    static func uuidArray(_ ids: Set<UUID>?) -> CanonValue { .uuidArray(Array(ids ?? [])) }

    /// Un `Double?` de confianza que la DDL modela como TEXT: nil → `.null`; si no, su repr decimal.
    static func doubleText(_ d: Double?) -> CanonValue { d.map { .string(String($0)) } ?? .null }

    /// Columna `text[]` desde un array Swift: JSON array de strings vía `.dataJSON` (el codec lo
    /// re-canonicaliza recursivamente preservando el orden). v1 no tiene un case `CanonValue` para
    /// `text[]`; el JSON-array es la representación determinista sobre el cable (PostgREST la acepta).
    static func textArray(_ items: [String]) -> CanonValue {
        do {
            let data = try JSONEncoder().encode(items)
            return .dataJSON(data)
        } catch {
            #if DEBUG
            print("Emit.textArray: encode error: \(error)")
            #endif
            return .dataJSON(Data("[]".utf8))
        }
    }

    /// Columna `text[]` desde un CSV `"a,b,c"`: nil → `.null`; si no, JSON array de los tokens (orden
    /// preservado). Vacío (`""`) → `[]`.
    static func csvTextArray(_ csv: String?) -> CanonValue {
        guard let csv else { return .null }
        let items = csv.split(separator: ",").map(String.init)
        return textArray(items)
    }

    /// Día civil (§d.1/S9) desde el instante de un `Date`, en el calendario dado (default `.current`).
    /// La derivación `{picker_components} → local_day` vive AQUÍ (I8c): se extraen los componentes
    /// año/mes/día en el calendario del usuario y se re-posiciona a MEDIANOCHE UTC de ese día civil (el
    /// codec luego formatea `YYYY-MM-DD` del prefijo de la T-CANON). Inyectar un calendario UTC lo hace
    /// determinista en tests.
    static func localDay(_ date: Date, _ calendar: Calendar) -> CanonValue {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else {
            return .localDay(date)  // fallback defensivo (componentes inesperadamente nil)
        }
        let days = CanonicalTime.daysFromCivil(year: Int64(y), month: Int64(m), day: Int64(d))
        let midnightUTC = Date(timeIntervalSince1970: Double(days) * 86_400)
        return .localDay(midnightUTC)
    }
}

// MARK: - ColumnEmitter / EntityEmission

/// Emisor de UNA columna Postgres: su nombre, su grupo de coherencia (o `nil` = unidad singleton
/// field-level) y el builder que lee el modelo y produce el `CanonValue`.
@MainActor
struct ColumnEmitter<Model: AnyObject> {
    let column: String
    let group: String?
    let build: (Model, Calendar) -> CanonValue

    init(_ column: String, group: String? = nil, _ build: @escaping (Model, Calendar) -> CanonValue) {
        self.column = column
        self.group = group
        self.build = build
    }
}

/// Proyección completa de una entidad: su tabla Postgres, sus emisores por columna, y (solo entidades
/// cableadas) el mapping keypath→columnas para el PATCH parcial del path de UPDATE.
@MainActor
struct EntityEmission<Model: AnyObject> {
    let table: String
    let emitters: [ColumnEmitter<Model>]
    /// keypath de propiedad → columna(s) que toca (para el UPDATE PATCH parcial). Una prop puede tocar
    /// varias columnas (p.ej. `date` → `date` + `local_day`; la relación M2M y su CSV mirror → el mismo
    /// `tag_refs`). `syncID` NUNCA está aquí (es la PK, no columna de dominio). Vacío en las 10 entidades
    /// aún no cableadas.
    let columnKeyPaths: [PartialKeyPath<Model>: [String]]

    init(
        table: String,
        emitters: [ColumnEmitter<Model>],
        columnKeyPaths: [PartialKeyPath<Model>: [String]] = [:]
    ) {
        self.table = table
        self.emitters = emitters
        self.columnKeyPaths = columnKeyPaths
    }

    /// Set de columnas emitidas (para el parity contra el manifest).
    var columns: Set<String> { Set(emitters.map(\.column)) }

    /// columna → group_key (solo las columnas agrupadas). Para el parity y la expansión de grupos.
    var groupByColumn: [String: String] {
        var m: [String: String] = [:]
        for e in emitters where e.group != nil { m[e.column] = e.group! }
        return m
    }
}

// MARK: - EntityEmissionMap

/// Registro declarativo de las 16 entidades de dominio.
@MainActor
enum EntityEmissionMap {

    // MARK: tx_items (money + tx_split) — CABLEADA

    static let transactionItem = EntityEmission<TransactionItem>(
        table: "tx_items",
        emitters: [
            ColumnEmitter("date") { m, _ in .timestamp(m.date) },
            ColumnEmitter("local_day") { m, cal in Emit.localDay(m.date, cal) },
            ColumnEmitter("amount", group: "money") { m, _ in .money(m.amount) },
            ColumnEmitter("currency_code") { m, _ in .string(m.currencyCode) },
            ColumnEmitter("note") { m, _ in Emit.text(m.note) },
            ColumnEmitter("category_ref") { m, _ in Emit.ref(m.category?.syncID) },
            ColumnEmitter("subcategory_ref") { m, _ in Emit.ref(m.subcategory?.shortcutID) },
            ColumnEmitter("account_ref") { m, _ in Emit.ref(m.account?.shortcutID) },
            ColumnEmitter("tag_refs") { m, _ in Emit.uuidArray(m.resolvedTagIDs()) },
            ColumnEmitter("amount_in_preferred_currency", group: "money") { m, _ in .money(m.amountInPreferredCurrency) },
            ColumnEmitter("preferred_currency_code", group: "money") { m, _ in .string(m.preferredCurrencyCode) },
            ColumnEmitter("exchange_rate", group: "money") { m, _ in .rate(m.exchangeRate) },
            ColumnEmitter("is_exchange_rate_provisional", group: "money") { m, _ in .bool(m.isExchangeRateProvisional) },
            ColumnEmitter("need_override") { m, _ in Emit.text(m.needOverride) },
            ColumnEmitter("scheduled_payment_ref") { m, _ in Emit.refFromString(m.scheduledPaymentID) },
            ColumnEmitter("balance_adjustment_type") { m, _ in Emit.text(m.balanceAdjustmentType) },
            ColumnEmitter("transfer_pair_id") { m, _ in Emit.text(m.transferPairID) },
            ColumnEmitter("split_expense_id") { m, _ in Emit.text(m.splitExpenseID) },
            ColumnEmitter("split_group_zone_id") { m, _ in Emit.text(m.splitGroupZoneID) },
            ColumnEmitter("split_settlement_id") { m, _ in Emit.text(m.splitSettlementID) },
            ColumnEmitter("split_total_amount", group: "tx_split") { m, _ in Emit.money(m.splitTotalAmount) },
            ColumnEmitter("split_type", group: "tx_split") { m, _ in Emit.text(m.splitType) },
            ColumnEmitter("split_my_value", group: "tx_split") { m, _ in Emit.money(m.splitMyValue) },
            ColumnEmitter("split_divisor", group: "tx_split") { m, _ in Emit.money(m.splitDivisor) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
        ],
        columnKeyPaths: [
            \TransactionItem.date: ["date", "local_day"],
            \TransactionItem.amount: ["amount"],
            \TransactionItem.currencyCode: ["currency_code"],
            \TransactionItem.note: ["note"],
            \TransactionItem.category: ["category_ref"],
            \TransactionItem.subcategory: ["subcategory_ref"],
            \TransactionItem.account: ["account_ref"],
            \TransactionItem.tags: ["tag_refs"],
            \TransactionItem.tagIDs: ["tag_refs"],
            \TransactionItem.amountInPreferredCurrency: ["amount_in_preferred_currency"],
            \TransactionItem.preferredCurrencyCode: ["preferred_currency_code"],
            \TransactionItem.exchangeRate: ["exchange_rate"],
            \TransactionItem.isExchangeRateProvisional: ["is_exchange_rate_provisional"],
            \TransactionItem.needOverride: ["need_override"],
            \TransactionItem.scheduledPaymentID: ["scheduled_payment_ref"],
            \TransactionItem.balanceAdjustmentType: ["balance_adjustment_type"],
            \TransactionItem.transferPairID: ["transfer_pair_id"],
            \TransactionItem.splitExpenseID: ["split_expense_id"],
            \TransactionItem.splitGroupZoneID: ["split_group_zone_id"],
            \TransactionItem.splitSettlementID: ["split_settlement_id"],
            \TransactionItem.splitTotalAmount: ["split_total_amount"],
            \TransactionItem.splitType: ["split_type"],
            \TransactionItem.splitMyValue: ["split_my_value"],
            \TransactionItem.splitDivisor: ["split_divisor"],
            \TransactionItem.createdAt: ["created_at"],
        ]
    )

    // MARK: scheduled_payments (split) — declarativa (aún sin syncID)

    static let scheduledPayment = EntityEmission<ScheduledPayment>(
        table: "scheduled_payments",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("note") { m, _ in Emit.text(m.note) },
            ColumnEmitter("amount", group: "split") { m, _ in .money(m.amount) },
            ColumnEmitter("currency_code") { m, _ in .string(m.currencyCode) },
            ColumnEmitter("is_variable_amount") { m, _ in .bool(m.isVariableAmount) },
            ColumnEmitter("transaction_type") { m, _ in .string(m.transactionType) },
            ColumnEmitter("account_ref") { m, _ in Emit.ref(m.account?.shortcutID) },
            ColumnEmitter("subcategory_ref") { m, _ in Emit.ref(m.subcategory?.shortcutID) },
            ColumnEmitter("tag_refs") { m, _ in Emit.uuidArray(m.resolvedTagIDs()) },
            ColumnEmitter("need_override") { m, _ in Emit.text(m.needOverride) },
            ColumnEmitter("is_recurring") { m, _ in .bool(m.isRecurring) },
            ColumnEmitter("recurrence_type") { m, _ in .string(m.recurrenceType) },
            ColumnEmitter("recurrence_interval") { m, _ in .int(m.recurrenceInterval) },
            ColumnEmitter("next_due_date") { m, _ in .timestamp(m.nextDueDate) },
            ColumnEmitter("day_of_month") { m, _ in Emit.int(m.dayOfMonth) },
            ColumnEmitter("selected_weekdays") { m, _ in Emit.csvTextArray(m.selectedWeekdays) },
            ColumnEmitter("yearly_month") { m, _ in Emit.int(m.yearlyMonth) },
            ColumnEmitter("yearly_day") { m, _ in Emit.int(m.yearlyDay) },
            ColumnEmitter("end_date") { m, _ in Emit.timestamp(m.endDate) },
            ColumnEmitter("payment_category") { m, _ in .string(m.paymentCategory) },
            ColumnEmitter("notify_on_due_date") { m, _ in .bool(m.notifyOnDueDate) },
            ColumnEmitter("notify_days_before") { m, _ in .int(m.notifyDaysBefore) },
            ColumnEmitter("is_active") { m, _ in .bool(m.isActive) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
            ColumnEmitter("last_paid_date") { m, _ in Emit.timestamp(m.lastPaidDate) },
            ColumnEmitter("skipped_dates_raw") { m, _ in Emit.csvTextArray(m.skippedDatesRaw) },
            ColumnEmitter("group_zone_id") { m, _ in Emit.text(m.groupZoneID) },
            ColumnEmitter("split_total_amount", group: "split") { m, _ in Emit.money(m.splitTotalAmount) },
            ColumnEmitter("split_type", group: "split") { m, _ in Emit.text(m.splitType) },
            ColumnEmitter("split_participant_ids_raw", group: "split") { m, _ in Emit.text(m.splitParticipantIDsRaw) },
            ColumnEmitter("split_values_raw", group: "split") { m, _ in Emit.text(m.splitValuesRaw) },
        ]
    )

    // MARK: budgets (budget) — declarativa (aún sin syncID)

    static let budget = EntityEmission<Budget>(
        table: "budgets",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("currency_code", group: "budget") { m, _ in .string(m.currencyCode) },
            ColumnEmitter("limit_amount", group: "budget") { m, _ in .money(m.limitAmount) },
            ColumnEmitter("category_id") { m, _ in Emit.ref(m.category?.syncID) },
            ColumnEmitter("period_type") { m, _ in .string(m.periodType) },
            ColumnEmitter("start_date") { m, _ in Emit.timestamp(m.startDate) },
            ColumnEmitter("end_date") { m, _ in Emit.timestamp(m.endDate) },
            ColumnEmitter("natures", group: "budget") { m, _ in Emit.csvTextArray(m.natures) },
            ColumnEmitter("subcategory_ids", group: "budget") { m, _ in Emit.uuidArray(m.resolvedSubcategoryIDs()) },
            ColumnEmitter("account_ids", group: "budget") { m, _ in Emit.uuidArray(m.resolvedAccountIDs()) },
            ColumnEmitter("tag_refs", group: "budget") { m, _ in Emit.uuidArray(m.resolvedTagIDs()) },
            ColumnEmitter("is_active") { m, _ in .bool(m.isActive) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
            ColumnEmitter("is_favorite") { m, _ in .bool(m.isFavorite) },
            ColumnEmitter("favorite_order") { m, _ in .int(m.favoriteOrder) },
            ColumnEmitter("alert_enabled") { m, _ in .bool(m.alertEnabled) },
            ColumnEmitter("alert_thresholds") { m, _ in Emit.csvTextArray(m.alertThresholds) },
            ColumnEmitter("include_shared_expenses") { m, _ in .bool(m.includeSharedExpenses) },
        ]
    )

    // MARK: inbox_drafts — CABLEADA

    static let inboxDraft = EntityEmission<InboxDraft>(
        table: "inbox_drafts",
        emitters: [
            ColumnEmitter("note") { m, _ in .string(m.note) },
            ColumnEmitter("amount") { m, _ in Emit.money(m.amount) },
            ColumnEmitter("date") { m, _ in Emit.timestamp(m.date) },
            ColumnEmitter("account_ref") { m, _ in Emit.ref(m.account?.shortcutID) },
            ColumnEmitter("subcategory_ref") { m, _ in Emit.ref(m.subcategory?.shortcutID) },
            ColumnEmitter("tag_refs") { m, _ in Emit.uuidArray(m.resolvedTagIDs()) },
            ColumnEmitter("approved_transaction_ref") { m, _ in Emit.ref(m.approvedTransaction?.syncID) },
            ColumnEmitter("source_type_raw") { m, _ in .string(m.sourceTypeRaw) },
            ColumnEmitter("raw_text") { m, _ in Emit.text(m.rawText) },
            ColumnEmitter("evidence") { m, _ in Emit.text(m.evidence) },
            ColumnEmitter("confidence_amount") { m, _ in Emit.doubleText(m.confidenceAmount) },
            ColumnEmitter("confidence_date") { m, _ in Emit.doubleText(m.confidenceDate) },
            ColumnEmitter("confidence_merchant") { m, _ in Emit.doubleText(m.confidenceMerchant) },
            ColumnEmitter("confidence_subcategory") { m, _ in Emit.doubleText(m.confidenceSubcategory) },
            ColumnEmitter("needs_user_input") { m, _ in Emit.textArray(m.needsUserInput) },
            ColumnEmitter("newly_created_tag_names") { m, _ in Emit.textArray(m.newlyCreatedTagNames) },
            ColumnEmitter("status_raw") { m, _ in .string(m.statusRaw) },
            ColumnEmitter("cached_account_name") { m, _ in Emit.text(m.cachedAccountName) },
            ColumnEmitter("cached_subcategory_name") { m, _ in Emit.text(m.cachedSubcategoryName) },
            ColumnEmitter("cached_category_color_hex") { m, _ in Emit.text(m.cachedCategoryColorHex) },
            ColumnEmitter("cached_subcategory_icon") { m, _ in Emit.text(m.cachedSubcategoryIcon) },
            ColumnEmitter("cached_currency_code") { m, _ in Emit.text(m.cachedCurrencyCode) },
            ColumnEmitter("source_scheduled_payment_ref") { m, _ in Emit.refFromString(m.sourceScheduledPaymentID) },
            ColumnEmitter("split_expense_id") { m, _ in Emit.text(m.splitExpenseID) },
            ColumnEmitter("split_group_zone_id") { m, _ in Emit.text(m.splitGroupZoneID) },
            ColumnEmitter("split_settlement_id") { m, _ in Emit.text(m.splitSettlementID) },
            ColumnEmitter("opt_in_personal_only") { m, _ in .bool(m.optInPersonalOnly) },
            ColumnEmitter("origin_reason_key") { m, _ in Emit.text(m.originReasonKey) },
            ColumnEmitter("origin_actor_name") { m, _ in Emit.text(m.originActorName) },
            ColumnEmitter("origin_group_name") { m, _ in Emit.text(m.originGroupName) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
            ColumnEmitter("updated_at_domain") { m, _ in .timestamp(m.updatedAt) },
        ],
        columnKeyPaths: [
            \InboxDraft.note: ["note"],
            \InboxDraft.amount: ["amount"],
            \InboxDraft.date: ["date"],
            \InboxDraft.account: ["account_ref"],
            \InboxDraft.subcategory: ["subcategory_ref"],
            \InboxDraft.tags: ["tag_refs"],
            \InboxDraft.tagIDs: ["tag_refs"],
            \InboxDraft.approvedTransaction: ["approved_transaction_ref"],
            \InboxDraft.sourceTypeRaw: ["source_type_raw"],
            \InboxDraft.rawText: ["raw_text"],
            \InboxDraft.evidence: ["evidence"],
            \InboxDraft.confidenceAmount: ["confidence_amount"],
            \InboxDraft.confidenceDate: ["confidence_date"],
            \InboxDraft.confidenceMerchant: ["confidence_merchant"],
            \InboxDraft.confidenceSubcategory: ["confidence_subcategory"],
            \InboxDraft.needsUserInput: ["needs_user_input"],
            \InboxDraft.newlyCreatedTagNames: ["newly_created_tag_names"],
            \InboxDraft.statusRaw: ["status_raw"],
            \InboxDraft.cachedAccountName: ["cached_account_name"],
            \InboxDraft.cachedSubcategoryName: ["cached_subcategory_name"],
            \InboxDraft.cachedCategoryColorHex: ["cached_category_color_hex"],
            \InboxDraft.cachedSubcategoryIcon: ["cached_subcategory_icon"],
            \InboxDraft.cachedCurrencyCode: ["cached_currency_code"],
            \InboxDraft.sourceScheduledPaymentID: ["source_scheduled_payment_ref"],
            \InboxDraft.splitExpenseID: ["split_expense_id"],
            \InboxDraft.splitGroupZoneID: ["split_group_zone_id"],
            \InboxDraft.splitSettlementID: ["split_settlement_id"],
            \InboxDraft.optInPersonalOnly: ["opt_in_personal_only"],
            \InboxDraft.originReasonKey: ["origin_reason_key"],
            \InboxDraft.originActorName: ["origin_actor_name"],
            \InboxDraft.originGroupName: ["origin_group_name"],
            \InboxDraft.createdAt: ["created_at"],
            \InboxDraft.updatedAt: ["updated_at_domain"],
        ]
    )

    // MARK: categories — CABLEADA

    static let category = EntityEmission<Category>(
        table: "categories",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("color_hex") { m, _ in .string(m.colorHex) },
            ColumnEmitter("is_income") { m, _ in .bool(m.isIncome) },
            ColumnEmitter("is_default_seed") { m, _ in .bool(m.isDefaultSeed) },
            ColumnEmitter("is_visible") { m, _ in .bool(m.isVisible) },
            ColumnEmitter("sort_order") { m, _ in .int(m.sortOrder) },
            ColumnEmitter("icon_name") { m, _ in Emit.text(m.iconName) },
            ColumnEmitter("is_system") { m, _ in .bool(m.isSystem) },
        ],
        columnKeyPaths: [
            \Category.name: ["name"],
            \Category.colorHex: ["color_hex"],
            \Category.isIncome: ["is_income"],
            \Category.isDefaultSeed: ["is_default_seed"],
            \Category.isVisible: ["is_visible"],
            \Category.sortOrder: ["sort_order"],
            \Category.iconName: ["icon_name"],
            \Category.isSystem: ["is_system"],
        ]
    )

    // MARK: favorite_payments — CABLEADA

    static let favoritePayment = EntityEmission<FavoritePayment>(
        table: "favorite_payments",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("transaction_type") { m, _ in .string(m.transactionType) },
            ColumnEmitter("amount") { m, _ in Emit.money(m.amount) },
            ColumnEmitter("note") { m, _ in Emit.text(m.note) },
            ColumnEmitter("account_ref") { m, _ in Emit.ref(m.account?.shortcutID) },
            ColumnEmitter("subcategory_ref") { m, _ in Emit.ref(m.subcategory?.shortcutID) },
            ColumnEmitter("tag_refs") { m, _ in Emit.uuidArray(m.resolvedTagIDs()) },
            ColumnEmitter("need_override") { m, _ in Emit.text(m.needOverride) },
            ColumnEmitter("currency_code") { m, _ in Emit.text(m.currencyCode) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
            ColumnEmitter("display_order") { m, _ in .int(m.displayOrder) },
        ],
        columnKeyPaths: [
            \FavoritePayment.name: ["name"],
            \FavoritePayment.transactionType: ["transaction_type"],
            \FavoritePayment.amount: ["amount"],
            \FavoritePayment.note: ["note"],
            \FavoritePayment.account: ["account_ref"],
            \FavoritePayment.subcategory: ["subcategory_ref"],
            \FavoritePayment.tags: ["tag_refs"],
            \FavoritePayment.tagIDs: ["tag_refs"],
            \FavoritePayment.needOverride: ["need_override"],
            \FavoritePayment.currencyCode: ["currency_code"],
            \FavoritePayment.createdAt: ["created_at"],
            \FavoritePayment.displayOrder: ["display_order"],
        ]
    )

    // MARK: merchant_memory — CABLEADA

    static let merchantMemory = EntityEmission<MerchantMemory>(
        table: "merchant_memory",
        emitters: [
            ColumnEmitter("merchant_canonical") { m, _ in .string(m.merchantCanonical) },
            ColumnEmitter("subcategory_ref") { m, _ in Emit.ref(m.subcategory?.shortcutID) },
            ColumnEmitter("count_approved") { m, _ in .int(m.countApproved) },
            ColumnEmitter("count_corrected") { m, _ in .int(m.countCorrected) },
            ColumnEmitter("last_approved_at") { m, _ in .timestamp(m.lastApprovedAt) },
            ColumnEmitter("aliases") { m, _ in Emit.textArray(m.aliases) },
        ],
        columnKeyPaths: [
            \MerchantMemory.merchantCanonical: ["merchant_canonical"],
            \MerchantMemory.subcategory: ["subcategory_ref"],
            \MerchantMemory.countApproved: ["count_approved"],
            \MerchantMemory.countCorrected: ["count_corrected"],
            \MerchantMemory.lastApprovedAt: ["last_approved_at"],
            \MerchantMemory.aliases: ["aliases"],
        ]
    )

    // MARK: exchange_rates — CABLEADA

    static let exchangeRate = EntityEmission<ExchangeRate>(
        table: "exchange_rates",
        emitters: [
            ColumnEmitter("date_key") { m, _ in .string(m.dateKey) },
            ColumnEmitter("base") { m, _ in .string(m.base) },
            ColumnEmitter("rates") { m, _ in .dataJSON(m.rates) },
            ColumnEmitter("timestamp") { m, _ in Emit.timestamp(m.timestamp) },
        ],
        columnKeyPaths: [
            \ExchangeRate.dateKey: ["date_key"],
            \ExchangeRate.base: ["base"],
            \ExchangeRate.rates: ["rates"],
            \ExchangeRate.timestamp: ["timestamp"],
        ]
    )

    // MARK: accounts — declarativa

    static let account = EntityEmission<Account>(
        table: "accounts",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("currency_code") { m, _ in .string(m.currencyCode) },
            ColumnEmitter("color_hex") { m, _ in .string(m.colorHex) },
            ColumnEmitter("icon_name") { m, _ in .string(m.iconName) },
            ColumnEmitter("type") { m, _ in .string(m.type) },
            ColumnEmitter("account_number") { m, _ in Emit.text(m.accountNumber) },
            ColumnEmitter("adjustment_mode") { m, _ in .string(m.adjustmentMode) },
            ColumnEmitter("exclude_from_statistics") { m, _ in .bool(m.excludeFromStatistics) },
            ColumnEmitter("is_archived") { m, _ in .bool(m.isArchived) },
            ColumnEmitter("is_system_account") { m, _ in .bool(m.isSystemAccount) },
            ColumnEmitter("credit_card_payment_reminder") { m, _ in .bool(m.creditCardPaymentReminder) },
            ColumnEmitter("credit_card_payment_day") { m, _ in .int(m.creditCardPaymentDay) },
        ]
    )

    // MARK: subcategories — declarativa

    static let subcategory = EntityEmission<Subcategory>(
        table: "subcategories",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("color_hex") { m, _ in Emit.text(m.colorHex) },
            ColumnEmitter("is_default_seed") { m, _ in .bool(m.isDefaultSeed) },
            ColumnEmitter("is_visible") { m, _ in .bool(m.isVisible) },
            ColumnEmitter("sort_order") { m, _ in .int(m.sortOrder) },
            ColumnEmitter("nature_raw_value") { m, _ in Emit.text(m.natureRawValue) },
            ColumnEmitter("icon_name") { m, _ in Emit.text(m.iconName) },
            ColumnEmitter("is_system") { m, _ in .bool(m.isSystem) },
            ColumnEmitter("category_ref") { m, _ in Emit.ref(m.category?.syncID) },
        ]
    )

    // MARK: tags — declarativa

    static let tag = EntityEmission<Tag>(
        table: "tags",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("color_hex") { m, _ in .string(m.colorHex) },
            ColumnEmitter("icon_name") { m, _ in .string(m.iconName) },
            ColumnEmitter("is_active") { m, _ in .bool(m.isActive) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
        ]
    )

    // MARK: notification_items — declarativa

    static let notificationItem = EntityEmission<NotificationItem>(
        table: "notification_items",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("text") { m, _ in .string(m.text) },
            ColumnEmitter("hour") { m, _ in .int(m.hour) },
            ColumnEmitter("minute") { m, _ in .int(m.minute) },
            ColumnEmitter("type_raw") { m, _ in .string(m.typeRaw) },
            ColumnEmitter("is_active") { m, _ in .bool(m.isActive) },
            ColumnEmitter("icon_name") { m, _ in .string(m.iconName) },
            ColumnEmitter("color_hex") { m, _ in .string(m.colorHex) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
            ColumnEmitter("sort_order") { m, _ in .int(m.sortOrder) },
            // Solo para tipos de reporte (CHECK de la DDL: NULL o valor válido).
            ColumnEmitter("report_data_type") { m, _ in
                m.notificationType.isReportType ? .string(m.reportConfig.dataType.rawValue) : .null
            },
            ColumnEmitter("report_day_preference") { m, _ in
                m.notificationType.isReportType ? .string(m.reportConfig.dayPreference.rawValue) : .null
            },
            ColumnEmitter("weekdays_raw") { m, _ in Emit.csvTextArray(m.weekdaysRaw) },
        ]
    )

    // MARK: cashflow_plans — declarativa

    static let cashFlowPlan = EntityEmission<CashFlowPlan>(
        table: "cashflow_plans",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("starting_balance") { m, _ in .money(m.startingBalance) },
            ColumnEmitter("default_months_ahead") { m, _ in .int(m.defaultMonthsAhead) },
            ColumnEmitter("default_months_back") { m, _ in .int(m.defaultMonthsBack) },
            ColumnEmitter("show_other_expenses") { m, _ in .bool(m.showOtherExpenses) },
            ColumnEmitter("show_accumulated_balance") { m, _ in .bool(m.showAccumulatedBalance) },
            ColumnEmitter("starting_balance_date") { m, _ in Emit.timestamp(m.startingBalanceDate) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
            ColumnEmitter("updated_at_domain") { m, _ in .timestamp(m.updatedAt) },
        ]
    )

    // MARK: cashflow_lines — declarativa

    static let cashFlowLine = EntityEmission<CashFlowLine>(
        table: "cashflow_lines",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("is_income") { m, _ in .bool(m.isIncome) },
            ColumnEmitter("sort_order") { m, _ in .int(m.sortOrder) },
            ColumnEmitter("is_enabled") { m, _ in .bool(m.isEnabled) },
            ColumnEmitter("estimation_method") { m, _ in .string(m.estimationMethod) },
            ColumnEmitter("manual_amount") { m, _ in Emit.money(m.manualAmount) },
            ColumnEmitter("custom_months_raw") { m, _ in Emit.csvTextArray(m.customMonthsRaw) },
            ColumnEmitter("category_ref") { m, _ in Emit.ref(m.category?.syncID) },
            ColumnEmitter("subcategory_ref") { m, _ in Emit.ref(m.subcategory?.shortcutID) },
            ColumnEmitter("scheduled_payment_ref") { m, _ in Emit.ref(m.scheduledPayment?.id) },
            ColumnEmitter("plan_ref") { m, _ in Emit.ref(m.plan?.id) },
        ]
    )

    // MARK: cashflow_overrides — declarativa

    static let cashFlowOverride = EntityEmission<CashFlowOverride>(
        table: "cashflow_overrides",
        emitters: [
            ColumnEmitter("month_key") { m, _ in .string(m.monthKey) },
            ColumnEmitter("amount") { m, _ in .money(m.amount) },
            ColumnEmitter("note") { m, _ in .string(m.note) },
            ColumnEmitter("line_ref") { m, _ in Emit.ref(m.line?.id) },
        ]
    )

    // MARK: group_bridge_prefs — declarativa

    static let groupBridgePreference = EntityEmission<GroupBridgePreference>(
        table: "group_bridge_prefs",
        emitters: [
            ColumnEmitter("group_zone_id") { m, _ in .string(m.groupZoneID) },
            ColumnEmitter("bridge_override") { m, _ in .bool(m.bridgeOverride) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
        ]
    )

    // MARK: - Mapeo NOMBRE-DE-CLASE → tabla Postgres (para el sender I8e)

    /// El `SyncOutbox.entityType` guarda el NOMBRE DE CLASE (`SyncEntityType.*`, ej. `"TransactionItem"`),
    /// no la tabla. El delta de wire (§d) exige la tabla Postgres (`entity_type`, key del manifest). Este
    /// mapeo cierra ese salto para las 6 entidades que HOY llevan `syncID` y se traducen a outbox (I3). Un
    /// `nil` = la fila de outbox referencia una clase que aún no está cableada al wire → el sender la
    /// DESCARTA con canario (no debe ocurrir: el drain solo produce filas de estas 6). Ancla los strings a
    /// `SyncEntityType` (renombrar la clase `@Model` NO cambia estos literales — invariante de rebind).
    static func table(forClass className: String) -> String? {
        switch className {
        case SyncEntityType.transactionItem: return transactionItem.table
        case SyncEntityType.inboxDraft: return inboxDraft.table
        case SyncEntityType.category: return category.table
        case SyncEntityType.favoritePayment: return favoritePayment.table
        case SyncEntityType.merchantMemory: return merchantMemory.table
        case SyncEntityType.exchangeRate: return exchangeRate.table
        default: return nil
        }
    }

    // MARK: - Catálogo type-erased (para EntityEmissionParityTests)

    /// tabla Postgres → (columnas emitidas, columna→group_key). Cubre las 16 entidades.
    static var catalog: [String: (columns: Set<String>, groups: [String: String])] {
        [
            transactionItem.table: (transactionItem.columns, transactionItem.groupByColumn),
            scheduledPayment.table: (scheduledPayment.columns, scheduledPayment.groupByColumn),
            budget.table: (budget.columns, budget.groupByColumn),
            inboxDraft.table: (inboxDraft.columns, inboxDraft.groupByColumn),
            category.table: (category.columns, category.groupByColumn),
            favoritePayment.table: (favoritePayment.columns, favoritePayment.groupByColumn),
            merchantMemory.table: (merchantMemory.columns, merchantMemory.groupByColumn),
            exchangeRate.table: (exchangeRate.columns, exchangeRate.groupByColumn),
            account.table: (account.columns, account.groupByColumn),
            subcategory.table: (subcategory.columns, subcategory.groupByColumn),
            tag.table: (tag.columns, tag.groupByColumn),
            notificationItem.table: (notificationItem.columns, notificationItem.groupByColumn),
            cashFlowPlan.table: (cashFlowPlan.columns, cashFlowPlan.groupByColumn),
            cashFlowLine.table: (cashFlowLine.columns, cashFlowLine.groupByColumn),
            cashFlowOverride.table: (cashFlowOverride.columns, cashFlowOverride.groupByColumn),
            groupBridgePreference.table: (groupBridgePreference.columns, groupBridgePreference.groupByColumn),
        ]
    }
}
