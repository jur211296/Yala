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

    private let maxCharacters = 500

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

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
                            if let url = supportMailURL(type: selectedType, message: message) {
                                openURL(url)
                                dismiss()
                            }
                        }
                        .disabled(!canSend)
                        .opacity(canSend ? 1 : 0.5)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Support.title)
            .navigationBarTitleDisplayMode(.inline)
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
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let systemVersion = UIDevice.current.systemVersion
        let modelName = UIDevice.current.model
        let themeName = themeManager.userChoice.label
        let locale = Locale.preferredLanguages.first ?? "?"

        let subject = "Yala (\(type.filterCode)) - \(L10n.Support.title): \(type.label)"
        let body = """
        \(message)

        ---
        App: Yala v\(version) (\(build))
        iOS: \(systemVersion)
        Device: \(modelName)
        Theme: \(themeName)
        Locale: \(locale)
        """

        guard var components = URLComponents(string: "mailto:\(AppConstants.supportEmail)") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

#Preview {
    SupportFormSheet()
}
