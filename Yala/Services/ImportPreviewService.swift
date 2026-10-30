//
//  ImportPreviewService.swift
//  Yala
//
//  La vista previa de una importación (auditoría UX 2.2, lote 7, L7-15).
//

import Foundation
import SwiftData

/// Hace la importación de verdad, pero en un contexto aparte que nunca se guarda, y devuelve lo que habría
/// entrado. Así la vista previa cuenta EXACTAMENTE lo que hará «Importar» —mismo lector, mismas reglas, mismas
/// filas malas— sin una segunda implementación que pueda divergir.
///
/// **El contexto aparte no se guarda nunca y no guarda solo** (`autosaveEnabled = false`): las categorías,
/// etiquetas y registros que la importación inserta en él se tiran al acabar. Las cuentas se vuelven a leer en
/// ese contexto por su identificador, porque una relación entre objetos de dos contextos distintos revienta.
@MainActor
enum ImportPreviewService {

    enum Target {
        case single(Account)
        case multi([String: Account])
        /// Cada fila a la cuenta que nombra su columna `account` (H7). `allowedNewAccountKeys` = las cuentas nuevas
        /// que se crean; `nil` = todas.
        case accountColumn(allowedNewAccountKeys: Set<String>?)
    }

    enum Failure: Error {
        /// Una cuenta elegida no se encontró en el contexto aparte (no debería pasar: ya está guardada).
        case accountUnavailable
    }

    /// La vista previa siempre se calcula con TODAS las cuentas nuevas: la elección (plan gratuito) se aplica encima
    /// sin volver a leer el archivo (`ImportPreviewLogic.applying`).
    static func preview(
        of url: URL,
        target: Target,
        allowCreatingNewCategories: Bool,
        container: ModelContainer
    ) async throws -> ImportPreview {
        let scratch = ModelContext(container)
        scratch.autosaveEnabled = false

        let destination: ImportDestination
        switch target {
        case .single(let account):
            guard let local = scratch.model(for: account.persistentModelID) as? Account else {
                throw Failure.accountUnavailable
            }
            destination = .account(local)
        case .multi(let map):
            var localMap: [String: Account] = [:]
            for (code, account) in map {
                guard let local = scratch.model(for: account.persistentModelID) as? Account else {
                    throw Failure.accountUnavailable
                }
                localMap[code] = local
            }
            destination = .byCurrency(localMap)
        case .accountColumn:
            destination = .accountColumn(allowedNewAccountKeys: nil)
        }

        let existingBillable = try scratch.fetch(FetchDescriptor<Account>()).billableUserAccounts.count
        let result = try await TransactionCSVImportService.importFile(
            from: url, destination: destination, in: scratch,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: true)

        // Se copia a valores ANTES de soltar el contexto: los borradores apuntan a objetos suyos.
        let preview = ImportPreviewLogic.make(result: result, existingBillableAccounts: existingBillable)
        scratch.rollback()
        return preview
    }
}
