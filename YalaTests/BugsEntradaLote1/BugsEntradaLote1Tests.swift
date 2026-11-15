//
//  BugsEntradaLote1Tests.swift
//  YalaTests
//
//  Lote 1 de bugs de entrada y recuperación de 2.3 (14-nov). Tres cards con lógica que fijar aquí; la cuarta (el aviso de
//  enlace no válido bajo «Unirme al grupo») la fija `InviteRecoveryPasteVisibleUITests`.
//
//  - «Conectar con la cuenta tarda 22–50 s»: la lectura de la cuenta pide páginas de 1.000 y el Merkle de la barra va en
//    paralelo con ella (medido en el iPhone 14: 15 páginas de ~2,5 s y 6 s de Merkle antes de empezar).
//  - «Un solo "Continuar"»: con «Traer mis datos» elegido en la puerta, «¡Qué bien volver a verte!» no vuelve a preguntar.
//  - «63 categorías y dos pantallas después 65»: el teléfono cuenta las categorías como la sonda de iCloud.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Card 2 · un solo «Continuar»

@Suite("Lote 1 · Restaurar no vuelve a preguntar «Traer mis datos»")
struct RestoreBringChoiceTests {

    @Test("Con la elección hecha en la puerta: solo «Continuar», sin «Empezar desde cero» ni flecha atrás")
    func chosenAtGate_singleContinue() {
        let actions = RestoreFoundActionsLogic.actions(bringChosenAtGate: true)
        #expect(actions == .init(primaryIsContinue: true, offersStartFresh: false, offersBack: false))
    }

    @Test("Sin elegir antes (Restaurar desde iCloud): la pregunta de siempre")
    func notChosen_keepsTheQuestion() {
        let actions = RestoreFoundActionsLogic.actions(bringChosenAtGate: false)
        #expect(actions == .init(primaryIsContinue: false, offersStartFresh: true, offersBack: true))
    }

    @Test("La marca se enciende, se lee y se apaga, y sin marca vale «no eligió»")
    func storeRoundTrip() {
        let defaults = makeIsolatedDefaults(prefix: "lote1.bringChoice")
        #expect(!RestoreBringChoiceStore.wasChosenAtGate(defaults: defaults))
        RestoreBringChoiceStore.recordChosenAtGate(defaults: defaults)
        #expect(RestoreBringChoiceStore.wasChosenAtGate(defaults: defaults))
        RestoreBringChoiceStore.clear(defaults: defaults)
        #expect(!RestoreBringChoiceStore.wasChosenAtGate(defaults: defaults))
    }
}

/// El cableado: quién enciende la marca, quién la apaga y qué lee la pantalla. Source-scan porque los tres lados son
/// closures de vistas SwiftUI.
@Suite("Lote 1 · cableado de la marca «ya eligió traer sus datos» (source-scan)")
struct RestoreBringChoiceWiringTests {

    @Test("«Traer mis datos» de la puerta apunta la elección ANTES de salir")
    func gateRecordsBeforeLeaving() throws {
        let gate = try Lote1SourceScan.code("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        let body = try #require(Lote1SourceScan.bodyOf("YalaPrimaryButton(L10n.Welcome.PrivateICloud.restoreAction) {", in: gate))
        #expect(Lote1SourceScan.lines(of: body) == ["RestoreBringChoiceStore.recordChosenAtGate()", "onRestore()"])
    }

    @Test("El Welcome apaga la marca al abrir Restaurar desde cualquier entrada que no sea la puerta")
    func welcomeClearsFromOtherEntries() throws {
        let container = try Lote1SourceScan.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let body = try #require(Lote1SourceScan.bodyOf("private func handleExistingOption(", in: container))
        #expect(body.contains("if step != .privateICloudGate { RestoreBringChoiceStore.clear() }"))
    }

    @Test("Restaurar lee la marca, la usa en «¡Qué bien volver a verte!» y la apaga al continuar y al volver")
    func restoreReadsAndClears() throws {
        let restore = try Lote1SourceScan.code("Yala/App/Views/Onboarding/WelcomeRestoreView.swift")
        #expect(restore.contains("@State private var bringChosenAtGate = RestoreBringChoiceStore.wasChosenAtGate()"))
        // El botón principal y «Empezar desde cero» dependen de la marca.
        #expect(restore.contains(
            "YalaPrimaryButton(foundActions.primaryIsContinue ? L10n.Action.continueAction : L10n.UXLote6.restoreBringBack) {"))
        #expect(restore.contains("if foundActions.offersStartFresh {"))
        // La flecha atrás: solo se esconde en `.found`.
        let back = try #require(Lote1SourceScan.bodyOf("private var showsBackButton: Bool {", in: restore))
        #expect(Lote1SourceScan.lines(of: back) == ["guard case .found = state else { return true }", "return foundActions.offersBack"])
        #expect(restore.contains("if showsBackButton {"))
        // Continuar y volver apagan la marca justo antes de irse (el código sin comentarios).
        let flat = Lote1SourceScan.lines(of: restore).joined(separator: " ")
        #expect(flat.contains("RestoreBringChoiceStore.clear() onBack()"))
        #expect(flat.contains("DS.Haptic.success() RestoreBringChoiceStore.clear() onContinueWithSummary(summary)"))
    }
}

// MARK: - Card 3 · la misma cifra de categorías en las tres pantallas

@Suite("Lote 1 · el teléfono cuenta las categorías como la sonda de iCloud", .serialized)
@MainActor
struct RestoreCategoriesCountTests {

    @Test("Identidades repetidas cuentan una vez; las que no tienen identidad, una a una")
    func visibleCount() {
        #expect(SubcategoryDedupLogic.visibleCount(identityKeys: []) == 0)
        #expect(SubcategoryDedupLogic.visibleCount(identityKeys: ["a", "a", "b"]) == 2)
        #expect(SubcategoryDedupLogic.visibleCount(identityKeys: [nil, nil, "a", "a"]) == 3)
    }

    /// El caso del recorrido: dos copias de la misma categoría de fábrica con sus subcategorías (la que bajó de iCloud y la
    /// que sembró el teléfono), más una del usuario. La sonda daría 3; el resumen del teléfono decía 5.
    @Test("Dos copias de fábrica y una propia: el resumen dice lo mismo que la sonda")
    func duplicatedSeeds_matchTheProbe() throws {
        let context = try makeTestContext()
        let seeds: [(order: Int, icon: String, name: String)] = [(0, "cart.fill", "Supermercado"), (1, "fork.knife", "Restaurantes")]
        var tally = ICloudCorpusCategoryTally()
        for copy in ["A", "B"] {
            let category = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false, iconName: "fork.knife")
            context.insert(category)
            tally.addCategory(recordName: copy, iconName: "fork.knife", colorHex: "#FF0000", isIncome: false)
            for seed in seeds {
                context.insert(Subcategory(name: seed.name, isDefaultSeed: true, sortOrder: seed.order,
                                           iconName: seed.icon, category: category))
                tally.addSubcategory(isDefaultSeed: true, isSystemSubcategory: false, categoryRecordName: copy,
                                     sortOrder: seed.order, iconName: seed.icon, name: seed.name)
            }
        }
        let own = YalaCategory(name: "Mío", colorHex: "#00FF00", isIncome: false, isDefaultSeed: false, iconName: "star")
        context.insert(own)
        context.insert(Subcategory(name: "Gym", isDefaultSeed: false, sortOrder: 0, iconName: "star", category: own))
        tally.addCategory(recordName: "own", iconName: "star", colorHex: "#00FF00", isIncome: false)
        tally.addSubcategory(isDefaultSeed: false, isSystemSubcategory: false, categoryRecordName: "own",
                             sortOrder: 0, iconName: "star", name: "Gym")
        try context.save()

        let summary = try context.iCloudAccountSummary(
            appPreferences: AppPreferences(defaults: makeIsolatedDefaults(prefix: "lote1.summary")))
        #expect(summary.categoriesCount == 3)
        #expect(summary.categoriesCount == tally.count)
    }

    @Test("Una subcategoría de sistema sigue fuera de la cifra")
    func systemStaysOut() throws {
        let context = try makeTestContext()
        let category = YalaCategory(name: "Grupos", colorHex: "#0000FF", isIncome: false, iconName: "person.2")
        context.insert(category)
        context.insert(Subcategory(name: "Grupo", isDefaultSeed: true, iconName: "person.2", isSystem: true, category: category))
        context.insert(Subcategory(name: "Gym", isDefaultSeed: false, iconName: "star", category: category))
        try context.save()
        let summary = try context.iCloudAccountSummary(
            appPreferences: AppPreferences(defaults: makeIsolatedDefaults(prefix: "lote1.summary.system")))
        #expect(summary.categoriesCount == 1)
    }
}

// MARK: - Card 1 · entrar con la cuenta sin esperas que no hacen falta

@Suite("Lote 1 · la lectura de la cuenta en el adopt (source-scan)")
@MainActor
struct AdoptEnumerationSpeedTests {

    @Test("Páginas de 1.000 filas: el máximo que sirve /sync/pull")
    func pageSizeIsTheServerMaximum() throws {
        #expect(MigrationWorkExecutor.adoptEnumerationPageSize == 1000)
        let gateway = try Lote1SourceScan.code("gateway/src/sync/routes.ts")
        #expect(gateway.contains("clamp(parseIntOr(c.req.query(\"limit\"), 500), 1, 1000)"))
        let executor = try Lote1SourceScan.code("Yala/Services/CloudSync/MigrationWorkExecutor.swift")
        let enumerate = try #require(Lote1SourceScan.bodyOf(
            "private func enumerateBackendSyncIDs(onPage: ((Int) -> Void)? = nil) async -> BackendEnumeration? {", in: executor))
        #expect(enumerate.contains("pullPage(since: cursor, limit: Self.adoptEnumerationPageSize)"))
    }

    /// La cifra de la barra no frena la lectura: el Merkle va en una tarea aparte y la lectura empieza sin esperarlo. Con el
    /// `await merkleClient.fetchMerkle()` de antes delante, la lectura arrancaba ~6 s tarde.
    @Test("El Merkle de la barra va en paralelo con la lectura y se cancela al terminarla")
    func progressMerkleDoesNotBlockTheRead() throws {
        let executor = try Lote1SourceScan.code("Yala/Services/CloudSync/MigrationWorkExecutor.swift")
        let reconcile = try #require(Lote1SourceScan.bodyOf("func runAdoptOrphanReconcile() async -> AdoptReconcileOutcome {",
                                                       in: executor))
        let read = try #require(reconcile.range(of: "let readEnumeration = await enumerateBackendSyncIDs("))
        let task = try #require(reconcile.range(of: "let expectedRowsTask = Task { @MainActor [weak self] in"))
        let cancel = try #require(reconcile.range(of: "expectedRowsTask.cancel()"))
        #expect(task.upperBound <= read.lowerBound)
        #expect(read.upperBound <= cancel.lowerBound)
        // Antes de la lectura no queda ningún Merkle esperado en línea.
        let beforeRead = String(reconcile[..<task.lowerBound])
        #expect(!beforeRead.contains("await merkleClient.fetchMerkle()"))
    }
}

// MARK: - Helpers

/// Lectura de fuentes del repo para los scans de cableado (molde de `GroupsGateWipeFailureTests`).
enum Lote1SourceScan {

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // BugsEntradaLote1
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // raíz
    }

    /// El fichero sin las líneas de comentario.
    static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    static func bodyOf(_ marker: String, in source: String) -> String? {
        guard let start = source.range(of: marker) else { return nil }
        var depth = marker.hasSuffix("{") ? 1 : 0
        var opened = depth > 0
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1; opened = true }
            if ch == "}" { depth -= 1; if opened && depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    /// Líneas no vacías, sin sangría.
    static func lines(of body: String) -> [String] {
        body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
