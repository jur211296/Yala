//
//  TabImplicitAnimationsWiringTests.swift
//  YalaTests
//
//  Card 8atf (opción B de la card 1yhi, Jürgen, 2026-10-30): `ContentView` sigue apagando la animación de toda
//  transacción que cruza las pestañas —contra el parpadeo al cerrar hojas y en la pestaña temporal de Buscar—, y lo que
//  merece animarse dentro de una pestaña lo hace con una animación implícita `.animation(_:value:)`, que actúa por
//  debajo del apagado. Un `withAnimation` ahí no anima nada (regla «Animar dentro de una pestaña» de `swiftui-ds.md`).
//
//  Source-scan: que el apagado siga, y que cada sitio elegido anime con la variable que cambia. Que de verdad anime se
//  vio en vídeo en el simulador (capturas del PR).
//

import Foundation
import Testing

@Suite("Animaciones dentro de las pestañas — cableado (source-scan)")
struct TabImplicitAnimationsWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Las líneas de código, sin comentarios, para que documentar el patrón no cuente como usarlo.
    private static func codeLines(_ relativePath: String) throws -> [String] {
        try source(relativePath).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    @Test func contentView_keepsTheGlobalSwitchOnTheTabs() throws {
        let code = try Self.codeLines("Yala/App/ContentView.swift")
        let tabStyle = try #require(code.firstIndex(of: ".tabViewStyle(.sidebarAdaptable)"))
        let switchOff = try #require(code.firstIndex(of: ".transaction { $0.animation = nil }"),
                                     "Se quitó el apagado global de ContentView: la decisión 1yhi es mantenerlo.")
        #expect(switchOff > tabStyle && switchOff - tabStyle < 8, "El apagado tiene que colgar de la TabView.")
    }

    /// (fichero, la animación implícita que tiene que llevar). Cada una anima la variable que el toque cambia.
    static let animated: [(path: String, needle: String)] = [
        ("Yala/App/Views/Panel/PanelView.swift",
         ".animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: notices)"),
        ("Yala/App/Views/Panel/PanelView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingActions)"),
        ("Yala/App/Views/Panel/Components/PanelNoticeCarousel.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: current)"),
        ("Yala/App/Views/Groups/GroupsContainerView.swift",
         ".animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: showNudgeBanner)"),
        ("Yala/App/Views/Groups/GroupsContainerView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingActions)"),
        ("Yala/App/Views/Groups/GroupDetailView.swift",
         ".animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: showNudgeBanner)"),
        ("Yala/App/Views/Planning/BudgetsListView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingNew)"),
        ("Yala/App/Views/Planning/ScheduledPaymentsView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.normal), value: showFloatingNew)"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: incomeCollapsed)"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: expenseCollapsed)"),
        ("Yala/App/Views/Reports/CashFlow/CashFlowMonthStrip.swift",
         ".animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: selectedMonthKey)"),
    ]

    @Test(arguments: animated.indices)
    func eachChosenSite_animatesImplicitly(_ index: Int) throws {
        let (path, needle) = Self.animated[index]
        let code = try Self.codeLines(path)
        #expect(code.contains(needle), "\(path) ya no anima con «\(needle)».")
    }
}
