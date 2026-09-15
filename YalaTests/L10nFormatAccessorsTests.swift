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

    /// Paso 4 · los tres accessors con formato de la puerta de iCloud. El de `lateBody` carga más peso
    /// que sus hermanos: su `%@` es la línea de CIFRAS del aviso, y una key cruda ahí le diría al usuario
    /// que borre su histórico sin enseñarle cuánto es.
    @Test func privateICloudAccessors_interpolate_neverRawKey() {
        let since = L10n.Welcome.PrivateICloud.foundSince("marzo de 2025")
        #expect(!since.contains("welcome.privateICloud"))
        #expect(since.contains("marzo de 2025"))

        let atLeast = L10n.Welcome.PrivateICloud.foundAtLeast(20_000)
        #expect(!atLeast.contains("welcome.privateICloud"))
        #expect(atLeast.contains("20"))

        let late = L10n.Welcome.PrivateICloud.lateBody("128 registros · 3 cuentas")
        #expect(!late.contains("welcome.privateICloud"))
        #expect(late.contains("128 registros · 3 cuentas"))
    }

    /// **Los tres accessors SIN formato de la puerta que vuelve atrás, y el motivo es el mismo aunque no
    /// interpolen nada** (2026-09-14): una errata en el literal de `ls(...)` sale a pantalla como key
    /// cruda, y **eso no lo caza la paridad** — `LocalizationParityTests` compara `.strings` contra
    /// `.strings` y jamás abre `L10n.swift`. El único guardián del copy de esta pantalla
    /// (`copy_isOwnAndNamesICloud`) lee el `.strings` directo, con lo que tampoco pasa por el accessor.
    ///
    /// Son las tres claves que sostienen la decisión (a): que la app **no declare** un borrado que no
    /// ocurrió. Un nombre de clave en pantalla, ahí, es peor que el copy viejo.
    @Test func discardUnverifiedAccessors_resolve_neverRawKey() {
        for texto in [L10n.Welcome.PrivateICloud.discardUnverifiedBody,
                      L10n.Welcome.PrivateICloud.discardUnverifiedNoAccountBody,
                      L10n.Welcome.PrivateICloud.discardUnverifiedBack] {
            #expect(!texto.contains("welcome.privateICloud"), """
                accessor devolvió la key cruda: el literal de `ls(...)` no casa con ninguna clave de los
                .strings. Texto: \(texto)
                """)
            #expect(!texto.isEmpty)
        }
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

    /// **El teléfono sin App Attest** (2026-09-15): los dos accessors con cifra y sus hermanos sin ella. Una key cruda en
    /// el aviso que ofrece PERDER cambios pediría decidir sin decir qué se pierde, y el botón destructivo sería el nombre
    /// de una clave. La paridad no lo caza: compara `.strings` con `.strings` y nunca abre `L10n.swift`.
    @Test func attestUnavailableAccessors_interpolate_neverRawKey() {
        let signOut = L10n.Groups.Errors.attestUnavailableSignOutLoss(7)
        #expect(!signOut.contains("groups.errors"))
        #expect(signOut.contains("7"))

        let welcome = L10n.Welcome.Groups.neutralAttestLossBody(7)
        #expect(!welcome.contains("welcome.groups"))
        #expect(welcome.contains("7"))

        for texto in [L10n.Groups.Errors.attestUnavailableTitle,
                      L10n.Groups.Errors.attestUnavailable,
                      L10n.Groups.Errors.attestUnavailableSignOutLossUnknown,
                      L10n.Groups.Errors.attestUnavailableSignOutLossButton,
                      L10n.Groups.Errors.leaveAttestUnavailable,
                      L10n.Welcome.Groups.neutralAttestLossBodyUnknown,
                      L10n.Welcome.Groups.neutralAttestLossContinue,
                      L10n.Action.notNow] {
            #expect(!texto.contains("groups.errors") && !texto.contains("welcome.groups") && !texto.contains("action."),
                    "accessor devolvió la key cruda: \(texto)")
            #expect(!texto.isEmpty)
        }
    }
}
