//
//  DataWipePreservesGroupsTests.swift
//  YalaTests
//
//  D1c (Gestión de datos §15): "Vaciar mis datos" (`DataWipeService.wipeAllUserData`) borra el corpus
//  PERSONAL pero JAMÁS toca el dominio de Grupos — los 5 `Split*` viven en un store aparte y el copy
//  "tus grupos no se tocan" (fila 👥 de la hoja de alcance D4, `settings.wipeScopeGroups`) lo promete al usuario. Este test FIJA esa
//  exención A NIVEL DE MODELOS ejecutando la función REAL sobre un container in-memory.
//
//  Nota (M4 del review): `wipeAllUserData` también resetea `UserDefaults.standard` + varios singletons de
//  estado (paso 2/3). Para no contaminar otras suites protegemos el dominio persistente de la app
//  (snapshot/restore en `defer`) y corremos serializado.
//
//  Y EL APP GROUP, que faltaba (2026-08-05). El paso 2 llega a `DataWipeService.resetAllUserPreferences()`
//  (`:195`, incondicional), que además del dominio de la app barre TRES claves del App Group REAL
//  —`expensesOnlyMode`, `firstWeekday`, `lastUsedAccountID` (`DataWipeService.swift:401-404`)—, y ese
//  almacén sobrevive al proceso y lo comparten el host de los unit tests y el de los XCUITest. El
//  snapshot/restore de abajo protege `.standard` y NO lo cubría. Lo cubre `.wipeAppGroupMirrorIsolated`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized, .wipeAppGroupMirrorIsolated)
struct DataWipePreservesGroupsTests {

    @Test func wipeAllUserData_preservesSplitModels_deletesPersonal() throws {
        // Proteger el estado global que la función toca (UserDefaults.standard vía resetAllUserPreferences).
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.yala.app"
        let snapshot = defaults.persistentDomain(forName: domain) ?? [:]
        defer { defaults.setPersistentDomain(snapshot, forName: domain) }

        let context = try makeTestContext()

        // Corpus PERSONAL (debe morir).
        context.insert(Account(
            name: "Efectivo", currencyCode: "PEN", colorHex: "#111111",
            iconName: "banknote", type: "cash"))
        context.insert(Yala.Tag(name: "Comida"))

        // Dominio de GRUPOS (debe sobrevivir) — uno de cada uno de los 5 Split*.
        context.insert(SplitGroup(name: "Viaje"))
        context.insert(SplitMember(groupZoneID: "zone-1", displayName: "Ana"))
        context.insert(SplitExpense(groupZoneID: "zone-1", amount: 10, expenseDescription: "Cena"))
        context.insert(SplitShare(memberID: "m1", amount: 5, groupZoneID: "zone-1"))
        context.insert(SplitSettlement(
            groupZoneID: "zone-1", fromMemberID: "m1", toMemberID: "m2", amount: 5))
        try context.save()

        // Sanity: sembrado correcto.
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)

        try DataWipeService.wipeAllUserData(
            in: context, reseedInitialData: false, broadcastSignal: false)

        // Personal borrado.
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Yala.Tag>()) == 0)

        // Grupos INTACTO — los 5 Split*.
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitMember>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitShare>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitSettlement>()) == 1)
    }
}
