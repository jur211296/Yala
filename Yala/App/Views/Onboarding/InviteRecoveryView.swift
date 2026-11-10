//
//  InviteRecoveryView.swift
//  Yala
//
//  A4 — Rama C del Welcome Chooser. "Me invitaron a un grupo" → paste link manual.
//
//  Soporta universal links en hosts canónicos + alternos (yala-pe.com etc.) y custom
//  schemes (yala://, yaladev://). Auto-detect del clipboard solo si `hasURLs == true`
//  (evita el toast iOS "accedió al portapapeles" cuando no hay URL).
//

import SwiftUI
import UIKit

struct InviteRecoveryView: View {

    @Environment(\.yalaTheme) private var theme

    @State private var linkText: String = ""
    @State private var validationError: String?
    @FocusState private var inputFocused: Bool

    var onSuccess: (URL) -> Void
    var onBack: () -> Void

    /// L12-16 · el enlace de Yala se saca de cualquier texto: el mensaje entero de WhatsApp vale.
    private var validatedURL: URL? {
        InviteLinkTextExtraction.firstInviteLink(in: linkText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(spacing: DS.Spacing.xl) {
                            Spacer(minLength: DS.Spacing.xl)

                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 56))
                                // A11Y-DM: verde decorativo de acento positivo en el hero (sistema, adapta a Dark Mode)
                                .foregroundStyle(.green)

                            VStack(spacing: DS.Spacing.sm) {
                                Text(L10n.Welcome.Invite.title)
                                    .font(DS.Typography.title2)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                Text(L10n.Welcome.Invite.body)
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, DS.Spacing.lg)
                            }

                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                TextField(L10n.Welcome.Invite.placeholder, text: $linkText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .lineLimit(2...5)
                                    .focused($inputFocused)
                                    .keyboardType(.URL)
                                    .textContentType(.URL)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .padding(DS.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                            .fill(.thCard)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                            .stroke(
                                                validationError != nil
                                                    ? DS.Semantic.errorForeground.opacity(0.6)
                                                    : Color.black.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    )
                                    .onChange(of: linkText) { _, newValue in
                                        updateValidation(for: newValue)
                                    }

                                // L12-16 · «Pegar» del sistema: un toque, sin el gesto escondido de mantener pulsado, y sin
                                // el aviso de iOS de «accedió al portapapeles» (lo pega la persona, no la app).
                                PasteButton(payloadType: String.self) { strings in
                                    guard let pasted = strings.first else { return }
                                    Task { @MainActor in applyPastedText(pasted) }
                                }
                                .buttonBorderShape(.capsule)
                                .labelStyle(.titleAndIcon)
                                .tint(theme.accent)
                                .accessibilityIdentifier("invite_recovery_paste")
                                .id(Self.pasteAnchor)

                                if let error = validationError {
                                    Text(error)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Semantic.errorForeground)
                                        .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.lg)

                            Spacer(minLength: DS.Spacing.lg)
                        }
                    }
                    // Con el teclado, el sistema sube el scroll hasta el CAMPO, y «Pegar» va debajo: se lleva también a la
                    // vista al escribir y al enfocar (card zdio).
                    .onChange(of: linkText) { _, _ in scroll.scrollTo(Self.pasteAnchor, anchor: .bottom) }
                    .onChange(of: inputFocused) { _, focused in revealPaste(focused: focused, scroll: scroll) }
                    // «Unirme al grupo» va en el borde del scroll, no encima: con un enlace largo y el teclado abierto, el
                    // botón fijo tapaba media «Pegar» (QA del 2026-11-05, iPhone 14). Así el contenido acaba por encima del
                    // botón y lo que no quepa se desplaza.
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        YalaPrimaryButton(L10n.Welcome.Invite.join, isDisabled: validatedURL == nil) {
                            guard let url = validatedURL else { return }
                            DS.Haptic.success()
                            onSuccess(url)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                    // El toque que oculta el teclado va en una capa de FONDO, hermana del contenido: colgado
                    // del ScrollView era padre del PasteButton y se quedaba con su toque (iPhone 14, iOS 27.2,
                    // 2026-11-05: «Pegar» no hacía nada; sin el gesto, pegaba).
                    .background {
                        Color.clear.dismissKeyboardOnTap()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        onBack()
                    }
                    .accessibilityIdentifier("invite_recovery_back")
                }
            }
            .task {
                autoFillFromClipboardIfNeeded()
                inputFocused = true
            }
        }
    }

    private static let pasteAnchor = "invite_recovery_paste_anchor"

    /// Al enfocar, espera a que el teclado termine de subir (su animación dura ~0,3 s) y lleva «Pegar» a la vista.
    private func revealPaste(focused: Bool, scroll: ScrollViewProxy) {
        guard focused else { return }
        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return
            }
            scroll.scrollTo(Self.pasteAnchor, anchor: .bottom)
        }
    }

    // MARK: - Validation

    private func updateValidation(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { validationError = nil; return }
        if let url = InviteLinkTextExtraction.firstInviteLink(in: trimmed) {
            validationError = nil
            // El campo se queda con el enlace limpio: se ve qué se va a abrir. Reescribirlo vuelve a pasar por aquí con el
            // mismo texto, así que no hay bucle.
            if trimmed != url.absoluteString { linkText = url.absoluteString }
        } else {
            validationError = L10n.Welcome.Invite.invalidLink
        }
    }

    /// Lo que entra por «Pegar»: si trae un enlace de Yala, el campo se queda con él; si no, con el texto, y el aviso dice
    /// que no parece de Yala.
    private func applyPastedText(_ text: String) {
        if let url = InviteLinkTextExtraction.firstInviteLink(in: text) {
            linkText = url.absoluteString
            validationError = nil
        } else {
            linkText = text
            updateValidation(for: text)
        }
    }

    // MARK: - Clipboard auto-detect

    private func autoFillFromClipboardIfNeeded() {
        let pb = UIPasteboard.general
        guard pb.hasURLs, let url = pb.url else { return }
        guard InviteLinkService.isInviteLink(url) else { return }
        linkText = url.absoluteString
        validationError = nil
    }
}
