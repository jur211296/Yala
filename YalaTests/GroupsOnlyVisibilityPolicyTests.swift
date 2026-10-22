//
//  GroupsOnlyVisibilityPolicyTests.swift
//  YalaTests
//
//  Pure-logic tests (Swift Testing, sin SwiftData ni UI) para el filtrado de
//  Perfil/Ajustes en modo solo-grupos.
//

import Testing
@testable import Yala

@Suite("GroupsOnlyVisibilityPolicy")
struct GroupsOnlyVisibilityPolicyTests {

    // MARK: - Themes

    @Test("Solo-grupos: solo temas free, sin Pro")
    func themes_groupsOnly_excludesPro() {
        let themes = GroupsOnlyVisibilityPolicy.selectableThemes(isGroupsOnlyShell: true)
        #expect(themes.allSatisfy { !$0.isPro })
        #expect(Set(themes) == [.system, .light, .dark, .liquidGlass])
    }

    @Test("Full: todos los temas en el orden de display")
    func themes_full_includesAll() {
        let themes = GroupsOnlyVisibilityPolicy.selectableThemes(isGroupsOnlyShell: false)
        #expect(themes == AppTheme.displayOrder)
    }

    @Test("Solo-grupos preserva el orden relativo de los free")
    func themes_groupsOnly_preservesOrder() {
        let themes = GroupsOnlyVisibilityPolicy.selectableThemes(isGroupsOnlyShell: true)
        let expectedOrder = AppTheme.displayOrder.filter { !$0.isPro }
        #expect(themes == expectedOrder)
    }

    // MARK: - Notifications

    @Test("Solo-grupos: solo la notificación de grupos")
    func notifications_groupsOnly_onlyGroups() {
        let visible = GroupsOnlyVisibilityPolicy.visibleNotificationTypes(
            NotificationType.allCases, isGroupsOnlyShell: true
        )
        #expect(visible == [.groups])
    }

    @Test("Full: todas las notificaciones")
    func notifications_full_all() {
        let visible = GroupsOnlyVisibilityPolicy.visibleNotificationTypes(
            NotificationType.allCases, isGroupsOnlyShell: false
        )
        #expect(visible == NotificationType.allCases)
    }

    @Test("Solo-grupos sin notif de grupos en la entrada → vacío")
    func notifications_groupsOnly_noGroupsType_empty() {
        let input: [NotificationType] = [.endOfDay, .lunchTime]
        let visible = GroupsOnlyVisibilityPolicy.visibleNotificationTypes(input, isGroupsOnlyShell: true)
        #expect(visible.isEmpty)
    }
}
