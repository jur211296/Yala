//
//  UsageModeFreshStartWipeTests.swift
//  YalaTests
//
//  «Empezar de cero» al volver de «Solo grupos» (card p0iu): borra registros, cuentas y presupuestos, conserva los
//  grupos, los avisos y lo que describe a la persona, y deja categorías para empezar (no se repite la bienvenida que
//  las sembraría). El control es «Vaciar datos» (`keepsPersonSettings: false`), que sí se lleva los avisos.
//
//  Como `DataWipePreservesGroupsTests`: el borrado toca `UserDefaults.standard` y el App Group real, así que protege el
//  dominio de la app y lleva `.wipeAppGroupMirrorIsolated`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized, .wipeAppGroupMirrorIsolated)
struct UsageModeFreshStartWipeTests {

    private func seed(_ context: ModelContext) throws {
        let account = Account(name: "BCP", currencyCode: "PEN", colorHex: "#111111", iconName: "creditcard",
                              type: "checking")
        context.insert(account)
        context.insert(TransactionItem(date: .now, amount: -20, currencyCode: "PEN", account: account))
        context.insert(NotificationItem(name: "Fin del día", text: "¿Registraste tus gastos?", hour: 21, minute: 0,
                                        type: .endOfDay))
        context.insert(SplitGroup(name: "Viaje"))
        try context.save()
    }

    private func withProtectedDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.yala.app"
        let snapshot = defaults.persistentDomain(forName: domain) ?? [:]
        defer { defaults.setPersistentDomain(snapshot, forName: domain) }
        try body()
    }

    @Test func empezarDeCero_conservaAvisosYGrupos_yResiembraCategorias() throws {
        try withProtectedDefaults {
            let context = try makeTestContext()
            try seed(context)
            UserDefaults.standard.set("Jürgen", forKey: "userName")

            try DataWipeService.wipePersonalDataKeepingGroups(
                in: context, broadcastSignal: false, keepsPersonSettings: true,
                defaults: makeIsolatedDefaults(prefix: "test.usagemode.fresh"))

            #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<Account>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<NotificationItem>()) == 1, "se llevó los avisos")
            #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1, "tocó los grupos")
            #expect(try context.fetchCount(FetchDescriptor<Yala.Category>()) > 0,
                    "sin categorías no se puede registrar, y no hay bienvenida que las siembre")
            #expect(UserDefaults.standard.string(forKey: "userName") == "Jürgen", "se llevó el nombre de la persona")
        }
    }

    /// Control: «Vaciar datos» sigue llevándose los avisos y las preferencias. Sin este caso, el de arriba pasaría
    /// también si el parámetro no hiciera nada en ningún borrado.
    @Test func vaciarDatos_sigueLlevandoseAvisosYPreferencias() throws {
        try withProtectedDefaults {
            let context = try makeTestContext()
            try seed(context)
            UserDefaults.standard.set("Jürgen", forKey: "userName")

            try DataWipeService.wipePersonalDataKeepingGroups(
                in: context, broadcastSignal: false,
                defaults: makeIsolatedDefaults(prefix: "test.usagemode.wipe"))

            #expect(try context.fetchCount(FetchDescriptor<NotificationItem>()) == 0,
                    "«Vaciar datos» ya no se lleva los avisos de la persona")
            #expect(UserDefaults.standard.string(forKey: "userName") == nil)
            #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        }
    }
}
