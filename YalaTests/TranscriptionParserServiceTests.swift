//
//  TranscriptionParserServiceTests.swift
//  YalaTests
//
//  Tests for ParserError descriptions and parseMultipleResponse JSON parsing.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct TranscriptionParserServiceTests {

    // MARK: - ParserError descriptions

    @Test func errorNoAPIKey_hasDescription() {
        let error = ParserError.noAPIKey
        #expect(error.errorDescription != nil)
    }

    @Test func errorEmptyText_hasDescription() {
        let error = ParserError.emptyText
        #expect(error.errorDescription != nil)
    }

    @Test func errorParsingFailed_includesMessage() {
        let error = ParserError.parsingFailed("bad input")
        #expect(error.errorDescription?.contains("bad input") == true)
    }

    @Test func errorInvalidResponse_hasDescription() {
        let error = ParserError.invalidResponse
        #expect(error.errorDescription != nil)
    }

    // MARK: - parseMultipleResponse JSON parsing

    @Test func parseResponse_validJSON_returnsTransactions() throws {
        let json = """
        {
          "transactions": [
            {
              "amount": 50.0,
              "date": "2026-03-10",
              "note": "Starbucks",
              "isExpense": true,
              "subcategoryHint": "Cafetería",
              "tagHints": [],
              "currencyHint": null,
              "confidence": { "amount": 0.9, "date": 0.8, "merchant": 0.7, "subcategory": 0.6, "tags": 0.5 }
            }
          ]
        }
        """
        let service = TranscriptionParserService()
        let result = try service.parseMultipleResponse(json)
        #expect(result.count == 1)
        #expect(result[0].amount == Decimal(50.0))
        #expect(result[0].note == "Starbucks")
        #expect(result[0].isExpense == true)
    }

    @Test func parseResponse_markdownWrapped_stripsBackticks() throws {
        let json = """
        ```json
        {
          "transactions": [
            {
              "amount": 25.0,
              "date": "2026-03-10",
              "note": "Uber",
              "isExpense": true,
              "subcategoryHint": null,
              "tagHints": [],
              "currencyHint": null,
              "confidence": { "amount": 0.9, "date": 0.8, "merchant": 0.7, "subcategory": 0.5, "tags": 0.5 }
            }
          ]
        }
        ```
        """
        let service = TranscriptionParserService()
        let result = try service.parseMultipleResponse(json)
        #expect(result.count == 1)
        #expect(result[0].note == "Uber")
    }

    @Test func parseResponse_multipleTransactions_returnsAll() throws {
        let json = """
        {
          "transactions": [
            {
              "amount": 10.0, "date": "2026-03-10", "note": "Coffee",
              "isExpense": true, "subcategoryHint": null, "tagHints": [], "currencyHint": null,
              "confidence": { "amount": 0.9, "date": 0.8, "merchant": 0.7, "subcategory": 0.5, "tags": 0.5 }
            },
            {
              "amount": 20.0, "date": "2026-03-10", "note": "Lunch",
              "isExpense": true, "subcategoryHint": null, "tagHints": [], "currencyHint": null,
              "confidence": { "amount": 0.9, "date": 0.8, "merchant": 0.7, "subcategory": 0.5, "tags": 0.5 }
            },
            {
              "amount": 30.0, "date": "2026-03-10", "note": "Taxi",
              "isExpense": true, "subcategoryHint": null, "tagHints": [], "currencyHint": null,
              "confidence": { "amount": 0.9, "date": 0.8, "merchant": 0.7, "subcategory": 0.5, "tags": 0.5 }
            }
          ]
        }
        """
        let service = TranscriptionParserService()
        let result = try service.parseMultipleResponse(json)
        #expect(result.count == 3)
    }

    @Test func parseResponse_invalidJSON_throwsParsingFailed() {
        let service = TranscriptionParserService()
        #expect(throws: ParserError.self) {
            try service.parseMultipleResponse("not json at all")
        }
    }

    @Test func parseResponse_emptyTransactions_returnsEmpty() throws {
        let json = """
        { "transactions": [] }
        """
        let service = TranscriptionParserService()
        let result = try service.parseMultipleResponse(json)
        #expect(result.isEmpty)
    }

    // MARK: - Date conversion via parseMultipleResponse

    @Test func parseResponse_validDate_parsesToNoon() throws {
        let json = """
        {
          "transactions": [
            {
              "amount": 10.0, "date": "2026-03-10", "note": "Test",
              "isExpense": true, "subcategoryHint": null, "tagHints": [], "currencyHint": null,
              "confidence": { "amount": 0.9, "date": 0.9, "merchant": 0.5, "subcategory": 0.5, "tags": 0.5 }
            }
          ]
        }
        """
        let service = TranscriptionParserService()
        let result = try service.parseMultipleResponse(json)
        let date = try #require(result[0].date)
        let hour = Calendar.current.component(.hour, from: date)
        #expect(hour == 12)
    }

    @Test func parseResponse_nullDate_returnsNilDate() throws {
        let json = """
        {
          "transactions": [
            {
              "amount": 10.0, "date": null, "note": "Test",
              "isExpense": true, "subcategoryHint": null, "tagHints": [], "currencyHint": null,
              "confidence": { "amount": 0.9, "date": 0.5, "merchant": 0.5, "subcategory": 0.5, "tags": 0.5 }
            }
          ]
        }
        """
        let service = TranscriptionParserService()
        let result = try service.parseMultipleResponse(json)
        #expect(result[0].date == nil)
    }

    @Test func parseResponse_nullAmount_handledAsNil() throws {
        let json = """
        {
          "transactions": [
            {
              "amount": null, "date": "2026-03-10", "note": "Test",
              "isExpense": true, "subcategoryHint": null, "tagHints": [], "currencyHint": null,
              "confidence": { "amount": 0.1, "date": 0.9, "merchant": 0.5, "subcategory": 0.5, "tags": 0.5 }
            }
          ]
        }
        """
        let service = TranscriptionParserService()
        let result = try service.parseMultipleResponse(json)
        #expect(result[0].amount == nil)
    }
}
