//
//  RelaunchChecklist.swift
//  Yala
//
//  UX 2.2 · L20-18 (opción D, variante 3), decidida por Jürgen el 2026-10-18: **reabrir Yala es una sola instrucción**.
//  Había tres para el mismo gesto —«ve a la pantalla de inicio y vuelve a abrir Yala» tras cerrar sesión, «cierra Yala
//  del todo (deslízala fuera del selector de apps)» tras migrar, «cierra y vuelve a abrir la app» con iCloud tarde—, sin
//  pasos ni dibujo, y nadie sabía si bastaba con salir al inicio.
//
//  La pantalla dice primero lo que YA está hecho (con check) y deja como único pendiente «Vuelve a abrir Yala», y debajo,
//  destacado, el gesto en tres pasos. iOS no deja que una app se reinicie sola, así que no hay botón.
//
//  **Los checks dicen solo lo que es verdad en esa pantalla**: los elige quien la monta (`SignOutRelaunchView`, la
//  tarjeta de relanzamiento de Ajustes). Los tres pasos son los mismos en todas, también dentro del aviso «iCloud ya
//  disponible» (`RelaunchSteps.inlineText`), que es un `.alert` y no puede pintar esta tarjeta.
//
//  El gesto vale también donde Yala se cierra sola al ir a inicio (el cierre de sesión): deslizar hacia arriba ya la manda
//  al fondo, y el resto de los pasos la vuelve a abrir.
//

import SwiftUI
import UIKit

/// Los tres pasos del gesto, en un solo sitio.
enum RelaunchSteps {
    /// En un iPhone con botón de inicio (SE, que iOS 26 sigue soportando) el selector de apps se abre con doble pulsación,
    /// no deslizando desde abajo: el primer paso cambia; los otros dos valen igual (review del 2026-10-19).
    static var all: [(icon: String, text: String)] { steps(hasHomeButton: deviceHasHomeButton) }

    static func steps(hasHomeButton: Bool) -> [(icon: String, text: String)] {
        [
            hasHomeButton ? ("circle.circle", L10n.UXL20N.relaunchStep1HomeButton)
                          : ("arrow.up.to.line", L10n.UXL20N.relaunchStep1),
            ("hand.draw", L10n.UXL20N.relaunchStep2),
            ("app.badge", L10n.UXL20N.relaunchStep3),
        ]
    }

    /// Sin margen seguro abajo en la ventana = hay botón de inicio (no hay indicador de inicio que lo reserve).
    private static var deviceHasHomeButton: Bool {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        guard let window else { return false }
        return window.safeAreaInsets.bottom == 0
    }

    /// Los mismos pasos en texto, numerados, para el mensaje de un `.alert`.
    static var inlineText: String {
        all.enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n")
    }
}

/// Lo hecho con check, el último paso pendiente y el gesto destacado.
struct RelaunchChecklist: View {
    let title: String
    /// Lo que ya pasó. Cada línea tiene que ser verdad en la pantalla que la monta.
    let done: [String]
    /// Una frase opcional bajo «Vuelve a abrir Yala»: lo que pasará al abrirla.
    var afterNote: String? = nil
    /// Un motivo opcional (por qué se paró algo), debajo del título.
    var reason: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(title)
                .font(DS.Typography.title2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let reason {
                Text(reason)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("relaunch_reason")
            }

            checklist
            stepsCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(done, id: \.self) { line in
                // Verde solo el icono: como TEXTO, `successForeground` sobre la tarjeta blanca no llega a AA.
                Label {
                    Text(line)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Semantic.successForeground)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L10n.UXL20N.relaunchDoneA11y(line))
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Label {
                    Text(L10n.UXL20N.relaunchPending)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "circle.dotted")
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L10n.UXL20N.relaunchPendingA11y)
                if let afterNote {
                    Text(afterNote)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, DS.Spacing.xxl)
                        .accessibilityIdentifier("relaunch_after_note")
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .accessibilityIdentifier("relaunch_checklist")
    }

    /// «Para terminar»: los tres pasos, numerados, sobre el relleno de la marca (lo importante destaca).
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.UXL20N.relaunchToFinish)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(RelaunchSteps.all.enumerated()), id: \.offset) { index, step in
                HStack(spacing: DS.Spacing.md) {
                    Text("\(index + 1)")
                        .font(DS.Typography.headline)
                        // A11Y-DM: blanco fijo sobre el círculo índigo sólido, en claro y en oscuro.
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.selectedIndigoFill, in: Circle())
                        .accessibilityHidden(true)
                    Text(step.text)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: step.icon)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(index + 1). \(step.text)")
                .accessibilityIdentifier("relaunch_step_\(index + 1)")
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.electricIndigo.opacity(0.22), in: RoundedRectangle(cornerRadius: DS.Radius.xl))
    }
}
