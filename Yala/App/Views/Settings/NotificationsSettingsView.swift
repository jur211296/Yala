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

    @State private var viewModel = NotificationsSettingsViewModel()
    @AppStorage("budgetAlertsEnabled") private var budgetAlertsEnabled: Bool = false

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Budget alerts toggle (SIEMPRE visible, al inicio)
                    budgetAlertsSection

                    // Notificaciones configurables
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        notificationsList
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxxl)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
        }
        .navigationTitle(L10n.Notifications.title)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "plus") {
                    viewModel.isCreatingNew = true
                }
            }
        }
        .sheet(isPresented: $viewModel.isCreatingNew, onDismiss: { viewModel.closeEditor() }) {
            NotificationEditorSheet(notification: nil) { newNotification in
                viewModel.insertNotification(newNotification)
                Task {
                    await NotificationService.shared.scheduleNotification(for: newNotification)
                }
            }
        }
        .sheet(item: $viewModel.selectedNotification) { notification in
            NotificationEditorSheet(notification: notification) { _ in
                viewModel.saveContext()
                Task {
                    await NotificationService.shared.scheduleNotification(for: notification)
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
        .padding(.top, 64)
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(viewModel.notifications) { notification in
                NotificationCard(
                    notification: notification,
                    onToggle: { isActive in
                        notification.isActive = isActive
                        viewModel.saveContext()
                        Task {
                            if isActive {
                                // Check permission status
                                let status = await NotificationService.shared.checkPermissionStatus()

                                switch status {
                                case .notDetermined:
                                    // First time - request permission
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
                                    // Previously denied - show settings alert
                                    await MainActor.run {
                                        notification.isActive = false
                                        viewModel.saveContext()
                                        viewModel.showPermissionAlert = true
                                    }

                                case .authorized, .provisional, .ephemeral:
                                    // Already authorized - schedule
                                    await NotificationService.shared.scheduleNotification(for: notification)

                                @unknown default:
                                    break
                                }
                            } else {
                                await NotificationService.shared.cancelNotification(for: notification)
                            }
                        }
                    },
                    onTap: {
                        viewModel.selectedNotification = notification
                    },
                    onDelete: notification.notificationType.isDeletable ? {
                        deleteNotification(notification)
                    } : nil
                )
            }
        }
    }

    // MARK: - Actions

    private func deleteNotification(_ notification: NotificationItem) {
        Task {
            await NotificationService.shared.cancelNotification(for: notification)
        }
        viewModel.deleteNotification(notification)
    }

    // MARK: - Budget Alerts Section

    private var budgetAlertsSection: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon (estilo NotificationCard)
            ZStack {
                Circle()
                    .fill(Color.hotPink)
                    .frame(width: 44, height: 44)

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Notifications.budgetAlertsTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(L10n.Notifications.budgetAlertsHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $budgetAlertsEnabled)
                .labelsHidden()
                .tint(Color.electricIndigo)
        }
        .padding(DS.Spacing.lg)
        .background(Color.yalaCard)
        .cornerRadius(DS.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Content
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text(notification.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text(notification.formattedTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(notification.displayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Toggle (stops propagation)
                Toggle("", isOn: $isActive)
                    .labelsHidden()
                    .tint(Color.electricIndigo)
                    .onChange(of: isActive) { _, newValue in
                        onToggle(newValue)
                    }
            }
            .padding(DS.Spacing.lg)
            .background(Color.yalaCard)
            .cornerRadius(DS.Radius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(L10n.Notifications.delete, systemImage: "trash")
                }
            }
        }
        .onChange(of: notification.isActive) { _, newValue in
            isActive = newValue
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
