//
//  ConectaTuIAView.swift
//  Yala
//
//  Ajustes › Tu IA («Conecta tu IA», 2.3, opción C de Jürgen del 23-nov): cómo conectar Claude, ChatGPT o Grok, qué puede
//  hacer, y las IA conectadas con «Desconectar» (contra `GET`/`DELETE /connections` del conector). Gratis para todos.
//  Sin los datos en la cuenta de Yala lo dice primero y apaga los pasos: la IA no vería nada.
//
//  La misma página sale en una hoja desde la Bandeja vacía (`presentation: .sheet`). Ahí no hay pila de Ajustes a la que
//  empujar «Dónde viven tus datos», así que el aviso lo dice con palabras.
//

import SwiftData
import SwiftUI

struct ConectaTuIAView: View {
    enum Presentation {
        /// Empujada en Ajustes: «Pasar a tu cuenta de Yala» abre «Dónde viven tus datos».
        case settings
        /// En una hoja (Bandeja): con «Listo» arriba.
        case sheet
    }

    var presentation: Presentation = .settings

    @State private var model: ConectaTuIAModel
    @State private var provider: ConectaTuIALogic.Provider = .claude
    @State private var pendingDisconnect: AIConnection?
    @State private var confirmingDisconnect = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    /// Lo que apuntó cada IA en este teléfono, para «último borrador hace 2 h» (decisión 4: no se guarda otra actividad).
    @Query(filter: #Predicate<InboxDraft> { $0.sourceTypeRaw == "aiConnector" }, sort: \InboxDraft.createdAt, order: .reverse)
    private var aiDrafts: [InboxDraft]

    init(presentation: Presentation = .settings, model: ConectaTuIAModel? = nil) {
        self.presentation = presentation
        _model = State(initialValue: model ?? ConectaTuIAModel(client: Self.defaultClient()))
    }

    private static func defaultClient() -> ConectaTuIAClient {
        #if DEBUG
        if ConectaTuIADemo.isActive { return ConectaTuIADemo.client() }
        #endif
        return ConectaTuIAClient()
    }

    private var availability: ConectaTuIALogic.Availability {
        CloudSessionRevision.shared.track()
        return ConectaTuIALogic.availability(
            storageIsCloud: CloudSyncFlags.storageMode == .cloud,
            hasSession: CloudAuthService.shared.hasSession,
            forcesReady: Self.isDemo)
    }

    private static var isDemo: Bool {
        #if DEBUG
        return ConectaTuIADemo.isActive
        #else
        return false
        #endif
    }

    var body: some View {
        let ready = availability == .ready
        YalaSettingsList {
            YalaSettingsSection {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.ConectaTuIA.headerTitle)
                        .font(DS.Typography.title3.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.ConectaTuIA.headerMessage)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, DS.Spacing.xxs)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("conecta_ia_header")
            }

            if !ready {
                accountSection
            }

            YalaSettingsSection(L10n.ConectaTuIA.stepsHeader) {
                ConectaTuIAGuide(provider: $provider, isEnabled: ready)
                    .padding(.vertical, DS.Spacing.xs)
            }

            YalaSettingsSection(L10n.ConectaTuIA.canHeader) {
                canRow(L10n.ConectaTuIA.canRead, icon: "checkmark.circle.fill", color: Color.incomeAmount)
                canRow(L10n.ConectaTuIA.canDraft, icon: "sparkles", color: theme.accentText)
                canRow(L10n.ConectaTuIA.canNever, icon: "xmark.circle.fill", color: DS.Semantic.errorForeground)
            } footer: {
                Text(L10n.ConectaTuIA.canFooter)
            }

            if ready {
                connectedSection
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.ConectaTuIA.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentation == .sheet {
                ToolbarItem(placement: .confirmationAction) {
                    YalaToolbarTextButton(L10n.Action.done) { dismiss() }
                        .accessibilityIdentifier("conecta_ia_done")
                }
            }
        }
        .accessibilityIdentifier("conecta_ia_screen")
        .task(id: ready) { if ready { await model.load() } }
        .refreshable { if ready { await model.load() } }
        .alert(
            pendingDisconnect.map { L10n.ConectaTuIA.disconnectConfirmTitle(name(of: $0)) } ?? "",
            isPresented: $confirmingDisconnect,
            presenting: pendingDisconnect
        ) { connection in
            Button(L10n.ConectaTuIA.disconnect, role: .destructive) {
                Task { await model.disconnect(connection) }
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: { _ in
            Text(L10n.ConectaTuIA.disconnectConfirmBody)
        }
    }

    // MARK: - Sin la cuenta de Yala

    private var accountSection: some View {
        YalaSettingsSection {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label {
                    Text(L10n.ConectaTuIA.accountTitle)
                        .font(DS.Typography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundStyle(.thAccentText)
                        .accessibilityHidden(true)
                }
                Text(L10n.ConectaTuIA.accountMessage)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if presentation == .sheet {
                    Text(L10n.ConectaTuIA.accountWhere)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, DS.Spacing.xxs)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("conecta_ia_needs_account")
            if presentation == .settings {
                NavigationLink(value: ProfileDestination.storageMode) {
                    Text(L10n.ConectaTuIA.accountButton)
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.thAccentText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("conecta_ia_open_storage")
            }
        }
    }

    // MARK: - Qué puede hacer

    private func canRow(_ text: String, icon: String, color: Color) -> some View {
        Label {
            Text(text)
                .font(DS.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Conectadas

    @ViewBuilder
    private var connectedSection: some View {
        switch model.phase {
        case .loading:
            YalaSettingsSection(L10n.ConectaTuIA.connectedHeader) {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.md)
                .accessibilityIdentifier("conecta_ia_loading")
            }
        case .failed:
            YalaSettingsSection(L10n.ConectaTuIA.connectedHeader) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.ConectaTuIA.loadFailed)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.Action.retry) {
                        Task { await model.load() }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("conecta_ia_retry")
                }
                .padding(.vertical, DS.Spacing.xs)
            }
        case .loaded(let connections):
            YalaSettingsSection(L10n.ConectaTuIA.connectedHeader) {
                if model.disconnectFailed {
                    Text(L10n.ConectaTuIA.disconnectFailed)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Semantic.errorForeground)
                        .accessibilityIdentifier("conecta_ia_disconnect_failed")
                }
                if connections.isEmpty {
                    Text(L10n.ConectaTuIA.connectedEmpty)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("conecta_ia_empty")
                } else {
                    ForEach(connections) { connection in
                        row(connection)
                    }
                }
            } footer: {
                Text(L10n.ConectaTuIA.connectedFooter)
            }
        }
    }

    private func name(of connection: AIConnection) -> String {
        ConectaTuIALogic.Provider(name: connection.ia)?.displayName ?? L10n.Inbox.sourceAIConnector
    }

    private func lastDraftDate(for connection: AIConnection) -> Date? {
        guard let name = ConectaTuIALogic.aiName(evidence: connection.ia) else { return nil }
        return aiDrafts.first { !$0.isDeleted && ConectaTuIALogic.aiName(evidence: $0.evidence) == name }?.createdAt
    }

    private func row(_ connection: AIConnection) -> some View {
        // `AdaptiveRowStack`: a tamaños de accesibilidad «Desconectar» baja a su propia línea en vez de partir el nombre.
        AdaptiveRowStack(spacing: DS.Spacing.sm) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thAccentText)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(verbatim: name(of: connection))
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(L10n.ConectaTuIA.detailLine(connection, lastDraftAt: lastDraftDate(for: connection)))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                // En el texto y no en la fila: en el contenedor tapaba el id de «Desconectar».
                .accessibilityIdentifier("conecta_ia_row")
            }
        } trailing: {
            if model.disconnecting == connection.id {
                ProgressView()
            } else {
                Button(L10n.ConectaTuIA.disconnect, role: .destructive) {
                    pendingDisconnect = connection
                    confirmingDisconnect = true
                }
                .buttonStyle(.borderless)
                .disabled(model.disconnecting != nil)
                .accessibilityIdentifier("conecta_ia_disconnect_\(connection.id)")
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }
}
