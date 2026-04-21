//
//  CashFlowMonthStrip.swift
//  Yala
//
//  Horizontal scrolling strip of month capsules for cash flow navigation.
//  Auto-scrolls to the selected month. Tap a capsule to select it.
//

import SwiftUI

struct CashFlowMonthStrip: View {
    let months: [CashFlowMonth]
    @Binding var selectedMonthKey: String
    let currencyCode: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(months, id: \.monthKey) { month in
                        CashFlowMonthCapsule(
                            month: month,
                            isSelected: month.monthKey == selectedMonthKey,
                            currencyCode: currencyCode
                        )
                        .id(month.monthKey)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                                selectedMonthKey = month.monthKey
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .onChange(of: selectedMonthKey) { _, newKey in
                withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                    proxy.scrollTo(newKey, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(selectedMonthKey, anchor: .center)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}
