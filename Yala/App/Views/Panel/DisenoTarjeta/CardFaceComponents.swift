//
//  CardFaceComponents.swift
//  Yala
//
//  Las piezas visuales de una tarjeta de cuenta (2026-11-16): el fondo (degradado + patrón + acabado), el chip y el
//  cuadrito del ícono. Todo dibujado con SwiftUI a partir de `CardLook`; ni una imagen. Ninguna pieza se lee con
//  VoiceOver: son adorno, y la tarjeta ya dice nombre, saldo y «terminada en…».
//

import SwiftUI

extension Color {
    /// Un color de la tarjeta (`CardRGB`, en sRGB).
    init(card rgb: CardRGB) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}

// MARK: - Fondo

/// El fondo de la tarjeta, recortado a su forma. Lo usan la tarjeta del Panel, la vista previa y las miniaturas del
/// editor.
struct CardBackgroundView: View {
    let look: CardLook
    var cornerRadius: CGFloat = DS.Radius.xl
    /// Las miniaturas de la galería dibujan el patrón más apretado: a su tamaño, el de la tarjeta casi no se ve.
    var patternScale: CGFloat = 1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            LinearGradient(
                colors: look.stops.map { Color(card: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            finishLayer
            if look.pattern != .none {
                CardPatternView(
                    pattern: look.pattern,
                    color: Color(card: look.foreground).opacity(CardLook.patternOpacity),
                    scale: patternScale
                )
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color(card: look.foreground).opacity(0.12), lineWidth: 1))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var finishLayer: some View {
        switch look.finish {
        case .flat:
            EmptyView()
        case .metallic:
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0.30),
                    .init(color: .white.opacity(CardFinish.metallic.highlightOpacity), location: 0.48),
                    .init(color: .white.opacity(0), location: 0.66),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .glow:
            GeometryReader { proxy in
                RadialGradient(
                    colors: [.white.opacity(CardFinish.glow.highlightOpacity), .white.opacity(0)],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.9
                )
            }
        }
    }
}

// MARK: - Patrón

/// El patrón, en el color del texto a muy poca opacidad.
struct CardPatternView: View {
    let pattern: CardPattern
    let color: Color
    var scale: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let path = Self.path(for: pattern, in: size, scale: scale)
            switch pattern {
            case .dots:
                context.fill(path, with: .color(color))
            default:
                context.stroke(path, with: .color(color), lineWidth: 0.8 * max(scale, 0.6))
            }
        }
        .accessibilityHidden(true)
    }

    static func path(for pattern: CardPattern, in size: CGSize, scale: CGFloat) -> Path {
        let width = size.width
        let height = size.height
        var path = Path()
        switch pattern {
        case .none:
            break
        case .grid:
            let step = 16 * scale
            var x: CGFloat = step
            while x < width {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height)); x += step
            }
            var y: CGFloat = step
            while y < height {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: width, y: y)); y += step
            }
        case .waves:
            let center = CGPoint(x: width * 0.2, y: height * 0.62)
            let step = 9 * scale
            var radius: CGFloat = 12 * scale
            let limit = max(width, height) * 1.2
            while radius < limit {
                path.addEllipse(in: CGRect(
                    x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                radius += step
            }
        case .lines:
            let step = 9 * scale
            var x: CGFloat = -height
            while x < width {
                path.move(to: CGPoint(x: x, y: height)); path.addLine(to: CGPoint(x: x + height, y: 0)); x += step
            }
        case .dots:
            let step = 12 * scale
            let radius = 1.3 * max(scale, 0.7)
            var y: CGFloat = step / 2
            var row = 0
            while y < height {
                var x: CGFloat = (row.isMultiple(of: 2) ? step / 2 : step)
                while x < width {
                    path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    x += step
                }
                y += step
                row += 1
            }
        case .topographic:
            let lines = 10
            for index in 0..<lines {
                let base = height * (CGFloat(index) + 0.5) / CGFloat(lines)
                let phase = CGFloat(index)
                var x: CGFloat = 0
                path.move(to: CGPoint(x: 0, y: topoY(x: 0, base: base, phase: phase, width: width, scale: scale)))
                while x <= width {
                    x += 4
                    path.addLine(to: CGPoint(x: x, y: topoY(x: x, base: base, phase: phase, width: width, scale: scale)))
                }
            }
        case .diamonds:
            let step = 14 * scale
            var x: CGFloat = -height
            while x < width + height {
                path.move(to: CGPoint(x: x, y: height)); path.addLine(to: CGPoint(x: x + height, y: 0))
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x + height, y: height))
                x += step
            }
        }
        return path
    }

    private static func topoY(x: CGFloat, base: CGFloat, phase: CGFloat, width: CGFloat, scale: CGFloat) -> CGFloat {
        let t = x / max(width, 1) * 2 * .pi
        return base + 7 * scale * sin(t * 1.3 + phase * 0.7) + 4 * scale * sin(t * 2.7 + phase * 1.9)
    }
}

// MARK: - Chip

/// El chip de la tarjeta: dorado, o plateado en las plantillas frías.
struct CardChipView: View {
    var silver: Bool = false
    var width: CGFloat = 38

    var body: some View {
        let height = width * 0.74
        let colors: [Color] = silver
            ? [Color(card: CardRGB(hex: "#F3F4F6") ?? .white), Color(card: CardRGB(hex: "#B5BBC4") ?? .white),
               Color(card: CardRGB(hex: "#E1E4E8") ?? .white)]
            : [Color(card: CardRGB(hex: "#F7DC8A") ?? .white), Color(card: CardRGB(hex: "#C99A35") ?? .white),
               Color(card: CardRGB(hex: "#EDCB6A") ?? .white)]
        let line = Color.black.opacity(0.28)
        RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: width, height: height)
            .overlay {
                Canvas { context, size in
                    var path = Path()
                    let inset = size.width * 0.3
                    path.addRoundedRect(
                        in: CGRect(x: inset, y: size.height * 0.24, width: size.width - inset * 2,
                                   height: size.height * 0.52),
                        cornerSize: CGSize(width: 3, height: 3))
                    path.move(to: CGPoint(x: 0, y: size.height / 2)); path.addLine(to: CGPoint(x: inset, y: size.height / 2))
                    path.move(to: CGPoint(x: size.width - inset, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    path.move(to: CGPoint(x: size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.24))
                    path.move(to: CGPoint(x: size.width / 2, y: size.height * 0.76))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    context.stroke(path, with: .color(line), lineWidth: 0.9)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: width * 0.18, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.18), lineWidth: 0.6)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Ícono

/// El ícono de la cuenta en un cuadrito translúcido, como el de la referencia.
struct CardIconBadge: View {
    let iconName: String
    let foreground: Color
    var size: CGFloat = DS.Icon.badgeLarge

    var body: some View {
        Image(systemName: iconName)
            .font(DS.Typography.body)
            // El cuadrito mide lo mismo con cualquier tamaño de texto: a tamaños de accesibilidad el glifo lo desbordaba.
            // Es adorno (VoiceOver no lo lee), así que no pierde información.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(foreground.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(foreground.opacity(0.22), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}
