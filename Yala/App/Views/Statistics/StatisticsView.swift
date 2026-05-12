//
//  StatisticsView.swift
//  Yala
//
//  Statistics tab view with PanelView-style navigation.
//

import SwiftUI

struct StatisticsView: View {
    @Environment(SessionState.self) private var sessionState

    var body: some View {
        NavigationStack {
            // DetailContainerView manages its own content, navigation, toolbar,
            // and navigation title (scroll-driven inline title per tab).
            DetailContainerView(initialTab: sessionState.selectedDetailTab)
        }
    }
}
