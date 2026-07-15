//
//  GroupEntityEmissionMap.swift
//  Yala
//
//  Mapa DECLARATIVO de emisión canónica c1 de las entidades del canal de sync de GRUPOS (incremento G2).
//  Espeja `EntityEmissionMap` (personal): `propiedad Swift → (columna Postgres, builder de CanonValue)`,
//  reutilizando `ColumnEmitter`/`EntityEmission`/`CanonValue`/`Emit`/`DeltaEmitter`/`Canonc1Codec` del
//  motor personal. Es la SSOT de la proyección de dominio limpio del wire de Grupos (§A.1).
//
//  Entidades EMISIBLES (4): `SplitGroup` (UPDATE-only — nace vía RPC create_group, G3+), `SplitExpense`,
//  `SplitShare`, `SplitSettlement`. `SplitMember` es PULL-ONLY (§A.1 `pull_only:true`): NO tiene emisión
//  (el cliente jamás la empuja).
//
//  Grupos de coherencia (§A.1): `gmoney` (split_expenses {amount, currency_code}), `gshare`
//  (split_shares {expense_id, member_key, amount}), `smoney` (split_settlements {amount, currency_code}).
//  La expansión al grupo entero (invariante de emisión) la hace `DeltaEmitter`, igual que en personal.
//
//  `@MainActor`: los builders leen `@Model`.
//

import Foundation

/// Nombres canónicos de tipo (= nombre de clase `@Model`) de las 5 entidades de Grupos. Literales
/// estables (renombrar la clase NO debe cambiarlos — invariante del muro anti-fuga y del apply).
nonisolated enum GroupSyncEntityType {
    static let splitGroup = "SplitGroup"
    static let splitMember = "SplitMember"
    static let splitExpense = "SplitExpense"
    static let splitShare = "SplitShare"
    static let splitSettlement = "SplitSettlement"
}

/// Registro declarativo de emisión de las 4 entidades EMISIBLES de Grupos + los nombres del muro.
@MainActor
enum GroupEntityEmissionMap {

    // MARK: - Muro anti-fuga (nombres de clase)

    /// Las 5 entidades del store de Grupos. El drain de `GroupsSyncClient` DESCARTA todo cambio cuyo
    /// entity name NO esté aquí (espejo de `CloudSyncEngine.personalEntityNames`, disjunto de él). El
    /// History token es por-CONTAINER (personal + grupos + sync-meta en un solo ModelContainer) → este
    /// filtro es PERMANENTE, no una optimización.
    static let groupEntityNames: Set<String> = [
        GroupSyncEntityType.splitGroup,
        GroupSyncEntityType.splitMember,
        GroupSyncEntityType.splitExpense,
        GroupSyncEntityType.splitShare,
        GroupSyncEntityType.splitSettlement,
    ]

    /// Subconjunto EMISIBLE (drain → outbox): excluye `SplitMember` (PULL-ONLY). El filtro del muro
    /// (`groupEntityNames`) sigue conteniendo a `SplitMember` para no re-drenarla ni por accidente al
    /// avanzar el token; simplemente su cambio NO produce fila de outbox.
    static let emittableGroupEntityNames: Set<String> = [
        GroupSyncEntityType.splitGroup,
        GroupSyncEntityType.splitExpense,
        GroupSyncEntityType.splitShare,
        GroupSyncEntityType.splitSettlement,
    ]

    // MARK: - split_expenses (gmoney) — sync_id = SplitExpense.id, group_id = groupZoneID

    static let splitExpense = EntityEmission<SplitExpense>(
        table: "split_expenses",
        emitters: [
            ColumnEmitter("amount", group: "gmoney") { m, _ in .money(m.amount) },
            ColumnEmitter("currency_code", group: "gmoney") { m, _ in .string(m.currencyCode) },
            ColumnEmitter("expense_description") { m, _ in .string(m.expenseDescription) },
            ColumnEmitter("note") { m, _ in Emit.text(m.note) },
            ColumnEmitter("date") { m, _ in .timestamp(m.date) },
            ColumnEmitter("created_at") { m, _ in .timestamp(m.createdAt) },
            ColumnEmitter("paid_by_member_key") { m, _ in .string(m.paidByMemberID) },
            ColumnEmitter("split_type") { m, _ in .string(m.splitType) },
            ColumnEmitter("is_settled") { m, _ in .bool(m.isSettled) },
            ColumnEmitter("is_opening_balance") { m, _ in .bool(m.isOpeningBalance) },
            ColumnEmitter("subcategory_name") { m, _ in Emit.text(m.subcategoryName) },
        ],
        columnKeyPaths: [
            \SplitExpense.amount: ["amount"],
            \SplitExpense.currencyCode: ["currency_code"],
            \SplitExpense.expenseDescription: ["expense_description"],
            \SplitExpense.note: ["note"],
            \SplitExpense.date: ["date"],
            \SplitExpense.createdAt: ["created_at"],
            \SplitExpense.paidByMemberID: ["paid_by_member_key"],
            \SplitExpense.splitType: ["split_type"],
            \SplitExpense.isSettled: ["is_settled"],
            \SplitExpense.isOpeningBalance: ["is_opening_balance"],
            \SplitExpense.subcategoryName: ["subcategory_name"],
        ]
    )

    // MARK: - split_shares (gshare) — sync_id = SplitShare.id, group_id = groupZoneID

    static let splitShare = EntityEmission<SplitShare>(
        table: "split_shares",
        emitters: [
            ColumnEmitter("expense_id", group: "gshare") { m, _ in .uuid(m.expenseID) },
            ColumnEmitter("member_key", group: "gshare") { m, _ in .string(m.memberID) },
            ColumnEmitter("amount", group: "gshare") { m, _ in .money(m.amount) },
            ColumnEmitter("is_paid") { m, _ in .bool(m.isPaid) },
        ],
        columnKeyPaths: [
            \SplitShare.expenseID: ["expense_id"],
            \SplitShare.memberID: ["member_key"],
            \SplitShare.amount: ["amount"],
            \SplitShare.isPaid: ["is_paid"],
        ]
    )

    // MARK: - split_settlements (smoney) — sync_id = SplitSettlement.id, group_id = groupZoneID

    static let splitSettlement = EntityEmission<SplitSettlement>(
        table: "split_settlements",
        emitters: [
            ColumnEmitter("from_member_key") { m, _ in .string(m.fromMemberID) },
            ColumnEmitter("to_member_key") { m, _ in .string(m.toMemberID) },
            ColumnEmitter("amount", group: "smoney") { m, _ in .money(m.amount) },
            ColumnEmitter("currency_code", group: "smoney") { m, _ in .string(m.currencyCode) },
            ColumnEmitter("note") { m, _ in Emit.text(m.note) },
            ColumnEmitter("date") { m, _ in .timestamp(m.date) },
            ColumnEmitter("is_confirmed") { m, _ in .bool(m.isConfirmed) },
        ],
        columnKeyPaths: [
            \SplitSettlement.fromMemberID: ["from_member_key"],
            \SplitSettlement.toMemberID: ["to_member_key"],
            \SplitSettlement.amount: ["amount"],
            \SplitSettlement.currencyCode: ["currency_code"],
            \SplitSettlement.note: ["note"],
            \SplitSettlement.date: ["date"],
            \SplitSettlement.isConfirmed: ["is_confirmed"],
        ]
    )

    // MARK: - split_groups (UPDATE-only) — identity = cloudKitZoneID (group_id), sync_id=null en el wire

    static let splitGroup = EntityEmission<SplitGroup>(
        table: "split_groups",
        emitters: [
            ColumnEmitter("name") { m, _ in .string(m.name) },
            ColumnEmitter("icon_name") { m, _ in .string(m.iconName) },
            ColumnEmitter("color_hex") { m, _ in .string(m.colorHex) },
            ColumnEmitter("currency_code") { m, _ in .string(m.currencyCode) },
            ColumnEmitter("simplify_debts") { m, _ in .bool(m.simplifyDebts) },
            ColumnEmitter("show_debts_in_single_currency") { m, _ in .bool(m.showDebtsInSingleCurrency) },
            ColumnEmitter("members_can_invite") { m, _ in .bool(m.membersCanInvite) },
            ColumnEmitter("default_split_type") { m, _ in .string(m.defaultSplitType) },
            ColumnEmitter("is_archived") { m, _ in .bool(m.isArchived) },
            ColumnEmitter("is_hidden_for_all") { m, _ in .bool(m.isHiddenForAll) },
            // created_at NO se emite: el column-grant del server (supabase-groups-staging.ddl, hallazgo #1
            // de G1) lo excluye del UPDATE de split_groups — emitirlo haría 42501 → rechazo del delta ENTERO
            // de meta. El manifest lo conserva solo para la proyección del PULL (applyGroupMeta sí lo lee).
        ],
        columnKeyPaths: [
            \SplitGroup.name: ["name"],
            \SplitGroup.iconName: ["icon_name"],
            \SplitGroup.colorHex: ["color_hex"],
            \SplitGroup.currencyCode: ["currency_code"],
            \SplitGroup.simplifyDebts: ["simplify_debts"],
            \SplitGroup.showDebtsInSingleCurrency: ["show_debts_in_single_currency"],
            \SplitGroup.membersCanInvite: ["members_can_invite"],
            \SplitGroup.defaultSplitType: ["default_split_type"],
            \SplitGroup.isArchived: ["is_archived"],
            \SplitGroup.isHiddenForAll: ["is_hidden_for_all"],
        ]
    )

    // MARK: - class → tabla Postgres

    /// El `GroupSyncOutbox.entityType` guarda el NOMBRE DE CLASE; el delta de wire exige la tabla Postgres.
    /// `nil` = clase no cableada (incluye `SplitMember`, pull-only) → el sender la DESCARTA con canario.
    static func table(forClass className: String) -> String? {
        switch className {
        case GroupSyncEntityType.splitExpense: return splitExpense.table
        case GroupSyncEntityType.splitShare: return splitShare.table
        case GroupSyncEntityType.splitSettlement: return splitSettlement.table
        case GroupSyncEntityType.splitGroup: return splitGroup.table
        default: return nil
        }
    }

    /// Catálogo type-erased (tabla → columnas + column→group_key) para tests de paridad contra el manifest.
    static var catalog: [String: (columns: Set<String>, groups: [String: String])] {
        [
            splitExpense.table: (splitExpense.columns, splitExpense.groupByColumn),
            splitShare.table: (splitShare.columns, splitShare.groupByColumn),
            splitSettlement.table: (splitSettlement.columns, splitSettlement.groupByColumn),
            splitGroup.table: (splitGroup.columns, splitGroup.groupByColumn),
        ]
    }
}
