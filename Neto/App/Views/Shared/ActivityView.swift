//
//  ActivityView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    /// completion(true) cuando el usuario completa una acción (guardar/compartir),
    /// completion(false) cuando simplemente cierra el share sheet.
    var completion: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No se necesita actualizar nada dinámicamente
    }
}
