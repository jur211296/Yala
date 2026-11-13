//
//  PrimerosPasosHomeScreenPresentation.swift
//  Yala
//
//  El paso 7 de Primeros pasos 2.3 (Y23-16, «Anota sin abrir Yala»), presentado desde el Panel a pantalla completa como
//  los pasos 3 a 5. Al cerrarse, el paso queda hecho u omitido según cómo salió (`HomeScreenTutorialLogic.resolution`);
//  con él se completa el mazo y llega el final (Y23-18). En su propio modificador: la cadena de `PanelSheetsModifier`
//  no admite más de tres por modificador en el compilador del CI.
//

import SwiftUI

struct PrimerosPasosHomeScreenPresentation: ViewModifier {
    @Binding var sheets: PanelSheetState

    @Environment(SessionState.self) private var sessionState

    /// El progreso vive aquí y no dentro de la pantalla: si iOS rehace su contenido, sigue donde iba.
    @State private var progress = HomeScreenTutorialProgress()
    /// Cómo terminó, copiado antes de cerrar: lo aplica el `onDismiss`.
    @State private var exit: HomeScreenTutorialLogic.Exit = .closed

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $sheets.showHomeScreenTutorial, onDismiss: afterTutorial) {
                HomeScreenTutorialFlowView(progress: progress, showsMail: showsMail) { result in
                    exit = result
                    sheets.showHomeScreenTutorial = false
                }
            }
    }

    /// La quinta manera, el correo del banco, con la misma regla que su fila de Ajustes: datos en la nube, sesión y fuera
    /// de solo grupos (Y23-19). La lista se fija al aparecer el paso (`HomeScreenTutorialProgress.methods`).
    private var showsMail: Bool {
        CloudSessionRevision.shared.track()
        return UITestHooks.bankEmailFake || BankEmailEntryLogic.showsRow(
            storageIsCloud: CloudSyncFlags.storageMode == .cloud,
            hasSession: CloudAuthService.shared.hasSession,
            isGroupsFocusedShell: sessionState.isGroupsFocusedShell)
    }

    private func afterTutorial() {
        let result = exit
        exit = .closed
        progress.reset()
        switch HomeScreenTutorialLogic.resolution(of: result) {
        case .completed: SetupChecklistManager.shared.markCompleted(.homeScreen)
        case .skipped: SetupChecklistManager.shared.markSkipped(.homeScreen)
        case nil: break
        }
    }
}
