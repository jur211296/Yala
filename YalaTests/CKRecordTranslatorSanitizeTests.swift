//
//  CKRecordTranslatorSanitizeTests.swift
//  YalaTests
//
//  Pure-logic tests (regla R8 — sin context) para el saneamiento de montos
//  entrantes de CKRecords no confiables (zona CKShare `.readWrite`).
//  Cierra el patrón raíz del security review 2.0: la ingestión remota no validaba
//  `amount` (NaN/Inf/negativos/magnitudes absurdas) mientras el path local sí.
//

import Foundation
import Testing

@testable import Yala

struct CKRecordTranslatorSanitizeTests {

    // MARK: - Valores válidos pasan intactos

    @Test func normalAmount_passesThrough() {
        #expect(CKRecordTranslator.sanitizeAmount(50.0) == 50.0)
        #expect(CKRecordTranslator.sanitizeAmount(0.01) == 0.01)
        #expect(CKRecordTranslator.sanitizeAmount(999_999.99) == 999_999.99)
    }

    @Test func zero_passesThrough() {
        #expect(CKRecordTranslator.sanitizeAmount(0) == 0)
    }

    // MARK: - No-finitos colapsan al fallback (A2: evita el crash Decimal(NaN))

    @Test func nan_collapsesToFallback() {
        #expect(CKRecordTranslator.sanitizeAmount(Double.nan) == 0)
        #expect(CKRecordTranslator.sanitizeAmount(Double.nan, fallback: 42) == 42)
    }

    @Test func infinity_collapsesToFallback() {
        #expect(CKRecordTranslator.sanitizeAmount(Double.infinity) == 0)
        #expect(CKRecordTranslator.sanitizeAmount(-Double.infinity) == 0)
        #expect(CKRecordTranslator.sanitizeAmount(Double.infinity, fallback: 7) == 7)
    }

    // MARK: - nil (campo ausente en el record) usa el fallback

    @Test func nil_usesFallback() {
        #expect(CKRecordTranslator.sanitizeAmount(nil) == 0)
        #expect(CKRecordTranslator.sanitizeAmount(nil, fallback: 123.45) == 123.45)
    }

    // MARK: - Negativos finitos → 0 (A1: no corrompen balances)

    @Test func negative_clampsToZero() {
        #expect(CKRecordTranslator.sanitizeAmount(-5) == 0)
        #expect(CKRecordTranslator.sanitizeAmount(-9_000_000_000) == 0)
        // Un negativo explícito se neutraliza a 0 incluso con fallback presente.
        #expect(CKRecordTranslator.sanitizeAmount(-5, fallback: 100) == 0)
    }

    // MARK: - Magnitudes absurdas → cap (A1: no desbordan cálculos)

    @Test func aboveCap_clampsToMax() {
        let cap = CKRecordTranslator.maxRemoteAmount
        #expect(CKRecordTranslator.sanitizeAmount(cap * 1000) == cap)
        #expect(CKRecordTranslator.sanitizeAmount(1e20) == cap)
    }

    @Test func atCap_passesThrough() {
        let cap = CKRecordTranslator.maxRemoteAmount
        #expect(CKRecordTranslator.sanitizeAmount(cap) == cap)
    }

    @Test func justBelowCap_passesThrough() {
        let cap = CKRecordTranslator.maxRemoteAmount
        #expect(CKRecordTranslator.sanitizeAmount(cap - 1) == cap - 1)
    }
}
