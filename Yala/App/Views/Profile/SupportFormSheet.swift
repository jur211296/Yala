//
//  SupportFormSheet.swift
//  Yala
//

import SwiftUI

enum SupportType: String, CaseIterable, Identifiable {
    case error
    case improvement
    case idea

    var id: String { rawValue }

    var label: String {
        switch self {
        case .error: L10n.Support.typeError
        case .improvement: L10n.Support.typeImprovement
        case .idea: L10n.Support.typeIdea
        }
    }

    /// Short code for inbox filtering (E/M/I)
    var filterCode: String {
        switch self {
        case .error: "E"
        case .improvement: "M"
        case .idea: "I"
        }
    }
}

struct SupportFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedType: SupportType = .error
    @State private var message: String = ""
    /// iOS no pudo abrir `mailto:` (no hay app de correo configurada): se avisa y el formulario NO se cierra.
    @State private var showNoMailAlert = false

    private let maxCharacters = 500

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                        // Type picker
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(L10n.Support.type)
                                .font(DS.Typography.label)
                                .foregroundStyle(.secondary)

                            Menu {
                                ForEach(SupportType.allCases) { type in
                                    Button {
                                        selectedType = type
                                    } label: {
                                        HStack {
                                            Text(type.label)
                                            if selectedType == type {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedType.label)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(DS.Typography.captionSmall.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, DS.Spacing.md)
                                .background(.thCard)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            }
                        }

                        // Message field
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(L10n.Support.message)
                                .font(DS.Typography.label)
                                .foregroundStyle(.secondary)

                            TextField(
                                L10n.Support.messagePlaceholder,
                                text: $message,
                                axis: .vertical
                            )
                            .accessibilityIdentifier("support_message_field")
                            .lineLimit(5...10)
                            .font(DS.Typography.body)
                            .padding(DS.Spacing.md)
                            .background(.thCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .onChange(of: message) { _, newValue in
                                if newValue.count > maxCharacters {
                                    message = String(newValue.prefix(maxCharacters))
                                }
                            }

                            HStack {
                                Spacer()
                                Text("\(message.count)/\(maxCharacters)")
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Send button
                        YalaPrimaryButton(L10n.Support.send) {
                            guard let url = supportMailURL(type: selectedType, message: message) else { return }
                            // Antes se cerraba sin mirar si iOS había abierto el correo: sin app de correo no pasaba
                            // nada y lo escrito se perdía (auditoría UX 2.2, lote 16). Solo se cierra si se abrió.
                            openURL(url) { accepted in
                                if accepted {
                                    dismiss()
                                } else {
                                    showNoMailAlert = true
                                }
                            }
                        }
                        .accessibilityIdentifier("support_send_button")
                        .disabled(!canSend)
                        .opacity(canSend ? 1 : 0.5)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xxl)
                    .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.Support.title)
            .navigationBarTitleDisplayMode(.inline)
            .alert(L10n.Support.noMailTitle, isPresented: $showNoMailAlert) {
                Button(L10n.Support.copyMessage) {
                    UIPasteboard.general.string = supportMailBody(type: selectedType, message: message)
                }
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(L10n.Support.noMailMessage(AppConstants.supportEmail))
            }
            .yalaScreenBackground(.subtle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Mail URL

    private func supportMailURL(type: SupportType, message: String) -> URL? {
        let subject = "Yala (\(type.filterCode)) - \(L10n.Support.title): \(type.label)"
        guard var components = URLComponents(string: "mailto:\(AppConstants.supportEmail)") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: supportMailBody(type: type, message: message)),
        ]
        return components.url
    }

    /// El cuerpo del correo: lo escrito más los datos que soporte necesita. Es también lo que se copia sin app de correo.
    private func supportMailBody(type: SupportType, message: String) -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let systemVersion = UIDevice.current.systemVersion
        let modelName = UIDevice.current.model
        let themeName = themeManager.userChoice.label
        let locale = Locale.preferredLanguages.first ?? "?"

        return """
        \(message)

        ---
        App: Yala v\(version) (\(build))
        iOS: \(systemVersion)
        Device: \(modelName)
        Theme: \(themeName)
        Locale: \(locale)
        """
    }
}

#Preview {
    SupportFormSheet()
}
