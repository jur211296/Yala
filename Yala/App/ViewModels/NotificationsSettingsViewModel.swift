//
//  NotificationsSettingsViewModel.swift
//  Yala
//
//  ViewModel for NotificationsSettingsView - handles notification items and operations.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications

@MainActor
@Observable
final class NotificationsSettingsViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var notifications: [NotificationItem] = []

    // MARK: - UI State

    var selectedNotification: NotificationItem?
    var isCreatingNew = false
    var showPermissionAlert = false
    var permissionStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Computed Properties

    var isEmpty: Bool {
        notifications.isEmpty
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadNotifications()
    }

    // MARK: - Data Loading

    func loadNotifications() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<NotificationItem>(sortBy: [SortDescriptor(\NotificationItem.sortOrder)])
        do {
            notifications = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("NotificationsSettingsViewModel: Error loading notifications: \(error)")
            #endif
            notifications = []
        }
    }

    // MARK: - Notification Operations

    func insertNotification(_ notification: NotificationItem) {
        guard let context = modelContext else { return }
        context.insert(notification)
        do {
            try context.save()
            loadNotifications()
        } catch {
            #if DEBUG
            print("NotificationsSettingsViewModel: Error inserting notification: \(error)")
            #endif
        }
    }

    func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
            loadNotifications()
        } catch {
            #if DEBUG
            print("NotificationsSettingsViewModel: Error saving context: \(error)")
            #endif
        }
    }

    func deleteNotification(_ notification: NotificationItem) {
        guard let context = modelContext else { return }
        context.delete(notification)
        do {
            try context.save()
            loadNotifications()
        } catch {
            #if DEBUG
            print("NotificationsSettingsViewModel: Error deleting notification: \(error)")
            #endif
        }
    }

    func openEditor(for notification: NotificationItem?) {
        if let notification = notification {
            selectedNotification = notification
        } else {
            isCreatingNew = true
        }
    }

    func closeEditor() {
        selectedNotification = nil
        isCreatingNew = false
        loadNotifications()
    }
}
