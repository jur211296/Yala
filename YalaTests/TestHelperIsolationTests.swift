//
//  TestHelperIsolationTests.swift
//  YalaTests
//
//  Regression tests para el CONTRATO de aislamiento de `makeTestContext()`
//  (fix 2026-07-04: container reusado por-archivo + wipe por-objeto + autosave OFF).
//
//  Ancla que el reset per-file NO fugue estado entre tests consecutivos del MISMO
//  archivo: aunque el container/store se reusa, cada `makeTestContext()` debe
//  devolver un store VACÍO. Si el wipe por-objeto volviera a fugar, el test 2
//  vería los inserts del test 1 y estas aserciones fallarían.
//
//  La suite DEBE ser `@Suite(.serialized)` (contrato de `makeTestContext()`: los
//  tests del mismo archivo reusan el container y no deben solaparse).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("TestHelper isolation contract — makeTestContext", .serialized)
struct TestHelperIsolationTests {

    // MARK: - (1) Reset per-file: dos tests consecutivos ven un store vacío al arrancar
    //
    // Los dos tests siguientes forman el par de regresión. `.serialized` garantiza
    // que corren en orden dentro de este archivo, reusando el MISMO container.
    // El primero inserta 3 Account; el segundo verifica que ve 0 al arrancar.
    // Si el wipe por-objeto fugara, el segundo vería los 3 inserts del primero.

    @Test func first_test_insertsAccounts_intoSharedStore() throws {
        let context = try makeTestContext()

        // Store debe arrancar vacío (nadie insertó antes, o el wipe lo limpió).
        let before = try context.fetch(FetchDescriptor<Account>())
        #expect(before.isEmpty, "El store debe arrancar vacío al inicio del primer test")

        _ = makeTestAccount(context: context, name: "Leak Sentinel A")
        _ = makeTestAccount(context: context, name: "Leak Sentinel B")
        _ = makeTestAccount(context: context, name: "Leak Sentinel C")
        try context.save()

        let after = try context.fetch(FetchDescriptor<Account>())
        #expect(after.count == 3, "El primer test debe ver sus 3 inserts")
    }

    @Test func second_test_seesEmptyStore_afterPriorTestInserts() throws {
        // Reusa el container del archivo; `makeTestContext()` debió vaciar el store
        // aunque el test anterior insertó (y guardó) 3 Account.
        let context = try makeTestContext()

        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.isEmpty, "El wipe per-file debe dejar el store vacío pese a los inserts del test previo")
    }

    // MARK: - (2) El contexto devuelto tiene autosave DESACTIVADO

    @Test func makeTestContext_returnsContext_withAutosaveDisabled() throws {
        let context = try makeTestContext()
        #expect(context.autosaveEnabled == false, "autosave debe quedar OFF: la persistencia es solo explícita")
    }

    // MARK: - (3) El mismo archivo reusa el MISMO container (identidad estable)

    @Test func makeTestContext_reusesSameContainer_withinFile() throws {
        let first = try makeTestContext()
        let second = try makeTestContext()
        // `mainContext` es 1:1 con su container → misma identidad de objeto ⇒ mismo container reusado.
        #expect(first === second, "Dos llamadas en el mismo archivo deben devolver el mainContext del mismo container")
    }

    // MARK: - Refuerzo: cada llamada dentro de UN test también vacía el store

    @Test func makeTestContext_wipesOnEachCall_withinSameTest() throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Ephemeral")
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Account>()).count == 1)

        // Segunda llamada (mismo test) debe re-vaciar el store reusado.
        let again = try makeTestContext()
        #expect(try again.fetch(FetchDescriptor<Account>()).isEmpty, "Cada makeTestContext() vacía el store reusado")
    }

    // NOTA: no se testea directamente `wipeAllModels` ni `testContainer(for:)` — ambos son
    // `private` en TestHelpers.swift. Su comportamiento queda cubierto indirectamente por los
    // tests de arriba (store vacío al arrancar = wipe OK; misma identidad = reuse OK).
}
