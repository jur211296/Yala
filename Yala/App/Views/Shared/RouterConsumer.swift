//
//  RouterConsumer.swift
//  Yala
//
//  View extension that wires a view up as an AppRouter consumer. Toggles
//  readiness on .task / .onDisappear and hooks a drain closure to revision
//  changes. Each consumer owns its own switch over RouterIntent cases.
//

import SwiftUI

extension View {
    /// Declares this view as a drain consumer for `consumer` in its window.
    ///
    /// Readiness is set on `.task` and cleared on `.onDisappear`. The
    /// `onDrain` closure runs whenever `AppRouter.shared.revision` changes
    /// AND when the view first mounts (via the `.task` bump). Consumers
    /// should use the single-intent drain pattern (NOT `while`) to avoid
    /// re-entrance.
    ///
    /// **La ventana sale del entorno** (`SceneNavigation`, fase 4 del carril adaptativo): el consumidor queda listo
    /// en SU ventana, y el `onDrain` drena con el mismo id. Sin `SceneNavigation` en el entorno (previews) queda listo
    /// sin ventana, que drena todo como antes.
    ///
    /// Example:
    /// ```
    /// .routerConsumer(.panel) {
    ///     if let intent = AppRouter.shared.drainNext(for: .panel, in: navigation.id) {
    ///         handle(intent)
    ///     }
    /// }
    /// ```
    func routerConsumer(
        _ consumer: AppRouter.ConsumerID,
        onDrain: @escaping () -> Void = {}
    ) -> some View {
        modifier(RouterConsumerModifier(consumer: consumer, onDrain: onDrain))
    }
}

private struct RouterConsumerModifier: ViewModifier {
    let consumer: AppRouter.ConsumerID
    let onDrain: () -> Void
    @Environment(SceneNavigation.self) private var navigation: SceneNavigation?

    func body(content: Content) -> some View {
        content
            .task {
                AppRouter.shared.markReady(consumer, in: navigation?.id)
                onDrain()
            }
            .onDisappear {
                AppRouter.shared.markUnready(consumer, in: navigation?.id)
            }
            .onChange(of: AppRouter.shared.revision) { _, _ in
                onDrain()
            }
    }
}
