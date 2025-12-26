//
//  CaptureModeChipsView.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import SwiftUI

// MARK: - Capture Mode Chips View

/// Chips horizontales para seleccionar el modo de captura
struct CaptureModeChipsView: View {
    @Binding var selectedMode: CaptureMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CaptureMode.allCases) { mode in
                    CaptureModeChip(
                        mode: mode,
                        isSelected: selectedMode == mode
                    ) {
                        if mode.isAvailable {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedMode = mode
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Capture Mode Chip

struct CaptureModeChip: View {
    let mode: CaptureMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 14, weight: .medium))

                Text(mode.rawValue)
                    .font(.subheadline.weight(.medium))

                if !mode.isAvailable {
                    Text("Próximamente")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.electricIndigo : Color.netoCard)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .foregroundStyle(isSelected ? .white : (mode.isAvailable ? .primary : .secondary))
            .opacity(mode.isAvailable ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!mode.isAvailable)
    }
}

#Preview {
    VStack {
        CaptureModeChipsView(selectedMode: .constant(.manual))
    }
    .padding(.vertical)
    .background(Color.netoBackground)
}
