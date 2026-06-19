//
//  OnboardingPrefillResolverTests.swift
//  YalaTests
//
//  Cubre el fix #9c: rama B con prefilled.userName desde iCloud no debe ser
//  pisada por un valor residual del KV-Store en UserDefaults. Funciones puras,
//  sin tocar singletons ni UserDefaults.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct OnboardingPrefillResolverTests {

    // MARK: - Helpers

    private func summary(userName: String? = nil, currency: String? = "USD") -> ICloudAccountSummary {
        ICloudAccountSummary(
            userName: userName,
            accountsCount: 0,
            transactionsCount: 0,
            budgetsCount: 0,
            groupsCount: 0,
            primaryCurrencyCode: currency,
            categoriesCount: 0
        )
    }

    // MARK: - resolveUserName

    @Test func resolveUserName_noPrefilled_noDefaults_returnsNil() {
        #expect(OnboardingPrefillResolver.resolveUserName(prefilled: nil, defaultsName: nil) == nil)
    }

    @Test func resolveUserName_noPrefilled_validDefaults_returnsDefaults() {
        #expect(OnboardingPrefillResolver.resolveUserName(prefilled: nil, defaultsName: "Test") == "Test")
    }

    @Test func resolveUserName_prefilledWithName_ignoresDefaults() {
        // Caso clave del bug #9c: prefilled gana, defaults residual se descarta.
        let s = summary(userName: "Juan")
        #expect(OnboardingPrefillResolver.resolveUserName(prefilled: s, defaultsName: "Test") == "Juan")
    }

    @Test func resolveUserName_prefilledNilName_ignoresDefaults() {
        // Rama B activa pero summary sin nombre: NO fallback a defaults
        // (preserva el modelo "rama B confía en iCloud para todo").
        let s = summary(userName: nil)
        #expect(OnboardingPrefillResolver.resolveUserName(prefilled: s, defaultsName: "Test") == nil)
    }

    @Test func resolveUserName_noPrefilled_emptyDefaults_returnsNil() {
        #expect(OnboardingPrefillResolver.resolveUserName(prefilled: nil, defaultsName: "") == nil)
    }

    @Test func resolveUserName_noPrefilled_sentinelDefaults_returnsNil() {
        // "Usuario" es el sentinel del default factory — no se debe usar.
        #expect(OnboardingPrefillResolver.resolveUserName(prefilled: nil, defaultsName: "Usuario") == nil)
    }

    // MARK: - resolveCurrencyCode

    @Test func resolveCurrencyCode_noPrefilled_noDefaults_returnsNil() {
        #expect(OnboardingPrefillResolver.resolveCurrencyCode(prefilled: nil, defaultsCode: nil) == nil)
    }

    @Test func resolveCurrencyCode_noPrefilled_validDefaults_returnsDefaults() {
        #expect(OnboardingPrefillResolver.resolveCurrencyCode(prefilled: nil, defaultsCode: "EUR") == "EUR")
    }

    @Test func resolveCurrencyCode_prefilled_ignoresDefaults() {
        let s = summary(currency: "USD")
        #expect(OnboardingPrefillResolver.resolveCurrencyCode(prefilled: s, defaultsCode: "EUR") == "USD")
    }

    @Test func resolveCurrencyCode_prefilledNilCurrency_ignoresDefaults() {
        let s = summary(currency: nil)
        #expect(OnboardingPrefillResolver.resolveCurrencyCode(prefilled: s, defaultsCode: "EUR") == nil)
    }
}
