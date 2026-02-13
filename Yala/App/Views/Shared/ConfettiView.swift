//
//  ConfettiView.swift
//  Yala
//
//  Confetti celebration animation for subscription success.
//

import SwiftUI

struct ConfettiView: View {

    // MARK: - State

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    // MARK: - Configuration

    private let particleCount: Int = 50
    private let colors: [Color] = [.yellow, .orange, .pink, .purple, .blue, .green, .mint, .cyan]

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { _ in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x * size.width - 4,
                        y: particle.y * size.height - 4,
                        width: particle.size,
                        height: particle.size
                    )

                    // Draw particle based on shape
                    switch particle.shape {
                    case .circle:
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(particle.color.opacity(particle.opacity))
                        )
                    case .rectangle:
                        context.fill(
                            Path(rect),
                            with: .color(particle.color.opacity(particle.opacity))
                        )
                    case .triangle:
                        var path = Path()
                        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                        path.closeSubpath()
                        context.fill(path, with: .color(particle.color.opacity(particle.opacity)))
                    }
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            generateParticles()
            startAnimation()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Particle Generation

    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: -0.3...0),
                velocityX: CGFloat.random(in: -0.003...0.003),
                velocityY: CGFloat.random(in: 0.005...0.012),
                size: CGFloat.random(in: 6...12),
                color: colors.randomElement() ?? .yellow,
                shape: ConfettiShape.allCases.randomElement() ?? .circle,
                opacity: 1.0,
                rotation: CGFloat.random(in: 0...360)
            )
        }
    }

    private func startAnimation() {
        isAnimating = true

        // Update particle positions every frame
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
            var allOffScreen = true

            for i in particles.indices {
                // Apply velocity
                particles[i].y += particles[i].velocityY
                particles[i].x += particles[i].velocityX

                // Add gravity acceleration
                particles[i].velocityY += 0.0002

                // Add slight horizontal drift
                particles[i].velocityX += CGFloat.random(in: -0.0002...0.0002)

                // Fade out as particles fall
                if particles[i].y > 0.8 {
                    particles[i].opacity = max(0, particles[i].opacity - 0.02)
                }

                // Check if still on screen
                if particles[i].y < 1.5 && particles[i].opacity > 0 {
                    allOffScreen = false
                }
            }

            // Stop animation when all particles are off screen
            if allOffScreen {
                timer.invalidate()
                isAnimating = false
            }
        }
    }
}

// MARK: - Particle Model

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var size: CGFloat
    let color: Color
    let shape: ConfettiShape
    var opacity: Double
    var rotation: CGFloat
}

enum ConfettiShape: CaseIterable {
    case circle
    case rectangle
    case triangle
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.3)
        ConfettiView()
    }
}
