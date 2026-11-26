//
//  DividirBoletaShareCard.swift
//  Yala
//
//  La imagen de «Dividir una boleta» que se manda por WhatsApp, Instagram o el menú de compartir. No se navega a ella:
//  se rasteriza con `ImageRenderer`. Tres diseños con los colores y el logo de Yala (Jürgen, 26-nov-2026: «más de un
//  diseño, todos con colores y logo de Yala en algún lugar»):
//
//  - **Clara**: blanca, con la franja índigo de Yala arriba y el logo en blanco dentro.
//  - **Yala**: el índigo de la marca entero, las personas en tarjetas y el logo grande al pie.
//  - **Boleta**: papel de boleta, con el logo en índigo y el subrayado rosa del ícono.
//
//  Las dos reglas de `GroupShareableSummaryCard` valen igual: **ni un `@Environment` aquí dentro** (el contenido se
//  hostea fuera del árbol de la app y uno sin resolver tumba la app) y **colores fijos** (`DividirBoletaPalette`, con su
//  contraste medido en `DividirBoletaImagenTests`): la imagen tiene que verse igual en cualquier teléfono. Los textos
//  llegan ya escritos y formateados (`DividirBoletaImageContent`). Tamaños de letra fijos por lo mismo.
//

import SwiftUI

/// Ancho de la tarjeta en puntos; el alto mínimo sale de la proporción 4:5 (WhatsApp y el feed de Instagram).
enum DividirBoletaShareCardMetrics {
    static let width: CGFloat = 360
    static var minHeight: CGFloat { width * 5 / 4 }
}

struct DividirBoletaShareCard: View {
    let content: DividirBoletaImageContent
    let style: DividirBoletaImageStyle

    var body: some View {
        Group {
            switch style {
            case .light: DividirBoletaLightCard(content: content)
            case .brand: DividirBoletaBrandCard(content: content)
            case .receipt: DividirBoletaReceiptCard(content: content)
            }
        }
        .frame(width: DividirBoletaShareCardMetrics.width)
        .frame(minHeight: DividirBoletaShareCardMetrics.minHeight, alignment: .top)
    }
}

// MARK: - Piezas comunes

private func hex(_ value: String) -> Color { Color(hex: value) }

/// El logo «yala» (vectorial, blanco en el catálogo) teñido del color que pida el diseño.
private struct YalaWordmark: View {
    let color: Color
    let height: CGFloat

    var body: some View {
        Image("YalaLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

/// El ícono de la app (índigo con la estrella turquesa y el subrayado rosa).
private struct YalaAppIcon: View {
    let size: CGFloat

    var body: some View {
        Image("YalaIconBranded")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct InitialsBadge: View {
    let initials: String
    let colorHex: String
    var size: CGFloat = 30

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .bold)) // A11Y-DT: imagen rasterizada, tamaño fijo
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(hex(colorHex)))
    }
}

private struct AmountLabel: View {
    let text: String
    let size: CGFloat
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded)) // A11Y-DT: imagen rasterizada
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            // El importe no cede ancho a la lista de lo que comió: se lee entero en cualquier fila.
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }
}

/// La lista de lo que le tocó a una persona, en una sola línea de texto partida por « · ».
private func itemsText(_ items: [String]) -> String { items.joined(separator: " · ") }

// MARK: - Clara

private struct DividirBoletaLightCard: View {
    let content: DividirBoletaImageContent

    private let ink = hex(DividirBoletaPalette.lightInk)
    private let inkSecondary = hex(DividirBoletaPalette.lightInkSecondary)
    private let hairline = hex(DividirBoletaPalette.lightHairline)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.rows) { row in
                    HStack(alignment: .top, spacing: 12) {
                        InitialsBadge(initials: row.initials, colorHex: row.colorHex)
                        // El importe va en la línea del nombre y lo que comió debajo, a todo el ancho: en la misma fila
                        // la lista larga le quitaba sitio y el importe salía encogido.
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.name)
                                    .font(.system(size: 16, weight: .semibold)) // A11Y-DT: imagen rasterizada
                                    .foregroundStyle(ink)
                                Spacer(minLength: 8)
                                AmountLabel(text: row.amount, size: 17, color: ink)
                            }
                            if !row.items.isEmpty {
                                Text(itemsText(row.items))
                                    .font(.system(size: 12.5)) // A11Y-DT: imagen rasterizada
                                    .foregroundStyle(inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                if let payerLine = content.payerLine {
                    Rectangle().fill(hairline).frame(height: 1)
                    Text(payerLine)
                        .font(.system(size: 13)) // A11Y-DT: imagen rasterizada
                        .foregroundStyle(inkSecondary)
                }
                if !content.lines.isEmpty {
                    DividirBoletaLinesBlock(
                        lines: content.lines, ink: ink, inkSecondary: inkSecondary, rule: hairline, dashed: false)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            Spacer(minLength: 0)
            footer
        }
        .background(hex(DividirBoletaPalette.lightBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                YalaWordmark(color: hex(DividirBoletaPalette.onIndigo), height: 44)
                Spacer()
                Text(content.dateText)
                    .font(.system(size: 12.5, weight: .medium)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(hex(DividirBoletaPalette.onIndigoSecondary))
            }
            Text(content.merchant.uppercased())
                .font(.system(size: 12, weight: .semibold)) // A11Y-DT: imagen rasterizada
                .tracking(0.6)
                .foregroundStyle(hex(DividirBoletaPalette.onIndigoSecondary))
                .padding(.top, 6)
            Text(content.headline)
                .font(.system(size: 15, weight: .medium)) // A11Y-DT: imagen rasterizada
                .foregroundStyle(hex(DividirBoletaPalette.onIndigo))
            AmountLabel(text: content.headlineAmount, size: 38, color: hex(DividirBoletaPalette.onIndigo))
            Text(content.subtitle)
                .font(.system(size: 12.5)) // A11Y-DT: imagen rasterizada
                .foregroundStyle(hex(DividirBoletaPalette.onIndigoSecondary))
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [hex(DividirBoletaPalette.indigoDeep), hex(DividirBoletaPalette.indigo)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(alignment: .bottomLeading) {
            // El subrayado rosa del ícono, bajo la franja.
            Rectangle().fill(hex(DividirBoletaPalette.pink)).frame(width: 56, height: 4)
                .padding(.leading, 22)
                .offset(y: 2)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            YalaAppIcon(size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(content.footerTitle)
                    .font(.system(size: 13, weight: .semibold)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(ink)
                Text(content.footerSubtitle)
                    .font(.system(size: 12)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(inkSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(hairline).frame(height: 1) }
    }
}

// MARK: - Yala

private struct DividirBoletaBrandCard: View {
    let content: DividirBoletaImageContent

    private let onBrand = hex(DividirBoletaPalette.onIndigo)
    private let onBrandSecondary = hex(DividirBoletaPalette.brandInkSecondary)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(content.merchant.uppercased())
                    .font(.system(size: 12, weight: .semibold)) // A11Y-DT: imagen rasterizada
                    .tracking(0.6)
                    .foregroundStyle(onBrandSecondary)
                    .lineLimit(1)
                Spacer()
                Text(content.dateText)
                    .font(.system(size: 12.5, weight: .medium)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(onBrandSecondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(content.headline)
                    .font(.system(size: 22, weight: .bold)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(onBrand)
                AmountLabel(text: content.headlineAmount, size: 40, color: onBrand)
                Text(content.subtitle)
                    .font(.system(size: 12.5)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(onBrandSecondary)
            }
            VStack(spacing: 8) {
                ForEach(content.rows) { row in
                    HStack(alignment: .top, spacing: 12) {
                        InitialsBadge(initials: row.initials, colorHex: row.colorHex, size: 32)
                            .overlay(Circle().stroke(onBrand.opacity(0.9), lineWidth: 1.5))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.name)
                                    .font(.system(size: 16, weight: .semibold)) // A11Y-DT: imagen rasterizada
                                    .foregroundStyle(onBrand)
                                Spacer(minLength: 8)
                                AmountLabel(text: row.amount, size: 19, color: onBrand)
                            }
                            if !row.items.isEmpty {
                                Text(itemsText(row.items))
                                    .font(.system(size: 12)) // A11Y-DT: imagen rasterizada
                                    .foregroundStyle(onBrandSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(hex(DividirBoletaPalette.brandCard)))
                }
            }
            if let payerLine = content.payerLine {
                Text(payerLine)
                    .font(.system(size: 13)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(onBrandSecondary)
            }
            if !content.lines.isEmpty {
                DividirBoletaLinesBlock(
                    lines: content.lines, ink: onBrand, inkSecondary: onBrandSecondary,
                    rule: onBrandSecondary.opacity(0.4), dashed: false)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    YalaWordmark(color: onBrand, height: 60)
                    // La estrella turquesa y el subrayado rosa del ícono, como firma.
                    Rectangle().fill(hex(DividirBoletaPalette.pink)).frame(width: 36, height: 4)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(content.footerTitle)
                        .font(.system(size: 13, weight: .semibold)) // A11Y-DT: imagen rasterizada
                        .foregroundStyle(onBrand)
                    Text(content.footerSubtitle)
                        .font(.system(size: 12)) // A11Y-DT: imagen rasterizada
                        .foregroundStyle(onBrandSecondary)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [hex(DividirBoletaPalette.indigoDeep), hex(DividirBoletaPalette.indigo)],
                    startPoint: .top, endPoint: .bottom)
                Image(systemName: "sparkle")
                    .font(.system(size: 64, weight: .bold)) // A11Y-DT: imagen rasterizada, adorno
                    .foregroundStyle(hex(DividirBoletaPalette.turquoise).opacity(0.85))
                    .padding(.top, 54)
                    .padding(.trailing, 18)
                    .accessibilityHidden(true)
            }
        )
    }
}

// MARK: - Boleta

private struct DividirBoletaReceiptCard: View {
    let content: DividirBoletaImageContent

    private let ink = hex(DividirBoletaPalette.paperInk)
    private let inkSecondary = hex(DividirBoletaPalette.paperInkSecondary)
    private let rule = hex(DividirBoletaPalette.paperRule)
    private let accent = hex(DividirBoletaPalette.paperAccent)

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            VStack(spacing: 6) {
                YalaWordmark(color: accent, height: 54)
                Rectangle().fill(hex(DividirBoletaPalette.pink)).frame(width: 34, height: 4)
            }
            .padding(.top, 6)
            VStack(spacing: 2) {
                Text(content.merchant.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .monospaced)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                Text(content.dateText)
                    .font(.system(size: 12, design: .monospaced)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(inkSecondary)
            }
            dashedRule
            VStack(spacing: 2) {
                Text(content.headline)
                    .font(.system(size: 15, weight: .semibold)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(hex(DividirBoletaPalette.paperPinkText))
                AmountLabel(text: content.headlineAmount, size: 36, color: ink)
                Text(content.subtitle)
                    .font(.system(size: 12)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(inkSecondary)
            }
            dashedRule
            VStack(alignment: .leading, spacing: 10) {
                ForEach(content.rows) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.name)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced)) // A11Y-DT: imagen rasterizada
                                .foregroundStyle(ink)
                            Spacer(minLength: 8)
                            Text(row.amount)
                                .font(.system(size: 15, weight: .bold, design: .monospaced)) // A11Y-DT: imagen rasterizada
                                .foregroundStyle(ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        if !row.items.isEmpty {
                            Text(itemsText(row.items))
                                .font(.system(size: 11.5, design: .monospaced)) // A11Y-DT: imagen rasterizada
                                .foregroundStyle(inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let payerLine = content.payerLine {
                    Text(payerLine)
                        .font(.system(size: 12, design: .monospaced)) // A11Y-DT: imagen rasterizada
                        .foregroundStyle(inkSecondary)
                }
                if !content.lines.isEmpty {
                    DividirBoletaLinesBlock(lines: content.lines, ink: ink, inkSecondary: inkSecondary, rule: rule, dashed: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            dashedRule
            HStack(spacing: 8) {
                YalaAppIcon(size: 22)
                Text(content.footerTitle + " · " + content.footerSubtitle)
                    .font(.system(size: 12, weight: .medium)) // A11Y-DT: imagen rasterizada
                    .foregroundStyle(accent)
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(hex(DividirBoletaPalette.paper))
        .overlay(alignment: .top) { ReceiptEdge().fill(hex(DividirBoletaPalette.indigo)).frame(height: 8) }
        .overlay(alignment: .bottom) {
            ReceiptEdge().fill(hex(DividirBoletaPalette.indigo)).frame(height: 8).rotationEffect(.degrees(180))
        }
    }

    private var dashedRule: some View {
        Line()
            .stroke(rule, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
    }
}

/// El borde dentado de una boleta, como franja índigo arriba y abajo.
private struct ReceiptEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tooth: CGFloat = 12
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        var x = rect.maxX
        var down = false
        while x > rect.minX {
            x -= tooth / 2
            path.addLine(to: CGPoint(x: max(x, rect.minX), y: down ? rect.maxY : rect.minY + rect.height / 2))
            down.toggle()
        }
        path.closeSubpath()
        return path
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - «Con detalle»: las líneas de la boleta

private struct DividirBoletaLinesBlock: View {
    let lines: [DividirBoletaImageContent.LineRow]
    let ink: Color
    let inkSecondary: Color
    let rule: Color
    let dashed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Group {
                if dashed {
                    Line().stroke(rule, style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(height: 1)
                } else {
                    Rectangle().fill(rule).frame(height: 1)
                }
            }
            .padding(.bottom, 3)
            ForEach(lines) { line in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(line.description)
                            .font(.system(size: 12.5, weight: .medium)) // A11Y-DT: imagen rasterizada
                            .foregroundStyle(ink)
                        Spacer(minLength: 8)
                        Text(line.amount)
                            .font(.system(size: 12.5, weight: .medium, design: .rounded)) // A11Y-DT: imagen rasterizada
                            .monospacedDigit()
                            .foregroundStyle(ink)
                            .lineLimit(1)
                    }
                    Text(line.who)
                        .font(.system(size: 11.5)) // A11Y-DT: imagen rasterizada
                        .foregroundStyle(inkSecondary)
                }
            }
        }
    }
}
