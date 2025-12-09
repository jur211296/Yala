//
//  BalanceStatusIndicator.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

struct BalanceStatusIndicator: View {
    let status: BalanceStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .bold))

            Text(statusText)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
        case .good: return .green
        case .critical: return .red
        case .normal: return .green  // Using green for normal as per reference image
        case .unknown: return .secondary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .good: return .green
        case .critical: return .red
        case .normal: return .green
        case .unknown: return .gray
        }
    }
}
