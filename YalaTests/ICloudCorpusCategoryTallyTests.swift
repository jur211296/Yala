//
//  ICloudCorpusCategoryTallyTests.swift
//  YalaTests
//
//  Card k15r (ticket `icloud-restore-preview-counts-categories-twice`): «Ya tienes datos en tu iCloud» contó 124
//  categorías y la pantalla siguiente 62. La zona traía cada subcategoría de fábrica dos veces y la restauración las
//  funde; la sonda cuenta ahora con la misma clave.
//

import Foundation
import Testing

@testable import Yala

@Suite("Sonda de iCloud · las categorías de fábrica repetidas cuentan una vez")
struct ICloudCorpusCategoryTallyTests {

    private static let seedSubs: [(sortOrder: Int, icon: String, name: String)] = [
        (0, "cart.fill", "Supermercado"), (1, "fork.knife", "Restaurantes"), (2, "cup.and.saucer.fill", "Café"),
    ]

    /// Dos siembras completas en la zona (dos categorías «Comida» con sus tres subcategorías): cuenta 3, no 6.
    @Test func twoCopiesOfTheSeed_countOnce() {
        var tally = ICloudCorpusCategoryTally()
        for parent in ["cat-A", "cat-B"] {
            tally.addCategory(recordName: parent, iconName: "fork.knife", colorHex: "#FF0000", isIncome: false)
            for sub in Self.seedSubs {
                tally.addSubcategory(isDefaultSeed: true, isSystemSubcategory: false, categoryRecordName: parent,
                                     sortOrder: sub.sortOrder, iconName: sub.icon, name: sub.name)
            }
        }
        #expect(tally.count == 3)
    }

    /// La categoría llega en una página posterior a sus subcategorías: el orden no cambia la cifra.
    @Test func categoryArrivingLater_stillDeduplicates() {
        var tally = ICloudCorpusCategoryTally()
        for parent in ["cat-A", "cat-B"] {
            tally.addSubcategory(isDefaultSeed: true, isSystemSubcategory: false, categoryRecordName: parent,
                                 sortOrder: 0, iconName: "cart.fill", name: "Supermercado")
        }
        tally.addCategory(recordName: "cat-A", iconName: "fork.knife", colorHex: "#FF0000", isIncome: false)
        tally.addCategory(recordName: "cat-B", iconName: "fork.knife", colorHex: "#FF0000", isIncome: false)
        #expect(tally.count == 1)
    }

    /// Las del usuario no se funden aunque se llamen igual: el deduplicador tampoco las toca.
    @Test func userSubcategories_countOneByOne() {
        var tally = ICloudCorpusCategoryTally()
        tally.addCategory(recordName: "cat-A", iconName: "fork.knife", colorHex: "#FF0000", isIncome: false)
        for _ in 0..<2 {
            tally.addSubcategory(isDefaultSeed: false, isSystemSubcategory: false, categoryRecordName: "cat-A",
                                 sortOrder: 0, iconName: "star", name: "Gym")
        }
        #expect(tally.count == 2)
    }

    /// Sin la categoría (no llegó, o el campo falta) no se funde: de más, nunca de menos.
    @Test func missingCategory_countsAlone() {
        var tally = ICloudCorpusCategoryTally()
        tally.addSubcategory(isDefaultSeed: true, isSystemSubcategory: false, categoryRecordName: "cat-A",
                             sortOrder: 0, iconName: "cart.fill", name: "Supermercado")
        tally.addSubcategory(isDefaultSeed: true, isSystemSubcategory: false, categoryRecordName: "cat-B",
                             sortOrder: 0, iconName: "cart.fill", name: "Supermercado")
        tally.addSubcategory(isDefaultSeed: true, isSystemSubcategory: false, categoryRecordName: nil,
                             sortOrder: 0, iconName: "cart.fill", name: "Supermercado")
        #expect(tally.count == 3)
    }

    /// Mismo icono y nombre en DOS categorías distintas (p. ej. «Otros»): no se funden.
    @Test func sameSubcategoryInDifferentCategories_countsTwice() {
        var tally = ICloudCorpusCategoryTally()
        tally.addCategory(recordName: "food", iconName: "fork.knife", colorHex: "#FF0000", isIncome: false)
        tally.addCategory(recordName: "home", iconName: "house.fill", colorHex: "#00FF00", isIncome: false)
        for parent in ["food", "home"] {
            tally.addSubcategory(isDefaultSeed: true, isSystemSubcategory: false, categoryRecordName: parent,
                                 sortOrder: 9, iconName: "ellipsis.circle.fill", name: "Otros")
        }
        #expect(tally.count == 2)
    }

    /// La clave es la del deduplicador: si divergen, la sonda y la restauración vuelven a dar cifras distintas.
    @Test func key_matchesTheDeduplicator() {
        let category = Category(name: "Comida", colorHex: "#FF0000", isIncome: false, iconName: "fork.knife")
        let sub = Subcategory(name: "Supermercado", isDefaultSeed: true, sortOrder: 0, iconName: "cart.fill",
                              category: category)
        let fromModel = SubcategoryDedupLogic.identityKey(for: sub)
        let fromProbe = SubcategoryDedupLogic.identityKey(
            categoryKey: SubcategoryDedupLogic.categoryKey(iconName: "fork.knife", colorHex: "#FF0000", isIncome: false),
            sortOrder: 0, iconName: "cart.fill", name: "Supermercado")
        #expect(fromModel == fromProbe)
    }
}
