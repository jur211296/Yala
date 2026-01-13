//
//  StatisticsView.swift
//  Neto
//
//  Statistics tab view with PanelView-style navigation.
//

import SwiftUI

struct StatisticsView: View {

    var body: some View {
        NavigationStack {
            // DetailContainerView manages its own content, navigation, and toolbar
            DetailContainerView(initialTab: .trends)
                .navigationTitle(L10n.Statistics.title)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
