//
//  NotificationsSettingsViewModelTests.swift
//  YalaTests
//
//  Tests for NotificationsSettingsViewModel UI state management.
//

import Foundation
import SwiftData
import Testing
import UserNotifications

@testable import Yala

struct NotificationsSettingsViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_notificationsEmpty() {
        let vm = NotificationsSettingsViewModel()
        #expect(vm.notifications.isEmpty)
    }

    @MainActor @Test func initialState_isEmptyTrue() {
        let vm = NotificationsSettingsViewModel()
        #expect(vm.isEmpty == true)
    }

    @MainActor @Test func initialState_selectedNotificationNil() {
        let vm = NotificationsSettingsViewModel()
        #expect(vm.selectedNotification == nil)
    }

    @MainActor @Test func initialState_isCreatingNewFalse() {
        let vm = NotificationsSettingsViewModel()
        #expect(vm.isCreatingNew == false)
    }

    @MainActor @Test func initialState_showPermissionAlertFalse() {
        let vm = NotificationsSettingsViewModel()
        #expect(vm.showPermissionAlert == false)
    }

    @MainActor @Test func initialState_permissionStatusNotDetermined() {
        let vm = NotificationsSettingsViewModel()
        #expect(vm.permissionStatus == .notDetermined)
    }

    // MARK: - openEditor

    @MainActor @Test func openEditor_withNotification_setsSelectedNotification() {
        let vm = NotificationsSettingsViewModel()
        let notification = NotificationItem(
            name: "Test",
            text: "Test text",
            hour: 12,
            minute: 0,
            type: .custom
        )

        vm.openEditor(for: notification)

        #expect(vm.selectedNotification != nil)
        #expect(vm.selectedNotification?.name == "Test")
        #expect(vm.isCreatingNew == false)
    }

    @MainActor @Test func openEditor_withNil_setsIsCreatingNew() {
        let vm = NotificationsSettingsViewModel()

        vm.openEditor(for: nil)

        #expect(vm.selectedNotification == nil)
        #expect(vm.isCreatingNew == true)
    }

    // MARK: - closeEditor

    @MainActor @Test func closeEditor_clearsSelectedNotification() {
        let vm = NotificationsSettingsViewModel()
        let notification = NotificationItem(
            name: "Test",
            text: "Test text",
            hour: 12,
            minute: 0,
            type: .custom
        )
        vm.openEditor(for: notification)
        #expect(vm.selectedNotification != nil)

        vm.closeEditor()

        #expect(vm.selectedNotification == nil)
        #expect(vm.isCreatingNew == false)
    }

    @MainActor @Test func closeEditor_clearsIsCreatingNew() {
        let vm = NotificationsSettingsViewModel()
        vm.openEditor(for: nil)
        #expect(vm.isCreatingNew == true)

        vm.closeEditor()

        #expect(vm.isCreatingNew == false)
    }

    // MARK: - openEditor sequence

    @MainActor @Test func openEditor_sequence_editThenNew() {
        let vm = NotificationsSettingsViewModel()
        let notification = NotificationItem(
            name: "Existing",
            text: "Text",
            hour: 8,
            minute: 30,
            type: .endOfDay
        )

        // First open for edit
        vm.openEditor(for: notification)
        #expect(vm.selectedNotification?.name == "Existing")
        #expect(vm.isCreatingNew == false)

        // Close
        vm.closeEditor()
        #expect(vm.selectedNotification == nil)

        // Then open for new
        vm.openEditor(for: nil)
        #expect(vm.selectedNotification == nil)
        #expect(vm.isCreatingNew == true)
    }
}

/*
Tests generated:
1. initialState_notificationsEmpty - Notifications start empty
2. initialState_isEmptyTrue - isEmpty is true initially
3. initialState_selectedNotificationNil - No notification selected
4. initialState_isCreatingNewFalse - Not creating new initially
5. initialState_showPermissionAlertFalse - Permission alert not shown
6. initialState_permissionStatusNotDetermined - Default permission status
7. openEditor_withNotification_setsSelectedNotification - Opens editor for existing
8. openEditor_withNil_setsIsCreatingNew - Opens editor for new
9. closeEditor_clearsSelectedNotification - Closes edit mode
10. closeEditor_clearsIsCreatingNew - Closes create mode
11. openEditor_sequence_editThenNew - Full edit/create cycle

Cases NOT covered (require ModelContext):
- insertNotification (needs context.insert + save)
- deleteNotification (needs context.delete + save)
- saveContext (needs context.save)
- loadNotifications (requires ModelContext)
*/
