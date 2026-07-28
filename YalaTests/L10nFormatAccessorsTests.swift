//
//  L10nFormatAccessorsTests.swift
//  YalaTests
//
//  Regresión de los accessors L10n con `String(format:)` cuya key lleva los
//  placeholders en el CONTENIDO (no en el nombre). Si la key desaparece de los
//  .strings o el format deja de interpolar, el usuario ve la key cruda — el bug
//  original del dialog parcial de Siri (`QuickExpenseIntent`).
//

import Foundation
import Testing

@testable import Yala

struct L10nFormatAccessorsTests {

    @Test func successPartial_interpolatesCounts_neverRawKey() {
        let result = L10n.Shortcut.successPartial(5, 3)

        #expect(!result.contains("shortcut.siriNatural"), "Accessor devolvió la key cruda — falta la key en el locale activo")
        #expect(result.contains("5"))
        #expect(result.contains("3"))
    }

    @Test func exchangeRateShort_embedsRate_neverRawKey() {
        let result = L10n.Transaction.exchangeRateShort("3.7500")

        #expect(!result.contains("transaction.exchangeRateShort"))
        #expect(result.contains("3.7500"))
    }

    @Test func variationAccessors_embedValue_neverRawKey() {
        let up = L10n.Accessibility.variationIncrease("+12%")
        let down = L10n.Accessibility.variationDecrease("-8%")

        #expect(!up.contains("accessibility.variation"))
        #expect(up.contains("+12%"))
        #expect(!down.contains("accessibility.variation"))
        #expect(down.contains("-8%"))
    }

    @Test func removeTab_embedsName_neverRawKey() {
        let result = L10n.Accessibility.removeTab("Panel")

        #expect(!result.contains("accessibility.removeTab"))
        #expect(result.contains("Panel"))
    }

    /// C-7: la nota de «usarás tu cuenta actual» nombra el método. Si la key se pierde, la card de
    /// migración mostraría `storage.migrate.accountReuseNote` en crudo justo antes de mover los datos.
    @Test func storageAccountReuseNote_embedsProvider_neverRawKey() {
        let result = L10n.Storage.Migrate.accountReuseNote("Google")

        #expect(!result.contains("storage.migrate.accountReuseNote"))
        #expect(result.contains("Google"))
        // La variante genérica (método desconocido) no interpola nada, pero tampoco puede ser la key.
        #expect(!L10n.Storage.Migrate.accountReuseNoteGeneric.contains("storage.migrate"))
    }

    /// C-7: el aviso de «esta copia es de otra cuenta» es lo único que separa al usuario de adoptar
    /// bajo la identidad equivocada. Si sale la key cruda, el aviso no comunica nada.
    @Test func storageOtherAccountNote_embedsProvider_neverRawKey() {
        let result = L10n.Storage.Adopt.otherAccountNote("Apple")

        #expect(!result.contains("storage.adopt.otherAccountNote"))
        #expect(result.contains("Apple"))
        #expect(!L10n.Storage.Adopt.otherAccountNoteGeneric.contains("storage.adopt"))
    }
}
