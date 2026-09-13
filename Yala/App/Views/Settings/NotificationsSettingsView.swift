//
//  NotificationsSettingsView.swift
//  Yala
//
//  Vista de configuración de notificaciones.
//

import SwiftData
import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppPreferences.self) private var appPreferences

    @State private var viewModel = NotificationsSettingsViewModel()

    private var isGroupsOnlyShell: Bool { !SessionState.shared.hasPrivateSession }

    /// En solo-grupos solo la notificación de grupos (event-driven); el resto son
    /// recordatorios/reportes/pagos personales. Regla en `GroupsOnlyVisibilityPolicy`.
    /// El maestro de avisos de Grupos (`NotificationItem` de tipo `.groups`).
    ///
    /// **Mismo criterio que el gate del servicio** (`GroupSettlementReminderService`
    /// `isGroupsNotificationActive`), incluido el fail-CERRADO cuando el item no existe: si el
    /// servicio no va a avisar, la tarjeta no debe dejar encender nada. Si los dos criterios se
    /// separan, vuelve el estado mentiroso que este cambio vino a cerrar.
    ///
    /// Se lee de `viewModel.notifications` —los mismos items que la pantalla ya tiene cargados— y no
    /// con un fetch propio, para que la tarjeta reaccione al toggle de Grupos en la misma pantalla.
    private var isGroupsMasterActive: Bool {
        viewModel.notifications.first { $0.notificationType == .groups }?.isActive ?? false
    }

    private var visibleNotifications: [NotificationItem] {
        let visibleTypes = Set(GroupsOnlyVisibilityPolicy.visibleNotificationTypes(
            NotificationType.allCases, isGroupsOnlyShell: isGroupsOnlyShell))
        return viewModel.notifications.filter { visibleTypes.contains($0.notificationType) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                    // Notificaciones configurables con budgetAlerts integrado.
                    // En solo-grupos se filtra a la notif de grupos (sin budgetAlerts ni "+").
                    if visibleNotifications.isEmpty {
                        if !isGroupsOnlyShell {
                            // Solo mostrar estas secciones cuando no hay otras notificaciones
                            settlementRemindersSection
                            budgetAlertsSection
                            emptyState
                        }
                    } else {
                        notificationsListWithBudgetAlerts
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxxl)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Notifications.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            if !isGroupsOnlyShell {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "plus", label: L10n.Action.add) {
                        viewModel.isCreatingNew = true
                    }
                    .accessibilityIdentifier("notifications_add")
                }
            }
        }
        .sheet(isPresented: $viewModel.isCreatingNew, onDismiss: { viewModel.closeEditor() }) {
            NotificationEditorSheet(notification: nil) { newNotification in
                viewModel.insertNotification(newNotification)
                Task {
                    await NotificationService.shared.scheduleNotification(for: newNotification)
                    replanPaymentSummariesIfNeeded(for: newNotification)
                }
            }
        }
        .sheet(item: $viewModel.selectedNotification, onDismiss: { viewModel.closeEditor() }) { notification in
            NotificationEditorSheet(notification: notification) { _ in
                viewModel.saveContext()
                Task {
                    await NotificationService.shared.scheduleNotification(for: notification)
                    // Cambiar la HORA del item mueve el disparo de las summaries agendadas —
                    // sin re-plan quedarían clavadas a la hora vieja.
                    replanPaymentSummariesIfNeeded(for: notification)
                }
            }
        }
        .alert(
            L10n.Notifications.permissionRequired,
            isPresented: $viewModel.showPermissionAlert
        ) {
            Button(L10n.Notifications.openSettings) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Notifications.permissionMessage)
        }
        .onAppear {
            viewModel.setContext(modelContext)
        }
        .task {
            // En UI tests no se solicita el permiso de notificaciones del sistema:
            // el prompt nativo no es determinista y bloquearía la automatización (estilo F1c).
            guard !UITestHooks.isActive else { return }

            viewModel.permissionStatus = await NotificationService.shared.checkPermissionStatus()

            // Request permission on first visit if not determined
            if viewModel.permissionStatus == .notDetermined {
                let granted = await NotificationService.shared.requestPermission()
                viewModel.permissionStatus = granted ? .authorized : .denied

                // If granted, schedule all active notifications
                if granted {
                    await NotificationService.shared.rescheduleAllNotifications(items: viewModel.notifications)
                }
            } else if viewModel.permissionStatus == .denied {
                // Show alert if previously denied
                viewModel.showPermissionAlert = true
            } else if viewModel.permissionStatus == .authorized || viewModel.permissionStatus == .provisional {
                // Ensure active notifications are scheduled
                await NotificationService.shared.rescheduleAllNotifications(items: viewModel.notifications)
            }
        }
    }

    /// Re-plan de las summaries diarias agendadas cuando el item tocado es el de pagos
    /// planificados (toggle u hora). Idempotente; no aplica a los demás tipos.
    private func replanPaymentSummariesIfNeeded(for notification: NotificationItem) {
        guard notification.notificationType == .scheduledPayments else { return }
        ScheduledPaymentNotificationService.shared.requestSummaryReplan()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState(
            icon: "bell.slash",
            title: L10n.Notifications.emptyTitle,
            message: L10n.Notifications.emptyMessage,
            actionTitle: L10n.Notifications.addNew
        ) {
            viewModel.isCreatingNew = true
        }
        .padding(.top, DS.Spacing.sheetTop)
    }

    // MARK: - Notifications List

    /// Notifications list with budgetAlertsSection at the end
    private var notificationsListWithBudgetAlerts: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(visibleNotifications) { notification in
                notificationCard(for: notification)
            }

            // Recordatorios de deuda: son de GRUPOS, así que se muestran también en modo solo-grupos
            // — al revés que las alertas de presupuesto, que son de finanzas personales. (En la rama
            // de lista vacía sí queda dentro del gate, pero ahí tampoco hay `NotificationItem`
            // `.groups` que encender, así que el toggle no serviría de nada.)
            settlementRemindersSection

            // Alertas de presupuesto: finanzas personales — ocultas en solo-grupos.
            if !isGroupsOnlyShell {
                budgetAlertsSection
            }
        }
    }

    private func notificationCard(for notification: NotificationItem) -> some View {
        NotificationCard(
            notification: notification,
            onToggle: { isActive in
                notification.isActive = isActive
                viewModel.saveContext()
                Task {
                    if isActive {
                        let status = await NotificationService.shared.checkPermissionStatus()

                        switch status {
                        case .notDetermined:
                            let granted = await NotificationService.shared.requestPermission()
                            if granted {
                                await NotificationService.shared.scheduleNotification(for: notification)
                            } else {
                                await MainActor.run {
                                    notification.isActive = false
                                    viewModel.saveContext()
                                }
                            }

                        case .denied:
                            await MainActor.run {
                                notification.isActive = false
                                viewModel.saveContext()
                                viewModel.showPermissionAlert = true
                            }

                        case .authorized, .provisional, .ephemeral:
                            await NotificationService.shared.scheduleNotification(for: notification)

                        @unknown default:
                            break
                        }
                    } else {
                        await NotificationService.shared.cancelNotification(for: notification)
                    }
                    // Toggle honesto del item de pagos: ON agenda las summaries diarias,
                    // OFF las cancela (scheduleNotification es no-op para tipos dinámicos —
                    // el re-plan es el efecto real de este toggle).
                    replanPaymentSummariesIfNeeded(for: notification)
                }
            },
            onTap: notification.notificationType.isEditable ? {
                viewModel.selectedNotification = notification
            } : {},
            onDelete: notification.notificationType.isDeletable ? {
                deleteNotification(notification)
            } : nil
        )
    }

    // MARK: - Actions

    private func deleteNotification(_ notification: NotificationItem) {
        Task {
            await NotificationService.shared.cancelNotification(for: notification)
        }
        viewModel.deleteNotification(notification)
    }

    // MARK: - Settlement Reminders Section

    /// Toggle del nudge de deuda parada. Hermano de `budgetAlertsSection`: mismo patrón de tarjeta y
    /// misma mecánica `@Bindable`.
    ///
    /// El COLOR sale del SSOT del tipo `.groups`, para que la tarjeta siga cualquier cambio de
    /// identidad de Grupos. El ICONO, en cambio, es propio y deliberadamente distinto del suyo
    /// (`person.2.fill`): la tarjeta de Grupos puede quedar justo encima con el mismo círculo morado, y
    /// dos filas idénticas que hacen cosas distintas se leen mal.
    private var settlementRemindersSection: some View {
        @Bindable var prefs = appPreferences
        return HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: NotificationType.groups.defaultColor))
                    .frame(width: 44, height: 44)

                Image(systemName: "hand.wave.fill")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Notifications.settlementRemindersTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                // Con el maestro de Grupos apagado el servicio no entrega NADA, y hasta el
                // 2026-09-08 eso pasaba en silencio: se podía encender el toggle, verlo en verde y no
                // recibir nunca un aviso. Decisión de Jürgen: que no se pueda encender, y que diga
                // por qué — un toggle encendido que no entrega nada es peor que uno apagado.
                Text(isGroupsMasterActive
                     ? L10n.Notifications.settlementRemindersHint
                     : L10n.Notifications.settlementRemindersGroupsOff)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle(L10n.Notifications.settlementRemindersTitle, isOn: $prefs.groupSettlementRemindersEnabled)
                .labelsHidden()
                .disabled(!isGroupsMasterActive)

        }
        .opacity(isGroupsMasterActive ? 1 : 0.6)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: DS.Shadow.subtle.color, radius: DS.Shadow.medium.radius, x: 0, y: DS.Shadow.medium.y)
    }

    // MARK: - Budget Alerts Section

    private var budgetAlertsSection: some View {
        @Bindable var prefs = appPreferences
        return HStack(spacing: DS.Spacing.md) {
            // Icon (estilo NotificationCard)
            ZStack {
                Circle()
                    .fill(Color.hotPink)
                    .frame(width: 44, height: 44)

                Image(systemName: "chart.bar.fill")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Notifications.budgetAlertsTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                Text(L10n.Notifications.budgetAlertsHint)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Toggle
            Toggle(L10n.Notifications.budgetAlertsTitle, isOn: $prefs.budgetAlertsEnabled)
                .labelsHidden()

        }
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: DS.Shadow.subtle.color, radius: DS.Shadow.medium.radius, x: 0, y: DS.Shadow.medium.y)
    }
}

// MARK: - Notification Card

struct NotificationCard: View {
    let notification: NotificationItem
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    @State private var isActive: Bool

    init(
        notification: NotificationItem,
        onToggle: @escaping (Bool) -> Void,
        onTap: @escaping () -> Void,
        onDelete: (() -> Void)?
    ) {
        self.notification = notification
        self.onToggle = onToggle
        self.onTap = onTap
        self.onDelete = onDelete
        self._isActive = State(initialValue: notification.isActive)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: notification.colorHex))
                        .frame(width: 44, height: 44)

                    Image(systemName: notification.iconName)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                }

                // Content
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text(notification.localizedName)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer()

                        if !notification.notificationType.isEventDriven {
                            Text(notification.formattedTime)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(notification.displayText)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Toggle (stops propagation)
                Toggle(notification.localizedName, isOn: $isActive)
                    .labelsHidden()

                    .onChange(of: isActive) { _, newValue in
                        onToggle(newValue)
                    }

                // Delete button (only for deletable notifications)
                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Semantic.errorForeground.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Action.delete)
                }
            }
            .padding(DS.Spacing.lg)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: DS.Shadow.subtle.color, radius: DS.Shadow.medium.radius, x: 0, y: DS.Shadow.medium.y)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onChange(of: notification.isActive) { _, newValue in
            isActive = newValue
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
    .previewAppPreferences()
}
