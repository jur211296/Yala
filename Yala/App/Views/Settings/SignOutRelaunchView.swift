//
//  SignOutRelaunchView.swift
//  Yala
//
//  Cover TERMINAL del cierre de sesión en `.cloud` (H4) y de la ventana de entrada
//  secundaria (M1): el push-all ya subió todo, la sesión está cerrada y el cleanup de
//  boot está ARMADO. Decisión owner 2026-07-14: basta IR AL INICIO — al pasar a
//  background el proceso termina solo (exit-on-background en ContentView) y el próximo
//  launch aterriza fresco. Desde L20-18 el texto es el mismo gesto en tres pasos que la tarjeta de
//  migración/reversa (que NO auto-exita): cerrarla desde el selector vale en los dos casos.
//  Sin botones a propósito: no hay nada más que hacer en esta sesión del proceso.
//

import SwiftUI

struct SignOutRelaunchView: View {

    /// H-2026-07-18-6: el cierre solo-grupos deja los datos personales EN el device (el device
    /// sigue en `.icloud`); tras el relaunch la app reabre con la vida personal intacta. El copy
    /// lo dice para no desorientar. La variante la decide el marker PERSISTIDO que arma ESE path
    /// (`groupsOnlyWipeArmed`) — solo se enciende ahí; `.cloud`/secundaria conservan el copy actual.
    private var isGroupsOnly: Bool { StorageModePersistence.isGroupsOnlyWipeArmed() }

    /// UX 2.2 · L20-18 (variante 3): lo hecho con check y el gesto en tres pasos (`RelaunchChecklist`). El único check
    /// que es verdad en TODOS los caminos que llegan aquí —cierre de sesión en cada celda, borrado de la cuenta, swap del
    /// contenedor— es que la sesión está cerrada; lo demás pasa al reabrir, y por eso va como frase bajo el pendiente.
    var body: some View {
        ScrollView {
            RelaunchChecklist(
                title: L10n.UXL20N.relaunchAlmostTitle,
                done: [L10n.UXL20N.relaunchDoneSignedOut],
                afterNote: isGroupsOnly ? L10n.UXL20N.relaunchAfterGroupsOnly : L10n.UXL20N.relaunchAfterSignOut)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
                .frame(maxWidth: DS.Adaptive.readableWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.center)
        .yalaScreenBackground(.panel)
        .interactiveDismissDisabled()
        // `.contain`: el id de la pantalla no pisa los de sus pasos (`relaunch_step_<n>`).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("signout_relaunch_screen")
    }
}
