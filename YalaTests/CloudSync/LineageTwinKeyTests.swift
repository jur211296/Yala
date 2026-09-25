//
//  LineageTwinKeyTests.swift
//  YalaTests
//
//  La clave de linaje y el casado de gemelas de la prueba de cobertura (ticket
//  `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`). Lógica pura: sin contexto ni red.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Clave de linaje y casado de gemelas · lógica pura")
struct LineageTwinKeyTests {

    private typealias Proof = MigrationWorkExecutor.AdoptSharedRowsProof
    private typealias Candidate = MigrationWorkExecutor.LineageCandidate
    private typealias Rebind = MigrationWorkExecutor.LineageRebind

    /// Las tablas en literal tienen que ser las de `EntityEmissionMap` de las seis entidades de identidad sintética: si una
    /// se renombra, la clave dejaría de leerse y esa tabla volvería a bloquear para siempre.
    @Test("las tablas sintéticas son las de EntityEmissionMap")
    func syntheticTables_matchTheEmissionMap() {
        #expect(LineageTwinKey.syntheticTables == [
            EntityEmissionMap.transactionItem.table, EntityEmissionMap.inboxDraft.table, EntityEmissionMap.category.table,
            EntityEmissionMap.favoritePayment.table, EntityEmissionMap.merchantMemory.table,
            EntityEmissionMap.exchangeRate.table,
        ])
    }

    /// El `created_at` del wire viene de PostgREST con microsegundos y zona; el local es un `Date` con fracción de ms. Los
    /// dos truncan a ms y dan la misma clave; un ms de diferencia, no.
    @Test("created_at: el wire con microsegundos y el Date local dan la misma clave; un ms de diferencia, no")
    func createdAt_wireAndLocalAgree() {
        let local = Date(timeIntervalSince1970: 1_700_000_000.123_987)
        #expect(LineageTwinKey.backend(table: "tx_items", fields: ["created_at": .string("2023-11-14T22:13:20.123987+00:00")])
                == LineageTwinKey.created(local))
        #expect(LineageTwinKey.backend(table: "inbox_drafts", fields: ["created_at": .string("2023-11-14T22:13:20.123Z")])
                == LineageTwinKey.created(local))
        #expect(LineageTwinKey.backend(table: "favorite_payments", fields: ["created_at": .string("2023-11-14T22:13:20.124Z")])
                != LineageTwinKey.created(local))
    }

    /// Sin el campo, o con un tipo que no es el suyo, no hay clave: `nil`, que la prueba lee como «puede ser cualquiera».
    @Test("sin el campo que la decide, no hay clave")
    func missingOrMistypedFields_haveNoKey() {
        #expect(LineageTwinKey.backend(table: "tx_items", fields: [:]) == nil)
        #expect(LineageTwinKey.backend(table: "tx_items", fields: ["created_at": .number(1)]) == nil)
        #expect(LineageTwinKey.backend(table: "merchant_memory", fields: [:]) == nil)
        #expect(LineageTwinKey.backend(table: "categories", fields: ["name": .string("x")]) == nil,
                "sin `is_default_seed` no se sabe qué clave toca")
        #expect(LineageTwinKey.backend(table: "categories", fields: ["is_default_seed": .bool(true),
                                                                    "color_hex": .string("#1"), "is_income": .bool(false)])
                == nil, "semilla sin `icon_name` (ni siquiera null)")
        #expect(LineageTwinKey.backend(table: "budgets", fields: ["created_at": .string("2023-11-14T22:13:20Z")]) == nil,
                "las tablas de identidad propia no casan por clave")
    }

    /// Categorías: la semilla por la clave del deduplicador (icono `null` incluido); las del usuario, SIN clave: renombrar
    /// para fundir dos categorías casaría la fila de una con la identidad de la otra.
    @Test("categorías: semilla por la clave del deduplicador; las del usuario no tienen clave")
    func categoryKeys() {
        #expect(LineageTwinKey.backend(table: "categories", fields: [
            "is_default_seed": .bool(true), "icon_name": .null, "color_hex": .string("#FF9500"), "is_income": .bool(true),
            "name": .string("Sueldo"),
        ]) == LineageTwinKey.category(isDefaultSeed: true, iconName: nil, colorHex: "#FF9500", isIncome: true))
        #expect(LineageTwinKey.backend(table: "categories", fields: ["is_default_seed": .bool(false), "name": .string("Viajes")])
                == nil)
        #expect(LineageTwinKey.category(isDefaultSeed: false, iconName: "x", colorHex: "#0", isIncome: false) == nil)
        #expect(LineageTwinKey.backend(table: "merchant_memory", fields: ["merchant_canonical": .string("starbucks")])
                == LineageTwinKey.merchant("starbucks"))
    }

    /// La clave de fusión: la de cada deduplicador del arranque, y ninguna para lo que no es semilla.
    @Test("clave de fusión: semillas y avisos de sistema; ni avisos custom ni filas del usuario")
    func fusionKeys() {
        #expect(LineageTwinKey.fusion(table: "subcategories", fields: ["is_default_seed": .bool(true), "icon_name": .string("cart")])
                == LineageTwinKey.subcategorySeedFusion(iconName: "cart"))
        #expect(LineageTwinKey.fusion(table: "subcategories", fields: ["is_default_seed": .bool(false), "icon_name": .string("cart")])
                == nil)
        #expect(LineageTwinKey.fusion(table: "notification_items", fields: ["type_raw": .string("dailyReminder")])
                == LineageTwinKey.notificationFusion(typeRaw: "dailyReminder"))
        #expect(LineageTwinKey.fusion(table: "notification_items", fields: ["type_raw": .string("custom")]) == nil)
        #expect(LineageTwinKey.fusion(table: "categories", fields: [
            "is_default_seed": .bool(true), "icon_name": .string("fork"), "color_hex": .string("#1"), "is_income": .bool(false),
        ]) == LineageTwinKey.backend(table: "categories", fields: [
            "is_default_seed": .bool(true), "icon_name": .string("fork"), "color_hex": .string("#1"), "is_income": .bool(false),
        ]))
        #expect(LineageTwinKey.fusion(table: "tx_items", fields: ["created_at": .string("2023-11-14T22:13:20Z")]) == nil)
    }

    // MARK: - El veredicto

    private let shared = UUID()
    private var baseInventory: [(table: String, syncID: UUID?)] { [("accounts", shared)] }

    /// Casa solo una clave ÚNICA en los dos lados. `t:1` sale dos veces en el backend: ni una de sus candidatas casa, y
    /// quedan sospechosas. `t:2` es única: casa. La fila con `t:9` (borrada aquí) no tiene candidata.
    @Test("solo casa una clave única en el backend y entre las candidatas")
    func proof_onlyUniqueKeysRebind() {
        let a = UUID(), b = UUID(), c = UUID(), deleted = UUID()
        let proof = MigrationWorkExecutor.adoptSharedRowsProof(
            plan: AdoptOrphanDiff.Plan(orphans: [:], needsIdentity: ["tx_items": 3]),
            inventory: baseInventory + [("tx_items", nil), ("tx_items", nil), ("tx_items", nil)],
            liveByTable: ["accounts": [shared], "tx_items": [a, b, c, deleted]],
            liveKeys: [a: "t:1", b: "t:1", c: "t:2", deleted: "t:9"],
            candidates: [Candidate(table: "tx_items", key: "t:1", ref: 0), Candidate(table: "tx_items", key: "t:1", ref: 1),
                         Candidate(table: "tx_items", key: "t:2", ref: 2)])
        #expect(proof == .accountRowsMissing(table: "tx_items", missing: 3), "a, b y la borrada, con dos sospechosas")
    }

    /// Y la unicidad del backend cuenta TODAS sus filas vivas de la tabla, también las que ya están aquí: `t:1` sale en una
    /// cubierta y en la que falta, así que la candidata con `t:1` no casa aunque sea la única.
    @Test("una clave repetida en el backend no casa aunque una de sus filas ya esté aquí")
    func proof_backendKeyRepeatedByACoveredRow_doesNotRebind() {
        let covered = UUID(), missing = UUID()
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: AdoptOrphanDiff.Plan(orphans: [:], needsIdentity: ["tx_items": 1]),
            inventory: baseInventory + [("tx_items", covered), ("tx_items", nil)],
            liveByTable: ["accounts": [shared], "tx_items": [covered, missing]],
            liveKeys: [covered: "t:1", missing: "t:1"],
            candidates: [Candidate(table: "tx_items", key: "t:1", ref: 0)])
            == .accountRowsMissing(table: "tx_items", missing: 1))
    }

    /// La clave única del backend no basta: si dos candidatas la comparten, ninguna casa.
    @Test("dos candidatas con la misma clave no casan aunque la del backend sea única")
    func proof_twoCandidatesWithTheSameKey_doNotRebind() {
        let a = UUID()
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: AdoptOrphanDiff.Plan(orphans: [:], needsIdentity: ["tx_items": 2]),
            inventory: baseInventory + [("tx_items", nil), ("tx_items", nil)],
            liveByTable: ["accounts": [shared], "tx_items": [a]],
            liveKeys: [a: "t:1"],
            candidates: [Candidate(table: "tx_items", key: "t:1", ref: 0), Candidate(table: "tx_items", key: "t:1", ref: 1)])
            == .accountRowsMissing(table: "tx_items", missing: 1))
    }

    /// Casar explica la fila; lo que sobra solo pasa si ninguna candidata restante es sospechosa. No lo son la nueva
    /// (`provenNew`) ni la semilla cuya clave de fusión es la de una fila sin explicar.
    @Test("tras casar, las filas sin explicar pasan solo si lo que queda es nuevo o semilla")
    func proof_unexplainedRowsPassOnlyWithoutSuspects() {
        let leaders = UUID(), deleted = UUID()
        let plan = AdoptOrphanDiff.Plan(orphans: [:], needsIdentity: ["tx_items": 2])
        let inventory = baseInventory + [("tx_items", nil), ("tx_items", nil)]
        let live: [String: Set<UUID>] = ["accounts": [shared], "tx_items": [leaders, deleted]]
        let keys = [leaders: "t:5", deleted: "t:9"]
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: plan, inventory: inventory, liveByTable: live, liveKeys: keys,
            candidates: [Candidate(table: "tx_items", key: "t:5", ref: 0),
                         Candidate(table: "tx_items", key: "t:7", ref: 1, provenNew: true)])
            == .proven(sharedRows: 1, rebinds: [Rebind(ref: 0, syncID: leaders)]))
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: plan, inventory: inventory, liveByTable: live, liveKeys: keys,
            candidates: [Candidate(table: "tx_items", key: "t:5", ref: 0), Candidate(table: "tx_items", key: "t:7", ref: 1)])
            == .accountRowsMissing(table: "tx_items", missing: 1), "una clave que no casa no prueba nada")
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: plan, inventory: inventory, liveByTable: live, liveKeys: keys, liveFusionKeys: [deleted: "f:1"],
            candidates: [Candidate(table: "tx_items", key: "t:5", ref: 0),
                         Candidate(table: "tx_items", key: "t:7", ref: 1, fusionKey: "f:1")])
            == .proven(sharedRows: 1, rebinds: [Rebind(ref: 0, syncID: leaders)]),
            "su clave de fusión es la de la fila sin explicar")
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: plan, inventory: inventory, liveByTable: live, liveKeys: keys, liveFusionKeys: [deleted: "f:1"],
            candidates: [Candidate(table: "tx_items", key: "t:5", ref: 0),
                         Candidate(table: "tx_items", key: "t:7", ref: 1, fusionKey: "f:2")])
            == .accountRowsMissing(table: "tx_items", missing: 1), "otra clave de fusión: el deduplicador no las fundiría")
    }

    /// Una fila del backend sin clave legible apaga el casado de TODA su tabla: puede ser la gemela de cualquiera, así que la
    /// clave `t:5` ya no es única aunque salga una vez.
    @Test("una fila del backend sin clave apaga el casado de la tabla")
    func proof_unkeyedBackendRow_disablesRebindingInItsTable() {
        let keyed = UUID(), unkeyed = UUID()
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: AdoptOrphanDiff.Plan(orphans: [:], needsIdentity: ["tx_items": 1]),
            inventory: baseInventory + [("tx_items", nil)],
            liveByTable: ["accounts": [shared], "tx_items": [keyed, unkeyed]],
            liveKeys: [keyed: "t:5"],
            candidates: [Candidate(table: "tx_items", key: "t:5", ref: 0)])
            == .accountRowsMissing(table: "tx_items", missing: 2))
    }

    /// Una clave ilegible no casa y deja la fila sin explicar: con una candidata sospechosa, bloquea.
    @Test("una fila sin clave legible no casa")
    func proof_unkeyedRowNeverRebinds() {
        let leaders = UUID()
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: AdoptOrphanDiff.Plan(orphans: [:], needsIdentity: ["categories": 1]),
            inventory: baseInventory + [("categories", nil)],
            liveByTable: ["accounts": [shared], "categories": [leaders]],
            candidates: [Candidate(table: "categories", key: "name:x", ref: 0)])
            == .accountRowsMissing(table: "categories", missing: 1))
    }

    /// En identidad propia no hay clave: la fila que falta pasa si todo lo que sube en esa tabla es nuevo.
    @Test("identidad propia: sin sospechosas pasa, con una bloquea")
    func proof_intrinsicTables() {
        let budget = UUID()
        let plan = AdoptOrphanDiff.Plan(orphans: ["budgets": [UUID()]], needsIdentity: [:])
        let live: [String: Set<UUID>] = ["accounts": [shared], "budgets": [budget]]
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: plan, inventory: baseInventory, liveByTable: live,
            candidates: [Candidate(table: "budgets", key: nil, ref: 0, provenNew: true)]) == .proven(sharedRows: 1))
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: plan, inventory: baseInventory, liveByTable: live,
            candidates: [Candidate(table: "budgets", key: nil, ref: 0)]) == .accountRowsMissing(table: "budgets", missing: 1))
    }

    /// Una candidata solo casa en SU tabla.
    @Test("una candidata de otra tabla no casa")
    func proof_candidatesOnlyMatchInTheirTable() {
        let leaders = UUID()
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: AdoptOrphanDiff.Plan(orphans: [:], needsIdentity: ["tx_items": 1, "inbox_drafts": 1]),
            inventory: baseInventory + [("tx_items", nil), ("inbox_drafts", nil)],
            liveByTable: ["accounts": [shared], "tx_items": [leaders]],
            liveKeys: [leaders: "t:5"],
            candidates: [Candidate(table: "inbox_drafts", key: "t:5", ref: 0),
                         Candidate(table: "tx_items", key: "t:6", ref: 1)])
            == .accountRowsMissing(table: "tx_items", missing: 1))
    }

    /// Sin fila compartida no hay nada que casar: el corpus es otro, aunque las claves coincidan.
    @Test("sin fila compartida, noSharedRows aunque las claves casen")
    func proof_withoutSharedRows_isNoSharedRows_evenIfKeysMatch() {
        let leaders = UUID()
        #expect(MigrationWorkExecutor.adoptSharedRowsProof(
            plan: AdoptOrphanDiff.Plan(orphans: [:], needsIdentity: ["tx_items": 1]),
            inventory: [("tx_items", nil)],
            liveByTable: ["tx_items": [leaders]],
            liveKeys: [leaders: "t:5"],
            candidates: [Candidate(table: "tx_items", key: "t:5", ref: 0)]) == .noSharedRows)
    }
}
