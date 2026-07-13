//
//  SecondaryHydrationBanner.swift
//  Yala
//
//  Banner de HIDRATACIÓN de la sesión secundaria (M1 Inc 7): tras el relaunch de entrada, el
//  store secundario nace VACÍO y el runtime lo puebla con el pull normal (cursor 0). Mientras
//  el primer pull no complete, la invitada vería una app "en cero" sin explicación — este chip
//  (molde del joinBanner de GroupsContainerView) muestra la fase REAL.
//
//  Poll de 1s (molde del refresh de StorageSettingsView): `hasCompletedFirstPull` no es
//  @Observable. Costo cero para el dueño: sin descriptor, el task sale en el primer chequeo.
//

import SwiftUI

/// Decisión pura del banner (testeable en tabla).
nonisolated enum SecondaryHydrationLogic {
    static func showBanner(secondaryActive: Bool, firstPullCompleted: Bool) -> Bool {
        secondaryActive && !firstPullCompleted
    }
}

struct SecondaryHydrationBanner: View {
    @State private var visible = false

    var body: some View {
        Group {
            if visible {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.Welcome.Cloud.secondaryHydrationBanner)
                        .font(DS.Typography.caption)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .glassEffect()
                .accessibilityIdentifier("secondary_hydration_banner")
                .padding(.top, DS.Spacing.xs)
                .allowsHitTesting(false)
            }
        }
        .task {
            while !Task.isCancelled {
                let secondary = SecondarySessionStore.isActive()
                visible = SecondaryHydrationLogic.showBanner(
                    secondaryActive: secondary,
                    firstPullCompleted: SyncQuiescenceCoordinator.shared.hasCompletedFirstPull)
                // Dueño (sin descriptor) o hidratación completa → terminar el poll.
                guard visible else { return }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
}
