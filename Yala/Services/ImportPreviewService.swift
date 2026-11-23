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

    /// La vista previa siempre se calcula con TODAS las cuentas nuevas y con los duplicados dentro: la elección (plan
    /// gratuito, «Importarlos igual») se aplica encima sin volver a leer el archivo (`ImportPreviewLogic.applying`).
    ///
    /// Desde el 2026-11-22 (H14) la vista previa solo VALIDA: no crea los movimientos para tirarlos. Devuelve también la
    /// tabla leída, que el import reutiliza en vez de volver a leer el archivo. La lectura se queda en el hilo
    /// principal: medida, cuesta 0,03 s con 3.000 filas, y sacarla obligaba a desaislar el lector, el de Excel y los
    /// errores del import.
    static func preview(
        of url: URL,
        target: Target,
        allowCreatingNewCategories: Bool,
        container: ModelContainer
    ) async throws -> ImportPreview {
        try await previewAndTable(
            of: url, target: target, allowCreatingNewCategories: allowCreatingNewCategories, container: container
        ).preview
    }

    static func previewAndTable(
        of url: URL,
        target: Target,
        allowCreatingNewCategories: Bool,
        container: ModelContainer
    ) async throws -> (preview: ImportPreview, table: ImportTable) {
        let table = try ImportFileReader.readTable(from: url)
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
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: true,
            preparedTable: table, insertsTransactions: false)

        // Se copia a valores ANTES de soltar el contexto: los borradores apuntan a objetos suyos.
        let preview = ImportPreviewLogic.make(result: result, existingBillableAccounts: existingBillable)
        scratch.rollback()
        return (preview, table)
    }
}
