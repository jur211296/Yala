//
//  CuentaSolaReglasHoja.swift
//  Yala
//
//  Lo que la parte 2 añade a la hoja de la foto (2026-11-21), en su propio modificador para no engordar el `body` de
//  `ImageSelectionView` (el CI compila con un Xcode que tipa peor: `swiftui-ds.md`):
//  - «Recordar» tras corregir la cuenta de un borrador: guarda la regla en esa cuenta o, si ya vive en otra, pregunta
//    «Ya tienes esta regla para X. ¿La paso a Y?».
//  - El permiso de voz y foto con versión: a quien aceptó el texto anterior se le vuelve a pedir UNA vez, porque desde la
//    versión 1 la foto manda también los nombres de las cuentas y las reglas en iCloud privado (decisión 1 de Jürgen,
//    21-nov). «Ahora no» deja la foto como antes, sin nombres.
//

import SwiftData
import SwiftUI

struct CuentaSolaReglasHoja: ViewModifier {
    @Binding var hoja: CuentaSolaAlLeerHoja
    /// La práctica guiada de Primeros pasos no vuelve a pedir el permiso: no es el momento.
    let isSetupTrial: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @State private var pendiente: Pendiente?
    @State private var showsDuplicate = false
    @State private var asksConsentAgain = false

    /// Una regla que ya vive en otra cuenta, a la espera de «Pasarla».
    private struct Pendiente {
        let draft: InboxDraft
        let rule: AccountCaptureRule
        let origen: Account
        let destino: Account
    }

    func body(content: Content) -> some View {
        content
            .environment(\.cuentaSolaAlLeerRecordar, CuentaSolaAlLeerRecordarAcciones(recordar: recordar, descartar: descartar))
            .alert(L10n.CuentaSolaAlLeer.Duplicate.title, isPresented: $showsDuplicate) {
                Button(L10n.CuentaSolaAlLeer.Duplicate.move) { pasar() }
                Button(L10n.Action.cancel, role: .cancel) { pendiente = nil }
            } message: {
                Text(duplicateMessage)
            }
            .background {
                Color.clear
                    .alert(L10n.AIConsent.processingTitle, isPresented: $asksConsentAgain) {
                        Button(L10n.AIConsent.processingAccept) { answerConsent(accepted: true) }
                            .keyboardShortcut(.defaultAction)
                        Button(L10n.CuentaSolaAlLeer.Consent.notNow, role: .cancel) { answerConsent(accepted: false) }
                    } message: {
                        Text(L10n.AIConsent.processingMessage)
                    }
                    .tint(Color.alertActionTint)
            }
            .onAppear(perform: askConsentAgainIfNeeded)
    }

    private var duplicateMessage: String {
        guard let pendiente else { return "" }
        return L10n.CuentaSolaAlLeer.Duplicate.message(from: pendiente.origen.name, to: pendiente.destino.name)
    }

    // MARK: - Recordar

    private func recordar(_ draft: InboxDraft, _ rule: AccountCaptureRule) {
        guard let chosen = draft.account else { return }
        let accounts = allAccounts()
        let destino = CuentaSolaReglasStore.owner(of: chosen, among: accounts)
        if let repetida = CuentaSolaReglasStore.repetida(rule, destino: destino, among: accounts) {
            pendiente = Pendiente(draft: draft, rule: rule, origen: repetida.account, destino: destino)
            showsDuplicate = true
            return
        }
        do {
            try CuentaSolaReglasStore.guardar(rule, en: destino, context: modelContext)
            confirm(draft, rule: rule, destino: destino)
        } catch {
            #if DEBUG
            print("CuentaSolaReglasHoja: Error: \(error)")
            #endif
        }
    }

    private func pasar() {
        guard let pendiente else { return }
        do {
            try CuentaSolaReglasStore.pasar(
                pendiente.rule, de: pendiente.origen, a: pendiente.destino, context: modelContext)
            confirm(pendiente.draft, rule: pendiente.rule, destino: pendiente.destino)
        } catch {
            #if DEBUG
            print("CuentaSolaReglasHoja: Error: \(error)")
            #endif
        }
        self.pendiente = nil
    }

    private func confirm(_ draft: InboxDraft, rule: AccountCaptureRule, destino: Account) {
        DS.Haptic.success()
        hoja.recordadas[ObjectIdentifier(draft)] = L10n.CuentaSolaAlLeer.Remember.done(
            AccountCaptureRule.cleaned(rule.value), destino.name)
    }

    private func descartar(_ draft: InboxDraft) {
        hoja.descartadas.insert(ObjectIdentifier(draft))
    }

    private func allAccounts() -> [Account] {
        do {
            return try modelContext.fetch(FetchDescriptor<Account>()).filter { !$0.isSystemAccount }
        } catch {
            #if DEBUG
            print("CuentaSolaReglasHoja: Error: \(error)")
            #endif
            return []
        }
    }

    // MARK: - El permiso, otra vez

    private func askConsentAgainIfNeeded() {
        guard CuentaSolaReglasConsentLogic.asksAgain(
            accepted: appPreferences.aiDataConsentAccepted,
            version: appPreferences.aiDataConsentVersion,
            askedVersion: appPreferences.aiDataConsentAskedVersion,
            isCloud: CloudSyncFlags.storageMode == .cloud,
            isSetupTrial: isSetupTrial) else { return }
        asksConsentAgain = true
    }

    private func answerConsent(accepted: Bool) {
        appPreferences.aiDataConsentAskedVersion = AIConsentRevision.processing
        if accepted { appPreferences.aiDataConsentVersion = AIConsentRevision.processing }
    }
}

/// Cuándo se vuelve a pedir el permiso de voz y foto (pura, para sus pruebas).
enum CuentaSolaReglasConsentLogic {
    /// A quien lo aceptó con un texto anterior, una sola vez por versión, fuera de la práctica guiada. En la nube no hace
    /// falta: ahí la regla «Modo nube» ya lo cubría.
    static func asksAgain(accepted: Bool, version: Int, askedVersion: Int, isCloud: Bool, isSetupTrial: Bool) -> Bool {
        accepted && version < AIConsentRevision.processing && askedVersion < AIConsentRevision.processing
            && !isCloud && !isSetupTrial
    }
}

extension View {
    func cuentaSolaReglasHoja(_ hoja: Binding<CuentaSolaAlLeerHoja>, isSetupTrial: Bool) -> some View {
        modifier(CuentaSolaReglasHoja(hoja: hoja, isSetupTrial: isSetupTrial))
    }
}
