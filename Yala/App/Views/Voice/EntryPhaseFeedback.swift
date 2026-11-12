//
//  EntryPhaseFeedback.swift
//  Yala
//
//  Dos piezas que comparten la hoja de voz (`VoiceRecordingView`) y la de foto (`ImageSelectionView`), revisión 2.3 de
//  Nuevo registro:
//  - **Decisión 62:** cada cambio de fase y cada fallo se anuncia a VoiceOver. Sin anuncio, quien no ve la pantalla no
//    sabía que la hoja había pasado de «Escuchando» a «Esto entendí» ni que algo había fallado.
//  - **Decisión 81 (regla de la 39):** «Volver a grabar» y «Otra foto» preguntan antes de borrar lo entendido que no se
//    guardó. Desde un fallo no hay nada que perder y no preguntan.
//

import SwiftUI

/// Qué se anuncia y cuándo se pregunta: lógica pura, sin vistas.
enum EntryPhaseFeedbackLogic {
    /// La frase del anuncio: el título y, si lo hay, el detalle (el porqué de un fallo). Vacío = nada que anunciar.
    static func announcement(title: String, detail: String? = nil) -> String {
        [title, detail ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.hasSuffix(".") || $0.hasSuffix("?") || $0.hasSuffix("!") || $0.hasSuffix("…") ? $0 : $0 + "." }
            .joined(separator: " ")
    }

    /// «Volver a grabar» / «Otra foto» preguntan solo si se está revisando lo entendido y queda algo sin guardar.
    static func asksBeforeDiscarding(isReviewing: Bool, unsavedCount: Int) -> Bool {
        isReviewing && unsavedCount > 0
    }
}

/// Anuncia a VoiceOver cada frase nueva de la hoja. Lo que ya se ve al abrir no se anuncia (no hay cambio).
private struct EntryPhaseAnnouncer: ViewModifier {
    let text: String
    @State private var lastAnnounced = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: text) { _, newText in announce(newText) }
            #if DEBUG
            .overlay(alignment: .topLeading) { uiTestWitness }
            #endif
    }

    private func announce(_ newText: String) {
        guard !newText.isEmpty else { return }
        // Prioridad alta: el foco que mueve la propia hoja al cambiar de fase no lo corta.
        var announcement = AttributedString(newText)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
        lastAnnounced = newText
    }

    #if DEBUG
    /// Testigo para XCUITest: el último anuncio, que VoiceOver no deja leer desde fuera. Solo bajo `-uitest`.
    @ViewBuilder
    private var uiTestWitness: some View {
        if UITestHooks.isActive {
            Text(verbatim: lastAnnounced)
                .foregroundStyle(.clear)
                .frame(width: 1, height: 1)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityIdentifier("entry_phase_announcement")
        }
    }
    #endif
}

/// La pregunta antes de descartar lo entendido. «Seguir revisando» es la salida segura y va como `.cancel` (siempre al
/// final en una alerta); un `confirmationDialog` colgado de un botón no pintaría «Cancelar» (`swiftui-ds.md`).
private struct EntryDiscardConfirmation: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button(L10n.Alert.discardChanges, role: .destructive) { onDiscard() }
                    .accessibilityIdentifier("entry_discard_confirm")
                Button(L10n.EntryDiscard.keepReviewing, role: .cancel) {}
                    .accessibilityIdentifier("entry_discard_keep")
            } message: {
                Text(message)
            }
    }
}

extension View {
    /// Anuncia `text` a VoiceOver cada vez que cambia (decisión 62).
    func announcesEntryPhase(_ text: String) -> some View {
        modifier(EntryPhaseAnnouncer(text: text))
    }

    /// Pregunta antes de descartar lo entendido (decisión 81).
    func asksBeforeDiscardingEntry(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        onDiscard: @escaping () -> Void
    ) -> some View {
        modifier(EntryDiscardConfirmation(title: title, message: message, isPresented: isPresented, onDiscard: onDiscard))
    }
}
