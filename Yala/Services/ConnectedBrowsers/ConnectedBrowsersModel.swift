//
//  ConnectedBrowsersModel.swift
//  Yala
//
//  El estado de «Navegadores conectados»: cargar la lista, cerrar una y cerrar todas. Tras cada respuesta guarda si quedan
//  sesiones web (`ConnectedBrowsersPresence`), que es lo que decide si el iPhone pregunta por lo apuntado en la web.
//

import Foundation
import Observation

@MainActor
@Observable
final class ConnectedBrowsersModel {
    enum Phase: Equatable {
        case loading
        case loaded([WebSession])
        case failed
    }

    private(set) var phase: Phase = .loading
    /// El id que se está cerrando (`"*"` = todas). Mientras no es `nil`, los botones de cerrar están apagados.
    private(set) var closing: String?
    /// El último cierre falló: la pantalla lo dice encima de la lista.
    private(set) var closeFailed = false

    private let client: ConnectedBrowsersClient
    private let defaults: UserDefaults
    private let now: () -> Date

    init(client: ConnectedBrowsersClient, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.client = client
        self.defaults = defaults
        self.now = now
    }

    var sessions: [WebSession] {
        if case .loaded(let list) = phase { return list }
        return []
    }

    func load() async {
        if case .loaded = phase {} else { phase = .loading }
        do {
            let list = try await client.sessions()
            phase = .loaded(list)
            ConnectedBrowsersPresence.record(sessionCount: list.count, at: now(), defaults: defaults)
        } catch {
            #if DEBUG
            print("ConnectedBrowsersModel: Error: \(error)")
            #endif
            if case .loaded = phase { closeFailed = true } else { phase = .failed }
        }
    }

    func close(_ session: WebSession) async {
        await run(marker: session.id) { try await self.client.close(id: session.id) }
    }

    func closeAll() async {
        await run(marker: "*") { try await self.client.closeAll() }
    }

    private func run(marker: String, _ action: () async throws -> Void) async {
        guard closing == nil else { return }
        closing = marker
        closeFailed = false
        defer { closing = nil }
        do {
            try await action()
            DS.Haptic.success()
        } catch {
            #if DEBUG
            print("ConnectedBrowsersModel: Error: \(error)")
            #endif
            closeFailed = true
            DS.Haptic.error()
            return
        }
        await load()
    }
}

/// Los textos de la pantalla, con la misma resolución de idioma que `L10n` (variante → padre → main), sin tocar el
/// catálogo de accesores: las claves viven en los 16 `Localizable.strings` con el prefijo `connectedBrowsers.`.
@MainActor
enum ConnectedBrowsersText {
    static func text(_ key: String) -> String {
        let resolution = LanguageManager.resolved
        let missing = "__YALA_MISSING__"
        for bundle in [resolution.bundle, resolution.parentBundle, Bundle.main].compactMap({ $0 }) {
            let value = NSLocalizedString(key, bundle: bundle, value: missing, comment: "")
            if value != missing { return value }
        }
        return key
    }

    static var title: String { text("connectedBrowsers.title") }
    static var rowSubtitle: String { text("connectedBrowsers.rowSubtitle") }
    static var intro: String { text("connectedBrowsers.intro") }
    static var empty: String { text("connectedBrowsers.empty") }
    static var close: String { text("connectedBrowsers.close") }
    static var closeAll: String { text("connectedBrowsers.closeAll") }
    static var closeAllConfirmTitle: String { text("connectedBrowsers.closeAllConfirmTitle") }
    static var closeAllConfirmBody: String { text("connectedBrowsers.closeAllConfirmBody") }
    static var closeAllConfirm: String { text("connectedBrowsers.closeAllConfirm") }
    static var footer: String { text("connectedBrowsers.footer") }
    static var loadFailed: String { text("connectedBrowsers.loadFailed") }
    static var closeFailed: String { text("connectedBrowsers.closeFailed") }
    static var unknownBrowser: String { text("connectedBrowsers.unknownBrowser") }
    static var sharedComputer: String { text("connectedBrowsers.sharedComputer") }
    static var justNow: String { text("connectedBrowsers.justNow") }

    /// «Chrome en Mac». Sin sistema, solo el navegador; sin navegador, «Navegador».
    static func browserTitle(navegador: String, sistema: String) -> String {
        let browser = navegador.isEmpty ? unknownBrowser : navegador
        guard !sistema.isEmpty else { return browser }
        return String(format: text("connectedBrowsers.browserOn"), locale: LanguageManager.resolved.locale, browser, sistema)
    }

    /// «Lima · hace 3 días · equipo compartido».
    static func detailLine(_ s: WebSession, now: Date = .now) -> String {
        var parts: [String] = []
        if let city = s.ciudad, !city.isEmpty { parts.append(city) }
        parts.append(relative(s.ultimoUso, now: now))
        if s.equipoCompartido { parts.append(sharedComputer) }
        return parts.joined(separator: " · ")
    }

    static func relative(_ epochSeconds: Double, now: Date) -> String {
        let date = Date(timeIntervalSince1970: epochSeconds)
        if now.timeIntervalSince(date) < 120 { return justNow }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LanguageManager.resolved.locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
