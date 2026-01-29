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

    @Query(sort: \NotificationItem.sortOrder) private var notifications: [NotificationItem]

    @State private var selectedNotification: NotificationItem?
    @State private var isCreatingNew = false
    @State private var showPermissionAlert = false
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if notifications.isEmpty {
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
                    isCreatingNew = true
                }
            }
        }
        .sheet(isPresented: $isCreatingNew) {
            NotificationEditorSheet(notification: nil) { newNotification in
                modelContext.insert(newNotification)
                try? modelContext.save()
                Task {
                    await NotificationService.shared.scheduleNotification(for: newNotification)
                }
            }
        }
        .sheet(item: $selectedNotification) { notification in
            NotificationEditorSheet(notification: notification) { _ in
                try? modelContext.save()
                Task {
                    await NotificationService.shared.scheduleNotification(for: notification)
                }
            }
        }
        .alert(
            L10n.Notifications.permissionRequired,
            isPresented: $showPermissionAlert
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
        .task {
            permissionStatus = await NotificationService.shared.checkPermissionStatus()

            // Request permission on first visit if not determined
            if permissionStatus == .notDetermined {
                let granted = await NotificationService.shared.requestPermission()
                permissionStatus = granted ? .authorized : .denied

                // If granted, schedule all active notifications
                if granted {
                    await NotificationService.shared.rescheduleAllNotifications(items: notifications)
                }
            } else if permissionStatus == .denied {
                // Show alert if previously denied
                showPermissionAlert = true
            } else if permissionStatus == .authorized || permissionStatus == .provisional {
                // Ensure active notifications are scheduled
                await NotificationService.shared.rescheduleAllNotifications(items: notifications)
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
            isCreatingNew = true
        }
        .padding(.top, 64)
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(notifications) { notification in
                NotificationCard(
                    notification: notification,
                    onToggle: { isActive in
                        notification.isActive = isActive
                        try? modelContext.save()
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
                                            try? modelContext.save()
                                        }
                                    }

                                case .denied:
                                    // Previously denied - show settings alert
                                    await MainActor.run {
                                        notification.isActive = false
                                        try? modelContext.save()
                                        showPermissionAlert = true
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
                        selectedNotification = notification
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
        modelContext.delete(notification)
        try? modelContext.save()
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
