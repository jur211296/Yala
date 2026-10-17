//
//  UXAudit22ReviewFixesTests.swift
//  YalaTests
//
//  Lo que la review adversarial de los lotes 5, 6 y 7 de la auditoría UX 2.2 encontró en la implementación
//  (2026-10-17), cada hallazgo con su red. Fichero propio: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Auditoría UX 2.2 · arreglos de la review (lotes 5-7)", .serialized)
@MainActor
struct UXAudit22ReviewFixesTests {

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: - L7-6 · «Editar el saldo»

    @Test("L7-6: un céntimo de diferencia se corrige también con importes grandes")
    func balanceCorrection_comparesCents() {
        // 1000,01 − 1000,00 da 0,00999… en Double: con el umbral de antes, «cuadra» y no se guardaba nada.
        #expect(AccountBalanceCorrectionLogic.plan(current: 1000.00, currentInitialBalance: 0, target: 1000.01)
            .needsCorrection)
        #expect(AccountBalanceCorrectionLogic.plan(current: 100.00, currentInitialBalance: 0, target: 100.01)
            .needsCorrection)
        #expect(!AccountBalanceCorrectionLogic.plan(current: 1000.00, currentInitialBalance: 0, target: 1000.004)
            .needsCorrection)
        #expect(!AccountBalanceCorrectionLogic.plan(current: -1200, currentInitialBalance: 0, target: -1200)
            .needsCorrection)
    }

    @Test("L7-6: «Ajustes de saldo» tiene su nombre de cada idioma en la lista de todos los idiomas")
    func balanceAdjustmentNames_coverEveryLocale() throws {
        let resources = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale)/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            let name = try #require(table["subcategory.balanceAdjustment"], "\(locale)")
            #expect(Subcategory.balanceAdjustmentNames.contains(name), "\(locale): «\(name)» no está en la lista")
        }
    }

    @Test("L7-6: la subcategoría sembrada en otro idioma se encuentra, y no se crea otra")
    func balanceAdjustment_isFoundInAnotherLanguage() throws {
        let context = try makeTestContext()
        let other = makeTestCategory(context: context, name: "Inne")
        let polish = makeTestSubcategory(context: context, name: "Korekta salda", category: other)
        try context.save()

        let found = InitialBalanceService.findBalanceAdjustmentSubcategory(context: context)
        #expect(found?.persistentModelID == polish.persistentModelID)
        let ensured = InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context)
        #expect(ensured?.persistentModelID == polish.persistentModelID)
        #expect(try context.fetchCount(FetchDescriptor<Subcategory>()) == 1)
    }

    @Test("L7-6: el guardado busca o crea la subcategoría y, sin ella, avisa en vez de cerrarse")
    func saveAccount_wiring() throws {
        let vm = try Self.source("Yala/App/ViewModels/Accounts/AccountFormViewModel.swift")
        #expect(vm.contains("InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context) : nil"))
        let guardBody = try #require(vm.range(of: "if writesBalanceRow && subcategory == nil {"))
        let tail = vm[guardBody.upperBound...].prefix(120)
        #expect(tail.contains("isShowingSaveError = true") && tail.contains("return false"))
    }

    @Test("L7-6: con un cambio de moneda pendiente no se promete ninguna cifra, y el ajuste no va al futuro")
    func balanceEdit_viewWiring() throws {
        let view = try Self.source("Yala/App/Views/Accounts/AccountFormView.swift")
        #expect(view.contains("let correction = viewModel.isCurrencyChangeRequested ? nil : viewModel.balanceCorrection"))
        // Los dos selectores de la fecha del ajuste (el de «Editar el saldo» y el del formulario de antes).
        let pickers = view.components(separatedBy: "date: $viewModel.adjustmentDate,").dropFirst()
        #expect(pickers.count == 2)
        #expect(pickers.allSatisfy { $0.prefix(80).contains("maxDate: nil") })
    }

    // MARK: - L7-10 · Mover los registros

    @Test("L7-10: el presupuesto sigue a sus registros, y lo de la categoría se mueve con ellos")
    func moveRecords_retargetsBudgetsCashFlowAndMemory() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context)
        let travel = makeTestCategory(context: context, name: "Viajes")
        let hotel = makeTestSubcategory(context: context, name: "Hotel", category: travel)
        let food = makeTestCategory(context: context, name: "Comida")
        let restaurant = makeTestSubcategory(context: context, name: "Restaurante", category: food)
        let groceries = makeTestSubcategory(context: context, name: "Súper", category: food)
        _ = makeTestTransaction(context: context, amount: -100, account: account, category: travel, subcategory: hotel)

        // Un presupuesto que solo contaba «Hotel»: sin el arreglo se quedaba sin filtro y contaba todo el gasto.
        let onlyHotel = makeTestBudget(context: context, subcategories: [hotel])
        onlyHotel.setSubcategoryIDs(from: [hotel])
        // Otro que contaba «Hotel» y «Súper»: «Súper» se queda y entra «Restaurante».
        let mixed = makeTestBudget(context: context, subcategories: [hotel, groceries])
        mixed.setSubcategoryIDs(from: [hotel, groceries])
        // Una línea del flujo de caja de la subcategoría y lo aprendido de un comercio.
        let plan = CashFlowPlan()
        context.insert(plan)
        let line = CashFlowLine(name: "Hotel", subcategory: hotel)
        line.plan = plan
        context.insert(line)
        let memory = MerchantMemory(merchantCanonical: "marriott", subcategory: hotel)
        context.insert(memory)
        try context.save()

        try CategoryRecordsMoveService.moveAllAndDelete(
            from: travel, to: restaurant, context: context, deletionService: EntityDeletionService.shared)

        #expect(onlyHotel.resolvedSubcategoryIDs() == [restaurant.shortcutID])
        #expect(Set(onlyHotel.subcategories?.map(\.persistentModelID) ?? []) == [restaurant.persistentModelID])
        #expect(mixed.resolvedSubcategoryIDs() == [restaurant.shortcutID, groceries.shortcutID])
        #expect(line.subcategory?.persistentModelID == restaurant.persistentModelID)
        #expect(line.category?.persistentModelID == food.persistentModelID)
        #expect(line.isEnabled, "El destino no tenía línea: la que llega sigue encendida.")
        #expect(memory.subcategory?.persistentModelID == restaurant.persistentModelID)
    }

    @Test("L7-10: la línea que llega a un destino con la suya se apaga, no duplica la previsión")
    func moveRecords_disablesADuplicatedCashFlowLine() throws {
        let context = try makeTestContext()
        let travel = makeTestCategory(context: context, name: "Viajes")
        let hotel = makeTestSubcategory(context: context, name: "Hotel", category: travel)
        let food = makeTestCategory(context: context, name: "Comida")
        let restaurant = makeTestSubcategory(context: context, name: "Restaurante", category: food)
        let plan = CashFlowPlan()
        context.insert(plan)
        let moving = CashFlowLine(name: "Hotel", manualAmount: 80, subcategory: hotel)
        moving.plan = plan
        let existing = CashFlowLine(name: "Restaurante", subcategory: restaurant)
        existing.plan = plan
        context.insert(moving)
        context.insert(existing)
        try context.save()

        try CategoryRecordsMoveService.moveAllAndDelete(
            from: travel, to: restaurant, context: context, deletionService: EntityDeletionService.shared)

        #expect(!moving.isEnabled)
        #expect(moving.manualAmount == 80, "Se conserva, por si tenía un importe a mano.")
        #expect(existing.isEnabled)
    }

    @Test("L7-10: una categoría con subcategorías de sistema no se mueve ni se borra desde la lista")
    func moveRecords_refusesSystemSubcategories() throws {
        let context = try makeTestContext()
        let others = makeTestCategory(context: context, name: "Otros")
        let adjustment = makeTestSubcategory(context: context, name: "Ajustes de saldo", category: others)
        _ = makeTestSubcategory(context: context, name: "Varios", category: others)
        let food = makeTestCategory(context: context, name: "Comida")
        let restaurant = makeTestSubcategory(context: context, name: "Restaurante", category: food)
        try context.save()

        #expect(adjustment.isAnySystem)
        #expect(CategoryRecordsMoveService.holdsSystemSubcategories(others))
        #expect(!CategoryRecordsMoveService.holdsSystemSubcategories(food))
        #expect(throws: CategoryRecordsMoveService.Failure.systemCategory) {
            try CategoryRecordsMoveService.moveAllAndDelete(
                from: others, to: restaurant, context: context, deletionService: EntityDeletionService.shared)
        }
        let viewModel = CategoriesSettingsListViewModel()
        #expect(!viewModel.canDelete(others))
        #expect(viewModel.canDelete(food))
    }

    @Test("L7-10: borrar una categoría ya no reescribe el filtro del presupuesto a «sin filtro»")
    func deleteCategory_doesNotWidenBudgets() throws {
        let deletion = try Self.source("Yala/Services/EntityDeletionService.swift")
        let start = try #require(deletion.range(of: "func deleteCategory("))
        let end = try #require(deletion.range(of: "// MARK: - Subcategory Deletion"))
        #expect(!deletion[start.upperBound..<end.lowerBound].contains("reencodeBudgetCSVMirrors"))
    }

    // MARK: - L7-15 · Importar

    @Test("L7-15: la vista previa espera a que se cierre la hoja de cuenta o de monedas")
    func importPreview_waitsForTheSheetToClose() throws {
        let sheet = try Self.source("Yala/App/Views/Import/ImportIntroSheet.swift")
        #expect(sheet.contains(".sheet(isPresented: $isShowingAccountPicker, onDismiss: runPreviewAfterDismiss)"))
        #expect(sheet.contains(".sheet(isPresented: $isShowingCurrencyMapping, onDismiss: runPreviewAfterDismiss)"))
        #expect(sheet.contains("previewAfterDismiss = .single(url, account)"))
        #expect(sheet.contains("previewAfterDismiss = .multiCurrency(url, currencyAccountMap)"))
    }

    // MARK: - L6 · Bienvenida

    @Test("L6-11: «Volver» de Restaurar vuelve a la pantalla desde la que se abrió")
    func restoreOrigin() {
        #expect(WelcomeBackStepLogic.restoreOrigin(openedFrom: .existingChooser) == .existingChooser)
        #expect(WelcomeBackStepLogic.restoreOrigin(openedFrom: .chooser) == .chooser)
        #expect(WelcomeBackStepLogic.restoreOrigin(openedFrom: .privateICloudGate) == .chooser)
    }

    @Test("L6-3: solo el primer consentimiento devuelve a «¡Hola de nuevo!» al cancelarlo")
    func consentCancel_isOneShot() throws {
        let view = try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        #expect(view.contains("requested: cancelConsentGoesBack && consentBackArmed, isAtIntro: phase == .intro)"))
        let accept = try #require(view.range(of: "persistsOnAccept: persistsConsentOnAccept, onAccept: {"))
        #expect(view[accept.upperBound...].prefix(120).contains("consentBackArmed = false"))
        let cancel = try #require(view.range(of: "requested: cancelConsentGoesBack && consentBackArmed"))
        #expect(view[cancel.upperBound...].prefix(120).contains("consentBackArmed = false"))
    }

    @Test("L6-13: conectar enseña el avance real, no unas cifras que no suben")
    func adopt_showsRealProgress() throws {
        let view = try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        #expect(!view.contains("AdoptLiveCountsView()"))
        #expect(view.contains("fraction.formatted(.percent.precision(.fractionLength(0)))"))
    }
}
