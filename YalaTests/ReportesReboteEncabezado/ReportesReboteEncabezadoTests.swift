//
//  ReportesReboteEncabezadoTests.swift
//  YalaTests
//
//  El rebote de la parte de arriba de Reportes (vídeo de Jürgen del 23-nov-2026, iPhone): con la barra «Comparativa /
//  Flujo de caja» colgada bajo la barra de navegación (`safeAreaBar`), su sitio dependía de si el título estaba grande o
//  compacto, y al moverse cambiaba el área segura del scroll, que es lo que decide el título. Sostenido el dedo en ese
//  umbral, el título, los chips y la lista saltaban 52 pt una y otra vez. Ahora la barra es una cabecera fija DENTRO de
//  cada scroll (`ReportChipsHeaderStack`), como el contenido del Panel, que no rebota.
//
//  El bucle no sale en el simulador con toques sintéticos (medido el 24-nov con XCUITest y Device MCP: el título se
//  pliega y se queda quieto), así que se fija el cableado, leído del código: ninguna barra de pantalla vuelve, cada
//  scroll de Reportes monta la cabecera, y la cabecera tapa lo que pasa por detrás.
//

import Foundation
import Testing

@Suite
struct ReportesReboteEncabezadoTests {

    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El código sin comentarios, con los espacios colapsados.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n")
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("//") ? "" : trimmed
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let reportView = "Yala/App/Views/Reports/FinancialReportView.swift"
    private static let cashFlowTable = "Yala/App/Views/Reports/CashFlow/CashFlowTableView.swift"
    private static let cashFlowSetup = "Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift"

    /// Ni `safeAreaBar` ni `safeAreaInset` arriba: las dos dejan la barra de chips colgada de la barra de navegación.
    @Test func laBarraDeChips_noCuelgaDeLaPantalla() throws {
        let code = Self.codeOnly(try Self.repoFile(Self.reportView))
        #expect(!code.contains(".safeAreaBar(edge: .top)"))
        #expect(!code.contains(".safeAreaInset(edge: .top)"))
        #expect(!code.contains(".navigationChipsInset"))
        // La barra llega a las pestañas por el entorno, y solo con más de una pestaña visible.
        #expect(code.contains("NavigationStack { tabContentWithChips .yalaScreenBackground()"))
        #expect(code.contains("tabContent .environment(\\.reportChipsHeader, chipsHeader)"))
        #expect(code.contains("guard visibleReportTabs.count > 1 else { return nil }"))
    }

    /// Cada scroll de Reportes monta la cabecera: la Comparativa, el vacío del Flujo de caja, el armado del plan y la
    /// tabla del plan. Uno que no la monte se queda sin chips.
    @Test func cadaScrollDeReportes_montaLaCabecera() throws {
        let report = Self.codeOnly(try Self.repoFile(Self.reportView))
        #expect(report.contains(
            "ScrollView(.vertical, showsIndicators: false) { ReportChipsHeaderStack(horizontalBleed: DS.Spacing.lg) { "
                + "VStack(spacing: DS.Spacing.xl) {"
        ))
        #expect(report.contains(
            "ScrollView { ReportChipsHeaderStack { emptyState(message: L10n.Report.cashFlowNoDataDescription)"
        ))

        let table = Self.codeOnly(try Self.repoFile(Self.cashFlowTable))
        #expect(table.contains(
            "ScrollView(.vertical, showsIndicators: false) { ReportChipsHeaderStack { if let projection = viewModel.projection {"
        ))

        let setup = Self.codeOnly(try Self.repoFile(Self.cashFlowSetup))
        #expect(setup.contains(
            "ScrollView(.vertical, showsIndicators: false) { ReportChipsHeaderStack { "
                + "VStack(alignment: .leading, spacing: DS.Spacing.xl) {"
        ))

        // Tantos scrolls verticales como cabeceras en cada fichero (la tira de meses es horizontal y vive aparte).
        for (path, code) in [(Self.reportView, report), (Self.cashFlowTable, table), (Self.cashFlowSetup, setup)] {
            let scrolls = code.components(separatedBy: "ScrollView(.vertical").count - 1
                + code.components(separatedBy: "ScrollView {").count - 1
            let headers = code.components(separatedBy: "{ ReportChipsHeaderStack").count - 1
            #expect(scrolls == headers, "\(path): hay un scroll vertical sin la cabecera de chips.")
        }
    }

    /// La cabecera es fija y tapa: sección con cabecera fija, el fondo de la pantalla desde arriba del todo y, debajo, el
    /// del sistema (el degradado claro acaba en un índigo al 10 %, y sin él las filas se leían a través).
    @Test func laCabecera_esFija_yTapaLoQuePasaPorDetras() throws {
        let code = Self.codeOnly(try Self.repoFile(Self.reportView))
        #expect(code.contains(
            "LazyVStack(spacing: DS.Spacing.none, pinnedViews: [.sectionHeaders]) { Section { content } header: {"
        ))
        #expect(code.contains(".background { ReportChipsHeaderBackground(pageHeight: header.pageHeight) }"))
        #expect(code.contains("PanelBackgroundView(ignoredEdges: []) .background(Color(uiColor: .systemBackground))"))
        // Del borde de arriba de la página al de abajo de la cabecera: tapa también lo que sube por encima de los chips.
        #expect(code.contains(
            ".frame(width: frame.width, height: max(frame.maxY, 0), alignment: .top) .clipped() .offset(y: -frame.minY)"
        ))
        #expect(code.contains(".allowsHitTesting(false)"))
    }

    /// Los márgenes laterales del scroll de la Comparativa no los hereda la barra, que pone los suyos: con ellos, los
    /// chips quedarían 16 pt más adentro que en el Flujo de caja.
    @Test func laBarra_noHeredaLosMargenesDelScroll() throws {
        let code = Self.codeOnly(try Self.repoFile(Self.reportView))
        #expect(code.contains("header.bar .padding(.horizontal, -horizontalBleed)"))
        #expect(code.contains(".scrollViewGlassEdges()"))
    }
}
