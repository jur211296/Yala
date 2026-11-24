//
//  BankNoticeBankView.swift
//  Yala
//
//  «Avisos del BCP» (B2 y B3 del atajo del banco): el estado de un banco, sus contadores del mes, la cuenta por defecto,
//  la pausa, la guía para activarlo (notificación o correo de Mail), un aviso de ejemplo para probar la lectura y cómo
//  quitarlo del todo.
//
//  Yala no ve la automatización: el estado sale de lo que llegó (`BankNoticeStatus`). Los atajos listos por enlace (I2)
//  necesitan publicarse desde un iPhone con la app de cada banco; mientras `BankNoticeShortcutLinks` no tenga el de un
//  banco, la guía va con los pasos a mano (I1, el respaldo que la propia propuesta deja dentro de I2).
//
//  Encargo del 23-nov-2026: abrir la pantalla ya no activa el banco. Queda «Aún no está activo» hasta que la persona
//  toca «Ya lo configuré» o llega un aviso; uno activo se puede quitar de «Activos». La guía explica Atajos para quien
//  nunca lo usó (seis pasos con los nombres de sus botones) y, con los datos en la cuenta de Yala, el correo lleva a
//  «Correo del banco» en vez de a una automatización de Mail.
//

import SwiftData
import SwiftUI

/// El enlace de iCloud del atajo listo de cada banco. Vacío hasta publicarlos (necesita un iPhone con la app del banco
/// para elegirla en el disparador). Con uno puesto, la guía ofrece «Añadir a Atajos» en el paso 1.
enum BankNoticeShortcutLinks {
    static let byBank: [BankNoticeBank: String] = [:]

    static func url(for bank: BankNoticeBank) -> URL? { byBank[bank].flatMap(URL.init(string:)) }
}

struct BankNoticeBankView: View {
    let bank: BankNoticeBank

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @Query(filter: #Predicate<Account> { $0.isSystemAccount == false && $0.isArchived == false }, sort: \Account.name)
    private var accounts: [Account]

    @State private var activity = BankNoticeActivity()
    @State private var settings = BankNoticeSettings()
    @State private var testResult: String?
    @State private var confirmsDeactivation = false

    /// El nombre del banco en la lista y en el título. Fuera de Perú, `.other` es el único que se ofrece y se llama
    /// «Tu banco o app»; con los bancos de Perú al lado, «Otro banco».
    static func displayName(_ bank: BankNoticeBank, offersPeruvianBanks: Bool = true) -> String {
        guard bank == .other else { return bank.brandName }
        return offersPeruvianBanks ? L10n.CapturaAtajoParte2.Bank.pickerOther : L10n.CapturaAtajoParte2.Bank.pickerOtherAlone
    }

    private var offersPeruvianBanks: Bool {
        BankNoticeChoiceLogic.offersPeruvianBanks(
            regionCode: Locale.current.region?.identifier, mainCurrencyCode: appPreferences.defaultCurrencyCode.rawValue)
    }

    private var name: String { Self.displayName(bank, offersPeruvianBanks: offersPeruvianBanks) }
    /// El banco dentro de una frase de la guía: «cada aviso de BCP», «cada aviso de tu banco».
    private var guideName: String { bank == .other ? L10n.CapturaAtajoParte2.Bank.guideYourBank : bank.brandName }
    /// «la app de BCP», «la app de tu banco».
    private var guideApp: String {
        bank == .other ? L10n.CapturaAtajoParte2.Bank.guideYourBankApp : L10n.CapturaAtajoParte2.Bank.guideAppOf(bank.brandName)
    }
    /// Lo que se elige en «Banco» dentro de Atajos: el valor de `BankNoticeBankChoice` («Otro banco» para `.other`).
    private var shortcutBankValue: String { bank == .other ? L10n.CapturaAtajoParte2.Bank.pickerOther : bank.brandName }
    private var isActive: Bool { BankNoticeChoiceLogic.isActive(settings: settings, activity: activity) }
    private var status: BankNoticeStatus { BankNoticeStatus.status(activity: activity, settings: settings) }

    /// «Correo del banco» exige los datos en la cuenta de Yala y sesión: la misma regla que su fila en Ajustes.
    private var offersBankEmail: Bool {
        CloudSessionRevision.shared.track()
        return UITestHooks.bankEmailFake || BankEmailEntryLogic.showsRow(
            storageIsCloud: CloudSyncFlags.storageMode == .cloud,
            hasSession: CloudAuthService.shared.hasSession,
            isGroupsFocusedShell: false)
    }

    var body: some View {
        YalaSettingsList {
            statusSection
            if activity.lastArrival != nil { monthSection }
            if isActive { settingsSection }
            if !isActive { introSection }
            guideSection
            mailSection
            testSection
            if isActive { removeSection }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        .onChange(of: settings) { _, _ in persist() }
        .accessibilityIdentifier("bank_notice_bank_\(bank.rawValue)")
        .alert(L10n.CapturaAtajoParte2.Bank.deactivateTitle(name), isPresented: $confirmsDeactivation) {
            Button(L10n.CapturaAtajoParte2.Bank.deactivateConfirm, role: .destructive) { deactivate() }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.CapturaAtajoParte2.Bank.deactivateMessage(name))
        }
    }

    // MARK: - Estado

    private var statusSection: some View {
        YalaSettingsSection {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: statusIcon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(statusTint)
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(statusTitle)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)
                        .accessibilityIdentifier("bank_notice_status_title")
                    Text(statusDetail)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .accessibilityElement(children: .combine)
            if case .silent = status {
                Button(L10n.CapturaAtajoParte2.Bank.openShortcuts) { openShortcuts() }
                    .accessibilityIdentifier("bank_notice_silent_open_shortcuts")
            }
        }
    }

    private var statusIcon: String {
        guard isActive else { return "circle.dashed" }
        switch status {
        case .waiting: return "hourglass"
        case .working: return "checkmark.circle.fill"
        case .silent: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    private var statusTint: Color {
        guard isActive else { return Color(uiColor: .secondaryLabel) }
        switch status {
        case .working: return DS.Semantic.successForeground
        case .silent: return DS.Semantic.warningForeground
        case .waiting, .paused: return Color(uiColor: .secondaryLabel)
        }
    }

    private var statusTitle: String {
        guard isActive else { return L10n.CapturaAtajoParte2.Bank.notSetUpTitle }
        switch status {
        case .waiting: return L10n.CapturaAtajoParte2.Bank.waitingTitle
        case .working: return L10n.CapturaAtajoParte2.Bank.workingTitle
        case .silent(let days, _): return L10n.CapturaAtajoParte2.Bank.silentTitle(days)
        case .paused: return L10n.CapturaAtajoParte2.Bank.pausedTitle
        }
    }

    private var statusDetail: String {
        guard isActive else { return L10n.CapturaAtajoParte2.Bank.notSetUpDetail }
        switch status {
        case .waiting: return L10n.CapturaAtajoParte2.Bank.waitingDetail
        case .working(let last): return lastNoticeLine(last)
        case .silent: return L10n.CapturaAtajoParte2.Bank.silentDetail
        case .paused: return L10n.CapturaAtajoParte2.Bank.pausedDetail
        }
    }

    private func lastNoticeLine(_ last: Date) -> String {
        let when = last.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(AppLocale.current))
        guard let movement = activity.lastMovement else { return L10n.CapturaAtajoParte2.Bank.lastNotice(when) }
        let amount = formatted(movement.amount, currencyCode: movement.currencyCode)
        let what = movement.counterparty.map { L10n.CapturaAtajoParte2.Bank.amountAt(amount, $0) } ?? amount
        return L10n.CapturaAtajoParte2.Bank.lastNoticeWith(when, what)
    }

    // MARK: - Este mes

    private var monthSection: some View {
        let counts = activity.counts(for: .now)
        return YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.monthSection) {
            countRow(L10n.CapturaAtajoParte2.Bank.monthRead, counts.read, id: "read")
            countRow(L10n.CapturaAtajoParte2.Bank.monthNotUnderstood, counts.notUnderstood, id: "not_understood")
            countRow(L10n.CapturaAtajoParte2.Bank.monthNotPurchases, counts.notPurchases, id: "not_purchases")
        } footer: {
            Text(L10n.CapturaAtajoParte2.Bank.monthFooter)
        }
    }

    private func countRow(_ title: String, _ value: Int, id: String) -> some View {
        HStack {
            Text(title).font(DS.Typography.body).foregroundStyle(.thPrimaryText)
            Spacer()
            Text(value.formatted()).font(DS.Typography.bodyBold).foregroundStyle(.thPrimaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bank_notice_count_\(id)")
    }

    // MARK: - Ajustes del banco

    private var settingsSection: some View {
        YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.settingsSection) {
            Picker(L10n.CapturaAtajoParte2.Bank.defaultAccount, selection: $settings.defaultAccountShortcutID) {
                Text(L10n.CapturaAtajoParte2.Bank.defaultAccountNone).tag(UUID?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(UUID?.some(account.shortcutID))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("bank_notice_default_account")
            YalaSettingsToggleRow(L10n.CapturaAtajoParte2.Bank.pause, isOn: $settings.isPaused)
                .accessibilityIdentifier("bank_notice_pause")
        } footer: {
            Text(L10n.CapturaAtajoParte2.Bank.defaultAccountFooter)
        }
    }

    // MARK: - Guía

    // MARK: - Antes de empezar

    /// Qué es Atajos y qué es una automatización, en una frase, para quien nunca los usó.
    private var introSection: some View {
        YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.introSection) {
            Text(L10n.CapturaAtajoParte2.Bank.introDetail(guideName))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, DS.Spacing.xxs)
                .accessibilityIdentifier("bank_notice_intro")
        }
    }

    private var guideSection: some View {
        YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.guideSection) {
            guideStep(1, L10n.CapturaAtajoParte2.Bank.guideStep1Title, L10n.CapturaAtajoParte2.Bank.guideStep1Detail)
            guideStep(2, L10n.CapturaAtajoParte2.Bank.guideStep2Title, L10n.CapturaAtajoParte2.Bank.guideStep2Detail)
            guideStep(3, L10n.CapturaAtajoParte2.Bank.guideStep3Title(guideApp), L10n.CapturaAtajoParte2.Bank.guideStep3Detail(guideApp))
            guideStep(4, L10n.CapturaAtajoParte2.Bank.guideStep4Title, L10n.CapturaAtajoParte2.Bank.guideStep4Detail)
            guideStep(5, L10n.CapturaAtajoParte2.Bank.guideStep5Title, L10n.CapturaAtajoParte2.Bank.guideStep5Detail(shortcutBankValue))
            guideStep(6, L10n.CapturaAtajoParte2.Bank.guideStep6Title, L10n.CapturaAtajoParte2.Bank.guideStep6Detail)
            if let link = BankNoticeShortcutLinks.url(for: bank) {
                Button(L10n.CapturaAtajoParte2.Bank.addShortcut) { open(link) }
                    .accessibilityIdentifier("bank_notice_add_shortcut")
            } else {
                Button(L10n.CapturaAtajoParte2.Bank.openShortcuts) { openShortcuts() }
                    .accessibilityIdentifier("bank_notice_open_shortcuts")
            }
            if !isActive {
                Button(L10n.CapturaAtajoParte2.Bank.confirmSetup) { confirmSetup() }
                    .font(DS.Typography.bodyBold)
                    .accessibilityIdentifier("bank_notice_confirm_setup")
            }
        } footer: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L10n.CapturaAtajoParte2.Bank.guidePreview(name))
                if bank == .other { Text(L10n.CapturaAtajoParte2.Bank.guideOtherNote) }
            }
        }
    }

    private func guideStep(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Text(number.formatted())
                .font(DS.Typography.labelSmall.weight(.bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                .background(Circle().fill(theme.accent))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title).font(DS.Typography.bodyBold).foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if !detail.isEmpty {
                    Text(detail)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bank_notice_guide_step_\(number)")
    }

    // MARK: - Correo de Mail (B3)

    private var mailSection: some View {
        YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.mailSection) {
            // Con los datos en la cuenta de Yala, el correo se reenvía a la dirección de Yala: sin automatización de Mail.
            Text(offersBankEmail ? L10n.CapturaAtajoParte2.Bank.mailCloudDetail : L10n.CapturaAtajoParte2.Bank.mailDetail)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, DS.Spacing.xxs)
                .accessibilityIdentifier("bank_notice_mail_detail")
            if offersBankEmail {
                NavigationLink {
                    BankEmailForwardingView()
                } label: {
                    Text(L10n.CapturaAtajoParte2.Bank.mailCloudButton)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thAccentText)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("bank_notice_mail_open_bank_email")
            }
        }
    }

    // MARK: - Probar

    private var testSection: some View {
        YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.testSection) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.CapturaAtajoParte2.Bank.testDetail(name))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(BankNoticeSamples.text(for: bank).replacingOccurrences(of: "\n", with: " · "))
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.thSecondaryText)
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(Color(uiColor: .tertiarySystemFill)))
                if let testResult {
                    Label(testResult, systemImage: "text.viewfinder")
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)
                        .accessibilityIdentifier("bank_notice_test_result")
                }
            }
            .padding(.vertical, DS.Spacing.xxs)
            Button(L10n.CapturaAtajoParte2.Bank.testButton) { runSample() }
                .accessibilityIdentifier("bank_notice_test_button")
        }
    }

    private func runSample() {
        Task { @MainActor in
            let entry = await BankNoticeIntent.read(
                text: BankNoticeSamples.text(for: bank), bankHint: bank, modelReader: BankNoticeModelReader.read)
            testResult = Self.resultLine(entry.reading, format: formatted)
            DS.Haptic.selection()
        }
    }

    /// Lo que leyó la prueba, en una frase.
    static func resultLine(_ reading: BankNoticeReading, format: (Decimal, String?) -> String) -> String {
        switch reading {
        case .movement(let movement, _):
            let amount = format(movement.amount, movement.currencyCode)
            guard let who = movement.counterparty else { return L10n.CapturaAtajoParte2.Bank.testAmountOnly(amount) }
            return movement.isExpense
                ? L10n.CapturaAtajoParte2.Bank.testExpense(amount, who)
                : L10n.CapturaAtajoParte2.Bank.testIncome(amount, who)
        case .notUnderstood:
            return L10n.CapturaAtajoParte2.Bank.testNotUnderstood
        case .notAMovement:
            return L10n.CapturaAtajoParte2.Bank.testNotAMovement
        }
    }

    // MARK: - Quitarlo

    private var removeSection: some View {
        YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.removeSection) {
            guideStep(1, L10n.CapturaAtajoParte2.Bank.removeStep1(name), "")
                .accessibilityIdentifier("bank_notice_remove_step_1")
            guideStep(2, L10n.CapturaAtajoParte2.Bank.removeStep2, "")
                .accessibilityIdentifier("bank_notice_remove_step_2")
            Button(L10n.CapturaAtajoParte2.Bank.deactivate, role: .destructive) { confirmsDeactivation = true }
                .accessibilityIdentifier("bank_notice_deactivate")
        }
    }

    // MARK: - Acciones

    private func reload() {
        activity = BankNoticeActivityStore.activity(for: bank)
        settings = BankNoticeActivityStore.settings(for: bank)
        // Abrir la pantalla ya no activa el banco (encargo del 23-nov-2026): lo activa «Ya lo configuré» o un aviso.
    }

    private func confirmSetup() {
        // El `onChange(of: settings)` lo guarda.
        settings = BankNoticeChoiceLogic.confirmingSetup(settings)
        DS.Haptic.success()
    }

    private func deactivate() {
        BankNoticeActivityStore.deactivate(bank)
        DS.Haptic.warning()
        dismiss()
    }

    private func persist() {
        BankNoticeActivityStore.save(settings, for: bank)
    }

    private func openShortcuts() {
        guard let url = URL(string: "shortcuts://") else { return }
        open(url)
    }

    private func open(_ url: URL) {
        openURL(url)
    }

    private func formatted(_ amount: Decimal, currencyCode: String?) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        guard let currencyCode else { return value.formatted(.number.precision(.fractionLength(2))) }
        return appPreferences.currency(value, currencyCode: currencyCode)
    }
}
