//
//  VisionDraftFactoryTests.swift
//  YalaTests
//
//  Tests for VisionDraftFactory pure logic methods:
//  mapImageTypeToSource, parseDate, buildNote — y la coherencia entre el signo del monto (que en
//  visión ES el tipo: el prompt pide gastos NEGATIVOS) y la naturaleza de la subcategoría que le
//  pone la memoria de comercios.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

/// `.serialized` porque los casos de naturaleza usan `makeTestContext()`, que REUSA el container por
/// `#fileID`: dos tests del mismo fichero en paralelo se pisan el store. Lo exige
/// `qa/check-test-isolation.sh` y lo comprueba el CI.
@Suite(.serialized)
struct VisionDraftFactoryTests {

    // MARK: - mapImageTypeToSource

    @Test @MainActor func mapImageTypeToSource_single_returnsScreenshotSingle() {
        let result = VisionDraftFactory.mapImageTypeToSource("single")
        #expect(result == .screenshotSingle)
    }

    @Test @MainActor func mapImageTypeToSource_list_returnsScreenshotList() {
        let result = VisionDraftFactory.mapImageTypeToSource("list")
        #expect(result == .screenshotList)
    }

    @Test @MainActor func mapImageTypeToSource_receipt_returnsReceiptPhoto() {
        let result = VisionDraftFactory.mapImageTypeToSource("receipt")
        #expect(result == .receiptPhoto)
    }

    @Test @MainActor func mapImageTypeToSource_caseInsensitive() {
        #expect(VisionDraftFactory.mapImageTypeToSource("SINGLE") == .screenshotSingle)
        #expect(VisionDraftFactory.mapImageTypeToSource("List") == .screenshotList)
        #expect(VisionDraftFactory.mapImageTypeToSource("RECEIPT") == .receiptPhoto)
    }

    @Test @MainActor func mapImageTypeToSource_unknown_defaultsToSingle() {
        #expect(VisionDraftFactory.mapImageTypeToSource("unknown") == .screenshotSingle)
        #expect(VisionDraftFactory.mapImageTypeToSource("") == .screenshotSingle)
        #expect(VisionDraftFactory.mapImageTypeToSource("photo") == .screenshotSingle)
    }

    // MARK: - parseDate

    @Test @MainActor func parseDate_validDate_returnsDate() {
        let result = VisionDraftFactory.parseDate("2025-03-15")
        #expect(result != nil)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: result!)
        #expect(components.year == 2025)
        #expect(components.month == 3)
        #expect(components.day == 15)
    }

    @Test @MainActor func parseDate_validDate_setsTimeToNoon() {
        let result = VisionDraftFactory.parseDate("2025-06-01")
        #expect(result != nil)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result!)
        #expect(hour == 12)
    }

    @Test @MainActor func parseDate_nil_returnsNil() {
        #expect(VisionDraftFactory.parseDate(nil) == nil)
    }

    @Test @MainActor func parseDate_invalidFormat_returnsNil() {
        #expect(VisionDraftFactory.parseDate("15/03/2025") == nil)
        #expect(VisionDraftFactory.parseDate("March 15, 2025") == nil)
        #expect(VisionDraftFactory.parseDate("not a date") == nil)
        #expect(VisionDraftFactory.parseDate("") == nil)
    }

    @Test @MainActor func parseDate_leapYear_works() {
        let result = VisionDraftFactory.parseDate("2024-02-29")
        #expect(result != nil)
        let components = Calendar.current.dateComponents([.month, .day], from: result!)
        #expect(components.month == 2)
        #expect(components.day == 29)
    }

    // MARK: - buildNote

    @Test @MainActor func buildNote_bothPresent_joinsWithDash() {
        let result = VisionDraftFactory.buildNote(merchant: "Walmart", note: "Groceries")
        #expect(result == "Walmart - Groceries")
    }

    /// La nota del draft pasa por `VisionNoteCleaner`: el reporte del 2026-10-10 salía con la plantilla del banco.
    @Test @MainActor func buildNote_dropsBankTemplate() {
        let result = VisionDraftFactory.buildNote(merchant: "GROK XAI", note: "Consumo con tarjeta de crédito BCP")
        #expect(result == "Grok (xAI)")
    }

    @Test @MainActor func buildNote_merchantOnly_returnsMerchant() {
        let result = VisionDraftFactory.buildNote(merchant: "Starbucks", note: nil)
        #expect(result == "Starbucks")
    }

    @Test @MainActor func buildNote_noteOnly_returnsNote() {
        let result = VisionDraftFactory.buildNote(merchant: nil, note: "Coffee")
        #expect(result == "Coffee")
    }

    @Test @MainActor func buildNote_bothNil_returnsEmpty() {
        let result = VisionDraftFactory.buildNote(merchant: nil, note: nil)
        #expect(result == "")
    }

    @Test @MainActor func buildNote_emptyMerchant_returnsNoteOnly() {
        let result = VisionDraftFactory.buildNote(merchant: "", note: "Some note")
        #expect(result == "Some note")
    }

    @Test @MainActor func buildNote_emptyNote_returnsMerchantOnly() {
        let result = VisionDraftFactory.buildNote(merchant: "Store", note: "")
        #expect(result == "Store")
    }

    @Test @MainActor func buildNote_bothEmpty_returnsEmpty() {
        let result = VisionDraftFactory.buildNote(merchant: "", note: "")
        #expect(result == "")
    }

    // MARK: - Naturaleza de la subcategoría recordada

    private func visionResponse(amount: Double?, merchant: String) -> VisionResponse {
        VisionResponse(
            imageType: "receipt",
            transactions: [
                VisionTransaction(amount: amount, date: nil, merchant: merchant, note: nil, currency: "PEN")
            ],
            confidence: VisionConfidence(overall: 0.9, imageType: 0.9)
        )
    }

    @MainActor
    private func seedMerchantMemory(
        context: ModelContext,
        merchant: String,
        subcategory: Subcategory
    ) {
        context.insert(
            MerchantMemory(
                merchantCanonical: MerchantCanonicalizer.canonicalize(merchant),
                subcategory: subcategory,
                countApproved: 5,
                countCorrected: 0,
                lastApprovedAt: Date.now,
                aliases: [merchant]
            )
        )
    }

    /// Un ticket de gasto (monto negativo) sobre un comercio que la memoria tiene aprendido en
    /// INGRESOS no se queda con esa subcategoría. Si se quedara, el draft se aprueba desde la Bandeja
    /// con un swipe —sin pasar por la hoja de edición, que es lo único que reconcilia el par— y la
    /// fila entra con el signo contrario a su categoría.
    @Test @MainActor func createDraft_rememberedIncomeSubcategory_expenseAmount_leavesItEmpty() throws {
        let context = try makeTestContext()
        let incomeSub = makeTestSubcategory(
            context: context,
            name: "Reintegros",
            category: makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        )
        seedMerchantMemory(context: context, merchant: "Reintegro Nómina", subcategory: incomeSub)

        let drafts = VisionDraftFactory.makeDrafts(
            from: visionResponse(amount: -80, merchant: "Reintegro Nómina"),
            rawText: nil,
            context: context
        )

        #expect(drafts.count == 1)
        #expect(drafts.first?.subcategory == nil)
        #expect(drafts.first?.needsUserInput.contains("subcategory") == true)
    }

    /// Control positivo: el mismo comercio con un monto POSITIVO —un abono— sí se queda con la
    /// subcategoría de ingreso recordada.
    @Test @MainActor func createDraft_rememberedIncomeSubcategory_incomeAmount_keepsIt() throws {
        let context = try makeTestContext()
        let incomeSub = makeTestSubcategory(
            context: context,
            name: "Reintegros",
            category: makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        )
        seedMerchantMemory(context: context, merchant: "Reintegro Nómina", subcategory: incomeSub)

        let drafts = VisionDraftFactory.makeDrafts(
            from: visionResponse(amount: 80, merchant: "Reintegro Nómina"),
            rawText: nil,
            context: context
        )

        #expect(drafts.first?.subcategory === incomeSub)
    }

    /// El caso común —ticket de gasto, comercio aprendido en gastos— sigue rellenando.
    @Test @MainActor func createDraft_rememberedExpenseSubcategory_expenseAmount_keepsIt() throws {
        let context = try makeTestContext()
        let expenseSub = makeTestSubcategory(
            context: context,
            name: "Supermercado",
            category: makeTestCategory(context: context, name: "Comida", isIncome: false)
        )
        seedMerchantMemory(context: context, merchant: "Wong", subcategory: expenseSub)

        let drafts = VisionDraftFactory.makeDrafts(
            from: visionResponse(amount: -45.5, merchant: "Wong"),
            rawText: nil,
            context: context
        )

        #expect(drafts.first?.subcategory === expenseSub)
    }

    /// Sin monto no hay signo del que leer el tipo: se asume GASTO, igual que hace la hoja de edición
    /// del Inbox al prefijar un draft sin monto. Aquí eso significa que una subcategoría de ingreso
    /// recordada no se planta a ciegas.
    @Test @MainActor func createDraft_noAmount_treatsItAsExpense() throws {
        let context = try makeTestContext()
        let incomeSub = makeTestSubcategory(
            context: context,
            name: "Reintegros",
            category: makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        )
        seedMerchantMemory(context: context, merchant: "Reintegro Nómina", subcategory: incomeSub)

        let drafts = VisionDraftFactory.makeDrafts(
            from: visionResponse(amount: nil, merchant: "Reintegro Nómina"),
            rawText: nil,
            context: context
        )

        #expect(drafts.first?.subcategory == nil)
    }
}
