//
//  CourtesyTrial.swift
//  Yala
//
//  Y23-09: la prueba de cortesía de «Aprender a registrar». Con cuenta Free, voz, foto y Yala IA funcionan UNA vez dentro
//  del tutorial y el registro se guarda de verdad; al cerrar su pantalla vuelve el candado. Arriba de cada una, la franja
//  «Prueba de cortesía: …, una vez gratis» con «Omitir».
//

import SwiftData
import SwiftUI

/// Lo que el chat necesita para la prueba de Yala IA.
struct ChatCourtesyTrial {
    /// «Omitir» de la franja.
    let onSkip: () -> Void
    /// Se guardó un registro desde una tarjeta de borrador.
    let onSaved: (PersistentIdentifier) -> Void

    /// El ancla de la ficha «Apunta un gasto» del saludo.
    static let logExpenseAnchor = "chat_courtesy_log_expense"

    /// La guía de foco: se sigue tocando la ficha.
    static var guideSteps: [CoachMarkStep] {
        [CoachMarkStep(
            id: logExpenseAnchor,
            title: L10n.PrimerosPasos23.Record.aiGuideTitle,
            message: L10n.PrimerosPasos23.Record.aiGuideMessage,
            advancesByAction: true
        )]
    }
}

/// La franja de arriba: «Prueba de cortesía: la voz, una vez gratis» · «Omitir».
struct CourtesyTrialStrip: View {
    let text: String
    let onSkip: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(.thAccentText)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Spacing.sm)
            Button(L10n.PrimerosPasos23.Record.skip, action: onSkip)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.thAccentText)
                .frame(minHeight: 44)
                .accessibilityIdentifier("courtesy_trial_skip")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.accent.opacity(0.12)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("courtesy_trial_strip")
    }
}

extension EnvironmentValues {
    /// En la prueba de Yala IA, «Abrir en el formulario completo» de los detalles del borrador no se ofrece: cerraba el
    /// chat y abría el formulario fuera del tutorial, después de terminarlo, y lo que se guardaba ahí no entraba en
    /// «¿Borramos los de prueba?» (review del lote, Y23-09). Guardar desde los detalles sigue igual.
    @Entry var chatDraftFullFormHidden = false
}
