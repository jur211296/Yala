//
//  SyncContentAnchorTests.swift
//  YalaTests / CloudSync
//
//  Determinismo del ancla de contenido (Modo Nube, I2). Los vectores esperados son SHA-256
//  LITERALES hardcodeados: pinnean que la serialización canónica es estable CROSS-PROCESO (mismo
//  input → mismo hash siempre). Si un refactor cambiara la serialización, estos rojos lo delatan.
//
//  Los hashes se derivan de `SHA256(componentes.joined("|"))` sobre UTF-8, con las reglas de
//  `SyncContentAnchor` (fechas → ms Unix enteros, montos → String(describing:), nil → "∅").
//

import Foundation
import Testing

@testable import Yala

@Suite("SyncContentAnchor · determinismo")
struct SyncContentAnchorTests {

    /// Date fija reutilizada: 1_700_000_000 s → 1_700_000_000_000 ms Unix.
    private static let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private static let fixedMs = "1700000000000"

    // MARK: - Vectores literales (SHA-256 hex esperado)

    @Test func category_normalizesAndHashes_toLiteralVector() {
        // "  Food  " → trim+lowercase → "food" → SHA256("food").
        let anchor = SyncContentAnchor.category(name: "  Food  ")
        #expect(anchor == "c1f026582fe6e8cb620d0c85a72fe421ddded756662a8ec00ed4c297ad10676b")
    }

    @Test func category_normalization_isCaseAndWhitespaceInsensitive() {
        let a = SyncContentAnchor.category(name: "FOOD")
        let b = SyncContentAnchor.category(name: "food")
        let c = SyncContentAnchor.category(name: "\n food \t")
        #expect(a == b)
        #expect(b == c)
    }

    @Test func merchantMemory_hashes_toLiteralVector() {
        let anchor = SyncContentAnchor.merchantMemory(merchantCanonical: "starbucks")
        #expect(anchor == "b21492b15d85500ef49e5ad990ec8a530c27772b9a3d129770fd6c733257c19b")
    }

    @Test func exchangeRate_hashes_toLiteralVector() {
        let anchor = SyncContentAnchor.exchangeRate(dateKey: "2025-01-15", base: "USD")
        #expect(anchor == "3d41c5c18b4a29ee0d1a870ff5e22c38a9a3368be0ce7db4854d43e549beaf8d")
    }

    @Test func exchangeRate_duplicatesCollide_acceptedResidual() {
        // Residual documentado (§b.3/A3): duplicados exactos → misma ancla → mismo syncID.
        let a = SyncContentAnchor.exchangeRate(dateKey: "2025-01-15", base: "USD")
        let b = SyncContentAnchor.exchangeRate(dateKey: "2025-01-15", base: "USD")
        #expect(a == b)
    }

    @Test func transactionItem_hashes_toLiteralVector_nilAccount() {
        let anchor = SyncContentAnchor.transactionItem(
            createdAt: Self.fixedDate,
            date: Self.fixedDate,
            amount: 12.5,
            currencyCode: "USD",
            accountShortcutID: nil
        )
        // "1700000000000|1700000000000|12.5|USD|∅"
        #expect(anchor == "6da97696a42ee072050f322b5ae30a8daebfed9034940c0ee5209999982da97a")
    }

    @Test func favoritePayment_hashes_toLiteralVectors() {
        let withAmount = SyncContentAnchor.favoritePayment(
            name: "Coffee", amount: 12.5, createdAt: Self.fixedDate, displayOrder: 3
        )
        #expect(withAmount == "bed727fa59e0e35779ccf3a9db539c9d7573647851d135a03cc62b6242fb3849")

        // amount nil → token "∅"; displayOrder 0.
        let nilAmount = SyncContentAnchor.favoritePayment(
            name: "Coffee", amount: nil, createdAt: Self.fixedDate, displayOrder: 0
        )
        #expect(nilAmount == "0c2d58b6072b656eaafeb9c34c4af43b3daf4076588a2bccc0778716f75a87ab")
    }

    @Test func inboxDraft_hashes_toLiteralVectors() {
        let nilRaw = SyncContentAnchor.inboxDraft(
            createdAt: Self.fixedDate, sourceTypeRaw: "voice", rawText: nil
        )
        #expect(nilRaw == "5e18646910f49787a3d8f10f79e0a274686ebe0edc81695511ab84dbd396e422")

        let withRaw = SyncContentAnchor.inboxDraft(
            createdAt: Self.fixedDate, sourceTypeRaw: "receiptPhoto", rawText: "hello"
        )
        #expect(withRaw == "d0fa162b90be67cbdc0bb240717d0ac8ea09ce5c2cb13008b9e3381fa987e260")
    }

    // MARK: - Tokens y serialización

    @Test func nilToken_isEmptySetGlyph() {
        #expect(SyncContentAnchor.nilToken == "\u{2205}")
        #expect(SyncContentAnchor.token(nil) == "\u{2205}")
        #expect(SyncContentAnchor.token("x") == "x")
        #expect(SyncContentAnchor.canonicalAmount(nil) == "\u{2205}")
    }

    @Test func canonicalDate_isUnixMillisInteger() {
        #expect(SyncContentAnchor.canonicalDate(Self.fixedDate) == Self.fixedMs)
    }

    @Test func canonicalAmount_usesDescribing() {
        #expect(SyncContentAnchor.canonicalAmount(12.0) == "12.0")
        #expect(SyncContentAnchor.canonicalAmount(12.5) == "12.5")
    }

    @Test func hash_isLowercaseHex64() {
        let h = SyncContentAnchor.hash(["anything"])
        #expect(h.count == 64)
        #expect(h.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    @Test func differentContent_yieldsDifferentAnchors() {
        let a = SyncContentAnchor.category(name: "food")
        let b = SyncContentAnchor.category(name: "transport")
        #expect(a != b)
    }
}
