//
//  BalanceStatusIndicator.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

struct BalanceStatusIndicator: View {
    let status: BalanceStatus

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: iconName)
                .font(DS.Typography.labelTiny).fontWeight(.bold)

            Text(statusText)
                .font(DS.Typography.labelSmall)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(backgroundColor.opacity(0.2))
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(backgroundColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch status {
        case .good: return "arrow.up.right.circle.fill"
        case .critical: return "exclamationmark.triangle.fill"
        case .normal: return "checkmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var statusText: String {
        switch status {
        case .good: return "Bueno"
        case .critical: return "Crítico"
        case .normal: return "Normal"
        case .unknown: return "--"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .good: return DS.Semantic.successForeground
        case .critical: return DS.Semantic.errorForeground
        case .normal: return DS.Semantic.successForeground
        case .unknown: return DS.Semantic.disabledForeground
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .good: return DS.Semantic.successForeground
        case .critical: return DS.Semantic.errorForeground
        case .normal: return DS.Semantic.successForeground
        case .unknown: return DS.Semantic.disabledForeground
        }
    }
}
