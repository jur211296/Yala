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

    private var validatedURL: URL? {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return InviteLinkService.isInviteLink(url) ? url : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        Spacer(minLength: DS.Spacing.xl)

                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 56))
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
                .dismissKeyboardOnTap()

                VStack(spacing: DS.Spacing.sm) {
                    Spacer()
                    YalaPrimaryButton(L10n.Welcome.Invite.join, isDisabled: validatedURL == nil) {
                        guard let url = validatedURL else { return }
                        DS.Haptic.success()
                        onSuccess(url)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        onBack()
                    }
                }
            }
            .task {
                autoFillFromClipboardIfNeeded()
                inputFocused = true
            }
        }
    }

    // MARK: - Validation

    private func updateValidation(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { validationError = nil; return }
        if let url = URL(string: trimmed), InviteLinkService.isInviteLink(url) {
            validationError = nil
        } else {
            validationError = L10n.Welcome.Invite.invalidLink
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
