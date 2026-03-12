//
//  VisionDraftFactoryTests.swift
//  YalaTests
//
//  Tests for VisionDraftFactory pure logic methods:
//  mapImageTypeToSource, parseDate, buildNote.
//

import Foundation
import Testing

@testable import Yala

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
}
