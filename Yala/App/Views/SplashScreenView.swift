//
//  SplashScreenView.swift
//  Yala
//
//  Animated splash screen with Yala branding.
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation states
    // Logo starts at same size as launch screen (120px) then grows to 280px
    // 120/280 ≈ 0.43
    @State private var logoScale: CGFloat = 0.43
    @State private var logoOpacity: Double = 1  // Visible immediately for seamless transition
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.8
    @State private var particles: [Particle] = []
    @State private var isPulsing = false
    @State private var particleTimer: Timer?

    // Particle model
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid background
                Color.electricIndigo
                    .ignoresSafeArea()

                // Floating particles
                ForEach(particles) { particle in
                    Circle()
                        .fill(Color.white.opacity(particle.opacity))
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                }

                // Glow effect behind logo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity)

                // Logo (3:1 aspect ratio)
                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
            }
            .onAppear {
                // Generate initial particles
                generateParticles(in: geometry.size)

                // Smooth scale animation from launch size to full size
                dsWithAnimation(reduceMotion, .easeInOut(duration: 0.8)) {
                    logoScale = 1
                }

                // Glow fades in after logo grows
                dsWithAnimation(reduceMotion, .easeOut(duration: 0.6).delay(0.4)) {
                    glowOpacity = 1
                    glowScale = 1
                }

                // Start continuous animations after entrance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    startPulseAnimation()
                    startParticleAnimation(in: geometry.size)
                }
            }
            .onDisappear {
                particleTimer?.invalidate()
                particleTimer = nil
            }
        }
    }

    // MARK: - Animations

    private func startPulseAnimation() {
        dsWithAnimation(reduceMotion,
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }

        // Glow pulse
        dsWithAnimation(reduceMotion,
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            glowScale = 1.15
            glowOpacity = 0.7
        }
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<15).map { _ in
            Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 3...8),
                opacity: Double.random(in: 0.1...0.4),
                speed: CGFloat.random(in: 0.3...1.0)
            )
        }
    }

    private func startParticleAnimation(in size: CGSize) {
        // Animate particles floating upward
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            dsWithAnimation(reduceMotion, .linear(duration: 0.05)) {
                for i in particles.indices {
                    particles[i].y -= particles[i].speed
                    particles[i].x += CGFloat.random(in: -0.5...0.5)

                    // Reset particle when it goes off screen
                    if particles[i].y < -20 {
                        particles[i].y = size.height + 20
                        particles[i].x = CGFloat.random(in: 0...size.width)
                        particles[i].opacity = Double.random(in: 0.1...0.4)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplashScreenView()
}
