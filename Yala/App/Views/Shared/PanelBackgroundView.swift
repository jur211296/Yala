//
//  PanelBackgroundView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

// MARK: - Fondo general tipo Liquid Glass claro

struct PanelBackgroundView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Group {
            if theme.usesMaterial {
                AnimatedMeshBackground(variant: themeManager.translucentVariant)
            } else if theme.hasGradient {
                LinearGradient(
                    colors: [
                        Color.financeBackgroundTop,
                        Color.financeBackgroundBottom,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                theme.background
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Animated Mesh Background (Translucent theme)

struct AnimatedMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let variant: TranslucentVariant

    var body: some View {
        if reduceMotion {
            staticMesh
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                meshGradient(time: time)
            }
        }
    }

    private var staticMesh: some View {
        meshGradient(time: 0)
    }

    private static let indigoColors: [Color] = [
        Color(hex: "0A0A1A"), Color(hex: "1A1040"), Color(hex: "0A0A1A"),
        Color(hex: "10082A"), Color(hex: "2A1A5E"), Color(hex: "1A0A30"),
        Color(hex: "0A0A1A"), Color(hex: "150D35"), Color(hex: "0A0A1A"),
    ]
    private static let rosaColors: [Color] = [
        Color(hex: "1A0A12"), Color(hex: "401028"), Color(hex: "1A0A12"),
        Color(hex: "2A0820"), Color(hex: "5E1A40"), Color(hex: "300A28"),
        Color(hex: "1A0A12"), Color(hex: "350D28"), Color(hex: "1A0A12"),
    ]
    private static let tealColors: [Color] = [
        Color(hex: "0A1A18"), Color(hex: "103830"), Color(hex: "0A1A18"),
        Color(hex: "082A22"), Color(hex: "1A5E4A"), Color(hex: "0A3028"),
        Color(hex: "0A1A18"), Color(hex: "0D3528"), Color(hex: "0A1A18"),
    ]

    private var colors: [Color] {
        switch variant {
        case .indigo: Self.indigoColors
        case .rosa: Self.rosaColors
        case .teal: Self.tealColors
        }
    }

    private func meshGradient(time: Double) -> MeshGradient {
        let speed = 0.04  // ~25s full cycle
        let amp: Float = 0.08
        let t = time * speed * .pi * 2

        let cx = Float(0.5) + amp * Float(sin(t))
        let cy = Float(0.5) + amp * Float(sin(t + 1.5))

        let points: [SIMD2<Float>] = [
            SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.5), SIMD2(cx, cy),    SIMD2(1.0, 0.5),
            SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
        ]

        return MeshGradient(
            width: 3, height: 3,
            points: points,
            colors: colors
        )
    }
}
