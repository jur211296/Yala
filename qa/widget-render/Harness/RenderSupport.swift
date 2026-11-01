//
//  RenderSupport.swift
//  WidgetRender (banco de capturas de los widgets, no es parte de la app)
//
//  Lo que `prepare-sources.sh` pone en lugar de WidgetKit y del reloj, y el marco que imita una casilla de la
//  pantalla de inicio. Ver README.
//

import SwiftUI
import UIKit
import WidgetKit

// MARK: - Reloj fijo

/// El «ahora» de las vistas copiadas. Se fija a la hora de la foto para que antes y después se pinten con el mismo día
/// aunque se rendericen en fechas distintas.
enum RenderClock {
    nonisolated(unsafe) static var fixed: Date?
    static var now: Date { fixed ?? Foundation.Date() }
}

extension Calendar {
    func renderIsDateInToday(_ date: Date) -> Bool {
        isDate(date, inSameDayAs: RenderClock.now)
    }

    func renderIsDateInTomorrow(_ date: Date) -> Bool {
        guard let tomorrow = self.date(byAdding: .day, value: 1, to: startOfDay(for: RenderClock.now)) else { return false }
        return isDate(date, inSameDayAs: tomorrow)
    }

    func renderIsDateInYesterday(_ date: Date) -> Bool {
        guard let yesterday = self.date(byAdding: .day, value: -1, to: startOfDay(for: RenderClock.now)) else { return false }
        return isDate(date, inSameDayAs: yesterday)
    }
}

// MARK: - Entorno de WidgetKit

extension EnvironmentValues {
    /// Sustituye a `widgetFamily`, que fuera de WidgetKit es de solo lectura.
    @Entry var renderFamily: WidgetFamily = .systemSmall
    /// Sustituye a `widgetRenderingMode`.
    @Entry var renderRenderingMode: WidgetRenderingMode = .fullColor
    /// Sustituye a `showsWidgetContainerBackground` (StandBy lo pone en `false`).
    @Entry var renderShowsContainerBackground: Bool = true
}

/// Imitación de `AccessoryWidgetBackground()`, que fuera de la pantalla bloqueada no pinta nada.
struct RenderAccessoryBackground: View {
    var body: some View {
        Circle().fill(Color.white.opacity(0.18))
    }
}

// MARK: - Medidas

/// Medidas en puntos de cada tamaño. iPhone 17 Pro (402 × 874), medidas de la pantalla de inicio de iOS 26/27; el
/// extragrande de iPad es el del iPad Pro 11 en horizontal. Los márgenes son los del sistema (contentMargins).
struct FamilySpec {
    let code: String
    let family: WidgetFamily
    let size: CGSize
    let margins: CGFloat
    let cornerRadius: CGFloat
    var isAccessory: Bool { family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline }

    static let small = FamilySpec(code: "s", family: .systemSmall, size: CGSize(width: 164, height: 164), margins: 16, cornerRadius: 23)
    static let medium = FamilySpec(code: "m", family: .systemMedium, size: CGSize(width: 344, height: 164), margins: 16, cornerRadius: 23)
    static let large = FamilySpec(code: "l", family: .systemLarge, size: CGSize(width: 344, height: 364), margins: 16, cornerRadius: 23)
    static let extraLarge = FamilySpec(code: "xl", family: .systemExtraLarge, size: CGSize(width: 715, height: 330), margins: 16, cornerRadius: 23)
    static var extraLargePortrait: FamilySpec? {
        if #available(iOS 27.0, *) {
            return FamilySpec(code: "xlv", family: .systemExtraLargePortrait, size: CGSize(width: 344, height: 564), margins: 16, cornerRadius: 23)
        }
        return nil
    }
    static let circular = FamilySpec(code: "circ", family: .accessoryCircular, size: CGSize(width: 72, height: 72), margins: 0, cornerRadius: 36)
    static let rectangular = FamilySpec(code: "rect", family: .accessoryRectangular, size: CGSize(width: 172, height: 76), margins: 0, cornerRadius: 0)
    static let inline = FamilySpec(code: "inline", family: .accessoryInline, size: CGSize(width: 234, height: 26), margins: 0, cornerRadius: 0)
}

/// Cómo se ve el fondo de la casilla.
enum RenderBackground {
    /// El de las tarjetas de la app: blanco en claro, #1C1C1E en oscuro.
    case card
    /// Un relleno sólido propio (Entrada rápida).
    case fill(Color)
}

/// El modo en que se pinta una captura. `tintado` es una APROXIMACIÓN del modo tintado/transparente de iOS 18/26: el
/// sistema pinta el contenido en blanco conservando la opacidad (lo marcado con `widgetAccentable()` va en el color del
/// tinte, que aquí también sale blanco). Sirve para ver lo que se pierde (un icono blanco sobre un relleno opaco), no
/// para juzgar el tinte.
enum RenderMode: String, CaseIterable {
    case claro, oscuro, standby, tintado

    var colorScheme: ColorScheme { self == .claro ? .light : .dark }
}

// MARK: - Marco

/// Una casilla de la pantalla de inicio (o de la bloqueada) sobre un fondo de pantalla neutro.
struct RenderFrame<Content: View>: View {
    let spec: FamilySpec
    let background: RenderBackground
    let mode: RenderMode
    @ViewBuilder let content: Content

    static var canvasPadding: CGFloat { 14 }

    var body: some View {
        ZStack {
            wallpaper
            widget
                .padding(spec.margins)
                .frame(width: spec.size.width, height: spec.size.height)
                .background { cardBackground }
                .clipShape(RoundedRectangle(cornerRadius: spec.cornerRadius, style: .continuous))
                .environment(\.renderFamily, spec.family)
                .environment(\.renderShowsContainerBackground, mode != .standby && mode != .tintado)
        }
        .frame(width: spec.size.width + Self.canvasPadding * 2, height: spec.size.height + Self.canvasPadding * 2)
        .environment(\.colorScheme, spec.isAccessory ? .dark : mode.colorScheme)
    }

    @ViewBuilder
    private var widget: some View {
        if mode == .tintado {
            content
                .environment(\.renderRenderingMode, .accented)
                .compositingGroup()
                .brightness(1)
        } else {
            content
                .environment(\.renderRenderingMode, spec.isAccessory ? .vibrant : .fullColor)
        }
    }

    @ViewBuilder
    private var wallpaper: some View {
        if mode == .tintado {
            Color(red: 0.20, green: 0.17, blue: 0.36)
        } else if mode == .standby {
            Color.black
        } else if spec.isAccessory {
            Color(red: 0.16, green: 0.18, blue: 0.24)
        } else if mode == .claro {
            Color(red: 0.70, green: 0.74, blue: 0.82)
        } else {
            Color(red: 0.12, green: 0.13, blue: 0.17)
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if mode == .tintado {
            Color.white.opacity(0.14)
        } else if mode == .standby || spec.isAccessory {
            Color.clear
        } else {
            switch background {
            case .card: Color(uiColor: .secondarySystemGroupedBackground)
            case .fill(let color): color
            }
        }
    }
}

// MARK: - Pintar

@MainActor
enum Renderer {
    static func png<V: View>(_ view: V, size: CGSize, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(size)
        guard let image = renderer.uiImage, let data = image.pngData() else {
            #if DEBUG
            print("WidgetRender: no se pudo pintar \(url.lastPathComponent)")
            #endif
            return
        }
        do {
            try data.write(to: url)
        } catch {
            #if DEBUG
            print("WidgetRender: Error: \(error)")
            #endif
        }
    }
}
