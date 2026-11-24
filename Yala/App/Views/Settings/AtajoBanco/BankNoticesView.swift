//
//  BankNoticesView.swift
//  Yala
//
//  Ajustes › «Avisos del banco» (B2 del atajo del banco, decisión 66 de Jürgen). La propuesta lo colgaba de «Lo que Yala
//  apunta solo», que no existe; su respaldo era Ajustes, al lado de «Siri y Atajos». Arriba, los bancos que ya están
//  activos (los que la persona eligió o de los que llegó algún aviso) con su estado; abajo, «¿De qué banco?» con los
//  demás. Gratis y también con los datos en iCloud: todo se lee en el iPhone.
//
//  Encargo del 23-nov-2026: arriba se explica qué es un aviso y cómo funciona, para quien nunca usó Atajos; fuera de
//  Perú solo se ofrece «Tu banco o app» (`BankNoticeChoiceLogic`); y con los datos en la cuenta de Yala, quien recibe
//  los avisos por correo va directo a «Correo del banco», sin Atajos.
//

import SwiftUI

struct BankNoticesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.settingsListIsAlongside) private var settingsListIsAlongside
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppPreferences.self) private var appPreferences

    /// Se relee al aparecer y al volver a primer plano: la acción de Atajos escribe el App Group desde otro proceso.
    @State private var known: [BankNoticeBank] = []

    private var available: [BankNoticeBank] {
        BankNoticeChoiceLogic.addableBanks(
            regionCode: Locale.current.region?.identifier,
            mainCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
            active: known)
    }

    private var offersPeruvianBanks: Bool {
        BankNoticeChoiceLogic.offersPeruvianBanks(
            regionCode: Locale.current.region?.identifier, mainCurrencyCode: appPreferences.defaultCurrencyCode.rawValue)
    }

    /// «Correo del banco» exige los datos en la cuenta de Yala y sesión: la misma regla que su fila en Ajustes. Esta
    /// pantalla solo existe fuera de solo-grupos, así que ese eje va en `false`.
    private var offersBankEmail: Bool {
        CloudSessionRevision.shared.track()
        return UITestHooks.bankEmailFake || BankEmailEntryLogic.showsRow(
            storageIsCloud: CloudSyncFlags.storageMode == .cloud,
            hasSession: CloudAuthService.shared.hasSession,
            isGroupsFocusedShell: false)
    }

    var body: some View {
        YalaSettingsList {
            YalaSettingsSection {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.CapturaAtajoParte2.Bank.pickerTitle)
                        .font(DS.Typography.title3)
                        .foregroundStyle(.thPrimaryText)
                    Text(L10n.CapturaAtajoParte2.Bank.pickerSubtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, DS.Spacing.xs)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }

            YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.howSection) {
                howRow("bell.badge.fill", L10n.CapturaAtajoParte2.Bank.howNotice, id: "notice")
                howRow("arrow.triangle.turn.up.right.diamond.fill", L10n.CapturaAtajoParte2.Bank.howShortcut, id: "shortcut")
                howRow("tray.and.arrow.down.fill", L10n.CapturaAtajoParte2.Bank.howInbox, id: "inbox")
            } footer: {
                Text(L10n.CapturaAtajoParte2.Bank.howFooter)
            }

            if !known.isEmpty {
                YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.activeSection) {
                    ForEach(known, id: \.self) { bank in
                        NavigationLink(value: bank) {
                            BankNoticeBankRow(bank: bank, name: name(bank), statusLine: statusLine(for: bank))
                        }
                        .accessibilityIdentifier("bank_notices_active_\(bank.rawValue)")
                    }
                }
            }

            YalaSettingsSection(known.isEmpty ? nil : L10n.CapturaAtajoParte2.Bank.addSection) {
                ForEach(available, id: \.self) { bank in
                    NavigationLink(value: bank) {
                        BankNoticeBankRow(bank: bank, name: name(bank), statusLine: nil)
                    }
                    .accessibilityIdentifier("bank_notices_bank_\(bank.rawValue)")
                }
            } footer: {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    if !offersPeruvianBanks { Text(L10n.CapturaAtajoParte2.Bank.pickerOtherAloneFooter) }
                    Text(L10n.CapturaAtajoParte2.Bank.privacyFooter)
                }
            }

            if offersBankEmail {
                YalaSettingsSection(L10n.CapturaAtajoParte2.Bank.emailSection) {
                    NavigationLink {
                        BankEmailForwardingView()
                    } label: {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(L10n.CapturaAtajoParte2.Bank.emailRowTitle)
                                .font(DS.Typography.bodyBold)
                                .foregroundStyle(.thPrimaryText)
                            Text(L10n.CapturaAtajoParte2.Bank.emailRowDetail)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.thSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, DS.Spacing.xxs)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("bank_notices_email_row")
                }
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.CapturaAtajoParte2.Bank.rowTitle)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            if !settingsListIsAlongside {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        dismiss()
                    }
                }
            }
        }
        .navigationDestination(for: BankNoticeBank.self) { bank in
            BankNoticeBankView(bank: bank)
        }
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        .accessibilityIdentifier("bank_notices_root")
    }

    private func reload() {
        known = BankNoticeActivityStore.knownBanks()
    }

    private func name(_ bank: BankNoticeBank) -> String {
        BankNoticeBankView.displayName(bank, offersPeruvianBanks: offersPeruvianBanks)
    }

    private func howRow(_ icon: String, _ text: String, id: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.thSecondaryText)
                .frame(width: DS.Icon.badgeSmall)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DS.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bank_notices_how_\(id)")
    }

    private func statusLine(for bank: BankNoticeBank) -> String {
        let status = BankNoticeStatus.status(
            activity: BankNoticeActivityStore.activity(for: bank),
            settings: BankNoticeActivityStore.settings(for: bank))
        switch status {
        case .waiting: return L10n.CapturaAtajoParte2.Bank.waitingTitle
        case .working: return L10n.CapturaAtajoParte2.Bank.workingTitle
        case .silent(let days, _): return L10n.CapturaAtajoParte2.Bank.silentTitle(days)
        case .paused: return L10n.CapturaAtajoParte2.Bank.pausedTitle
        }
    }
}

/// Una fila de banco: inicial sobre su color, nombre, «Listo» (hay reglas probadas) o «Beta» (lo lee el modelo del
/// iPhone) y, si está activo, su estado.
struct BankNoticeBankRow: View {
    let bank: BankNoticeBank
    let name: String
    let statusLine: String?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            BankNoticeBankBadge(bank: bank)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(name)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.thPrimaryText)
                if let statusLine {
                    Text(statusLine)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.thSecondaryText)
                } else if bank == .other {
                    Text(L10n.CapturaAtajoParte2.Bank.pickerOtherDetail)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.thSecondaryText)
                }
            }
            Spacer(minLength: DS.Spacing.sm)
            if statusLine == nil {
                Text(bank == .other ? L10n.CapturaAtajoParte2.Bank.pickerBeta : L10n.CapturaAtajoParte2.Bank.pickerReady)
                    .font(DS.Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(.thSecondaryText)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// La inicial del banco sobre su color: sin logos (sus marcas no están en el banco de comercios del teléfono).
struct BankNoticeBankBadge: View {
    let bank: BankNoticeBank
    var diameter: CGFloat = DS.Icon.badgeLarge

    var body: some View {
        ZStack {
            Circle().fill(Self.color(for: bank))
            if bank == .other {
                Image(systemName: "building.columns.fill")
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
            } else {
                Text(String(bank.brandName.prefix(1)))
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    /// Un color fijo por banco, oscuro para que el blanco de la inicial se lea (AA).
    // A11Y-DM: colores de marca de cada banco, oscuros en los dos modos para que la inicial blanca pase AA.
    static func color(for bank: BankNoticeBank) -> Color {
        switch bank {
        case .bcp: return Color(red: 0.0, green: 0.27, blue: 0.62)
        case .yape: return Color(red: 0.45, green: 0.13, blue: 0.55)
        case .interbank: return Color(red: 0.0, green: 0.45, blue: 0.27)
        case .plin: return Color(red: 0.0, green: 0.38, blue: 0.55)
        case .bbva: return Color(red: 0.0, green: 0.27, blue: 0.51)
        case .scotiabank: return Color(red: 0.70, green: 0.05, blue: 0.10)
        case .other: return Color(red: 0.33, green: 0.33, blue: 0.38)
        }
    }
}
