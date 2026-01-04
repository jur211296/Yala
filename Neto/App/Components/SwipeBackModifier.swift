//
//  SwipeBackModifier.swift
//  Neto
//
//  Enables swipe-back gesture while keeping the back button hidden.
//

import SwiftUI
import UIKit

/// A view modifier that hides the navigation back button while preserving the swipe-back gesture.
/// Use this instead of `.navigationBarBackButtonHidden(true)` when you want custom toolbar buttons
/// but still want the native iOS swipe-back gesture to work.
struct SwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .background(
                SwipeBackHelper()
            )
    }
}

/// UIViewControllerRepresentable that enables the interactive pop gesture
private struct SwipeBackHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackViewController {
        SwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: SwipeBackViewController, context: Context) {}
}

/// Helper view controller that enables the interactive pop gesture recognizer
private class SwipeBackViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Enable the interactive pop gesture recognizer
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}

// MARK: - View Extension

extension View {
    /// Hides the navigation back button while preserving the swipe-back gesture.
    /// Use this instead of `.navigationBarBackButtonHidden(true)` when you want custom toolbar buttons
    /// but still want the native iOS swipe-back gesture to work.
    func swipeBack() -> some View {
        modifier(SwipeBackModifier())
    }
}
