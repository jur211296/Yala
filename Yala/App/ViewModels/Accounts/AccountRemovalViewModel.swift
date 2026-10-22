//
//  AccountRemovalViewModel.swift
//  Yala
//
//  Estado de la hoja «Eliminar cuenta» cuando la cuenta tiene algo dentro.
//  Card `tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst`.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class AccountRemovalViewModel {

    /// Una sola hoja con fases (no dos `.alert` encadenados: `swiftui-ds.md`).
    enum Phase: Equatable {
        case choose
        case confirmDelete
        case working
        case failed(AccountRemovalService.Failure)
    }

    enum Choice: Equatable { case move, delete }

    /// Una cuenta destino tal como la pinta la hoja.
    struct DestinationOption: Identifiable, Equatable {
        let id: PersistentIdentifier
        let name: String
        let currencyCode: String
        let verdict: AccountRemovalLogic.MoveVerdict

        var isAllowed: Bool {
            if case .allowed = verdict { return true }
            return false
        }
    }

    let account: Account
    /// Nombre y divisa leídos por quien presenta, ANTES de eliminar: la hoja sigue pintándose mientras se cierra,
    /// con la cuenta ya eliminada, y SwiftUI puede volver a evaluar este `init` en cualquier repintado. Leerlos de
    /// `account` ahí leería un modelo borrado.
    let accountName: String
    let sourceCurrencyCode: String
    /// Los movimientos que la persona vio al abrir: «Borrar» solo borra estos.
    private var confirmedTransactionIDs: Set<PersistentIdentifier> = []
    private(set) var phase: Phase = .choose
    private(set) var shape: AccountRemovalLogic.Inventory<PersistentIdentifier>?
    private(set) var destinations: [DestinationOption] = []
    private var destinationAccounts: [PersistentIdentifier: Account] = [:]
    var choice: Choice = .move
    var destinationID: PersistentIdentifier?

    init(account: Account, name: String, currencyCode: String) {
        self.account = account
        accountName = name
        sourceCurrencyCode = normalizeCurrencyCode(currencyCode)
    }

    // MARK: - Leer

    /// Lee lo que cuelga de la cuenta y las cuentas destino, y elige los valores por defecto: mover, a la
    /// primera cuenta permitida (antes las de la misma divisa). Si no se puede mover, borrar; si tampoco,
    /// nada elegido.
    func load(context: ModelContext) {
        do {
            let inventory = try AccountRemovalService.inventory(of: account, context: context)
            let accounts = try AccountRemovalService.destinations(excluding: account, context: context)
            let shape = inventory.shape
            self.shape = shape
            confirmedTransactionIDs = Set(inventory.transactions.map(\.persistentModelID))
            destinationAccounts = Dictionary(uniqueKeysWithValues: accounts.map { ($0.persistentModelID, $0) })
            let source = sourceCurrencyCode
            destinations = accounts
                .map { dest in
                    DestinationOption(
                        id: dest.persistentModelID,
                        name: dest.name,
                        currencyCode: normalizeCurrencyCode(dest.currencyCode),
                        verdict: AccountRemovalLogic.moveVerdict(
                            shape, to: .init(id: dest.persistentModelID, currencyCode: dest.currencyCode))
                    )
                }
                .sorted { lhs, rhs in
                    let lSame = lhs.currencyCode == source
                    let rSame = rhs.currencyCode == source
                    if lSame != rSame { return lSame }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            destinationID = destinations.first(where: \.isAllowed)?.id
            if destinationID != nil {
                choice = .move
            } else if canDelete {
                choice = .delete
            }
            phase = .choose
        } catch {
            shape = nil
            phase = .failed(.unreadable)
        }
    }

    // MARK: - Lo que la hoja pregunta

    var deleteVerdict: AccountRemovalLogic.DeleteVerdict? {
        shape.map(AccountRemovalLogic.deleteVerdict)
    }

    var canDelete: Bool {
        if case .allowed = deleteVerdict { return true }
        return false
    }

    var canMove: Bool { destinations.contains(where: \.isAllowed) }

    /// Por qué no se puede mover: no hay otra cuenta, o todas están en otra divisa y algo no se convierte.
    var cannotMoveReason: String {
        destinations.isEmpty ? L10n.Account.Removal.noDestination : L10n.Account.Removal.noAllowedDestination
    }

    var selectedDestination: DestinationOption? {
        destinations.first { $0.id == destinationID }
    }

    /// El botón principal se puede tocar.
    var canProceed: Bool {
        switch choice {
        case .move: return selectedDestination?.isAllowed == true
        case .delete: return canDelete
        }
    }

    func select(_ option: DestinationOption) {
        guard option.isAllowed else { return }
        destinationID = option.id
        choice = .move
    }

    // MARK: - Actuar

    /// «Mover» actúa ya; «Borrar» pasa antes por su confirmación con la cifra.
    /// - Returns: `true` si la cuenta quedó eliminada (la hoja se cierra y el formulario también).
    func proceed(context: ModelContext, deleteAccount: (Account) throws -> Void) async -> Bool {
        // Un segundo toque mientras el primero espera las tasas lanzaría otra mudanza encima.
        guard phase == .choose else { return false }
        switch choice {
        case .delete:
            guard canDelete else { return false }
            phase = .confirmDelete
            return false
        case .move:
            guard let option = selectedDestination, option.isAllowed,
                  let destination = destinationAccounts[option.id] else { return false }
            phase = .working
            do {
                try await AccountRemovalService.move(
                    account, to: destination, context: context, deleteAccount: deleteAccount)
                return true
            } catch let failure as AccountRemovalService.Failure {
                phase = .failed(failure)
                return false
            } catch {
                phase = .failed(.saveFailed)
                return false
            }
        }
    }

    /// El «sí» de la confirmación de borrar.
    func confirmDelete(context: ModelContext, deleteAccount: (Account) throws -> Void) -> Bool {
        guard phase == .confirmDelete else { return false }
        phase = .working
        do {
            try AccountRemovalService.deleteRecords(
                of: account, confirmedTransactionIDs: confirmedTransactionIDs,
                context: context, deleteAccount: deleteAccount)
            return true
        } catch let failure as AccountRemovalService.Failure {
            phase = .failed(failure)
            return false
        } catch {
            phase = .failed(.saveFailed)
            return false
        }
    }

    /// Vuelve a elegir. Tras un fallo se relee: el motivo pudo ser que algo cambió.
    func back(context: ModelContext) {
        if case .failed = phase {
            load(context: context)
        } else {
            phase = .choose
        }
    }
}
