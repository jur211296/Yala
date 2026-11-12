//
//  TopPrimaryActionRevealLogicTests.swift
//  YalaTests
//
//  Cards 2m2r y hsqm (encargo fluidez-extra, 2026-11-02). El «+» flotante de Grupos, Presupuestos, Pagos y Estadísticas
//  lo enciende `revealsFloatingActionWhenScrolledAway` cuando el botón de arriba deja de verse. Dos avisos del sistema
//  no hablan del scroll y se ignoran: los de la página oculta (otra pestaña delante) y el primer «no visible» al
//  montarse, antes de haber visto nunca el botón. Medido en vídeo: el primero hacía asomar el «+» al volver a la
//  pestaña; el segundo, además, animaba el reajuste del scroll y la primera entrada pintaba el contenido 44 pt abajo.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("El «+» flotante ignora la página oculta y el primer aviso al montarse")
struct TopPrimaryActionRevealLogicTests {

    private func floating(visible: Bool, shown: Bool, seen: Bool) -> Bool? {
        TopPrimaryActionRevealLogic.floatingAfterVisibilityChange(
            topActionVisible: visible, isPageShown: shown, hasSeenTopAction: seen)
    }

    @Test func withThePageShownAndTheButtonSeen_theScrollDecides() {
        #expect(floating(visible: false, shown: true, seen: true) == true, "Bajar se lleva el botón: sale el «+».")
        #expect(floating(visible: true, shown: true, seen: true) == false, "El botón vuelve: el «+» se va.")
    }

    /// Punto 1: con otra pestaña delante el botón cuenta como «no visible» por la pestaña. Ni enciende ni apaga.
    @Test func withThePageHidden_nothingChanges() {
        for visible in [false, true] {
            for seen in [false, true] {
                #expect(floating(visible: visible, shown: false, seen: seen) == nil)
            }
        }
    }

    /// Punto 2: el primer «no visible» llega antes de que el scroll tenga su sitio, con el botón en pantalla.
    @Test func theFirstNotVisible_beforeEverSeeingTheButton_isIgnored() {
        #expect(floating(visible: false, shown: true, seen: false) == nil)
    }

    /// Y el primer «visible» sí cuenta: apaga un «+» que hubiera quedado encendido.
    @Test func theFirstVisible_countsEvenBeforeSeeingTheButton() {
        #expect(floating(visible: true, shown: true, seen: false) == false)
    }

    /// El primer «no visible» no se tira: queda en suspenso, por si el botón nació fuera de pantalla (iPhone girado
    /// con texto grande). Solo ese: ni con la página oculta, ni con el botón visto, ni con un «visible».
    @Test func onlyTheFirstNotVisible_awaitsConfirmation() {
        #expect(TopPrimaryActionRevealLogic.awaitsConfirmation(
            topActionVisible: false, isPageShown: true, hasSeenTopAction: false))
        #expect(!TopPrimaryActionRevealLogic.awaitsConfirmation(
            topActionVisible: false, isPageShown: false, hasSeenTopAction: false))
        #expect(!TopPrimaryActionRevealLogic.awaitsConfirmation(
            topActionVisible: false, isPageShown: true, hasSeenTopAction: true))
        #expect(!TopPrimaryActionRevealLogic.awaitsConfirmation(
            topActionVisible: true, isPageShown: true, hasSeenTopAction: false))
    }

    /// El falso del montaje se desmiente en ~0,2 s (medido en vídeo): la espera tiene que pasar de eso sin hacer
    /// esperar de más al «+» de un botón nacido fuera.
    @Test func theConfirmationOutlastsTheMountingFalseAlarm() {
        #expect(TopPrimaryActionRevealLogic.firstHiddenConfirmation > .milliseconds(250))
        #expect(TopPrimaryActionRevealLogic.firstHiddenConfirmation <= .seconds(1))
    }
}

@MainActor
@Suite("La raíz dice qué página se ve de verdad")
struct RootDisplayedTabTests {
    private func displayed(_ selected: AppTab, _ mounted: [ConfigurableTab],
                           more: Bool = true, search: Bool = true) -> AppTab {
        RootTabLayoutLogic.displayedTab(selected: selected, mounted: mounted, showsMore: more, showsSearch: search)
    }

    @Test func theSelectedPage_whenItIsMounted() {
        #expect(displayed(.planning, [.panel, .statistics, .planning]) == .planning)
        #expect(displayed(.more, [.panel]) == .more)
        #expect(displayed(.search, [.panel]) == .search)
    }

    /// La shell de solo grupos monta solo Grupos y la selección puede quedarse en Panel: se ve Grupos.
    @Test func groupsOnlyShell_withTheSelectionLeftOnPanel_showsGroups() {
        #expect(displayed(.panel, [.groups]) == .groups)
    }

    @Test func aSystemTabThatIsNotThere_fallsToTheFirstPage() {
        #expect(displayed(.search, [.groups], search: false) == .groups)
        #expect(displayed(.more, [.panel, .groups], more: false) == .panel)
    }
}

@Suite("Primera entrada a Grupos sin fundido")
struct GroupsFirstLoadLogicTests {
    /// Solo la carga que llega en el mismo `onAppear` se libra del fundido de C7: la que llega después, o una recarga,
    /// no.
    @Test func onlyTheLoadThatArrivesOnAppearSkipsTheFade() {
        #expect(GroupsFirstLoadLogic.arrivedWithoutWaiting(hadLoadedBefore: false, hasLoadedNow: true))
        #expect(!GroupsFirstLoadLogic.arrivedWithoutWaiting(hadLoadedBefore: false, hasLoadedNow: false),
                "El arranque aún no configuró el contexto: la carga llegará después y se fundirá.")
        #expect(!GroupsFirstLoadLogic.arrivedWithoutWaiting(hadLoadedBefore: true, hasLoadedNow: true))
    }
}

@Suite("El «+» flotante y la primera entrada a Grupos — cableado (source-scan)")
struct TopPrimaryActionRevealWiringTests {

    private static func source(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// El código sin comentarios, en una línea por sentencia recortada, para que documentar no cuente como usar.
    private static func code(_ relativePath: String) throws -> String {
        try source(relativePath).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cada página de la raíz dice si es la elegida: las de la configuración, Más y Buscar.
    @Test func theRootTellsEachPageWhetherItIsShown() throws {
        let code = try Self.code("Yala/App/ContentView.swift")
        #expect(code.contains("""
            viewForTab(tab)
            .environment(\\.isRootPageShown, displayedTab == tab.appTab)
            """), "Las páginas de la configuración no reciben si son la que se ve.")
        #expect(code.contains("""
            MoreView()
            .environment(\\.isRootPageShown, displayedTab == .more)
            """), "Más no recibe si es la que se ve.")
        #expect(code.contains("""
            GlobalSearchView()
            .environment(\\.isRootPageShown, displayedTab == .search)
            """), "Buscar no recibe si es la que se ve.")
        // La que se ve, no la seleccionada: en la shell de solo grupos la selección se queda en Panel.
        #expect(code.contains("""
            RootTabLayoutLogic.displayedTab(
            selected: navigation.selectedMainTab,
            mounted: mountedTabs,
            """))
    }

    /// El modificador pasa a la lógica lo que lee del entorno y el pestillo, y enciende el pestillo solo con el botón a
    /// la vista en la página elegida.
    @Test func theModifierFeedsTheLogic() throws {
        let code = try Self.code("Yala/App/Views/Shared/TopPrimaryAction.swift")
        #expect(code.contains("@Environment(\\.isRootPageShown) private var isRootPageShown"))
        #expect(code.contains("@State private var hasSeenTopAction = false"))
        #expect(code.contains("""
            topActionVisible: visible, isPageShown: isRootPageShown, hasSeenTopAction: hasSeenTopAction)
            """), "El modificador no pasa la página elegida o el pestillo a la lógica.")
        #expect(code.contains("if visible && isRootPageShown { hasSeenTopAction = true }"))
        #expect(code.contains("firstHiddenConfirmation = awaits ? confirmFirstHidden() : nil"),
                "El primer «no visible» ya no queda en suspenso: un botón nacido fuera de pantalla no sacaría el «+».")
        #expect(!code.contains("TopPrimaryActionRevealLogic.showsFloating(topActionVisible: visible)"),
                "El modificador volvió a decidir solo por la visibilidad.")
    }

    /// La carga que llega en el `onAppear` de Grupos apaga solo el fundido de C7, no las animaciones de lo que su
    /// `onChange` presente (la hoja de invitar, el grupo pendiente): nada de transacciones sin animación.
    @Test func groupsFirstLoadSkipsOnlyTheLoadFade() throws {
        let code = try Self.code("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(code.contains("""
            let hadLoaded = viewModel.hasLoadedOnce
            viewModel.setContext(modelContext)
            if GroupsFirstLoadLogic.arrivedWithoutWaiting(
            hadLoadedBefore: hadLoaded, hasLoadedNow: viewModel.hasLoadedOnce) {
            firstLoadArrivedOnAppear = true
            }
            """), "La carga del onAppear de Grupos ya no marca que llegó sin esperar.")
        #expect(code.contains(
            ".animation(reduceMotion || firstLoadArrivedOnAppear ? nil : DS.Animation.appear, value: viewModel.hasLoadedOnce)"))
        #expect(!code.contains("disablesAnimations"), "Una transacción sin animaciones viaja a los onChange de la carga.")
    }
}
