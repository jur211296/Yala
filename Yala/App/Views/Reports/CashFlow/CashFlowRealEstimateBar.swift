//
//  CashFlowRealEstimateBar.swift
//  Yala
//
//  Real y estimado se distinguen sin leer (decisión 31 de la revisión 2.3, opción A, 9-nov-2026): en el mes en curso, la
//  barra de una línea del plan pinta lo real en sólido y lo estimado que falta rayado. Es el mismo código que la línea
//  punteada de «Ver proyectado»: lo sólido ya pasó, lo discontinuo se espera. Cuánto va de cada tono lo decide
//  `CashFlowRealEstimateBarLogic`.
//

import SwiftUI

struct CashFlowRealEstimateBar: View {
    let segments: CashFlowRealEstimateBarLogic.Segments
    var height: CGFloat = DS.Sizing.budgetProgressBarHeight

    @State private var barWidth: CGFloat = 0

    var body: some View {
        // Fondo con el progreso en su `overlay`, como `BudgetProgressBar`: así la barra encoge al estrechar la ventana.
        Capsule()
            .fill(DS.Semantic.neutralBackground)
            .frame(height: height)
            .overlay(alignment: .leading) {
                HStack(spacing: DS.Spacing.none) {
                    Rectangle()
                        .fill(Color.electricIndigo)
                        .frame(width: barWidth * segments.real)
                    StripedFill(color: Color.electricIndigo)
                        .frame(width: barWidth * segments.estimate)
                }
                .frame(height: height)
                .clipShape(Capsule())
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { barWidth = $0 }
            .accessibilityElement()
            .accessibilityLabel(L10n.CashFlowPlan.real + ", " + L10n.CashFlowPlan.plan)
            .accessibilityValue("\(Int((segments.real * 100).rounded())) %")
            .accessibilityIdentifier("cashflow_line_real_estimate_bar")
    }
}

/// Rayas diagonales: lo estimado. Se dibujan con `Canvas` para no depender de una imagen ni del tema.
private struct StripedFill: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color.opacity(0.18)))
            let step: CGFloat = 5
            var x: CGFloat = -size.height
            var stripes = Path()
            while x < size.width {
                stripes.move(to: CGPoint(x: x, y: size.height))
                stripes.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += step
            }
            context.stroke(stripes, with: .color(color.opacity(0.75)), lineWidth: 1.5)
        }
        .accessibilityHidden(true)
    }
}
