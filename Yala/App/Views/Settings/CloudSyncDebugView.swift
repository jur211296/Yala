//
//  CloudSyncDebugView.swift
//  Yala
//
//  Panel de diagnóstico del Modo Nube — SOLO `DEV_BUILD` (tooling interno). Vehículo del e2e de device
//  del I7c (primer `signInWithIdToken` real contra staging) y semilla del A2 del roadmap.
//
//  ALCANCE EXPLÍCITO: Sign in with Apple · Claim account · Sign out. NO incluye "run sync cycle" — un
//  ciclo sobre el `mainContext` real subiría/drenaría datos reales del owner a staging y asignaría
//  syncIDs al store de producción; eso es el dogfooding de I10, no I7c.
//
//  Strings HARDCODED a propósito: es tooling `DEV_BUILD`, NO copy de usuario → fuera del pipeline de
//  l10n (no hay keys que mantener en 16 locales). Reglas UI del repo igualmente respetadas: DS tokens,
//  `.yalaScreenBackground(.subtle)` (stack de Settings), Button + contentShape.
//

#if DEV_BUILD
import DeviceCheck
import SwiftUI
import UIKit

@MainActor
@Observable
final class CloudSyncDebugModel {
    var isWorking = false
    var lastMessage: String?
    var lastClaimState: String?
    var attestStatus: String?
    var credentialStatus: String?

    private let auth = CloudAuthService.shared
    private let accountClient = CloudAccountClient()

    var isConfigured: Bool { CloudBackendConfig.isConfigured }
    var configLabel: String {
        guard let url = CloudBackendConfig.supabaseURL else { return "unconfigured (prod placeholder)" }
        return "staging · \(url.host ?? url.absoluteString)"
    }
    var sessionLabel: String {
        guard let sub = auth.currentUserID else { return "signed out" }
        let short = String(sub.prefix(8))
        if let expiry = auth.sessionExpiry {
            return "user \(short)… · exp \(expiry.formatted(date: .omitted, time: .standard))"
        }
        return "user \(short)…"
    }
    var attestSupportedLabel: String {
        DCAppAttestService.shared.isSupported ? "supported" : "unsupported (sim → dev bypass)"
    }

    func signIn() async {
        isWorking = true; defer { isWorking = false }
        do {
            try await auth.signInWithApple()
            lastMessage = "Sign in OK — \(sessionLabel)"
        } catch {
            lastMessage = "Sign in failed: \(error.localizedDescription)"
        }
        await refreshCredential()
    }

    func claim() async {
        isWorking = true; defer { isWorking = false }
        guard let jwt = await auth.accessToken() else {
            lastMessage = "Claim skipped: no session (sign in first)"
            return
        }
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "yala-debug-device"
        let outcome = await accountClient.claim(jwt: jwt, deviceID: deviceID, provider: "apple")
        switch outcome {
        case .success(let state):
            lastClaimState = "\(state)"
            lastMessage = "Claim OK → \(state)"
        case .sessionExpired(let detail):
            lastMessage = "Claim 401 (re-sign): \(detail)"
        case .accountUnavailable(let detail):
            lastMessage = "Claim 403: \(detail)"
        case .transient(let detail):
            lastMessage = "Claim transient: \(detail)"
        }
    }

    func signOut() async {
        isWorking = true; defer { isWorking = false }
        await auth.signOut()
        lastClaimState = nil
        lastMessage = "Signed out — \(sessionLabel)"
        await refreshCredential()
    }

    func refreshAttest() async {
        isWorking = true; defer { isWorking = false }
        do {
            _ = try await AppAttestClient.shared.currentSessionToken()
            attestStatus = "token OK"
        } catch {
            attestStatus = "token failed: \(error)"
        }
    }

    /// Estado de la credencial de Apple (mitigación #23) — visible en el e2e del owner. En sim el
    /// query puede fallar (SIWA es device-only); el label lo refleja sin romper nada.
    func refreshCredential() async {
        credentialStatus = await auth.credentialStateDescription() ?? "no apple user captured"
    }
}

struct CloudSyncDebugView: View {
    @State private var model = CloudSyncDebugModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                stateCard
                actionsCard
                if let message = model.lastMessage {
                    Text(message)
                        .font(DS.Typography.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.lg)
                }
                Text("DEV_BUILD only · staging. No incluye ‘run sync cycle’ (eso toca datos reales — es I10).")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DS.Spacing.lg)
            }
            .padding(.vertical, DS.Spacing.xxl)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle("Modo Nube · Auth")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.refreshAttest()
            await model.refreshCredential()
        }
    }

    private var stateCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            row("Config", model.configLabel)
            row("Session", model.sessionLabel)
            row("Attest", model.attestSupportedLabel)
            if let attestStatus = model.attestStatus {
                row("Attest token", attestStatus)
            }
            if let credentialStatus = model.credentialStatus {
                row("Credential", credentialStatus)
            }
            if let claim = model.lastClaimState {
                row("Last claim", claim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var actionsCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            actionButton("Sign in with Apple", disabled: !model.isConfigured) {
                await model.signIn()
            }
            actionButton("Claim account", disabled: !model.isConfigured) {
                await model.claim()
            }
            actionButton("Sign out", disabled: !model.isConfigured) {
                await model.signOut()
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func actionButton(
        _ title: String, disabled: Bool, action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(DS.Typography.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .disabled(disabled || model.isWorking)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(DS.Typography.caption.monospaced())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
