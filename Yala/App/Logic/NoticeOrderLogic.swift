//
//  NoticeOrderLogic.swift
//  Yala
//
//  La regla de orden ENTRE los dos consumidores del shell (`.contentView` y `.mainTab`). Ticket
//  `notices-come-out-one-after-another-by-priority`.
//
//  La cola de `AppRouter` ya está ordenada por prioridad y, dentro de la misma, por llegada. Pero cada
//  consumidor drena SU parte: con un aviso de cada uno en cola, salía primero el del consumidor que miraba
//  antes, no el que iba delante. Leído en el código: Novedades (`.low`, `.contentView`) podía salir antes que
//  «Tu prueba terminó» (`.high`, `.mainTab`); y en la misma vuelta de `revision` la hoja del hito podía
//  presentarse antes que el aviso de datos borrados de iCloud, que luego esperaba detrás de ella.
//
//  La regla: **entre los avisos del shell de una misma ventana, sale primero el que va delante en la cola**.
//  Un aviso cede su turno al de delante solo si el consumidor de ese otro está listo para drenarlo en esa ventana;
//  si no, no espera a nadie (nunca se cuelga detrás de un consumidor que no va a drenar).
//
//  Lo que NO cede nunca: los avisos críticos y dudosos de `.contentView` (`waitsForForeignPresentation == false`:
//  vaciados, Apple ID, espejo tardío, la respuesta a un toque). Salen al momento, igual que con una hoja de otra
//  pestaña encima. El Panel y Planificación quedan fuera: sus hojas son lo que la persona acaba de pedir (una foto
//  compartida, dictar, un formulario) y ya esperan a que el shell esté libre.
//

import Foundation

enum NoticeOrderLogic {

    /// ¿Debe `intent` esperar a que salga `ahead`, que va delante en la cola? Solo responde para los dos consumidores
    /// del shell; quien llama ya comprobó que `ahead` va delante, es de la misma ventana y su consumidor está listo.
    static func yields(_ intent: RouterIntent, to ahead: RouterIntent) -> Bool {
        switch (intent.handler, ahead.handler) {
        // Las tres hojas de MainTab (prueba terminada, fin de Pro, hito) son diferibles: ceden ante cualquier cosa
        // del shell que vaya delante. Lo de `.contentView` que va delante sale en el acto (su consumidor está listo),
        // así que esperar cuesta lo que tarda en presentarse.
        case (.mainTab, .contentView):
            return RouterConsumerGateLogic.presentsModal(intent)
        // De `.contentView` solo ceden los avisos diferibles, y solo ante una hoja de MainTab. Los críticos y los que
        // contestan a un toque no ceden: protegen datos o cuenta, o la persona está esperando su respuesta.
        //
        // **Lo que la persona acaba de pedir desde un enlace no cede aunque sea diferible** (`bringsLeaderForward`: la
        // respuesta a una invitación y sus pantallas de unirse). Lo cazó la review adversarial del 2026-10-30: la cadena
        // de la invitación cierra el Welcome para drenar (`supersedesWelcomeChain`, B4-04), y si después cedía ante
        // «Tu prueba terminó», esa hoja salía sobre una app sin onboarding y la invitación esperaba detrás.
        case (.contentView, .mainTab):
            return RouterConsumerGateLogic.waitsForForeignPresentation(intent)
                && !intent.bringsLeaderForward
                && RouterConsumerGateLogic.presentsModal(ahead)
        default:
            return false
        }
    }
}
