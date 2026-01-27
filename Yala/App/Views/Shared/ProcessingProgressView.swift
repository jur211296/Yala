//
//  ProcessingProgressView.swift
//  Yala
//
//  Reusable processing progress component with two modes:
//  - Determinate: capsule progress bar (e.g., images 2/5)
//  - Stepped: sequential circles connected by lines (e.g., voice steps)
//

import SwiftUI

struct ProcessingProgressView: View {

    enum Mode {
        /// Capsule progress bar showing current/total (e.g., image processing)
        case determinate(current: Int, total: Int)
        /// Sequential step circles connected by lines (e.g., voice processing)
        case stepped(currentStep: Int, steps: [String])
    }

    let mode: Mode
    let accentColor: Color
    let statusText: String

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            // Main processing circle
            processingCircle

            // Status text
            VStack(spacing: DS.Spacing.sm) {
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(.primary)

                progressIndicator
            }

            Spacer()
        }
    }

    // MARK: - Processing Circle

    private var processingCircle: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 50,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .blur(radius: 10)

            // Main circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.8), accentColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: accentColor.opacity(0.4), radius: 20, x: 0, y: 8)

            // Glass overlay
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 120, height: 120)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Spinner
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        }
    }

    // MARK: - Progress Indicator

    @ViewBuilder
    private var progressIndicator: some View {
        switch mode {
        case .determinate(let current, let total):
            determinateProgress(current: current, total: total)
        case .stepped(let currentStep, let steps):
            steppedProgress(currentStep: currentStep, steps: steps)
        }
    }

    // MARK: - Determinate (Capsule Bar)

    private func determinateProgress(current: Int, total: Int) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            if total > 1 {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(accentColor.opacity(0.15))
                            .frame(height: 8)

                        // Fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(8, geometry.size.width * CGFloat(current) / CGFloat(total)),
                                height: 8
                            )
                            .animation(.easeInOut(duration: 0.3), value: current)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, DS.Spacing.xxxxl)

                // Counter text
                Text("\(current)/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.Image.processingSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Stepped (Circles + Lines)

    private func steppedProgress(currentStep: Int, steps: [String]) -> some View {
        VStack(spacing: DS.Spacing.md) {
            // Step circles with connecting lines
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if index > 0 {
                        // Connecting line
                        Rectangle()
                            .fill(index <= currentStep ? accentColor : Color.secondary.opacity(0.2))
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }

                    // Step circle
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? accentColor : Color.secondary.opacity(0.15))
                            .frame(width: 28, height: 28)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)

                        if index < currentStep {
                            // Completed checkmark
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        } else if index == currentStep {
                            // Current step: pulsing dot
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        } else {
                            // Future step: number
                            Text("\(index + 1)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)

            // Current step label
            if currentStep < steps.count {
                Text(steps[currentStep])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }
}

#Preview("Determinate") {
    ProcessingProgressView(
        mode: .determinate(current: 2, total: 5),
        accentColor: .teal,
        statusText: "Analizando imágenes"
    )
    .background(Color.yalaBackground)
}

#Preview("Stepped") {
    ProcessingProgressView(
        mode: .stepped(currentStep: 1, steps: ["Transcribiendo", "Analizando", "Guardando"]),
        accentColor: .electricIndigo,
        statusText: "Procesando audio"
    )
    .background(Color.yalaBackground)
}
