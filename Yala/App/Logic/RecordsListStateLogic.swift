//
//  RecordsListStateLogic.swift
//  Yala
//
//  Qué enseña la lista de Registros (y Estadísticas › Registros) según cómo fue la carga. Decisión 78 de la revisión 2.3
//  (9-nov): un fallo al leer los movimientos se veía como «Sin registros», y mientras cargaba no había nada en pantalla.
//

import Foundation

enum RecordsListState: Equatable {
    /// Aún no se ha filtrado nada: la lista no sabe si está vacía.
    case loading
    /// Leer los movimientos falló y no hay nada que enseñar: no es «Sin registros».
    case failed
    /// Cargó bien y, con lo elegido, no hay ningún registro.
    case empty
    case records
}

enum RecordsListStateLogic {
    /// Lo que se enseña. Un fallo solo manda si la lista se queda sin filas: con los movimientos de la carga anterior en
    /// memoria (el fallo fue al recargar), se siguen viendo.
    static func state(hasAppliedFilters: Bool, loadFailed: Bool, isEmpty: Bool) -> RecordsListState {
        if loadFailed && isEmpty { return .failed }
        if !hasAppliedFilters { return .loading }
        return isEmpty ? .empty : .records
    }

    /// Cuánto espera el indicador de carga antes de asomar. La primera pasada suele tardar menos que esto, y un
    /// indicador que aparece y se va en un fotograma es el destello que quitó la card C7.
    static let loadingIndicatorDelay: Duration = .milliseconds(400)
}

enum RecordRowAccessibilityDate {
    /// La fecha que VoiceOver lee al final de cada fila: con el mes en letras y el año, en el idioma de la app.
    static func text(_ date: Date, locale: Locale = AppLocale.current) -> String {
        date.formatted(.dateTime.day().month(.wide).year().locale(locale))
    }
}

/// La tarjeta que enseña Siri o Atajos tras apuntar un registro (decisión 76 de la revisión 2.3, 9-nov).
enum TransactionSnippetLogic {
    /// La cuenta que la tarjeta nombra, o `nil` para no pintar la fila. Desde Siri la cuenta aún no se conoce (la elige
    /// la app al revisar el borrador), y la fila decía «Cuenta: —».
    static func visibleAccountName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, trimmed != "—", trimmed != "-"
        else { return nil }
        return trimmed
    }

    /// La fecha con el mes en letras («12 de noviembre de 2026»): en números, «12/11/2026» se lee al revés según el país.
    static func dateText(_ date: Date, locale: Locale = AppLocale.current) -> String {
        date.formatted(.dateTime.day().month(.wide).year().locale(locale))
    }
}
