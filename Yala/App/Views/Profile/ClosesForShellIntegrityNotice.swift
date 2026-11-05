//
//  ClosesForShellIntegrityNotice.swift
//  Yala
//
//  Card ulks (lote N1 de la 2.3), decisión de Jürgen del 2026-11-04, opción A: con Ajustes abierto, un aviso de integridad
//  del shell (vaciado remoto, cambio de Apple ID, iCloud cambiado) cierra Ajustes y sale al momento. Ajustes se abre como
//  hoja desde diez sitios y ninguno publica nada al shell, así que es Ajustes quien dice que está delante y quien se cierra
//  cuando el shell se lo pide (`SceneNavigation.settingsCloseRequest`). El aviso no se presenta en la misma vuelta: espera
//  a que la ventana quede libre (`RouterConsumerGateLogic.contentViewClosesSettingsFirst`).
//

import SwiftUI

struct ClosesForShellIntegrityNotice: ViewModifier {
    let navigation: SceneNavigation
    let close: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { navigation.isSettingsSheetPresented = true }
            // Al desmontarse, también si UIKit la tumbó sin `onDismiss`: un `true` pegado no retiene nada por sí solo
            // (la retención exige además una presentación viva), pero dejaría de ser verdad.
            .onDisappear { navigation.isSettingsSheetPresented = false }
            .onChange(of: navigation.settingsCloseRequest) { _, _ in close() }
    }
}
