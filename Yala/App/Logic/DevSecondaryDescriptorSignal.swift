//
//  DevSecondaryDescriptorSignal.swift
//  Yala
//
//  CHIP M3 · **la señal que le faltaba a la red de la ventana de entrada secundaria.**
//
//  El residual vivo de M1-1: activar el descriptor desde el panel DEBUG no emitía NADA, así que hasta la
//  siguiente re-evaluación del net —`onAppear`, la caída del welcome cover, o volver a `.active`— la app
//  quedaba navegable sobre el store del DUEÑO con la sesión secundaria ya armada. El fix que el hallazgo
//  pedía («re-evaluar también en `scenePhase.active`») lleva puesto desde julio y cerró la mitad grande;
//  esto cierra el instante exacto del repro, que es de QA y solo de QA.
//
//  **Por qué una notificación y no un `@Observable`:** los tres triggers del modifier son statics
//  (`SecondarySessionStore.isActive()` + `SwiftDataConfiguration.secondaryStoreMounted`) y ninguno es
//  observable — hacerlos observables cambiaría el camino REAL de entrada, que el chip prohíbe tocar. Una
//  notificación añade un cuarto trigger sin mover ni un byte de la decisión, que sigue viviendo en
//  `RelaunchNetLogic`.
//
//  **Todo el tipo vive bajo `DEV_BUILD`** —igual que su emisor y su receptor— porque la invariante del chip
//  es que ningún atajo de QA entre al binario de producción. El camino real (Welcome → SIWA →
//  `SecondaryEntryLogic.begin`) no lo necesita: ahí el cover primario es la fase `.relaunchSecondary`
//  dentro del welcome cloud cover, y esta red es la de respaldo.
//

#if DEV_BUILD

import Foundation

/// El descriptor de la sesión secundaria cambió desde el panel DEBUG (activar FAKE / limpiar).
enum DevSecondaryDescriptorSignal {

    static let didChange = Notification.Name("yala.dev.secondaryDescriptorDidChange")

    /// Se emite DESPUÉS de escribir el descriptor: el receptor re-evalúa la condición VIVA, no un payload.
    /// Emitirla antes dejaría al net leyendo el estado anterior, que es exactamente el bug que cierra.
    static func post() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

#endif
