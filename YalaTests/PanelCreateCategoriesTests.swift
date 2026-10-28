//
//  PanelCreateCategoriesTests.swift
//  YalaTests
//
//  Card omw5 (2026-10-27): tras un onboarding de cero, «Nuevo registro», Voz y Foto salían apagados sin explicación.
//  Había cuenta y ninguna subcategoría: la semilla del «Sí» salía por su centinela antes de mirar la base. Aquí:
//  (1) qué enseña la fila del Panel en cada estado, (2) que una petición explícita siembra aunque el centinela esté
//  puesto —con el control de que la semilla automática, con el mismo centinela, no siembra—, y (3) que los dos
//  sitios donde la persona pide categorías llaman a la petición y no a la semilla automática.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Panel · sin categorías no se queda gris en silencio (card omw5)", .serialized)
@MainActor
struct PanelCreateCategoriesTests {

    // MARK: - 1 · El estado de la fila

    @Test func sinCuenta_pideLaCuenta_aunqueTampocoHayaCategorias() {
        #expect(PanelQuickActionsGateLogic.state(hasActiveAccount: false, hasVisibleSubcategory: false) == .needsAccount)
        #expect(PanelQuickActionsGateLogic.state(hasActiveAccount: false, hasVisibleSubcategory: true) == .needsAccount)
    }

    @Test func conCuentaYSinSubcategoriaVisible_pideCategorias() {
        #expect(PanelQuickActionsGateLogic.state(hasActiveAccount: true, hasVisibleSubcategory: false) == .needsCategories)
    }

    @Test func conCuentaYSubcategoriaVisible_esLaFilaDeSiempre() {
        #expect(PanelQuickActionsGateLogic.state(hasActiveAccount: true, hasVisibleSubcategory: true) == .ready)
    }

    @Test func crearCategorias_siembraSoloSinCategoriasPropias() {
        #expect(PanelQuickActionsGateLogic.createCategoriesAction(userCategoryCount: 0) == .seedDefaults)
        #expect(PanelQuickActionsGateLogic.createCategoriesAction(userCategoryCount: 1) == .openCategoriesSettings)
    }

    // MARK: - 2 · La petición explícita no la anula el centinela

    /// `seedCategoriesIfNeeded` lee el centinela de `UserDefaults.standard` (no admite inyección), así que el test lo
    /// fija y lo devuelve como estaba. La suite es `.serialized`.
    private func withStaleSentinel(_ body: () throws -> Void) rethrows {
        let key = CategorySeedSentinel.currentKey
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(true, forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        try body()
    }

    private func userCategoryCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Yala.Category>(predicate: #Predicate { !$0.isSystem }))
    }

    private func visibleSubcategoryCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.isVisible }))
    }

    /// El control: es el bug. Con el centinela de una vida anterior y la base vacía, la semilla automática no siembra.
    @Test func control_laSemillaAutomatica_conElCentinelaPuesto_noSiembra() throws {
        let context = try makeTestContext()
        try withStaleSentinel {
            seedCategoriesIfNeeded(in: context)
            let userCategories = try userCategoryCount(context)
            #expect(userCategories == 0)
        }
    }

    @Test func peticion_conElCentinelaPuestoYSinCategorias_siembra() throws {
        let context = try makeTestContext()
        try withStaleSentinel {
            #expect(seedDefaultCategoriesOnUserRequest(in: context))
            let userCategories = try userCategoryCount(context)
            let visibleSubcategories = try visibleSubcategoryCount(context)
            #expect(userCategories > 0)
            #expect(visibleSubcategories > 0)
        }
    }

    /// Las categorías sistema de Grupos no se eligen al registrar: no cuentan como «ya tiene categorías».
    @Test func peticion_conSoloCategoriasSistema_siembra() throws {
        let context = try makeTestContext()
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        seedSystemGroupCategoriesIfNeeded(in: context, defaults: defaults)
        let systemCategories = try context.fetchCount(
            FetchDescriptor<Yala.Category>(predicate: #Predicate { $0.isSystem }))
        #expect(systemCategories > 0)
        try withStaleSentinel {
            #expect(seedDefaultCategoriesOnUserRequest(in: context))
            let userCategories = try userCategoryCount(context)
            #expect(userCategories > 0)
        }
    }

    @Test func peticion_conUnaCategoriaPropia_noSiembraNiDuplica() throws {
        let context = try makeTestContext()
        context.insert(Yala.Category(name: "Mía", colorHex: "#123456", isIncome: false))
        try context.save()
        try withStaleSentinel {
            #expect(seedDefaultCategoriesOnUserRequest(in: context) == false)
            let userCategories = try userCategoryCount(context)
            #expect(userCategories == 1)
        }
    }

    // MARK: - 3 · El cableado (source-scan)

    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El «Sí» del onboarding y «Crear categorías» del selector son peticiones: si vuelven a la semilla automática, el
    /// centinela de una vida anterior las deja sin efecto otra vez.
    @Test(arguments: [
        "Yala/App/Views/Onboarding/OnboardingView.swift",
        "Yala/App/Views/Transactions/SubcategorySelectorSheet.swift",
    ])
    func lasPeticionesDeCategorias_noPasanPorElCentinela(_ path: String) throws {
        let code = try Self.code(path)
        #expect(code.contains("seedDefaultCategoriesOnUserRequest(in: modelContext)"))
        #expect(!code.contains("seedCategoriesIfNeeded("), "\(path) volvió a la semilla con centinela.")
    }

    /// La fila del Panel recibe el estado y la salida: sin esto, el Panel volvería a la fila apagada.
    @Test func elPanel_pasaElEstadoSinCategoriasYSuSalida() throws {
        let code = try Self.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(code.contains("needsCategories: viewModel.quickActionsState == .needsCategories"))
        #expect(code.contains("onCreateCategories: { createCategoriesFromPanel() }"))
        #expect(code.contains("sheets.settingsInitialDestination = .categories"))
    }
}
