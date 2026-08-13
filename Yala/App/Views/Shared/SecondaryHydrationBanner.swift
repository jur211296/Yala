//
//  SecondaryHydrationBanner.swift
//  Yala
//
//  Banner de HIDRATACIÓN: el store nace VACÍO y el runtime lo puebla con el pull normal (cursor 0).
//  Mientras el primer pull no complete, la persona vería una app "en cero" sin explicación — este chip
//  (molde del joinBanner de GroupsContainerView) muestra la fase REAL.
//
//  **Nació solo para la invitada (M1 Inc 7) y cubría medio problema.** Tras el relanzamiento del adopt,
//  el store personal del DUEÑO nace igual de vacío y se puebla igual desde el cursor 0: quien cambia de
//  móvil entra con su cuenta, reinicia, y se encuentra Yala en blanco sin una palabra. Era el mismo
//  hecho por la otra puerta, y el primer término del gate (`secondaryActive`) lo excluía.
//
//  Desde el 2026-08-12 el gate lee el MUNDO y no el camino: **se ve vacío + el motor está hidratando**.
//  Así llega a quien vuelve sin tener que enumerar por qué ruta llegó, que es justo lo que dejó fuera a
//  la re-entrada. Los dos falsos positivos que sigue evitando: quien ya tiene sus datos en pantalla
//  (no espera nada) y quien no tiene motor de nube (no hay ninguna descarga que explicar).
//
//  Poll de 1s (molde del refresh de StorageSettingsView): `hasCompletedFirstPull` no es
//  @Observable. Costo cero para el modo privado: sin motor ni descriptor, el task sale en el primero.
//

import SwiftUI

/// Decisión pura del banner (testeable en tabla).
nonisolated enum SecondaryHydrationLogic {
    /// - Parameters:
    ///   - secondaryActive: `SecondarySessionStore.isActive()`. Su store SIEMPRE nace vacío, así que no
    ///     hace falta mirar nada más — el término se conserva tal cual por eso.
    ///   - firstPullCompleted: `SyncQuiescenceCoordinator.hasCompletedFirstPull`, señal GENÉRICA del
    ///     motor. Es de sesión de proceso, por eso sola no basta para el dueño: en un arranque normal
    ///     empieza en `false` y el banner saldría cada vez.
    ///   - cloudEngineActive: hay motor que pueda estar descargando algo (`storageMode == .cloud`).
    ///   - storeLooksEmpty: la app se ve en cero. Es el término que convierte «el motor arranca» en «la
    ///     pantalla que estás mirando está vacía y por eso te lo explico».
    static func showBanner(
        secondaryActive: Bool,
        firstPullCompleted: Bool,
        cloudEngineActive: Bool,
        storeLooksEmpty: Bool
    ) -> Bool {
        guard !firstPullCompleted else { return false }
        if secondaryActive { return true }
        return cloudEngineActive && storeLooksEmpty
    }
}

struct SecondaryHydrationBanner: View {
    /// «La app se ve vacía», tal como lo mide el shell (`ContentView.checkHasExistingData`). Se recibe
    /// del anchor en vez de re-contarlo aquí: es el MISMO detector que decide el alert del Welcome, y
    /// dos detectores distintos de «hay datos» es como divergen.
    var storeLooksEmpty: Bool

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
                visible = SecondaryHydrationLogic.showBanner(
                    secondaryActive: SecondarySessionStore.isActive(),
                    firstPullCompleted: SyncQuiescenceCoordinator.shared.hasCompletedFirstPull,
                    cloudEngineActive: CloudSyncFlags.storageMode == .cloud,
                    storeLooksEmpty: storeLooksEmpty)
                // Modo privado, o hidratación completa → terminar el poll.
                guard visible else { return }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
}
