//
//  GroupNotificationsOptInCard.swift
//  Yala
//
//  Auditoría UX 2.2 · L12-8 (decisión de Jürgen del 18-oct, opción B): el permiso de los avisos de grupo se pide dentro
//  de la pantalla que sigue a crear un grupo («“X” está listo») o a entrar en uno («Ya estás en «X»»), con su línea de
//  por qué. Sustituye a la alerta suelta que salía en la lista en cuanto aparecía el primer grupo.
//
//  Encender = el aviso de grupos de Yala (`NotificationItem` «groups») y, si iOS aún no preguntó, su permiso. Con el
//  permiso negado, iOS ya no vuelve a preguntar: se dice y se ofrece Ajustes.
//

import SwiftData
import SwiftUI
import UserNotifications

struct GroupNotificationsOptInCard: View {

    /// Card fptw: en la lista de Grupos, solo a quien nunca vio la tarjeta (`GroupNotificationsOptInLogic`).
    var onlyIfNeverSeen: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.openURL) private var openURL
    @Environment(\.yalaTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    /// `nil` hasta medir; la tarjeta no se pinta antes para no parpadear.
    @State private var state: GroupNotificationsOptInLogic.State?
    @State private var showsCard = false
    @State private var isWorking = false

    var body: some View {
        if let state {
            if showsCard { card(state) }
        } else {
            // Un `.task` colgado de un `Group` vacío no corre nunca (no hay vista que aparezca): la medida inicial cuelga de
            // un punto invisible que solo existe hasta que hay respuesta. Medido el 2026-10-21: la tarjeta no salía.
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
                .task { await measure(initial: true) }
        }
    }

    private func card(_ state: GroupNotificationsOptInLogic.State) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: state == .enabled ? "bell.badge.fill" : "bell.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.UXD14.notifyTitle)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    Text(state == .denied ? L10n.UXD14.notifyDenied : L10n.UXD14.notifyWhy)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            switch state {
            case .ask:
                YalaSecondaryButton(L10n.UXD14.notifyEnable, icon: "bell") {
                    Task { await activate() }
                }
                .disabled(isWorking)
                .accessibilityIdentifier("group_notifications_enable")
            case .denied:
                YalaSecondaryButton(L10n.Notifications.openSettings, icon: "gearshape") {
                    // El aviso de grupos de Yala se enciende ya: al volver con el permiso dado en Ajustes, basta con eso.
                    activateGroupsItem()
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .accessibilityIdentifier("group_notifications_settings")
            case .enabled:
                Label(L10n.UXD14.notifyEnabled, systemImage: "checkmark.circle.fill")
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Semantic.successForeground)
                    .accessibilityIdentifier("group_notifications_enabled")
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_notifications_card")
        // Volver de Ajustes con el permiso dado tiene que verse: la tarjeta vuelve a medir.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await measure(initial: false) } }
        }
    }

    // MARK: - Medir y encender

    private func authorization() async -> UNAuthorizationStatus {
        #if DEBUG
        // El aviso del sistema no es determinista en XCUITest (molde de `NotificationEditorSheet.runTestNotification`).
        if UITestHooks.notificationsDenied { return .denied }
        if UITestHooks.isActive { return .notDetermined }
        #endif
        return await NotificationService.shared.checkPermissionStatus()
    }

    private func groupsItem() -> NotificationItem? {
        let descriptor = FetchDescriptor<NotificationItem>(predicate: #Predicate { $0.typeRaw == "groups" })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("GroupNotificationsOptInCard: Error fetching groups notification: \(error)")
            #endif
            return nil
        }
    }

    private func measure(initial: Bool) async {
        let measured = GroupNotificationsOptInLogic.state(
            itemActive: groupsItem()?.isActive ?? false,
            authorization: await authorization())
        if initial {
            showsCard = GroupNotificationsOptInLogic.showsCard(
                initialState: measured,
                onlyIfNeverSeen: onlyIfNeverSeen,
                hasSeenPrompt: appPreferences.hasSeenGroupsNotificationPrompt)
            // Card fptw: vista en cualquier pantalla cuenta, para que la lista no la repita después.
            if showsCard { appPreferences.hasSeenGroupsNotificationPrompt = true }
        }
        state = measured
    }

    /// Enciende el aviso de grupos de Yala (`NotificationItem` «groups»). Sin el permiso del sistema no llega nada, pero
    /// queda listo para cuando lo dé.
    private func activateGroupsItem() {
        guard let item = groupsItem(), !item.isActive else { return }
        item.isActive = true
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("GroupNotificationsOptInCard: Error activating groups notification: \(error)")
            #endif
        }
    }

    private func activate() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        activateGroupsItem()
        #if DEBUG
        if UITestHooks.isActive {
            // Bajo XCUITest no se pide el permiso real: se da por concedido para ver el estado final.
            withAnimation { state = .enabled }
            return
        }
        #endif
        if await NotificationService.shared.checkPermissionStatus() == .notDetermined {
            _ = await NotificationService.shared.requestPermission()
        }
        DS.Haptic.light()
        await measure(initial: false)
    }
}
