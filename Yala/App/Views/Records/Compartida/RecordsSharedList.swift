//
//  RecordsSharedList.swift
//  Yala
//
//  La lista de Registros, UNA para las dos pantallas que la enseñan: la pestaña Registros (`RecordsStandaloneView`) y
//  Estadísticas › Registros (`DetailContainerView`). Decisión de Jürgen del 17-nov: la de Estadísticas es idéntica a la
//  de Registros —mismos filtros, buscador, filas, agrupación, lista/calendario, selección y menús—, con el período de
//  Estadísticas como filtro de partida (el período es de la sesión: `RecordsViewModel.period`).
//
//  Hasta ese día las dos montaban `RecordsTabView` cada una con sus llaves, y Estadísticas iba sin los chips rápidos
//  (decisión 15 de 2.3, F2), sin «Buscar en Registros» (decisión 14) y con el calendario apretado en la columna del iPad
//  (decisión 66). Aquí no hay llaves: lo que una pantalla tenga, lo tiene la otra. Lo único que cada anfitrión decide es
//  cómo se monta la página a su alrededor (columna de detalle, panel, barra de arriba).
//

import SwiftUI

// MARK: - La lista

struct RecordsSharedList: View {
    @Environment(\.yalaTheme) private var theme
    @Bindable var viewModel: RecordsViewModel
    let accounts: [Account]
    let categories: [Category]
    let tags: [Tag]
    let subcategories: [Subcategory]
    let transactionDateRange: (start: Date, end: Date)
    let defaultCurrencyCode: String
    /// Todos los movimientos y las recargas del contenedor: «Tu dinero hoy» del hero sale de ahí.
    let allTransactions: [TransactionItem]
    let dataGeneration: Int
    /// Un filtro cambió: el anfitrión recalcula lo que dependa de él.
    var onFilterChange: () -> Void
    var loadFailed: Bool
    var onRetryLoad: () -> Void
    /// La página va a una columna con la vista calendario (decisión 66 de 2.3): el calendario, a ancho legible.
    var keepsCalendarAtReadableWidth: Bool

    var body: some View {
        RecordsTabView(
            viewModel: viewModel,
            accounts: accounts,
            categories: categories,
            tags: tags,
            subcategories: subcategories,
            transactionDateRange: transactionDateRange,
            defaultCurrencyCode: defaultCurrencyCode,
            allTransactions: allTransactions,
            dataGeneration: dataGeneration,
            onFilterChange: onFilterChange,
            loadFailed: loadFailed,
            onRetryLoad: onRetryLoad,
            keepsCalendarAtReadableWidth: keepsCalendarAtReadableWidth
        )
        // El tinte de la pestaña Registros (el de la barra de pestañas, card 1c9w). Estadísticas pinta su pantalla con
        // `.tint(.primary)`, y sin esto el mes del calendario y lo tintado de la lista salían en negro solo allí.
        .tint(theme.accentText)
    }
}

// MARK: - La barra de arriba

/// «Seleccionar» a la vista y el menú «···» (Seleccionar · Filtros · Identificar duplicados). Cada anfitrión pone
/// después su avatar.
struct RecordsToolbarItems: ToolbarContent {
    let viewModel: RecordsViewModel
    /// El tinte de «Seleccionar» con solo ícono (columna del iPad): el de la pestaña Registros. Con texto va en primary,
    /// como todo botón de texto de la barra (`RecordsSelectToolbarButton`).
    let accent: Color
    /// En la columna de lista del iPad, «Seleccionar» va con su icono: con el texto, el título no cabía (decisión 67).
    var selectIconOnly = false

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            RecordsSelectToolbarButton(viewModel: viewModel, iconOnly: selectIconOnly)
                .tint(selectIconOnly ? accent : Color.primary)
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ToolbarItem(placement: .topBarTrailing) {
            RecordsOverflowMenu(viewModel: viewModel)
                .accessibilityIdentifier("records_overflow_menu")
        }
    }
}

/// La barra en modo selección: «Cancelar» y «Seleccionar todo».
struct RecordsSelectionToolbar: ToolbarContent {
    let viewModel: RecordsViewModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            YalaToolbarTextButton(L10n.Common.cancel) {
                viewModel.exitSelectionMode()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            RecordsSelectAllButton(viewModel: viewModel)
        }
    }
}

// MARK: - Lo abierto cuando la página se estrecha

/// Qué pasa con el registro abierto en la columna (Registros) o en el panel (Estadísticas) cuando la página deja de
/// ser ancha. Dos causas con salida distinta: la ventana se estrechó (lo abierto sigue a la vista, en hoja) o se eligió
/// la vista calendario en una ventana ancha (decisión 66: la página pasa a una columna y lo abierto se cierra, sin
/// sacar una hoja encima del calendario).
enum RecordsOpenRecordOnNarrowing: Equatable {
    case keep
    case close
    case moveToSheet

    static func action(
        window: UserInterfaceSizeClass?, page: UserInterfaceSizeClass?, hasOpenRecord: Bool
    ) -> RecordsOpenRecordOnNarrowing {
        guard hasOpenRecord, page != .regular else { return .keep }
        return window == .regular ? .close : .moveToSheet
    }
}
