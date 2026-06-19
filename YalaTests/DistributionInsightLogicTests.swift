//
//  DistributionInsightLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para DistributionInsightLogic.finding(...).
//  Sin SwiftData, sin UI, sin singletons. Cubre los 6 cases (ONSET / NEW_CATEGORY /
//  SHIFTED up/down / CONCENTRATED / TOP_SUB_FALLBACK / BALANCED) + edge cases
//  (umbral exacto, previousLabel nil, multiple new cats).
//

import Foundation
import Testing

@testable import Yala

struct DistributionInsightLogicTests {

    @Test func finding_emptyCategories_returnsOnset() {
        let result = DistributionInsightLogic.finding(
            categories: [], topSub: nil, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .onset)
    }

    @Test func finding_allZeroAmount_returnsOnset() {
        let cats = [
            DistributionCategoryInput(name: "Comida", amount: 0, percentage: 0, previousAmount: 100, variation: -100),
            DistributionCategoryInput(name: "Viajes", amount: 0, percentage: 0, previousAmount: 50, variation: -100)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .onset)
    }

    @Test func finding_newCategoryWithNilPrevious_returnsNewCategory() {
        // Viajes (mayor amount) tiene previousAmount nil → NEW_CATEGORY.
        let cats = [
            DistributionCategoryInput(name: "Viajes", amount: 800, percentage: 60, previousAmount: nil, variation: nil),
            DistributionCategoryInput(name: "Comida", amount: 300, percentage: 40, previousAmount: 280, variation: 7.1)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .newCategory(name: "Viajes", period: "este mes"))
    }

    @Test func finding_newCategorySkippedWhenPreviousLabelNil_fallsToOtherRules() {
        // .allTime no tiene previousLabel → NEW_CATEGORY no aplica → cae a CONCENTRATED.
        let cats = [
            DistributionCategoryInput(name: "Viajes", amount: 800, percentage: 60, previousAmount: nil, variation: nil)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: nil, period: "siempre"
        )
        #expect(result == .concentrated(percent: 60, topCategory: "Viajes"))
    }

    @Test func finding_concentratedAtExactly40Threshold_returnsConcentrated() {
        // top1.percentage == 40 exacto entra a CONCENTRATED (>= no >).
        let cats = [
            DistributionCategoryInput(name: "Comida", amount: 400, percentage: 40, previousAmount: 380, variation: 5.3),
            DistributionCategoryInput(name: "Viajes", amount: 300, percentage: 30, previousAmount: 290, variation: 3.4),
            DistributionCategoryInput(name: "Salud", amount: 300, percentage: 30, previousAmount: 310, variation: -3.2)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .concentrated(percent: 40, topCategory: "Comida"))
    }

    @Test func finding_shiftedUp_top1Variation25_returnsShiftedUp() {
        // top1 variation +25% (>= 20% threshold) Y previousLabel != nil → SHIFTED.
        let cats = [
            DistributionCategoryInput(name: "Comida", amount: 500, percentage: 35, previousAmount: 400, variation: 25),
            DistributionCategoryInput(name: "Viajes", amount: 200, percentage: 30, previousAmount: 195, variation: 2.6)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .shifted(percent: 25, category: "Comida", direction: .up, previousLabel: "Abr 26"))
    }

    @Test func finding_shiftedDown_top1VariationNegative30_returnsShiftedDown() {
        let cats = [
            DistributionCategoryInput(name: "Comida", amount: 350, percentage: 35, previousAmount: 500, variation: -30),
            DistributionCategoryInput(name: "Viajes", amount: 300, percentage: 30, previousAmount: 290, variation: 3.4)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .shifted(percent: 30, category: "Comida", direction: .down, previousLabel: "Abr 26"))
    }

    @Test func finding_topSubFallback_top1Cat35AndSubAt35_returnsTopSubFallback() {
        // top1 cat percentage < 40 + topSub.percentageOfCategory >= 30 → TOP_SUB_FALLBACK.
        let cats = [
            DistributionCategoryInput(name: "Comida", amount: 350, percentage: 35, previousAmount: 340, variation: 2.9),
            DistributionCategoryInput(name: "Viajes", amount: 300, percentage: 30, previousAmount: 290, variation: 3.4),
            DistributionCategoryInput(name: "Salud", amount: 350, percentage: 35, previousAmount: 340, variation: 2.9)
        ]
        let sub = DistributionTopSubInput(name: "Restaurantes", parent: "Comida", percentageOfCategory: 35)
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: sub, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .topSubFallback(percent: 35, sub: "Restaurantes", parent: "Comida"))
    }

    @Test func finding_balanced_below25TopWith3Cats_returnsBalanced() {
        // Sin shifted (variations < 20%), sin concentrated (top < 40), sin top sub (todos < 30 sub).
        let cats = [
            DistributionCategoryInput(name: "Comida", amount: 200, percentage: 22, previousAmount: 210, variation: -4.8),
            DistributionCategoryInput(name: "Viajes", amount: 180, percentage: 20, previousAmount: 175, variation: 2.9),
            DistributionCategoryInput(name: "Salud", amount: 150, percentage: 18, previousAmount: 145, variation: 3.4),
            DistributionCategoryInput(name: "Ocio", amount: 130, percentage: 15, previousAmount: 125, variation: 4.0),
            DistributionCategoryInput(name: "Otros", amount: 110, percentage: 14, previousAmount: 100, variation: 10),
            DistributionCategoryInput(name: "Extra", amount: 100, percentage: 11, previousAmount: 95, variation: 5.3)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .balanced(maxPercent: 22))
    }

    @Test func finding_variationBelow20_skipsShifted() {
        // Variation top1 == 15% (< 20% threshold) Y top1 == 50% → cae a CONCENTRATED, no SHIFTED.
        let cats = [
            DistributionCategoryInput(name: "Comida", amount: 500, percentage: 50, previousAmount: 435, variation: 15),
            DistributionCategoryInput(name: "Viajes", amount: 300, percentage: 30, previousAmount: 295, variation: 1.7)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: "Abr 26", period: "este mes"
        )
        #expect(result == .concentrated(percent: 50, topCategory: "Comida"))
    }

    @Test func finding_nilPreviousLabel_neverShifted() {
        // .allTime sin previousLabel → SHIFTED no dispara aún con variation grande.
        let cats = [
            DistributionCategoryInput(name: "Comida", amount: 500, percentage: 35, previousAmount: 100, variation: 400)
        ]
        let result = DistributionInsightLogic.finding(
            categories: cats, topSub: nil, previousLabel: nil, period: "siempre"
        )
        // Cae a BALANCED (no concentrated porque 35 < 40, sin sub fallback).
        #expect(result == .balanced(maxPercent: 35))
    }
}
