//
//  ChatIntentClassifierServiceTests.swift
//  YalaTests
//
//  Tests pure-logic del classifier (parse JSON + regex fallback).
//  No mockean OpenAI — esos paths se cubren en device QA con inputs reales.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct ChatIntentClassifierServiceTests {

    // MARK: - parseClassificationJSON

    @Test func parse_validJSON_register_highConfidence() throws {
        let json = #"{"intent":"register","confidence":0.95}"#
        let result = try ChatIntentClassifierService.parseClassificationJSON(json)
        #expect(result.intent == .register)
        #expect(result.confidence == 0.95)
        #expect(result.usedFallback == false)
    }

    @Test func parse_validJSON_ask() throws {
        let json = #"{"intent":"ask","confidence":0.9}"#
        let result = try ChatIntentClassifierService.parseClassificationJSON(json)
        #expect(result.intent == .ask)
    }

    @Test func parse_validJSON_ambiguous() throws {
        let json = #"{"intent":"ambiguous","confidence":0.5}"#
        let result = try ChatIntentClassifierService.parseClassificationJSON(json)
        #expect(result.intent == .ambiguous)
    }

    @Test func parse_confidenceClampedTo01() throws {
        let json = #"{"intent":"register","confidence":1.5}"#
        let r1 = try ChatIntentClassifierService.parseClassificationJSON(json)
        #expect(r1.confidence == 1.0)

        let json2 = #"{"intent":"register","confidence":-0.3}"#
        let r2 = try ChatIntentClassifierService.parseClassificationJSON(json2)
        #expect(r2.confidence == 0.0)
    }

    @Test func parse_missingConfidence_defaultsToZero() throws {
        let json = #"{"intent":"ask"}"#
        let result = try ChatIntentClassifierService.parseClassificationJSON(json)
        #expect(result.confidence == 0)
    }

    @Test func parse_invalidIntent_throws() {
        let json = #"{"intent":"unknown","confidence":0.9}"#
        #expect(throws: ChatAssistantError.self) {
            _ = try ChatIntentClassifierService.parseClassificationJSON(json)
        }
    }

    @Test func parse_malformedJSON_throws() {
        let json = "not json"
        #expect(throws: (any Error).self) {
            _ = try ChatIntentClassifierService.parseClassificationJSON(json)
        }
    }

    // MARK: - regexFallback — register patterns

    @Test func fallback_register_explicit_es() {
        let r = ChatIntentClassifierService.regexFallback("registra 30 de gasolina")
        #expect(r.intent == .register)
        #expect(r.usedFallback == true)
    }

    @Test func fallback_register_implicit_es() {
        let r = ChatIntentClassifierService.regexFallback("hoy gasté 50 en mercado")
        #expect(r.intent == .register)
    }

    @Test func fallback_register_compre_es() {
        let r = ChatIntentClassifierService.regexFallback("compré pan por 12")
        #expect(r.intent == .register)
    }

    @Test func fallback_register_anota_es() {
        let r = ChatIntentClassifierService.regexFallback("anota 100 de salario")
        #expect(r.intent == .register)
    }

    @Test func fallback_register_spent_en() {
        let r = ChatIntentClassifierService.regexFallback("I spent 50 on groceries today")
        #expect(r.intent == .register)
    }

    @Test func fallback_register_log_en() {
        let r = ChatIntentClassifierService.regexFallback("log 25 dollars for coffee")
        #expect(r.intent == .register)
    }

    // MARK: - regexFallback — ask patterns

    @Test func fallback_ask_cuanto_es() {
        let r = ChatIntentClassifierService.regexFallback("cuánto gasté este mes?")
        #expect(r.intent == .ask)
    }

    @Test func fallback_ask_como_es() {
        let r = ChatIntentClassifierService.regexFallback("cómo voy con presupuestos")
        #expect(r.intent == .ask)
    }

    @Test func fallback_ask_questionMark_endingsAreAsk() {
        let r = ChatIntentClassifierService.regexFallback("realmente algo me gasté?")
        #expect(r.intent == .ask)
    }

    @Test func fallback_ask_howmuch_en() {
        let r = ChatIntentClassifierService.regexFallback("how much did I spend on food?")
        #expect(r.intent == .ask)
    }

    @Test func fallback_ask_diacriticInsensitive() {
        let r = ChatIntentClassifierService.regexFallback("CUANTO gaste este mes")
        #expect(r.intent == .ask)
    }

    // MARK: - regexFallback — defaults

    @Test func fallback_emptyString_defaultsAsk_zeroConfidence() {
        let r = ChatIntentClassifierService.regexFallback("")
        #expect(r.intent == .ask)
        #expect(r.confidence == 0)
    }

    @Test func fallback_unrecognized_defaultsAsk() {
        let r = ChatIntentClassifierService.regexFallback("alemán random text Frühstück")
        #expect(r.intent == .ask, "Sin pattern → conservative default ask (limitación documentada v1)")
    }

    @Test func fallback_alwaysSetsUsedFallbackTrue() {
        let r = ChatIntentClassifierService.regexFallback("anything")
        #expect(r.usedFallback == true)
    }
}
