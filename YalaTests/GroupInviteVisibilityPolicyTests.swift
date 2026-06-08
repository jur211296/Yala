//
//  GroupInviteVisibilityPolicyTests.swift
//  YalaTests
//
//  Pure-logic tests (Swift Testing, sin SwiftData ni UI) para el filtrado de
//  Perfil/Ajustes en modo solo-grupos.
//

import Testing
@testable import Yala

@Suite("GroupInviteVisibilityPolicy")
struct GroupInviteVisibilityPolicyTests {

    // MARK: - Themes

    @Test("Solo-grupos: solo temas free, sin Pro")
    func themes_groupInvite_excludesPro() {
        let themes = GroupInviteVisibilityPolicy.selectableThemes(isGroupInvite: true)
        #expect(themes.allSatisfy { !$0.isPro })
        #expect(Set(themes) == [.system, .light, .dark, .liquidGlass])
    }

    @Test("Full: todos los temas en el orden de display")
    func themes_full_includesAll() {
        let themes = GroupInviteVisibilityPolicy.selectableThemes(isGroupInvite: false)
        #expect(themes == AppTheme.displayOrder)
    }

    @Test("Solo-grupos preserva el orden relativo de los free")
    func themes_groupInvite_preservesOrder() {
        let themes = GroupInviteVisibilityPolicy.selectableThemes(isGroupInvite: true)
        let expectedOrder = AppTheme.displayOrder.filter { !$0.isPro }
        #expect(themes == expectedOrder)
    }

    // MARK: - Notifications

    @Test("Solo-grupos: solo la notificación de grupos")
    func notifications_groupInvite_onlyGroups() {
        let visible = GroupInviteVisibilityPolicy.visibleNotificationTypes(
            NotificationType.allCases, isGroupInvite: true
        )
        #expect(visible == [.groups])
    }

    @Test("Full: todas las notificaciones")
    func notifications_full_all() {
        let visible = GroupInviteVisibilityPolicy.visibleNotificationTypes(
            NotificationType.allCases, isGroupInvite: false
        )
        #expect(visible == NotificationType.allCases)
    }

    @Test("Solo-grupos sin notif de grupos en la entrada → vacío")
    func notifications_groupInvite_noGroupsType_empty() {
        let input: [NotificationType] = [.endOfDay, .lunchTime]
        let visible = GroupInviteVisibilityPolicy.visibleNotificationTypes(input, isGroupInvite: true)
        #expect(visible.isEmpty)
    }
}
