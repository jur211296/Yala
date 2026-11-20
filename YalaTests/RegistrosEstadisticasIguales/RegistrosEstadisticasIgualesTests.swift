//
//  RegistrosEstadisticasIgualesTests.swift
//  YalaTests
//
//  Decisión de Jürgen del 17-nov: Estadísticas › Registros es idéntica a la pestaña Registros. Estos casos fijan que
//  las dos pantallas montan LA MISMA pieza (`RecordsSharedList`, `Records/Compartida/`) y que nadie vuelve a montar
//  `RecordsTabView` con llaves propias, que es como divergieron (sin chips rápidos ni buscador en Estadísticas).
//  Más la lógica de lo abierto al pasar al calendario en una ventana ancha, que ahora comparten las dos.
//

import Foundation
import SwiftUI
import Testing
@testable import Yala

@Suite("Registros y Estadísticas › Registros: la misma lista")
struct RegistrosEstadisticasIgualesTests {

    // MARK: - Fuentes

    private static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Yala.xcodeproj").path) { return url }
        }
        return url
    }()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios: documentar lo que el test cuenta no puede ponerlo en rojo.
    private static func code(_ path: String) throws -> String {
        try source(path)
            .components(separatedBy: "\n")
            .map { line -> String in
                guard let range = line.range(of: "//") else { return line }
                return String(line[..<range.lowerBound])
            }
            .joined(separator: "\n")
    }

    private static let shared = "Yala/App/Views/Records/Compartida/RecordsSharedList.swift"
    private static let standalone = "Yala/App/Views/Records/RecordsStandaloneView.swift"
    private static let stats = "Yala/App/Views/Statistics/DetailContainerView.swift"
    private static let tab = "Yala/App/Views/Statistics/RecordsTabView.swift"

    private static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    // MARK: - Una sola pieza

    @Test("Las dos pantallas montan la lista compartida")
    func bothHostsMountTheSharedList() throws {
        #expect(Self.occurrences(of: "RecordsSharedList(", in: try Self.code(Self.standalone)) == 1)
        #expect(Self.occurrences(of: "RecordsSharedList(", in: try Self.code(Self.stats)) == 1)
    }

    @Test("Nadie más que la pieza compartida monta RecordsTabView")
    func onlyTheSharedPieceMountsTheTab() throws {
        let views = Self.repoRoot.appendingPathComponent("Yala/App")
        let enumerator = FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil)
        var mounts: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let relative = url.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
            let text = try Self.code(relative)
            if text.contains("RecordsTabView(") { mounts.append(relative) }
        }
        #expect(mounts == [Self.shared], "Montan RecordsTabView fuera de la pieza compartida: \(mounts)")
    }

    @Test("La lista no tiene llaves que la hagan distinta en una pantalla")
    func theTabHasNoPerHostSwitches() throws {
        let text = try Self.code(Self.tab)
        #expect(!text.contains("showsQuickFilters"), "Los chips rápidos vuelven a depender de quién monta la lista.")
        #expect(text.contains("RecordsQuickFilterBar("))
    }

    @Test("El tinte de la pestaña Registros lo pone la pieza compartida")
    func tintIsSetByTheSharedPiece() throws {
        // Estadísticas pinta su pantalla en `.primary`.
        #expect(try Self.code(Self.shared).contains(".tint(theme.accentText)"))
    }

    @Test("La barra de arriba sale de la misma pieza en las dos pantallas")
    func bothHostsShareTheToolbar() throws {
        for host in [Self.standalone, Self.stats] {
            let text = try Self.code(host)
            let toolbar = text.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
            #expect(toolbar.contains("RecordsToolbarItems("), "\(host) no usa la barra compartida.")
            #expect(text.contains("accent: theme.accentText"), "\(host) no le pasa el tinte de Registros a la barra.")
            #expect(text.contains("RecordsSelectionToolbar(viewModel: recordsViewModel)"), "\(host) no usa la barra de selección compartida.")
            #expect(!text.contains("RecordsOverflowMenu("), "\(host) monta su propio menú «···».")
            #expect(!text.contains("RecordsSelectAllButton("), "\(host) monta su propio «Seleccionar todo».")
        }
    }

    @Test("Estadísticas decide su panel con la página, como Registros (calendario en ancho = una columna)")
    func statsPaneFollowsTheCalendarPage() throws {
        let text = try Self.code(Self.stats)
        #expect(text.contains("RecordsCalendarPageLogic.pageSizeClass(window: horizontalSizeClass, viewMode: recordsViewModel.recordsViewMode)"))
        #expect(text.contains("private var recordsOpensInPane: Bool { recordsPageSizeClass == .regular }"))
        #expect(text.contains("keepsCalendarAtReadableWidth: horizontalSizeClass == .regular"))
        #expect(try Self.code(Self.standalone).contains("keepsCalendarAtReadableWidth: horizontalSizeClass == .regular"))
    }

    // MARK: - Lo abierto al estrecharse la página

    @Test("Sin registro abierto no se hace nada")
    func nothingOpen_keeps() {
        #expect(RecordsOpenRecordOnNarrowing.action(window: .regular, page: .compact, hasOpenRecord: false) == .keep)
        #expect(RecordsOpenRecordOnNarrowing.action(window: .compact, page: .compact, hasOpenRecord: false) == .keep)
    }

    @Test("Página ancha: lo abierto sigue en su columna o panel")
    func widePage_keeps() {
        #expect(RecordsOpenRecordOnNarrowing.action(window: .regular, page: .regular, hasOpenRecord: true) == .keep)
    }

    @Test("Calendario en ventana ancha: lo abierto se cierra, sin hoja encima")
    func calendarInWideWindow_closes() {
        let page = RecordsCalendarPageLogic.pageSizeClass(window: .regular, viewMode: .calendar)
        #expect(page == .compact)
        #expect(RecordsOpenRecordOnNarrowing.action(window: .regular, page: page, hasOpenRecord: true) == .close)
    }

    @Test("La ventana se estrecha: lo abierto pasa a la hoja")
    func narrowWindow_movesToSheet() {
        #expect(RecordsOpenRecordOnNarrowing.action(window: .compact, page: .compact, hasOpenRecord: true) == .moveToSheet)
        #expect(RecordsOpenRecordOnNarrowing.action(window: nil, page: nil, hasOpenRecord: true) == .moveToSheet)
    }
}
