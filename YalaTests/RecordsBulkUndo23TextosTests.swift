//
//  RecordsBulkUndo23TextosTests.swift
//  YalaTests
//
//  Los textos de la selección en lote de Registros (decisión 18 y 75 de la revisión 2.3):
//  - Punto 2: «2334 seleccionados» y «¿Eliminar 2334 registros?» sin separador de miles. Con el código de antes,
//    `String(format:)` sin locale escribía «2334» en todos los idiomas.
//  - Punto 3: la edición masiva decía «Hoy: 3 subcategorías distintas», y «Hoy» parece una fecha.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Registros · textos del lote (decisiones 18 y 75 de 2.3)", .serialized, .appLanguageStateIsolated)
struct RecordsBulkUndo23TextosTests {

    /// El recuento con el separador de miles del idioma de la app.
    private func grouped(_ value: Int) -> String {
        value.formatted(.number.locale(AppLocale.current))
    }

    /// Punto 2: en la selección, al borrar y en el aviso, «2,334» y nunca «2334».
    @Test(arguments: ["es-419", "en", "de"])
    func countsCarryTheThousandsSeparator(_ language: String) {
        LanguageManager.overrideLanguage = language
        let count = 2_334
        let expected = grouped(count)
        #expect(expected != "2334", "el idioma \(language) no separa miles: el caso no discrimina")
        let texts = [
            L10n.Records.selectedCount(count),
            L10n.Records.deleteConfirmTitle(count),
            L10n.Records.groupRecordsKept(count),
            L10n.UXL10.deletedRecords(count),
            L10n.UXL8B.BulkEdit.title(count),
            L10n.UXL8B.BulkEdit.apply(count),
            L10n.RecordsBulkUndo.selectAll(count),
            L10n.RecordsBulkUndo.edited(count),
            L10n.RecordsBulkUndo.editedInto(count, "Transporte público"),
        ]
        for text in texts {
            #expect(text.contains(expected), "«\(text)» no lleva \(expected)")
            #expect(!text.contains("2334"), "«\(text)» sin separador de miles")
        }
    }

    /// E2: «Seleccionar los 2,334» dice cuántos marca, y el aviso del lote nombra la categoría.
    @Test func selectAllAndEditNotice_sayHowMany() {
        LanguageManager.overrideLanguage = "es-419"
        let count = grouped(2_334)
        #expect(L10n.RecordsBulkUndo.selectAll(2_334) == "Seleccionar los \(count)")
        #expect(L10n.RecordsBulkUndo.selectAll(1) == "Seleccionar 1")
        #expect(L10n.RecordsBulkUndo.editedInto(3, "Transporte público") == "3 registros ahora son Transporte público")
        #expect(L10n.RecordsBulkUndo.edited(3) == "Cambiaste 3 registros")
        #expect(L10n.RecordsBulkUndo.selectDay == "Seleccionar día")
    }

    /// Punto 3: en las cuatro variantes del español, la fila de la edición masiva dice «Ahora:», no «Hoy:».
    @Test(arguments: ["es", "es-419", "es-ES", "es-AR"])
    func bulkEditCurrentValue_saysNowNotToday(_ language: String) {
        LanguageManager.overrideLanguage = language
        let text = L10n.UXL8B.BulkEdit.today(L10n.UXL8B.BulkEdit.distinctSubcategories(3))
        #expect(!text.hasPrefix("Hoy"), "«\(text)» parece una fecha")
        #expect(text.hasPrefix("Ahora: "), "«\(text)»")
    }
}
