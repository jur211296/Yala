//
//  ListDetailSplit.swift
//  Yala
//
//  Lista y detalle: un único `NavigationSplitView` de dos columnas que en ventana ancha los pone a la vez y en
//  compacta se pliega solo a la pila de siempre (ADR «Yala se adapta por espacio, no por dispositivo»). Lo usan
//  Registros y Planificación. Lo que resuelve aquí, medido en el iPad el 2026-09-29 (`swiftui-ds.md`):
//
//  - la columna de lista con el ancho de un iPhone SE como mínimo (sin tope propio el split la deja en ~280-320 y
//    las filas se rompen);
//  - la visibilidad en manos del split (`@State`), para que pueda superponer la lista cuando no caben las dos
//    (iPad mini en vertical) y retirarla;
//  - al abrir algo con la lista superpuesta, la retira, para que se vea lo abierto.
//

import SwiftUI

/// Estado de un `ListDetailSplit`. Es un objeto, y no un closure en el entorno, para que su identidad no cambie
/// en cada render (un closure en `@Entry` invalida a todos los que lo leen en cada actualización).
@MainActor @Observable
final class ListDetailSplitState {
    var columnVisibility: NavigationSplitViewVisibility = .all
    @ObservationIgnored private var splitWidth: CGFloat = 0
    @ObservationIgnored fileprivate var detailWidth: CGFloat = 0

    /// Otra ventana (girar, redimensionar): la lista vuelve a la vista y el split decide de nuevo si cabe al lado
    /// o encima.
    fileprivate func splitWidthChanged(to newWidth: CGFloat) {
        if splitWidth > 0, abs(newWidth - splitWidth) > 1 { columnVisibility = .all }
        splitWidth = newWidth
    }

    /// El detalle enseña su vacío («Elige un…»): sin nada abierto, esconder la lista deja la pantalla sin salida.
    @ObservationIgnored fileprivate var detailIsEmpty = false

    fileprivate func emptyDetailAppeared() {
        detailIsEmpty = true
        keepListWhileDetailIsEmpty()
    }

    fileprivate func emptyDetailDisappeared() {
        detailIsEmpty = false
    }

    /// En una ventana donde la lista va superpuesta (iPad mini en vertical) el split arranca con ella retirada
    /// (medido). Con el detalle vacío eso deja solo «Elige un…»: la lista vuelve.
    fileprivate func keepListWhileDetailIsEmpty() {
        if detailIsEmpty, columnVisibility == .detailOnly { columnVisibility = .all }
    }

    /// Algo se acaba de abrir en el detalle: si la lista lo estaba tapando, se retira.
    func didShowDetail() {
        detailIsEmpty = false
        let covers = ListDetailOverlayLogic.listCoversDetail(
            splitWidth: splitWidth,
            detailWidth: detailWidth,
            listIsShown: columnVisibility != .detailOnly)
        if covers { columnVisibility = .detailOnly }
    }
}

extension EnvironmentValues {
    /// El split que contiene esta vista. Fuera de un `ListDetailSplit` es `nil`.
    @Entry var listDetailSplit: ListDetailSplitState? = nil
}

extension View {
    /// Marca el vacío de la columna de detalle («Elige un registro…»): mientras se vea, la lista no se esconde.
    func marksEmptyDetailColumn() -> some View {
        modifier(MarksEmptyDetailColumn())
    }

    /// Marca una vista como «lo abierto» de la columna de detalle: al aparecer, si la lista la estaba tapando, el
    /// split la retira. En iPhone (split plegado) no hay lista encima y no pasa nada.
    func announcesShownInDetailColumn() -> some View {
        modifier(AnnouncesShownInDetailColumn())
    }
}

private struct AnnouncesShownInDetailColumn: ViewModifier {
    @Environment(\.listDetailSplit) private var split

    func body(content: Content) -> some View {
        content.onAppear { split?.didShowDetail() }
    }
}

private struct MarksEmptyDetailColumn: ViewModifier {
    @Environment(\.listDetailSplit) private var split

    func body(content: Content) -> some View {
        content
            .onAppear { split?.emptyDetailAppeared() }
            .onDisappear { split?.emptyDetailDisappeared() }
    }
}

struct ListDetailSplit<ListColumn: View, DetailColumn: View>: View {
    private let preferredCompactColumn: Binding<NavigationSplitViewColumn>?
    private let list: ListColumn
    private let detail: DetailColumn

    @State private var state = ListDetailSplitState()

    /// `preferredCompactColumn`: qué columna se ve con el split plegado. `nil` deja la del sistema (la lista, y lo
    /// empujado encima).
    init(
        preferredCompactColumn: Binding<NavigationSplitViewColumn>? = nil,
        @ViewBuilder list: () -> ListColumn,
        @ViewBuilder detail: () -> DetailColumn
    ) {
        self.preferredCompactColumn = preferredCompactColumn
        self.list = list()
        self.detail = detail()
    }

    var body: some View {
        split
            .navigationSplitViewStyle(.balanced)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { state.splitWidthChanged(to: $0) }
            .onChange(of: state.columnVisibility) { _, _ in state.keepListWhileDetailIsEmpty() }
            .environment(\.listDetailSplit, state)
    }

    @ViewBuilder
    private var split: some View {
        if let preferredCompactColumn {
            NavigationSplitView(columnVisibility: $state.columnVisibility, preferredCompactColumn: preferredCompactColumn) {
                listColumn
            } detail: {
                detailColumn
            }
        } else {
            NavigationSplitView(columnVisibility: $state.columnVisibility) {
                listColumn
            } detail: {
                detailColumn
            }
        }
    }

    /// El ancho va DETRÁS de todo lo demás de la columna: con un `.toolbar(removing:)` detrás, el split lo ignora
    /// sin avisar (medido).
    private var listColumn: some View {
        list.navigationSplitViewColumnWidth(
            min: DS.Adaptive.listColumnMinWidth,
            ideal: DS.Adaptive.listColumnIdealWidth,
            max: DS.Adaptive.listColumnMaxWidth)
    }

    private var detailColumn: some View {
        detail
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { state.detailWidth = $0 }
    }
}
