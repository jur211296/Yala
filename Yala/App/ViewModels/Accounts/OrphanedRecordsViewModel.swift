//
//  OrphanedRecordsViewModel.swift
//  Yala
//
//  Estado de la hoja «Movimientos sin cuenta».
//  Card `tablero-los-movimientos-que-quedaron-sin-cuenta-sovw`.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class OrphanedRecordsViewModel {

    /// Una sola hoja con fases, como la de eliminar cuenta (no dos `.alert` encadenados: `swiftui-ds.md`).
    enum Phase: Equatable {
        case choose
        case working
        case failed(AccountRemovalService.Failure)
    }

    /// Un movimiento tal como lo pinta la hoja. Se copia al leer: la hoja sigue pintándose mientras se cierra, con los
    /// movimientos ya movidos (o borrados, los de una transferencia que se quita).
    struct Record: Identifiable, Equatable {
        let id: PersistentIdentifier
        let title: String
        let date: Date
        let amount: Double
        let currencyCode: String
    }

    /// Una cuenta destino tal como la pinta la hoja.
    struct DestinationOption: Identifiable, Equatable {
        let id: PersistentIdentifier
        let name: String
        let currencyCode: String
        let outcome: OrphanedRecordsLogic.MoveOutcome
    }

    private(set) var phase: Phase = .choose
    private(set) var records: [Record] = []
    private(set) var destinations: [DestinationOption] = []
    private var destinationAccounts: [PersistentIdentifier: Account] = [:]
    var destinationID: PersistentIdentifier?

    // MARK: - Leer

    /// Lee los huérfanos y las cuentas destino. Elige por defecto la primera cuenta, antes las de la moneda que más se
    /// repite entre los huérfanos.
    func load(context: ModelContext) {
        do {
            let inventory = try OrphanedRecordsService.inventory(context: context)
            let accounts = try OrphanedRecordsService.destinations(context: context)
            records = inventory.transactions.map { tx in
                Record(
                    id: tx.persistentModelID,
                    title: Self.title(of: tx),
                    date: tx.date,
                    amount: tx.amount,
                    currencyCode: normalizeCurrencyCode(tx.currencyCode))
            }
            let mainCurrency = Self.mostFrequentCurrency(records.map(\.currencyCode))
            destinationAccounts = Dictionary(uniqueKeysWithValues: accounts.map { ($0.persistentModelID, $0) })
            destinations = accounts
                .map { dest in
                    DestinationOption(
                        id: dest.persistentModelID,
                        name: dest.name,
                        currencyCode: normalizeCurrencyCode(dest.currencyCode),
                        outcome: inventory.outcome(to: dest))
                }
                .sorted { lhs, rhs in
                    let lSame = lhs.currencyCode == mainCurrency
                    let rSame = rhs.currencyCode == mainCurrency
                    if lSame != rSame { return lSame }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            if selectedDestination == nil {
                destinationID = destinations.first?.id
            }
            phase = .choose
        } catch {
            records = []
            phase = .failed(.unreadable)
        }
    }

    // MARK: - Lo que la hoja pregunta

    var selectedDestination: DestinationOption? {
        destinations.first { $0.id == destinationID }
    }

    var canMove: Bool { phase == .choose && !records.isEmpty && selectedDestination != nil }

    func select(_ option: DestinationOption) {
        destinationID = option.id
    }

    // MARK: - Actuar

    /// - Returns: `true` si se movieron (la hoja se cierra).
    func move(context: ModelContext) async -> Bool {
        // Un segundo toque mientras el primero espera las tasas lanzaría otra mudanza encima.
        guard canMove, let option = selectedDestination, let destination = destinationAccounts[option.id] else {
            return false
        }
        phase = .working
        do {
            try await OrphanedRecordsService.move(Set(records.map(\.id)), to: destination, context: context)
            return true
        } catch let failure as AccountRemovalService.Failure {
            phase = .failed(failure)
            return false
        } catch {
            phase = .failed(.saveFailed)
            return false
        }
    }

    /// Vuelve a elegir, releyendo: el motivo del fallo pudo ser que algo cambió.
    func back(context: ModelContext) {
        load(context: context)
    }

    // MARK: - Piezas

    /// La nota, y si no hay, la subcategoría o la categoría: lo mismo que enseña la fila de Registros.
    private static func title(of tx: TransactionItem) -> String {
        if let note = tx.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { return note }
        if let name = tx.subcategory?.name, !name.isEmpty { return name }
        if let name = tx.category?.name, !name.isEmpty { return name }
        return L10n.OrphanedRecords.untitled
    }

    private static func mostFrequentCurrency(_ codes: [String]) -> String? {
        let counts = Dictionary(codes.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }?.key
    }
}
