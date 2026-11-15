//
//  BankEmailForwardingView.swift
//  Yala
//
//  «Correo del banco» (2.3): la dirección `auto+<código>@yalainbox.com` de la persona, su cupo de prueba y una guía por
//  pasos para reenviar los avisos del banco desde Gmail, Outlook o iCloud Mail. Solo sale con los datos en la nube y
//  sesión (la fila de Ajustes la gatea `BankEmailEntryLogic.showsRow`).
//
//  La guía es un `YalaStepGuide`: se hace fuera de Yala, en el correo de la persona. El paso de Gmail que pide el código
//  de confirmación lo enseña aquí en cuanto llega a la dirección de Yala (el gateway lo guarda sin leerlo con IA).
//

import SwiftData
import SwiftUI

/// ¿Sale la fila en Ajustes? Pura, para los tests.
enum BankEmailEntryLogic {
    static func showsRow(storageIsCloud: Bool, hasSession: Bool, isGroupsFocusedShell: Bool) -> Bool {
        storageIsCloud && hasSession && !isGroupsFocusedShell
    }
}

enum BankEmailProvider: String, CaseIterable, Identifiable, Hashable {
    case gmail, outlook, icloud

    var id: String { rawValue }

    /// Nombres de producto: no se traducen.
    var name: String {
        switch self {
        case .gmail: return "Gmail"
        case .outlook: return "Outlook"
        case .icloud: return "iCloud Mail"
        }
    }

    var progressID: String {
        switch self {
        case .gmail: return StepGuideProgressStore.bankEmailGmail
        case .outlook: return StepGuideProgressStore.bankEmailOutlook
        case .icloud: return StepGuideProgressStore.bankEmailICloud
        }
    }

    /// Dónde se configura el reenvío, en la web (las apps de los tres no lo permiten).
    var settingsURL: URL? {
        switch self {
        case .gmail: return URL(string: "https://mail.google.com/mail/u/0/#settings/fwdandpop")
        case .outlook: return URL(string: "https://outlook.live.com/mail/0/options/mail/rules")
        case .icloud: return URL(string: "https://www.icloud.com/mail")
        }
    }
}

@Observable
@MainActor
final class BankEmailModel {
    enum Phase: Equatable {
        case loading
        case ready(BankEmailAddressInfo)
        case failed
    }

    private(set) var phase: Phase = .loading
    private let client: BankEmailClient

    init(client: BankEmailClient? = nil) {
        self.client = client ?? BankEmailDraftService.makeClient()
    }

    /// La dirección fija de `-uitest-bank-email`: sin red ni cuenta.
    static func uiTestInfo(withGmailCode: Bool) -> BankEmailAddressInfo {
        BankEmailAddressInfo(
            address: "auto+k7m2xq9wpb@yalainbox.com", pro: false, trialLimit: 5, trialUsed: 2, skippedQuota: 0,
            lastReceivedAtMs: nil,
            gmailConfirmation: withGmailCode ? .init(code: "482913765", receivedAtMs: Date.now.timeIntervalSince1970 * 1000) : nil)
    }

    var info: BankEmailAddressInfo? {
        if case .ready(let info) = phase { return info }
        return nil
    }

    func refresh() async {
        if UITestHooks.bankEmailFake {
            phase = .ready(Self.uiTestInfo(withGmailCode: UITestHooks.bankEmailFakeGmailCode))
            return
        }
        if info == nil { phase = .loading }
        do {
            let info = try await client.address()
            phase = .ready(info)
            BankEmailSetupStore.markSetUp()
        } catch {
            #if DEBUG
            print("BankEmailModel: Error: \(error)")
            #endif
            if info == nil { phase = .failed }
        }
    }
}

struct BankEmailForwardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.settingsListIsAlongside) private var settingsListIsAlongside
    @State private var model = BankEmailModel()
    @State private var copied = false

    var body: some View {
        YalaSettingsList {
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Image(systemName: "envelope.badge.fill")
                        .font(DS.Typography.amountLarge)
                        .foregroundStyle(.thAccentText)
                        .accessibilityHidden(true)
                    Text(L10n.BankEmail.intro)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Aire lateral del bloque, como las cabeceras de sección: con la fila sin márgenes y el texto alineado a la
                // izquierda, `sm` dejaba cortado el borde de los glifos de la primera columna (medido en la captura).
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            YalaSettingsSection(L10n.BankEmail.addressCaption) {
                addressContent
            } footer: {
                if let info = model.info {
                    Text(BankEmailCopy.quotaLine(info))
                        .accessibilityIdentifier("bank_email_quota")
                }
            }

            if let info = model.info, !info.pro, info.trialUsed >= info.trialLimit {
                YalaSettingsSection {
                    NavigationLink {
                        SubscriptionView(source: "bankEmail")
                    } label: {
                        Text(L10n.BankEmail.seePro)
                            .foregroundStyle(.thAccentText)
                    }
                    .accessibilityIdentifier("bank_email_see_pro")
                }
            }

            YalaSettingsSection(L10n.BankEmail.guidesCaption) {
                ForEach(BankEmailProvider.allCases) { provider in
                    NavigationLink(value: provider) {
                        Text(provider.name)
                            .foregroundStyle(.thPrimaryText)
                    }
                    .disabled(model.info == nil)
                    .accessibilityIdentifier("bank_email_provider_\(provider.rawValue)")
                }
            } footer: {
                Text(L10n.BankEmail.privacyFooter)
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.BankEmail.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            if !settingsListIsAlongside {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) { dismiss() }
                }
            }
        }
        .navigationDestination(for: BankEmailProvider.self) { provider in
            BankEmailGuideView(provider: provider, model: model)
        }
        .task {
            await model.refresh()
            // Con la dirección lista, lo que ya llegó pasa a la Bandeja sin esperar a la próxima vuelta a primer plano.
            await BankEmailDraftService.syncIfNeeded(context: modelContext)
        }
        .accessibilityIdentifier("bank_email_root")
    }

    @ViewBuilder
    private var addressContent: some View {
        switch model.phase {
        case .loading:
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text(L10n.BankEmail.addressLoading)
                    .foregroundStyle(.thSecondaryText)
            }
        case .failed:
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.BankEmail.addressError)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.BankEmail.retry) {
                    Task { await model.refresh() }
                }
                .accessibilityIdentifier("bank_email_retry")
            }
        case .ready(let info):
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(verbatim: info.address)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("bank_email_address")
                Button {
                    UIPasteboard.general.string = info.address
                    copied = true
                    DS.Haptic.success()
                } label: {
                    Label(copied ? L10n.BankEmail.copied : L10n.BankEmail.copyAddress,
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .accessibilityIdentifier("bank_email_copy")
            }
        }
    }
}

/// Textos que dependen del estado. Puros, para los tests.
enum BankEmailCopy {
    static func quotaLine(_ info: BankEmailAddressInfo) -> String {
        if info.pro { return L10n.BankEmail.proLine }
        if info.trialUsed >= info.trialLimit {
            return info.skippedQuota > 0
                ? L10n.BankEmail.trialExhausted + " " + L10n.BankEmail.skipped(info.skippedQuota)
                : L10n.BankEmail.trialExhausted
        }
        return L10n.BankEmail.trialUsed(info.trialUsed, info.trialLimit)
    }
}

// MARK: - Guía por correo

struct BankEmailGuideView: View {
    let provider: BankEmailProvider
    let model: BankEmailModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showSupport = false

    var body: some View {
        YalaStepGuide(
            navigationTitle: provider.name,
            rootIdentifier: "bank_email_guide_\(provider.rawValue)",
            progressID: provider.progressID,
            header: StepGuideHeader(
                systemImage: "envelope.fill",
                tint: .blue,
                title: L10n.BankEmail.guideTitle(provider.name),
                lines: [model.info?.address ?? "", L10n.BankEmail.guideLine].filter { !$0.isEmpty }),
            steps: steps,
            guarantee: L10n.BankEmail.guarantee,
            successTitle: L10n.Action.done,
            onSuccess: { StepGuideProgressStore.clear(provider.progressID); dismiss() },
            onStuck: { showSupport = true })
        .sheet(isPresented: $showSupport) {
            SupportFormSheet()
        }
    }

    private var steps: [StepGuideStep] {
        var list: [StepGuideStep] = []
        var copyStep = StepGuideStep(id: 0, title: L10n.BankEmail.stepCopyTitle, detail: L10n.BankEmail.stepCopyDetail)
        copyStep.action = StepGuideStep.Action(
            title: L10n.BankEmail.copyAddress, systemImage: "doc.on.doc",
            perform: { markDone in
                guard let address = model.info?.address else { return }
                UIPasteboard.general.string = address
                markDone()
            })
        list.append(copyStep)

        switch provider {
        case .gmail:
            var add = StepGuideStep(id: 1, title: L10n.BankEmail.gmailAddTitle, detail: L10n.BankEmail.gmailAddDetail)
            add.action = openAction(title: L10n.BankEmail.openProvider(provider.name))
            list.append(add)

            var confirm = StepGuideStep(
                id: 2, title: L10n.BankEmail.gmailConfirmTitle,
                detail: model.info?.gmailConfirmation.map { L10n.BankEmail.gmailConfirmCode($0.code) }
                    ?? L10n.BankEmail.gmailConfirmWaiting)
            if let code = model.info?.gmailConfirmation?.code {
                confirm.action = StepGuideStep.Action(
                    title: L10n.BankEmail.copyCode, systemImage: "doc.on.doc",
                    perform: { markDone in
                        UIPasteboard.general.string = code
                        markDone()
                    })
            } else {
                confirm.action = StepGuideStep.Action(
                    title: L10n.BankEmail.checkCode, systemImage: "arrow.clockwise",
                    perform: { _ in Task { await model.refresh() } })
            }
            list.append(confirm)

            list.append(StepGuideStep(id: 3, title: L10n.BankEmail.gmailFilterTitle, detail: L10n.BankEmail.gmailFilterDetail))
        case .outlook:
            var rule = StepGuideStep(id: 1, title: L10n.BankEmail.ruleTitle, detail: L10n.BankEmail.outlookRuleDetail)
            rule.action = openAction(title: L10n.BankEmail.openProvider(provider.name))
            list.append(rule)
        case .icloud:
            var rule = StepGuideStep(id: 1, title: L10n.BankEmail.ruleTitle, detail: L10n.BankEmail.icloudRuleDetail)
            rule.action = openAction(title: L10n.BankEmail.openProvider(provider.name))
            list.append(rule)
        }

        list.append(StepGuideStep(id: list.count, title: L10n.BankEmail.stepWaitTitle, detail: L10n.BankEmail.stepWaitDetail))
        return list
    }

    /// Abrir la configuración ES el paso solo si iOS la abrió; el paso en sí se hace allí.
    private func openAction(title: String) -> StepGuideStep.Action {
        StepGuideStep.Action(title: title, systemImage: "arrow.up.forward.app", perform: { markDone in
            guard let url = provider.settingsURL else { return }
            openURL(url) { accepted in
                if accepted { markDone() }
            }
        })
    }
}
