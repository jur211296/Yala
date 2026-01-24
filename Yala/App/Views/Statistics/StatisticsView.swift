//
//  StatisticsView.swift
//  Yala
//
//  Statistics tab view with PanelView-style navigation.
//

import SwiftUI

struct StatisticsView: View {
    private var sessionState = SessionState.shared

    var body: some View {
        NavigationStack {
            // DetailContainerView manages its own content, navigation, and toolbar
            DetailContainerView(initialTab: sessionState.selectedDetailTab)
                .navigationTitle(L10n.Statistics.title)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
