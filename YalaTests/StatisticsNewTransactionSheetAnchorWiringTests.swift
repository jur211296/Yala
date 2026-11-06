//
//  StatisticsNewTransactionSheetAnchorWiringTests.swift
//  YalaTests
//
//  Ticket `external-entry-panel-link-loses-the-typed-amount-intermittently` (card «Nuevo registro desde Estadísticas
//  pierde el importe al salir y volver por enlace»). La hoja de «Nuevo registro» colgaba de `DetailContainerView`, el
//  contenido RAÍZ de la pila de Estadísticas, y SwiftUI la desmontaba y la volvía a montar sin cerrarse cuando un enlace
//  cambiaba de pestaña con la app volviendo a primer plano: el formulario volvía con «0.00». Colgada del contenedor
//  (`StatisticsView`, fuera de la `NavigationStack`), sobrevive. Molde de `ProfileSheetsAnchorWiringTests`.
//
//  La red de comportamiento es `ExternalEntryForeignSheetUITests` (siete casos, intermitente: 1 de 21 en el iPhone SE con
//  el código de antes). Este scan fija el sitio, que es lo que un refactor movería sin que nada cante a la primera.
//

import Foundation
import Testing

@Suite("La hoja de Nuevo registro de Estadísticas cuelga del contenedor de la pila")
struct StatisticsNewTransactionSheetAnchorWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test func theSheet_hangsFromStatisticsView_outsideTheStack() throws {
        let statistics = try Self.source("Yala/App/Views/Statistics/StatisticsView.swift")
        let stackEnd = try #require(statistics.range(of: "NavigationStack {"))
        let sheet = try #require(
            statistics.range(of: ".sheet(isPresented: $recordsViewModel.showNewTransaction)"),
            "StatisticsView ya no presenta la hoja de Nuevo registro.")
        #expect(sheet.lowerBound > stackEnd.upperBound)
        // Fuera de la pila: entre el cierre del `NavigationStack { … }` y la hoja no hay otro `NavigationStack`, y la hoja
        // va DESPUÉS de la llave que lo cierra (el contenido de la pila termina en `.navigationBarTitleDisplayMode`).
        let title = try #require(statistics.range(of: ".navigationBarTitleDisplayMode(.large)"))
        let between = statistics[title.upperBound..<sheet.lowerBound]
        #expect(between.contains("}"), "La hoja tiene que ir por fuera de la llave que cierra el NavigationStack.")
        #expect(statistics.contains("NewTransactionView()"))
        // Lo que la hoja recibía del entorno dentro de Estadísticas: el «Editar» del aviso tras guardar.
        #expect(statistics.contains(".environment(\\.savedRecordEditorOpener, recordsViewModel.savedRecordEditorOpener)"))
        // Y le pasa a la pila el MISMO ViewModel cuyo `showNewTransaction` escriben los botones.
        #expect(statistics.contains("DetailContainerView(initialTab: navigation.selectedDetailTab, recordsViewModel: recordsViewModel)"))
    }

    @Test func detailContainer_doesNotPresentItAnymore_andReloadsOnClose() throws {
        let detail = try Self.source("Yala/App/Views/Statistics/DetailContainerView.swift")
        #expect(!detail.contains(".sheet(isPresented: $recordsViewModel.showNewTransaction)"),
                "La hoja de Nuevo registro volvió al contenido raíz de la pila de Estadísticas.")
        #expect(!detail.contains("NewTransactionView()"))
        #expect(detail.contains(".onChange(of: recordsViewModel.showNewTransaction)"),
                "Al cerrar la hoja, Estadísticas tiene que recargar (antes lo hacía su onDisappear).")
        #expect(detail.contains("if !isOpen { reloadAndRecalculate() }"))
    }
}
