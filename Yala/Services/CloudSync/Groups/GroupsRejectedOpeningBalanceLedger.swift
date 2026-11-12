//
//  GroupsRejectedOpeningBalanceLedger.swift
//  Yala
//
//  Card m76a (2026-11-02) · los repartos de un saldo inicial NUEVO que el servidor rechazó quedan huérfanos en el servidor
//  y en el teléfono. El trigger `opening_balance_guard` (g27_01) rechaza el gasto (`not_admin`, `group_closed`,
//  `locked`), pero sus repartos llegan después y no los juzga: su gasto no existe en el servidor. Se aplican, y el re-pull
//  de `settleRejectedOpeningBalances` (card e6fd) los vuelve a bajar. No cambian ningún saldo (`GroupBalanceService` indexa
//  los repartos por gasto), pero son filas basura que nadie ve.
//
//  Decisión (a) de la card, solo cliente: `settleRejectedOpeningBalances` apunta aquí cada gasto que descarta, y cuando el
//  pull siguiente TERMINA —el re-pull desde 0 de su grupo ya bajó todo lo que el servidor tiene— `GroupsSyncClient
//  .sweepRejectedOpeningBalanceShares` mira si el gasto volvió:
//   · volvió → el servidor lo tiene (era una edición rechazada): nada que limpiar, sus repartos son los de verdad;
//   · no volvió → era nuevo: sus repartos locales se borran con el autor normal, el drain los sube como tombstones y el
//     servidor los acepta (medido en staging, `qa/cloud/g29_01-staging-probe.sh` casos 6-8: el trigger no los juzga y la
//     RLS deja borrar al miembro activo; el de un saldo que SÍ existe lo rechaza el mismo trigger). Con el grupo cerrado
//     (`group_closed`) ningún tombstone pasaría la RLS: se borran solo aquí.
//
//  Es durable (UserDefaults) porque entre el descarte y el final del re-pull puede haber un kill. Va por dueño de sesión:
//  lo apuntado por una cuenta no lo limpia otra. Del TELÉFONO, como el resto del canal: no viaja.
//

import Foundation

nonisolated enum GroupsRejectedOpeningBalanceLedger {

    struct Entry: Codable, Equatable, Sendable {
        let groupID: String
        let expenseID: UUID
        let ownerUserID: String?
        /// `true` con `group_closed`: los repartos se borran solo en el teléfono (ningún tombstone pasaría la RLS).
        let localOnly: Bool
    }

    static let key = "groupsSync.rejectedOpeningBalances"

    /// Bajo tests NUNCA `.standard`: el host es la app del simulador. Inyectable (los tests lo restauran en `defer`).
    nonisolated(unsafe) static var defaults: UserDefaults = makeDefaults()

    static var entries: [Entry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            #if DEBUG
            print("GroupsRejectedOpeningBalanceLedger: Error decoding: \(error)")
            #endif
            return []
        }
    }

    static func add(_ new: [Entry]) {
        guard !new.isEmpty else { return }
        var all = entries
        for entry in new where !all.contains(where: { $0.expenseID == entry.expenseID }) { all.append(entry) }
        persist(all)
    }

    static func remove(expenseIDs: Set<UUID>) {
        guard !expenseIDs.isEmpty else { return }
        persist(entries.filter { !expenseIDs.contains($0.expenseID) })
    }

    private static func persist(_ all: [Entry]) {
        guard !all.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }
        do {
            defaults.set(try JSONEncoder().encode(all), forKey: key)
        } catch {
            #if DEBUG
            print("GroupsRejectedOpeningBalanceLedger: Error encoding: \(error)")
            #endif
        }
    }

    private static func makeDefaults() -> UserDefaults {
        let isRunningTests = ProcessInfo.processInfo.environment["YALA_TEST_MODE"] == "1"
            || NSClassFromString("XCTestObservationCenter") != nil
        guard isRunningTests else { return .standard }
        let suite = "yala.tests.groupsRejectedOpeningBalanceLedger"
        let testDefaults = UserDefaults(suiteName: suite) ?? .standard
        testDefaults.removePersistentDomain(forName: suite)
        return testDefaults
    }
}
