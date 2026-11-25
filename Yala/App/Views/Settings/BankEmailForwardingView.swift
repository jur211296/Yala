//
//  BankEmailForwardingView.swift
//  Yala
//
//  «Correo del banco» (2.3): la dirección `auto+<código>@yalainbox.com` de la persona, su cupo de prueba y una guía por
//  pasos para reenviar los avisos del banco desde Gmail, Outlook o iCloud Mail. Solo sale con los datos en la nube y
//  sesión (la fila de Ajustes la gatea `BankEmailEntryLogic.showsRow`).
//
//  La guía es un `YalaStepGuide`: se hace fuera de Yala, en el correo de la persona. El paso de Gmail que confirma la
//  dirección enseña aquí lo que manda Gmail en cuanto llega a la dirección de Yala (el gateway lo guarda sin leerlo con
//  IA): el ENLACE de confirmación, que es lo único que manda Gmail desde 2025 (medido el 2026-11-24), o el código de antes.
//  Mientras no llega, lo busca solo cada 10 s durante 2 minutos y dice en qué está (`GmailConfirmationSearch`).
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

/// La búsqueda de la confirmación de Gmail en el paso 3. Pura, para los tests.
///
/// Antes del 2026-11-24 el botón solo pedía la dirección otra vez: sin carga, sin desactivarse y sin decir nada si no había
/// llegado (Jürgen: «he apretado mil veces y no tiene una animación, ni se bloquea ni me dice nada»). Ahora la pantalla
/// busca sola cada `interval` mientras el paso está a la vista, y a los `window` deja de buscar y ofrece salidas.
struct GmailConfirmationSearch: Equatable {
    enum Phase: Equatable {
        /// Lista para buscar: la primera vez, o tras volver a la pantalla.
        case idle
        case searching
        /// Preguntó y todavía no llegó; la siguiente búsqueda va en `nextAt`.
        case notYet(nextAt: Date)
        /// No se pudo preguntar (red, servidor); se reintenta en `nextAt`.
        case failed(nextAt: Date)
        /// Pasó la ventana sin nada: no busca más sola, y el botón vuelve a abrir otra ventana.
        case gaveUp(lastFailed: Bool)
        /// Llegó el código o el enlace.
        case found
    }

    enum Result: Equatable {
        case found, notYet, failed
    }

    static let interval: TimeInterval = 10
    static let window: TimeInterval = 120

    private(set) var phase: Phase = .idle
    private(set) var windowStart: Date?

    var isSearching: Bool { phase == .searching }

    /// El botón se puede tocar al principio y cuando ya no busca sola. Entre una búsqueda y otra, espera: la pantalla dice
    /// cuánto falta y la búsqueda llega sola.
    var canSearchByHand: Bool {
        switch phase {
        case .idle, .gaveUp: return true
        case .searching, .notYet, .failed, .found: return false
        }
    }

    /// El paso vuelve a estar a la vista (al abrirlo o al volver de Gmail): ventana nueva y búsqueda en el acto.
    mutating func start(now: Date) {
        guard phase != .found, phase != .searching else { return }
        windowStart = now
        phase = .idle
    }

    func isDueForAutoSearch(now: Date) -> Bool {
        guard windowStart != nil else { return false }
        switch phase {
        case .idle: return true
        case .notYet(let next), .failed(let next): return now >= next
        case .searching, .gaveUp, .found: return false
        }
    }

    /// A mano: tras rendirse, abre otra ventana de 2 minutos.
    mutating func beginByHand(now: Date) -> Bool {
        guard canSearchByHand else { return false }
        if case .gaveUp = phase { windowStart = now }
        if windowStart == nil { windowStart = now }
        phase = .searching
        return true
    }

    mutating func beginAuto(now: Date) -> Bool {
        guard isDueForAutoSearch(now: now) else { return false }
        phase = .searching
        return true
    }

    mutating func finish(_ result: Result, now: Date) {
        if result == .found {
            phase = .found
            return
        }
        let expired = windowStart.map { now.timeIntervalSince($0) >= Self.window } ?? true
        if expired {
            phase = .gaveUp(lastFailed: result == .failed)
        } else {
            let next = now.addingTimeInterval(Self.interval)
            phase = result == .failed ? .failed(nextAt: next) : .notYet(nextAt: next)
        }
    }

    /// Segundos que faltan para la siguiente búsqueda, redondeados hacia arriba (nunca 0 mientras espera).
    func secondsLeft(now: Date) -> Int? {
        switch phase {
        case .notYet(let next), .failed(let next):
            return max(1, Int(next.timeIntervalSince(now).rounded(.up)))
        default:
            return nil
        }
    }
}

/// Qué ofrece el paso 3 según lo que llegó de Gmail. Pura, para los tests.
enum GmailConfirmationStepLogic {
    enum Offer: Equatable {
        /// El enlace de confirmación: abrirlo ES confirmar.
        case link(URL)
        /// El código de antes (Gmail ya no lo manda, pero un gateway viejo o un correo viejo pueden traerlo).
        case code(String)
        /// Nada todavía: buscar.
        case search
    }

    /// Solo enlaces `https` de Gmail: lo que el servidor mande se abre en Safari, y nada más que Google.
    static let linkHosts: Set<String> = ["mail-settings.google.com", "mail.google.com", "isolated.mail.google.com"]

    static func confirmationURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme == "https",
              let host = url.host?.lowercased(), linkHosts.contains(host), url.user == nil, url.port == nil else { return nil }
        return url
    }

    /// El enlace primero: desde 2025 Gmail no tiene dónde escribir el código.
    static func offer(for info: BankEmailAddressInfo?) -> Offer {
        if let url = confirmationURL(info?.gmailLink?.url) { return .link(url) }
        if let code = info?.gmailConfirmation?.code { return .code(code) }
        return .search
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
    private(set) var gmailSearch = GmailConfirmationSearch()
    private let fetch: @MainActor () async throws -> BankEmailAddressInfo
    /// Lo mínimo que se enseña «Buscando…» tras un toque: una respuesta en 200 ms parecería que el botón no hizo nada.
    private let minimumVisibleSearch: Duration
    /// Búsquedas hechas, para el gancho `-uitest-bank-email-gmail-link-after`.
    private var fakeSearches = 0

    init(client: BankEmailClient? = nil) {
        let client = client ?? BankEmailDraftService.makeClient()
        self.fetch = { try await client.address() }
        self.minimumVisibleSearch = .milliseconds(700)
    }

    /// Para los tests: la respuesta del servidor sin red y sin la espera mínima.
    init(fetch: @escaping @MainActor () async throws -> BankEmailAddressInfo, minimumVisibleSearch: Duration = .zero) {
        self.fetch = fetch
        self.minimumVisibleSearch = minimumVisibleSearch
    }

    static let uiTestGmailLink = "https://mail-settings.google.com/mail/vf-%5BANGjdJ8uitest%5D-Yala"

    /// La dirección fija de `-uitest-bank-email`: sin red ni cuenta.
    static func uiTestInfo(withGmailCode: Bool, withGmailLink: Bool = false) -> BankEmailAddressInfo {
        let now = Date.now.timeIntervalSince1970 * 1000
        return BankEmailAddressInfo(
            address: "auto+k7m2xq9wpb@yalainbox.com", pro: false, trialLimit: 5, trialUsed: 2, skippedQuota: 0,
            lastReceivedAtMs: nil,
            gmailConfirmation: withGmailCode ? .init(code: "482913765", receivedAtMs: now) : nil,
            gmailLink: withGmailLink ? .init(url: uiTestGmailLink, receivedAtMs: now) : nil)
    }

    var info: BankEmailAddressInfo? {
        if case .ready(let info) = phase { return info }
        return nil
    }

    var gmailConfirmationArrived: Bool { GmailConfirmationStepLogic.offer(for: info) != .search }

    func refresh() async {
        if info == nil { phase = .loading }
        do {
            let info = try await address()
            phase = .ready(info)
            if !UITestHooks.bankEmailFake { BankEmailSetupStore.markSetUp() }
        } catch {
            #if DEBUG
            print("BankEmailModel: Error: \(error)")
            #endif
            if info == nil { phase = .failed }
        }
    }

    /// Mientras el paso 3 está a la vista: busca ya y luego cada 10 s, hasta que llegue o pasen 2 minutos. La corta quien la
    /// lanzó (el `.task` del paso) al salir de la pantalla, al pasar de paso o al irse la app a segundo plano.
    func watchGmailConfirmation(now: @escaping () -> Date = { .now }) async {
        gmailSearch.start(now: now())
        while !Task.isCancelled {
            if gmailConfirmationArrived {
                gmailSearch.finish(.found, now: now())
                return
            }
            if gmailSearch.beginAuto(now: now()) {
                await runGmailSearch(byHand: false, now: now)
            }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return // cancelada: la pantalla se fue
            }
        }
    }

    /// El botón «Buscar ahora». No hace nada mientras busca o espera su turno.
    func searchGmailConfirmationByHand(now: @escaping () -> Date = { .now }) async {
        guard gmailSearch.beginByHand(now: now()) else { return }
        await runGmailSearch(byHand: true, now: now)
    }

    private func runGmailSearch(byHand: Bool, now: () -> Date) async {
        let started = ContinuousClock.now
        var result: GmailConfirmationSearch.Result
        do {
            let fresh = try await address()
            phase = .ready(fresh)
            result = gmailConfirmationArrived ? .found : .notYet
        } catch {
            #if DEBUG
            print("BankEmailModel: Error: \(error)")
            #endif
            result = .failed
        }
        if byHand {
            let elapsed = ContinuousClock.now - started
            if elapsed < minimumVisibleSearch {
                do {
                    try await Task.sleep(for: minimumVisibleSearch - elapsed)
                } catch {
                    #if DEBUG
                    print("BankEmailModel: Error: \(error)")
                    #endif
                }
            }
        }
        gmailSearch.finish(result, now: now())
        if result == .found { DS.Haptic.success() }
    }

    private struct FakeSearchFailure: Error {}

    private func address() async throws -> BankEmailAddressInfo {
        guard UITestHooks.bankEmailFake else { return try await fetch() }
        if UITestHooks.bankEmailFakeSearchFails, info != nil { throw FakeSearchFailure() }
        fakeSearches += 1
        // La primera llamada es la de la pantalla de la dirección; las búsquedas cuentan desde la segunda.
        let linkArrived = UITestHooks.bankEmailFakeGmailLink
            || UITestHooks.bankEmailFakeGmailLinkAfter.map { fakeSearches > $0 } ?? false
        return Self.uiTestInfo(withGmailCode: UITestHooks.bankEmailFakeGmailCode, withGmailLink: linkArrived)
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
                lines: [model.info?.address ?? "", L10n.CorreosBancoGuia.guideLine].filter { !$0.isEmpty },
                // Copiar la dirección, a mano en cualquier paso: sin tener que volver al primero (2026-11-23).
                accessory: model.info.map { AnyView(BankEmailGuideCopyButton(address: $0.address)) }),
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
        var copyStep = StepGuideStep(id: 0, title: L10n.CorreosBancoGuia.copyTitle, detail: L10n.CorreosBancoGuia.copyDetail)
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
            var add = StepGuideStep(id: 1, title: L10n.CorreosBancoGuia.Gmail.addTitle, detail: L10n.CorreosBancoGuia.Gmail.addDetail)
            add.action = openAction(title: L10n.BankEmail.openProvider(provider.name))
            list.append(add)

            list.append(gmailConfirmStep)

            list.append(StepGuideStep(
                id: 3, title: L10n.CorreosBancoGuia.Gmail.filterTitle, detail: L10n.CorreosBancoGuia.findBank + "\n\n" + L10n.CorreosBancoGuia.Gmail.filterDetail))
        case .outlook:
            var rule = StepGuideStep(
                id: 1, title: L10n.CorreosBancoGuia.ruleTitle, detail: L10n.CorreosBancoGuia.findBank + "\n\n" + L10n.CorreosBancoGuia.outlookRuleDetail)
            rule.action = openAction(title: L10n.BankEmail.openProvider(provider.name))
            list.append(rule)
        case .icloud:
            var rule = StepGuideStep(
                id: 1, title: L10n.CorreosBancoGuia.ruleTitle, detail: L10n.CorreosBancoGuia.findBank + "\n\n" + L10n.CorreosBancoGuia.icloudRuleDetail)
            rule.action = openAction(title: L10n.BankEmail.openProvider(provider.name))
            list.append(rule)
        }

        list.append(StepGuideStep(id: list.count, title: L10n.CorreosBancoGuia.waitTitle, detail: L10n.CorreosBancoGuia.waitDetail))
        return list
    }

    /// Paso 3 de Gmail. Con el enlace, abrirlo ES confirmar; con el código de antes, copiarlo; sin nada, buscar (solo y a
    /// mano) diciendo en qué está.
    private var gmailConfirmStep: StepGuideStep {
        switch GmailConfirmationStepLogic.offer(for: model.info) {
        case .link(let url):
            var step = StepGuideStep(id: 2, title: L10n.CorreosBancoGuia.Gmail.confirmTitle, detail: L10n.CorreosBancoGuia.Gmail.confirmLink)
            step.action = StepGuideStep.Action(title: L10n.BankEmail.confirmInGoogle, systemImage: "checkmark.seal", perform: { markDone in
                openURL(url) { accepted in
                    if accepted { markDone() }
                }
            })
            return step
        case .code(let code):
            var step = StepGuideStep(id: 2, title: L10n.CorreosBancoGuia.Gmail.confirmTitle, detail: L10n.CorreosBancoGuia.Gmail.confirmCode(code))
            step.action = StepGuideStep.Action(title: L10n.BankEmail.copyCode, systemImage: "doc.on.doc", perform: { markDone in
                UIPasteboard.general.string = code
                markDone()
            })
            return step
        case .search:
            var step = StepGuideStep(id: 2, title: L10n.CorreosBancoGuia.Gmail.confirmTitle, detail: L10n.CorreosBancoGuia.Gmail.confirmWaiting)
            let search = model.gmailSearch
            step.action = StepGuideStep.Action(
                title: search.isSearching ? L10n.BankEmail.searching : L10n.BankEmail.checkCode,
                systemImage: "arrow.clockwise",
                perform: { _ in Task { await model.searchGmailConfirmationByHand() } },
                isBusy: search.isSearching,
                isEnabled: search.canSearchByHand)
            step.footnote = AnyView(GmailConfirmationStatusView(model: model, gmailSettingsURL: provider.settingsURL))
            return step
        }
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

/// Bajo «Buscar ahora»: cuánto falta para volver a buscar, si falló la conexión, y la salida si no llega. Lanza la búsqueda
/// sola mientras está a la vista con la app delante: solo existe en el paso activo, así que pasar de paso o salir la corta.
struct GmailConfirmationStatusView: View {
    let model: BankEmailModel
    let gmailSettingsURL: URL?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
        }
        .font(DS.Typography.subheadline)
        .foregroundStyle(.thSecondaryText)
        .fixedSize(horizontal: false, vertical: true)
        // Volver de Gmail (o de segundo plano) abre otra ventana y busca en el acto.
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            await model.watchGmailConfirmation()
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch model.gmailSearch.phase {
        case .notYet:
            Text(L10n.BankEmail.gmailNotYet(model.gmailSearch.secondsLeft(now: now) ?? 1))
                .accessibilityIdentifier("bank_email_gmail_status")
        case .failed:
            Text(L10n.BankEmail.gmailSearchFailed(model.gmailSearch.secondsLeft(now: now) ?? 1))
                .accessibilityIdentifier("bank_email_gmail_status")
        case .gaveUp(let lastFailed):
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(lastFailed ? L10n.BankEmail.gmailGaveUpOffline : L10n.BankEmail.gmailGaveUp)
                    .accessibilityIdentifier("bank_email_gmail_status")
                if let gmailSettingsURL {
                    Button {
                        openURL(gmailSettingsURL)
                    } label: {
                        Label(L10n.BankEmail.openProvider("Gmail"), systemImage: "arrow.up.forward.app")
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(.thAccentText)
                            .padding(.vertical, DS.Spacing.xxs)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bank_email_gmail_open")
                }
            }
        case .idle, .searching, .found:
            EmptyView()
        }
    }
}

/// «Copiar dirección» en la cabecera de la guía: la dirección de Yala a mano en cualquier paso.
private struct BankEmailGuideCopyButton: View {
    let address: String

    @Environment(\.yalaTheme) private var theme
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = address
            copied = true
            DS.Haptic.success()
        } label: {
            Label(copied ? L10n.BankEmail.copied : L10n.BankEmail.copyAddress,
                  systemImage: copied ? "checkmark" : "doc.on.doc")
                .font(DS.Typography.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(theme.accentText)
        .accessibilityIdentifier("bank_email_guide_copy")
    }
}
