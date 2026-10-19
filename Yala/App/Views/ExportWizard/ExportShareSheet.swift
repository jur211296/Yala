//
//  ExportShareSheet.swift
//  Yala
//
//  La hoja de compartir de las exportaciones y el aviso que la sigue. Vivía dentro del paso de resumen del asistente,
//  que desapareció con la pantalla única de L20-1 (2026-10-19).
//

import SwiftUI
import UIKit

// MARK: - Exported File Model

struct ExportedFile: Identifiable {
    let id = UUID()
    /// Uno o más archivos a compartir. Con el export personal solo = `[personal]`; con
    /// "Incluir mis grupos" activo = `[personal, grupos]` (G5-D2).
    let urls: [URL]
}

// MARK: - Share Sheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    /// Callback opcional que indica si la actividad se completó (`true`)
    /// o si el usuario canceló (`false`).
    var onComplete: ((Bool) -> Void)? = nil
    /// Lo mismo, con el identificador de la actividad elegida (L20-3: «Listo, tu archivo está en <app>»).
    var onFinish: ((_ completed: Bool, _ activityType: String?) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )

        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete?(completed)
            onFinish?(completed, activityType?.rawValue)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - El aviso tras compartir (L20-3 · L19-16)

/// Guarda lo que contestó la hoja de compartir y lo resuelve cuando la hoja ya se fue. Cancelar no enseña nada: decir
/// «Exportación completada» sin saber si el archivo se guardó es lo que hacía que alguien vaciara sin copia (L20-3).
///
/// iOS llama al `completionWithItemsHandler` a veces antes y a veces después del `onDismiss` de la hoja; por eso el
/// desenlace se resuelve una vuelta después del cierre, con lo que haya llegado (nada = cancelado).
@MainActor
@Observable
final class ExportShareResult {
    private(set) var pendingOutcome: ExportRecordsLogic.ShareOutcome?
    /// El aviso que se está enseñando. `nil` = ninguno.
    var shownOutcome: ExportRecordsLogic.ShareOutcome?

    func record(completed: Bool, activityType: String?) {
        pendingOutcome = ExportRecordsLogic.shareOutcome(completed: completed, activityType: activityType)
    }

    /// Desde el `onDismiss` de la hoja de compartir.
    func sheetDidClose() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            let outcome = pendingOutcome ?? .cancelled
            pendingOutcome = nil
            if outcome != .cancelled { shownOutcome = outcome }
        }
    }

    var isShowingAlert: Bool {
        get { shownOutcome != nil }
        set { if !newValue { shownOutcome = nil } }
    }

    /// «Listo, tu archivo está en Archivos» o «Listo, ya compartiste tu archivo».
    static func title(for outcome: ExportRecordsLogic.ShareOutcome?) -> String {
        switch outcome {
        case .sharedTo(let destination):
            return L10n.UXL20D.doneIn(appName(destination))
        case .sharedSomewhere, .cancelled, nil:
            return L10n.UXL20D.doneShared
        }
    }

    static func appName(_ destination: ExportRecordsLogic.KnownDestination) -> String {
        switch destination {
        case .files: return L10n.UXL20D.appFiles
        case .mail: return "Mail"
        case .messages: return L10n.UXL20D.appMessages
        case .notes: return L10n.UXL20D.appNotes
        case .brand(let name): return name
        }
    }
}
