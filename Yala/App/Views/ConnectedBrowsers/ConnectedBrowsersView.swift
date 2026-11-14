//
//  ConnectedBrowsersView.swift
//  Yala
//
//  Ajustes › Tu cuenta de Yala › «Navegadores conectados» (Yala web, lote 1, decisión D5): las sesiones de Yala web
//  abiertas con esta cuenta, con «Cerrar» en cada una y «Cerrar todas». Al cerrar, esa pestaña se vacía en menos de un
//  minuto (la web pregunta por su sesión cada 30 s). Solo existe en Yala Dev: la web de 2.3 vive en staging.
//

import SwiftUI

struct ConnectedBrowsersView: View {
    @State private var model: ConnectedBrowsersModel
    @State private var confirmCloseAll = false

    init(model: ConnectedBrowsersModel? = nil) {
        _model = State(initialValue: model ?? ConnectedBrowsersModel(client: Self.defaultClient()))
    }

    private static func defaultClient() -> ConnectedBrowsersClient {
        #if DEBUG
        if ConnectedBrowsersDemo.isActive { return ConnectedBrowsersDemo.client() }
        #endif
        return ConnectedBrowsersClient()
    }

    var body: some View {
        YalaSettingsList {
            YalaSettingsSection {
                Text(ConnectedBrowsersText.intro)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("connected_browsers_intro")
            }

            content
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(ConnectedBrowsersText.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("connected_browsers_screen")
        .task { await model.load() }
        .refreshable { await model.load() }
        .alert(ConnectedBrowsersText.closeAllConfirmTitle, isPresented: $confirmCloseAll) {
            Button(ConnectedBrowsersText.closeAllConfirm, role: .destructive) {
                Task { await model.closeAll() }
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(ConnectedBrowsersText.closeAllConfirmBody)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            YalaSettingsSection {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.md)
                .accessibilityIdentifier("connected_browsers_loading")
            }
        case .failed:
            YalaSettingsSection {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(ConnectedBrowsersText.loadFailed)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.Action.retry) {
                        Task { await model.load() }
                    }
                    .accessibilityIdentifier("connected_browsers_retry")
                }
                .padding(.vertical, DS.Spacing.xs)
            }
        case .loaded(let sessions):
            if sessions.isEmpty {
                YalaSettingsSection {
                    Text(ConnectedBrowsersText.empty)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("connected_browsers_empty")
                }
            } else {
                YalaSettingsSection {
                    if model.closeFailed {
                        Text(ConnectedBrowsersText.closeFailed)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Semantic.errorForeground)
                            .accessibilityIdentifier("connected_browsers_close_failed")
                    }
                    ForEach(sessions) { session in
                        row(session)
                    }
                } footer: {
                    Text(ConnectedBrowsersText.footer)
                }
                YalaSettingsSection {
                    Button(role: .destructive) {
                        confirmCloseAll = true
                    } label: {
                        Text(ConnectedBrowsersText.closeAll)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .disabled(model.closing != nil)
                    .accessibilityIdentifier("connected_browsers_close_all")
                }
            }
        }
    }

    private func row(_ session: WebSession) -> some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            Image(systemName: icon(for: session.sistema))
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(ConnectedBrowsersText.browserTitle(navegador: session.navegador, sistema: session.sistema))
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Text(ConnectedBrowsersText.detailLine(session))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: DS.Spacing.sm)
            if model.closing == session.id {
                ProgressView()
            } else {
                Button(ConnectedBrowsersText.close, role: .destructive) {
                    Task { await model.close(session) }
                }
                .buttonStyle(.borderless)
                .disabled(model.closing != nil)
                .accessibilityIdentifier("connected_browsers_close_\(session.id)")
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
        .accessibilityIdentifier("connected_browsers_row")
    }

    private func icon(for system: String) -> String {
        switch system {
        case "iPhone": "iphone"
        case "iPad": "ipad"
        case "Android": "smartphone"
        case "Mac": "laptopcomputer"
        default: "desktopcomputer"
        }
    }
}
