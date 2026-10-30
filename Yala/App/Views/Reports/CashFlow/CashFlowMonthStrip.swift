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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(months, id: \.monthKey) { month in
                        Button {
                            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                                selectedMonthKey = month.monthKey
                            }
                        } label: {
                            CashFlowMonthCapsule(
                                month: month,
                                isSelected: month.monthKey == selectedMonthKey,
                                currencyCode: currencyCode
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("cashflow_month_capsule_\(month.monthKey)")
                        .id(month.monthKey)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                // La cápsula elegida cambia con el mes (tocarla o deslizar la lista). Implícita: el `withAnimation`
                // del toque no anima dentro de una pestaña (card 8atf).
                .animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: selectedMonthKey)
                .scrollTargetLayout()
            }
            .fadesTowardVerticalBar()
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
