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
    /// Declares this view as a drain consumer for `consumer`.
    ///
    /// Readiness is set on `.task` and cleared on `.onDisappear`. The
    /// `onDrain` closure runs whenever `AppRouter.shared.revision` changes
    /// AND when the view first mounts (via the `.task` bump). Consumers
    /// should use the single-intent drain pattern (NOT `while`) to avoid
    /// re-entrance.
    ///
    /// Example:
    /// ```
    /// .routerConsumer(.panel) {
    ///     if let intent = AppRouter.shared.drainNext(for: .panel) {
    ///         handle(intent)
    ///     }
    /// }
    /// ```
    func routerConsumer(
        _ consumer: AppRouter.ConsumerID,
        onDrain: @escaping () -> Void = {}
    ) -> some View {
        self
            .task {
                AppRouter.shared.markReady(consumer)
                onDrain()
            }
            .onDisappear {
                AppRouter.shared.markUnready(consumer)
            }
            .onChange(of: AppRouter.shared.revision) { _, _ in
                onDrain()
            }
    }
}
