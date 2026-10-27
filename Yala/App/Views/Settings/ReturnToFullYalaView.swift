//
//  ReturnToFullYalaView.swift
//  Yala
//
//  La vuelta a Yala completo desde «Solo grupos» CON registros guardados (card p0iu, decisión 3 de Jürgen del
//  2026-10-26). Sin registros no hay hoja: `ContentView` vuelve directo.
//
//  Una sola hoja con fases (`swiftui-ds.md`: una cadena de dos gestos no son dos presentaciones del mismo anchor):
//  1. «Tienes N registros guardados»: «Seguir donde lo dejé» (por defecto) / «Empezar de cero» + «Exportar una copia».
//  2. «¿Seguro? Esto es definitivo.» con el recuento: un `.alert` colgado de esta hoja, no de `ContentView`.
//  3. «¿Cuál es tu cuenta principal?», con nombre y divisa de antes. NADA se borra hasta «Empezar» (D6 del Paso 0).
//
//  Vive en la hoja de `.presentFullModeActivation` (D4): hereda su sitio en la matriz de presentaciones y la absorción
//  del borrado deliberado (`isShowingFullModeActivation`).
//

import SwiftData
import SwiftUI

struct ReturnToFullYalaView: View {
    enum Outcome { case keptEverything, startedFresh }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    let summary: UsageModeLogic.SavedSummary
    let onFinished: (Outcome) -> Void
    let onNotNow: () -> Void

    private enum Phase { case choose, account, working }
    @State private var phase: Phase = .choose
    @State private var startsFresh = false
    @State private var showsConfirm = false
    @State private var showsExport = false
    @State private var showsCurrencyPicker = false
    @State private var accountName = ""
    @State private var accountCurrency: CurrencyCode = .usd
    @State private var accountType = "checking"
    @State private var accountIcon = "creditcard"
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch phase {
            case .choose: chooseContent
            case .account: accountContent
            case .working: workingContent
            }
        }
        .yalaScreenBackground(.subtle)
        .presentationDragIndicator(phase == .working ? .hidden : .visible)
        .interactiveDismissDisabled(phase != .choose)
        .alert(L10n.UsageMode.confirmTitle, isPresented: $showsConfirm) {
            Button(L10n.UsageMode.confirmButton, role: .destructive) { goToAccountStep() }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.UsageMode.confirmMessage(
                records: summary.records, accounts: summary.accounts, budgets: summary.budgets,
                inCloudAccount: CloudSyncFlags.storageMode == .cloud))
        }
        .sheet(isPresented: $showsExport) {
            ExportRecordsView()
        }
        .sheet(isPresented: $showsCurrencyPicker) {
            NavigationStack {
                CurrencySelectorView(selectedCurrency: $accountCurrency)
            }
        }
    }

    // MARK: - Fase 1 · conservar o empezar de cero

    private var chooseContent: some View {
        VStack(spacing: DS.Spacing.md) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.UsageMode.savedTitle(summary.records))
                        .font(DS.Typography.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("usage_mode_return_title")
                        .padding(.top, DS.Spacing.xl)
                    Text(rangeLine + " " + L10n.UsageMode.savedQuestion(summary.records))
                        .font(DS.Typography.body)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)

                    choice(id: "usage_mode_return_keep", title: L10n.UsageMode.keepTitle, body: L10n.UsageMode.keepBody,
                           isSelected: !startsFresh) { startsFresh = false }
                    choice(id: "usage_mode_return_fresh", title: L10n.UsageMode.freshTitle,
                           body: L10n.UsageMode.freshBody, isSelected: startsFresh) { startsFresh = true }

                    Button(L10n.UXL20D.wipeExportCopy) { showsExport = true }
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(theme.accentText)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("usage_mode_return_export")
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.UsageMode.continueAction) {
                    if startsFresh {
                        showsConfirm = true
                    } else {
                        onFinished(.keptEverything)
                    }
                }
                .accessibilityIdentifier("usage_mode_return_continue")
                Button(L10n.UsageMode.notNow) { onNotNow() }
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.accentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("usage_mode_return_not_now")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    /// «Del 12 mar al 20 oct de 2026, en 3 cuentas.» — un solo día dice «El 12 mar…».
    private var rangeLine: String {
        guard let first = summary.firstDate, let last = summary.lastDate else {
            return ""
        }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLocale.current)
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return L10n.UsageMode.savedRangeSameDay(first.formatted(style), accounts: summary.accounts)
        }
        return L10n.UsageMode.savedRange(from: first.formatted(style), to: last.formatted(style),
                                         accounts: summary.accounts)
    }

    private func choice(id: String, title: String, body: String, isSelected: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title3)
                    .foregroundStyle(isSelected ? theme.accentText : Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.primary)
                    Text(body)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(theme.accent, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(id)
    }

    // MARK: - Fase 3 · la cuenta principal

    private func goToAccountStep() {
        let prefill = UsageModeService.primaryAccountPrefill(
            context: modelContext, fallbackCurrency: appPreferences.defaultCurrencyCode.rawValue)
        accountName = prefill.name
        accountCurrency = CurrencyCode(rawValue: prefill.currencyCode) ?? appPreferences.defaultCurrencyCode
        accountType = prefill.type
        accountIcon = prefill.iconName
        errorMessage = nil
        phase = .account
    }

    private var trimmedName: String { accountName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var accountContent: some View {
        VStack(spacing: DS.Spacing.md) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Image(systemName: "creditcard.fill")
                        .font(DS.Typography.title2)
                        .foregroundStyle(theme.accentText)
                        .frame(width: 56, height: 56)
                        .background(theme.accent.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .accessibilityHidden(true)
                        .padding(.top, DS.Spacing.xl)
                    Text(L10n.UsageMode.accountTitle)
                        .font(DS.Typography.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("usage_mode_account_title")
                    Text(L10n.UsageMode.accountBody)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L10n.UsageMode.accountNameLabel)
                            .font(DS.Typography.caption.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                        TextField(L10n.UsageMode.accountNameLabel, text: $accountName)
                            .font(DS.Typography.body)
                            .padding(DS.Spacing.md)
                            .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                            .accessibilityIdentifier("usage_mode_account_name")
                    }

                    Button {
                        showsCurrencyPicker = true
                    } label: {
                        HStack {
                            Text(L10n.UsageMode.accountCurrency)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(accountCurrency.rawValue) · \(accountCurrency.localizedName)")
                                .font(DS.Typography.body)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.chevron)
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                .accessibilityHidden(true)
                        }
                        .padding(DS.Spacing.md)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("usage_mode_account_currency")

                    Text(L10n.UsageMode.accountFootnote)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Semantic.errorForeground)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("usage_mode_account_error")
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .dismissKeyboardOnTap()

            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.UsageMode.accountStart, isDisabled: trimmedName.isEmpty) {
                    start()
                }
                .accessibilityIdentifier("usage_mode_account_start")
                // Hasta «Empezar» no se ha borrado nada, y si el borrado falla la hoja no puede quedarse sin salida (se
                // cierra deslizando solo en la primera fase).
                Button(L10n.UsageMode.notNow) { onNotNow() }
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.accentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("usage_mode_account_not_now")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private var workingContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(theme.accent)
            Text(L10n.UsageMode.working)
                .font(DS.Typography.body)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("usage_mode_working")
    }

    private func start() {
        let name = trimmedName
        guard !name.isEmpty else { return }
        phase = .working
        Task { @MainActor in
            do {
                try await UsageModeService.startFresh(
                    context: modelContext, accountName: name, currencyCode: accountCurrency.rawValue,
                    accountType: accountType, iconName: accountIcon)
                onFinished(.startedFresh)
            } catch {
                #if DEBUG
                print("ReturnToFullYalaView: Error starting fresh: \(error)")
                #endif
                errorMessage = L10n.UsageMode.error
                phase = .account
            }
        }
    }
}
