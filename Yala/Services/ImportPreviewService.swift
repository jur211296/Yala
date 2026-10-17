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
    }

    enum Failure: Error {
        /// Una cuenta elegida no se encontró en el contexto aparte (no debería pasar: ya está guardada).
        case accountUnavailable
    }

    static func preview(
        of url: URL,
        target: Target,
        allowCreatingNewCategories: Bool,
        container: ModelContainer
    ) async throws -> ImportPreview {
        let scratch = ModelContext(container)
        scratch.autosaveEnabled = false
        let isXLSX = url.pathExtension.lowercased() == "xlsx"

        let result: TransactionImportResult
        let accountNames: [String]
        switch target {
        case .single(let account):
            guard let local = scratch.model(for: account.persistentModelID) as? Account else {
                throw Failure.accountUnavailable
            }
            accountNames = [local.name]
            result = isXLSX
                ? try await TransactionCSVImportService.importXLSX(
                    from: url, into: local, in: scratch,
                    allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: true)
                : try await TransactionCSVImportService.importCSV(
                    from: url, into: local, in: scratch,
                    allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: true)
        case .multi(let map):
            var localMap: [String: Account] = [:]
            for (code, account) in map {
                guard let local = scratch.model(for: account.persistentModelID) as? Account else {
                    throw Failure.accountUnavailable
                }
                localMap[code] = local
            }
            accountNames = localMap.sorted { $0.key < $1.key }.map(\.value.name)
            result = isXLSX
                ? try await TransactionCSVImportService.importXLSXMultiCurrency(
                    from: url, currencyAccountMap: localMap, in: scratch,
                    allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: true)
                : try await TransactionCSVImportService.importCSVMultiCurrency(
                    from: url, currencyAccountMap: localMap, in: scratch,
                    allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: true)
        }

        // Se copia a valores ANTES de soltar el contexto: los borradores apuntan a objetos suyos.
        let rows = result.drafts.map {
            ImportPreview.Row(
                date: $0.date,
                amount: ($0.amount as NSDecimalNumber).doubleValue,
                currencyCode: $0.normalizedCurrencyCode,
                categoryName: $0.category.name,
                subcategoryName: $0.subcategory.name
            )
        }
        let preview = ImportPreviewLogic.make(
            rows: rows,
            accountNames: accountNames,
            failures: result.failures.compactMap(\.errorDescription),
            ignoredFutureCount: result.ignoredFutureDatesCount
        )
        scratch.rollback()
        return preview
    }
}
