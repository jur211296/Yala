//
//  GmailConnectSheet.swift
//  Yala
//
//  Hoja de «Conectar Gmail», fase 1 — SOLO `DEV_BUILD` (encargo 2026-10-23, video de la verificación de Google).
//
//  Diseño provisional a propósito: icono, titular, qué se lee y qué no, y un botón. No es el diseño final; las
//  propuestas están en el PR. Textos en español escritos a mano, fuera del pipeline de l10n (molde
//  `CloudSyncDebugView`): no se ve en producción y su copy no está decidido.
//

#if DEV_BUILD
import SwiftData
import SwiftUI

struct GmailConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(DraftService.self) private var draftService

    private enum Phase: Equatable {
        case intro
        case working
        case done(GmailBankAlertImporter.Summary)
        case failed(String)
    }

    @State private var phase: Phase = .intro
    @State private var connectedEmail: String?
    /// Ancho fijo de la columna de iconos, para que el texto de las viñetas arranque en la misma línea.
    @ScaledMetric(relativeTo: .body) private var bulletIconWidth: CGFloat = 24

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    header
                    switch phase {
                    case .intro, .working:
                        explanation
                    case .done(let summary):
                        doneCard(summary)
                    case .failed(let message):
                        failedCard(message)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .safeAreaInset(edge: .bottom) { actions }
            .yalaScreenBackground(.subtle)
            .navigationTitle("Correo del banco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") { dismiss() }
                }
            }
        }
        .task {
            await GmailBankAlertImporter.restoreIfPossible()
            connectedEmail = GmailBankAlertImporter.connectedEmail
        }
    }

    // MARK: - Piezas

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Image(systemName: "envelope.badge")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(DS.Semantic.infoForeground)
                .accessibilityHidden(true)
            Text("Conecta tu Gmail y los avisos de tu banco llegan solos a la Bandeja")
                .font(DS.Typography.title2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            bullet("magnifyingglass", "Yala busca solo los correos de aviso de tu banco (por ahora, el BCP).")
            bullet("tray.and.arrow.down", "Cada aviso se convierte en un borrador: lo revisas y lo guardas tú.")
            bullet("iphone", "El correo se lee en este iPhone. No se envía a ningún servidor ni a ninguna IA.")
            bullet("hand.raised", "Yala no lee el resto de tu correo, no escribe ni borra nada, y no vende ni comparte tus datos.")
            bullet("xmark.circle", "Puedes quitar el permiso cuando quieras, aquí o en tu cuenta de Google.")
            if let connectedEmail {
                Text("Conectado como \(connectedEmail)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("gmail_connected_email")
            }
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: bulletIconWidth)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func doneCard(_ summary: GmailBankAlertImporter.Summary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label(doneTitle(summary), systemImage: "checkmark.circle.fill")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Semantic.successForeground)
            if let email = summary.email {
                Text("Cuenta: \(email)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Text(doneDetail(summary))
                .font(DS.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gmail_import_done")
    }

    private func failedCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(DS.Typography.body)
            .foregroundStyle(DS.Semantic.errorForeground)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("gmail_import_failed")
    }

    private var actions: some View {
        VStack(spacing: DS.Spacing.sm) {
            switch phase {
            case .done:
                YalaPrimaryButton("Ver la Bandeja", icon: "tray") { dismiss() }
                    .accessibilityIdentifier("gmail_done")
            default:
                YalaPrimaryButton("Continuar con Google", icon: "envelope", isLoading: phase == .working) {
                    Task { await connect() }
                }
                .accessibilityIdentifier("gmail_continue")
            }
            if connectedEmail != nil {
                Button("Quitar el permiso de Gmail") {
                    Task { await disconnect() }
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("gmail_disconnect")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.md)
    }

    // MARK: - Textos del resultado

    private func doneTitle(_ summary: GmailBankAlertImporter.Summary) -> String {
        switch summary.created {
        case 0: return "Gmail conectado"
        case 1: return "1 borrador nuevo en la Bandeja"
        default: return "\(summary.created) borradores nuevos en la Bandeja"
        }
    }

    private func doneDetail(_ summary: GmailBankAlertImporter.Summary) -> String {
        if summary.found == 0 {
            return "No encontramos avisos de tu banco en los últimos seis meses."
        }
        if summary.created == 0 {
            return "Los avisos que encontramos ya estaban en la Bandeja."
        }
        return "Revisa cada borrador, elige la cuenta si falta y guárdalo."
    }

    // MARK: - Acciones

    private func connect() async {
        guard phase != .working else { return }
        phase = .working
        do {
            let summary = try await GmailBankAlertImporter.connectAndImport(
                context: modelContext, draftService: draftService)
            connectedEmail = GmailBankAlertImporter.connectedEmail
            phase = .done(summary)
        } catch CloudAuthError.cancelled {
            phase = .intro
        } catch {
            #if DEBUG
            print("GmailConnectSheet: Error: \(error)")
            #endif
            phase = .failed(error.localizedDescription)
        }
    }

    private func disconnect() async {
        do {
            try await GmailBankAlertImporter.disconnect()
        } catch {
            #if DEBUG
            print("GmailConnectSheet: Error: \(error)")
            #endif
        }
        connectedEmail = GmailBankAlertImporter.connectedEmail
        phase = .intro
    }
}
#endif
