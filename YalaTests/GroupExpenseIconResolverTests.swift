//
//  GroupExpenseIconResolverTests.swift
//  YalaTests
//
//  Tests pure-logic de `GroupExpenseIconResolver.resolve` (cadena bridge-first + fallback por
//  nombre self-contained). Sin SwiftData ni ModelContext: se pasan tuplas/diccionarios directos.
//

import Foundation
import Testing

@testable import Yala

struct GroupExpenseIconResolverTests {

    private let foodLookup: [String: (iconName: String, colorHex: String)] = [
        "comida": ("fork.knife", "#FF0000"),
        "transporte": ("car.fill", "#00FF00"),
    ]

    // MARK: - 1. Bridge gana

    @Test func bridgePresent_wins_overName() {
        // El bridge (subcat elegida por el usuario) gana aunque el nombre del creador también resuelva.
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: ("cart.fill", "#123456"),
            subcategoryName: "Comida",
            nameLookup: foodLookup,
            fallbackIconName: "tag.fill"
        )
        #expect(resolved == ResolvedIcon(iconName: "cart.fill", colorHex: "#123456", isGeneric: false))
    }

    @Test func bridgePresent_wins_evenWithNilNameAndEmptyLookup() {
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: ("cart.fill", "#123456"),
            subcategoryName: nil,
            nameLookup: [:],
            fallbackIconName: "tag.fill"
        )
        #expect(resolved == ResolvedIcon(iconName: "cart.fill", colorHex: "#123456", isGeneric: false))
    }

    // MARK: - 2. Nombre matchea (case-insensitive)

    @Test func noBridge_nameMatches_exact() {
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: nil,
            subcategoryName: "comida",
            nameLookup: foodLookup,
            fallbackIconName: "tag.fill"
        )
        #expect(resolved == ResolvedIcon(iconName: "fork.knife", colorHex: "#FF0000", isGeneric: false))
    }

    @Test func noBridge_nameMatches_caseInsensitive() {
        // El creador clasificó "Comida" / "COMIDA"; el lookup local está en minúscula → debe casar.
        for variant in ["Comida", "COMIDA", "cOmIdA"] {
            let resolved = GroupExpenseIconResolver.resolve(
                bridgeIcon: nil,
                subcategoryName: variant,
                nameLookup: foodLookup,
                fallbackIconName: "tag.fill"
            )
            #expect(resolved == ResolvedIcon(iconName: "fork.knife", colorHex: "#FF0000", isGeneric: false))
        }
    }

    @Test func noBridge_nameMatches_withSurroundingWhitespace() {
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: nil,
            subcategoryName: "  Transporte  ",
            nameLookup: foodLookup,
            fallbackIconName: "tag.fill"
        )
        #expect(resolved == ResolvedIcon(iconName: "car.fill", colorHex: "#00FF00", isGeneric: false))
    }

    // MARK: - 3. Nombre no matchea → genérico

    @Test func noBridge_nameNotFound_isGeneric() {
        // Caso cross-idioma: el creador clasificó "Food" y el que mira no tiene esa subcat local.
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: nil,
            subcategoryName: "Food",
            nameLookup: foodLookup,
            fallbackIconName: "tag.fill"
        )
        #expect(resolved == ResolvedIcon(iconName: "tag.fill", colorHex: nil, isGeneric: true))
    }

    @Test func noBridge_nameNotFound_usesProvidedFallbackIcon() {
        // El callsite del detalle pasa el ícono del tipo de división como fallback.
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: nil,
            subcategoryName: "Food",
            nameLookup: foodLookup,
            fallbackIconName: "equal.circle.fill"
        )
        #expect(resolved == ResolvedIcon(iconName: "equal.circle.fill", colorHex: nil, isGeneric: true))
    }

    // MARK: - 4. subcategoryName nil / vacío → genérico

    @Test func noBridge_nilName_isGeneric() {
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: nil,
            subcategoryName: nil,
            nameLookup: foodLookup,
            fallbackIconName: "tag.fill"
        )
        #expect(resolved == ResolvedIcon(iconName: "tag.fill", colorHex: nil, isGeneric: true))
    }

    @Test func noBridge_emptyName_isGeneric() {
        for empty in ["", "   "] {
            let resolved = GroupExpenseIconResolver.resolve(
                bridgeIcon: nil,
                subcategoryName: empty,
                nameLookup: foodLookup,
                fallbackIconName: "tag.fill"
            )
            #expect(resolved == ResolvedIcon(iconName: "tag.fill", colorHex: nil, isGeneric: true))
        }
    }

    // MARK: - 5. Lookup vacío → genérico

    @Test func noBridge_emptyLookup_isGeneric() {
        let resolved = GroupExpenseIconResolver.resolve(
            bridgeIcon: nil,
            subcategoryName: "Comida",
            nameLookup: [:],
            fallbackIconName: "tag.fill"
        )
        #expect(resolved == ResolvedIcon(iconName: "tag.fill", colorHex: nil, isGeneric: true))
    }

    // MARK: - normalizedKey

    @Test func normalizedKey_trimsAndLowercases() {
        #expect(GroupExpenseIconResolver.normalizedKey("  Comida ") == "comida")
        #expect(GroupExpenseIconResolver.normalizedKey("TRANSPORTE") == "transporte")
        #expect(GroupExpenseIconResolver.normalizedKey("") == "")
    }
}
