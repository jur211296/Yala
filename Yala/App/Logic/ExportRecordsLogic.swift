//
//  ExportRecordsLogic.swift
//  Yala
//
//  Decisiones de Jürgen sobre el lote 20 de la auditoría UX 2.2 (Exportar y Vaciar), 2026-10-18. Lógica PURA de la
//  pantalla «Llévate tus registros» (L20-1/L20-2), del aviso tras compartir (L20-3/L19-16), del nombre del archivo
//  (L20-4) y de la fila y la frase de «Vaciar datos» (L20-5). Sin SwiftData ni UI: la vista mapea cada token a su texto.
//

import Foundation

nonisolated enum ExportRecordsLogic {

    // MARK: - L20-1 · El período en fichas

    /// Las cuatro fichas de la variante elegida (L20-1-A): «Todo», «Este año», «Este mes» y «Fechas…».
    enum PeriodChoice: String, CaseIterable, Equatable {
        case all, thisYear, thisMonth, dates

        /// El período del asistente de siempre que corresponde a la ficha.
        var detailPeriod: DetailPeriod {
            switch self {
            case .all: return .allTime
            case .thisYear: return .thisYear
            case .thisMonth: return .thisMonth
            case .dates: return .custom
            }
        }
    }

    // MARK: - L20-2 · Los filtros activos, a la vista

    /// Un filtro que de verdad recorta lo que sale. El orden es el de las filas de «Más opciones».
    enum ActiveFilter: Equatable {
        case accounts(Int)
        case categories(Int)
        case tags(Int)
        case needs(Int)
        case currencies([String])
        case amount
        case note(String)
        /// «Ocultar»: lo elegido arriba se quita en vez de quedarse.
        case hidingSelected
    }

    /// Qué filtros recortan algo. Un filtro con TODO elegido no recorta y no sale; tampoco la nota en blanco. El modo
    /// «Ocultar» sale siempre que esté puesto: cambia lo que significan los demás, y es el que se olvida (L20-2).
    static func activeFilters(
        markedAccounts: Int, offeredAccounts: Int,
        selectedSubcategories: Int, visibleSubcategories: Int,
        selectedTags: Int, allTags: Int,
        selectedNeeds: Int, allNeeds: Int,
        selectedCurrencies: [String], availableCurrencies: Int,
        amountIsActive: Bool,
        note: String,
        isExcludeMode: Bool
    ) -> [ActiveFilter] {
        var result: [ActiveFilter] = []
        if offeredAccounts > 0, markedAccounts < offeredAccounts { result.append(.accounts(markedAccounts)) }
        if selectedSubcategories > 0, selectedSubcategories < visibleSubcategories {
            result.append(.categories(selectedSubcategories))
        }
        if selectedTags > 0, selectedTags < allTags { result.append(.tags(selectedTags)) }
        if selectedNeeds < allNeeds { result.append(.needs(selectedNeeds)) }
        if !selectedCurrencies.isEmpty, selectedCurrencies.count < availableCurrencies {
            result.append(.currencies(selectedCurrencies.sorted()))
        }
        if amountIsActive { result.append(.amount) }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { result.append(.note(trimmed)) }
        if isExcludeMode { result.append(.hidingSelected) }
        return result
    }

    /// La moneda del monto en Exportar: la única que queda a la vista, con la regla de Registros › Filtros
    /// (`RecordsAmountFilterCurrencyLogic`). El asistente tiene UN modo para todo: en «Ocultar» las monedas marcadas son
    /// las que desaparecen. Hasta el 2026-10-28 el campo se etiquetaba con la marcada también en «Ocultar», la moneda
    /// oculta (ticket `export-wizard-amount-filter-in-hidden-currency`). Una marcada que no está entre las disponibles no
    /// cuenta: el asistente arranca con todas marcadas.
    static func amountCurrency(
        marked: Set<CurrencyCode>,
        available: [CurrencyCode],
        isExcludeMode: Bool
    ) -> CurrencyCode? {
        let marked = marked.intersection(available)
        return RecordsAmountFilterCurrencyLogic.currency(
            included: isExcludeMode ? [] : marked,
            excluded: isExcludeMode ? marked : [],
            available: available
        )
    }

    /// El monto que se aplica: sin una sola moneda a la vista, ninguno. La sección dice que no se puede usar, y un monto
    /// escrito con una moneda que sigue puesto al marcar otra compararía cada registro en su propia moneda.
    static func effectiveAmount(_ condition: AmountFilterCondition, currency: CurrencyCode?) -> AmountFilterCondition {
        currency == nil ? .any : condition
    }

    /// La línea sobre el botón: cuántos registros saldrán, o que no sale ninguno.
    enum CountLine: Equatable {
        /// Aún contando (al abrir, o tras cambiar un filtro): sin cifra, y el botón dice solo «Exportar».
        case counting
        case none
        case some(Int)
    }

    static func countLine(for count: Int?) -> CountLine {
        guard let count else { return .counting }
        return count == 0 ? .none : .some(count)
    }

    /// ¿Se puede tocar «Exportar»? Con la cifra en cero no: el archivo saldría vacío, que es lo que L20-2 evita.
    static func canExport(count: Int?, hasAccountSelected: Bool, amountIsValid: Bool, hasColumns: Bool) -> Bool {
        guard hasAccountSelected, amountIsValid, hasColumns else { return false }
        if let count { return count > 0 }
        return false
    }

    /// ¿El período termina hoy? Con «Todo», «Este año» y «Este mes» la frase dice «a hoy»; con fechas elegidas, la
    /// última fecha. Se compara por día del calendario: el fin efectivo de un período en curso es hoy a las 23:59:59.
    static func endsToday(_ interval: DateInterval, now: Date, calendar: Calendar) -> Bool {
        calendar.isDate(interval.end, inSameDayAs: now)
    }

    // MARK: - L20-3 · Lo que pasó al compartir

    enum ShareOutcome: Equatable {
        /// Se cerró la hoja sin compartir: no se enseña nada (L20-3 B, sin «completada»).
        case cancelled
        /// Se compartió con una app que sabemos nombrar.
        case sharedTo(KnownDestination)
        /// Se compartió, pero iOS no dice con qué app de forma que podamos nombrarla.
        case sharedSomewhere
    }

    /// Las apps que el aviso nombra. Las de Apple van traducidas (Archivos, Mensajes, Notas); las demás son marcas.
    enum KnownDestination: Equatable {
        case files, mail, messages, notes
        case brand(String)
    }

    /// Lo que devolvió `UIActivityViewController`: si se completó y con qué actividad (`activityType.rawValue`).
    /// iOS no da el nombre de la app, solo el identificador de la actividad (o de la extensión de compartir de la app),
    /// y por eso se reconocen por prefijo. AirDrop y copiar no son un sitio donde «está» el archivo: frase genérica.
    static func shareOutcome(completed: Bool, activityType: String?) -> ShareOutcome {
        guard completed else { return .cancelled }
        guard let raw = activityType?.lowercased(), !raw.isEmpty else { return .sharedSomewhere }
        if raw.contains("documentmanager") || raw.contains("savetofiles") || raw.contains("com.apple.filesapp") {
            return .sharedTo(.files)
        }
        if raw == "com.apple.uikit.activity.mail" || raw.hasPrefix("com.apple.mobilemail") { return .sharedTo(.mail) }
        if raw == "com.apple.uikit.activity.message" || raw.hasPrefix("com.apple.mobilesms") {
            return .sharedTo(.messages)
        }
        if raw.hasPrefix("com.apple.mobilenotes") { return .sharedTo(.notes) }
        for (prefix, name) in brandPrefixes where raw.hasPrefix(prefix) { return .sharedTo(.brand(name)) }
        return .sharedSomewhere
    }

    /// Extensiones de compartir de apps conocidas, por el prefijo de su identificador. El nombre es la marca y no se
    /// traduce. Orden: de lo más concreto a lo más general (Gmail antes que Drive, que comparten `com.google`).
    private static let brandPrefixes: [(String, String)] = [
        ("net.whatsapp", "WhatsApp"),
        ("ph.telegra", "Telegram"),
        ("com.google.gmail", "Gmail"),
        ("com.google.drive", "Google Drive"),
        ("com.google.sheets", "Google Sheets"),
        ("com.microsoft.office.outlook", "Outlook"),
        ("com.microsoft.office.excel", "Excel"),
        ("com.microsoft.skydrive", "OneDrive"),
        ("com.apple.iwork.numbers", "Numbers"),
        ("com.getdropbox", "Dropbox"),
        ("com.tinyspeck", "Slack"),
    ]

    // MARK: - L20-4 · El nombre del archivo

    /// `Yala_Registros_17-oct-2026.xlsx`: la palabra y la fecha en el idioma de la app. La fecha sale del formato corto
    /// del idioma (`d MMM y`) sin lo que un nombre de archivo lleva mal: puntos, comas, barras y espacios.
    static func fileName(stem: String, date: Date, locale: Locale, fileExtension: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMy")
        let readable = sanitizedForFileName(formatter.string(from: date))
        let safeStem = sanitizedForFileName(stem)
        return "Yala_\(safeStem)_\(readable).\(fileExtension)"
    }

    static func sanitizedForFileName(_ text: String) -> String {
        let separators = CharacterSet(charactersIn: " /\\:.,\u{00A0}\u{202F}")
        let parts = text.components(separatedBy: separators).filter { !$0.isEmpty }
        return parts.joined(separator: "-")
    }

    // MARK: - L20-5 · Vaciar datos

    /// El subtítulo de la fila, según lo que haya: promete conservar la cuenta solo a quien tiene una, y los grupos
    /// solo a quien tiene alguno.
    enum WipeRowKeeps: Equatable { case accountAndGroups, account, groups, nothing }

    static func wipeRowKeeps(hasYalaAccount: Bool, hasGroups: Bool) -> WipeRowKeeps {
        switch (hasYalaAccount, hasGroups) {
        case (true, true): return .accountAndGroups
        case (true, false): return .account
        case (false, true): return .groups
        case (false, false): return .nothing
        }
    }

    /// La frase de la pantalla: dónde borra. Sale de la MISMA operación que la hoja y el borrado
    /// (`DestructiveScopeLogic.wipeDescription`), y de dónde vive lo personal, como la fila ☁️ de la hoja.
    enum WipeSentence: Equatable { case deviceAndICloud, deviceAndCloudAccount, profileOnly }

    static func wipeSentence(for operation: DestructiveScopeLogic.Operation,
                             cloudLabel: DestructiveScopeLogic.CloudLabel) -> WipeSentence {
        switch DestructiveScopeLogic.wipeDescription(for: operation) {
        case .profileAndPreferences:
            return .profileOnly
        case .wholePersonalData, nil:
            return cloudLabel == .cloudAccount ? .deviceAndCloudAccount : .deviceAndICloud
        }
    }

    /// «Exportar una copia antes» solo donde hay registros que copiar: la completa. En solo grupos se borran el perfil y
    /// las preferencias, y los grupos no se tocan.
    static func offersExportCopy(for operation: DestructiveScopeLogic.Operation) -> Bool {
        DestructiveScopeLogic.wipeDescription(for: operation) == .wholePersonalData
    }
}
