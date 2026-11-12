//
//  FluidezWiringTests.swift
//  YalaTests
//
//  Card pjum (2026-10-31), pasada de fluidez: source-scan de las piezas del sistema común que un cambio inocente
//  desharía sin que ningún test de comportamiento lo note. Que animen de verdad se vio en vídeo (capturas del PR).
//

import Foundation
import Testing

@Suite("Fluidez — chips, cifras y hápticos (source-scan)")
struct FluidezWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    private static func code(_ relativePath: String) throws -> [String] {
        try source(relativePath).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
    }

    static let stagedScreens = [
        "Yala/App/Views/Groups/GroupDetailView.swift",
        "Yala/App/Views/Statistics/DetailContainerView.swift",
    ]

    /// El detalle de grupo y Estadísticas montan sus páginas con `StagedTabPages`: con un `switch` de la pestaña
    /// elegida, la página nueva se montaba al terminar la animación del chip y llegaba de golpe después.
    @Test(arguments: stagedScreens)
    func chipScreens_mountTheirPagesStaged(_ path: String) throws {
        let lines = try Self.code(path)
        #expect(lines.contains("StagedTabPages(selection: $pages) { tab in"), "\(path) ya no monta con StagedTabPages.")
        #expect(!lines.contains { $0.contains("chipsSelection") },
                "\(path) vuelve a pintar el chip por delante de la página.")
    }

    @Test func theTwoStepSwitch_isGone() throws {
        let lines = try Self.code("Yala/App/DesignSystem/NavigationChipsBar.swift")
        #expect(!lines.contains { $0.contains("func switchTab") },
                "Vuelve el cambio en dos tiempos (chip primero, página al terminar) que Jürgen vio desfasado.")
    }

    /// Una vez por gesto: el chip vibra al cambiar, y la fila de Registros en modo selección vibra solo por su marca.
    @Test func chip_vibratesOnChange() throws {
        let lines = try Self.code("Yala/App/DesignSystem/NavigationChipsBar.swift")
        #expect(lines.contains("if !isSelected { DS.Haptic.selection() }"))
    }

    @Test func recordRow_vibratesOncePerToggle() throws {
        let lines = try Self.code("Yala/App/Views/Records/Components/RecordRowView.swift")
        let explicit = lines.filter { $0.contains("DS.Haptic.selection()") }.count
        let declarative = lines.filter { $0.contains(".sensoryFeedback(.selection, trigger: isSelected)") }.count
        #expect(explicit + declarative == 1, "La fila vuelve a vibrar dos veces por toque.")
    }

    /// La cifra rueda solo con ella ya a la vista: el primer cálculo de una página recién montada llega quieto (si no,
    /// Distribución rodaba de 0 a su saldo al abrirse).
    @Test func amountRoll_waitsUntilTheFigureIsSettled() throws {
        let lines = try Self.code("Yala/App/Views/Shared/AmountText.swift")
        #expect(lines.contains(".modifier(AmountRollModifier(isEnabled: animatesValue, value: value))"),
                "El cuerpo de AmountText ya no aplica el modificador que hace rodar la cifra.")
        #expect(lines.contains("try await Task.sleep(for: Self.settleDelay)"))
        #expect(lines.contains("settled = true"), "Sin quien lo encienda, la cifra no rueda nunca.")
        #expect(lines.contains(".contentTransition(settled ? .numericText(value: value) : .identity)"))
        #expect(lines.contains(".dsAnimation(settled ? DS.Animation.number : nil, value: value, reduceMotion: reduceMotion)"))
    }

    /// (fichero, cuántas cifras ruedan en él).
    static let rollingHeroes: [(path: String, count: Int)] = [
        ("Yala/App/Views/Panel/HeroMonthView.swift", 2),
        ("Yala/App/Views/Groups/GroupBalanceHero.swift", 1),
        ("Yala/App/Views/Statistics/CategoriesTabView.swift", 1),
        ("Yala/App/Views/Statistics/TrendsTabView.swift", 1),
        ("Yala/App/Views/Statistics/InsightsTabView.swift", 1),
        ("Yala/App/Views/Statistics/RecordsTabView.swift", 3),
        ("Yala/App/Views/Planning/ScheduledPaymentsListView.swift", 1),
    ]

    @Test(arguments: rollingHeroes.indices)
    func heroes_rollTheirFigure(_ index: Int) throws {
        let (path, count) = Self.rollingHeroes[index]
        let lines = try Self.code(path)
        #expect(lines.filter { $0.contains("animatesValue: true") }.count == count,
                "\(path) ya no hace rodar sus \(count) cifras.")
    }

    /// «Guardar los N» del chat vibra una vez, no una por borrador.
    @Test func chatSaveAll_vibratesOnce() throws {
        let lines = try Self.code("Yala/App/ViewModels/ChatAssistantViewModel.swift")
        #expect(lines.contains("await saveDraft(messageID: messageID, draftID: draft.id, vibrates: false)"))
        #expect(lines.contains("if vibrates { DS.Haptic.success() }"))
    }

    /// La red de `StagedTabSelection.select`: si el `onAppear` de la página no vuelve a llegar, se enseña igual.
    @Test func stagedSelect_hasARevealFallback() throws {
        let lines = try Self.code("Yala/App/DesignSystem/StagedTabPages.swift")
        #expect(lines.contains("DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealFallbackDelay) {"))
    }
}
