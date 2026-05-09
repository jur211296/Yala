//
//  MainTabSelectionLogic.swift
//  Yala
//
//  Pure-logic helper for SessionState.selectMainTab(_:). Decides whether
//  a requested AppTab is currently visible in the TabView and, if not,
//  which ConfigurableTab should be added as temporary so SwiftUI can
//  mount the corresponding Tab(value:) before the binding selects it.
//

import Foundation

enum MainTabSelectionLogic {
    struct Decision: Equatable {
        let selectedTab: AppTab
        let temporaryTab: ConfigurableTab?
        let requiresDelay: Bool
    }

    /// Returns the decision for switching the main tab to `requested`,
    /// given the currently effective `TabBarConfiguration` (already filtered
    /// by onboarding mode via `TabBarConfiguration.forMode(_:stored:)`).
    ///
    /// - `.more` / `.search`: always-visible system tabs without a configurable
    ///   equivalent — direct assignment, no delay.
    /// - Tab present in `config.activeTabs`: direct assignment, no delay.
    /// - Tab absent from `config.activeTabs`: caller must set `temporaryTab`
    ///   first and wait one runloop tick (50 ms) before assigning
    ///   `selectedMainTab`, so SwiftUI mounts the new `Tab(value:)` in time.
    static func decide(requested: AppTab, config: TabBarConfiguration) -> Decision {
        guard let asConfig = requested.asConfigurable else {
            return Decision(selectedTab: requested, temporaryTab: nil, requiresDelay: false)
        }
        if config.activeTabs.contains(asConfig) {
            return Decision(selectedTab: requested, temporaryTab: nil, requiresDelay: false)
        }
        return Decision(selectedTab: requested, temporaryTab: asConfig, requiresDelay: true)
    }
}
