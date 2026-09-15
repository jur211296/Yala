//
//  ModalPresentationProbe.swift
//  Yala
//
//  ¿Hay algo presentado de verdad sobre el árbol de la app? Una pregunta a UIKit, no a SwiftUI.
//
//  **Por qué hace falta.** SwiftUI no cuenta si una presentación llegó a montar: un `.alert` cuyo
//  `isPresented` se enciende con el anchor ocupado se descarta en silencio y el flag se queda en
//  `true` —`.alert` no tiene `onDismiss` con el que enterarse—. Cuando ese mismo flag es además
//  BLOCKER de la matriz de readiness, «no montó» se convierte en un brick de la sesión entera: el
//  router no vuelve a drenar nada hasta que se mata la app (regla de `.claude/rules/swiftui-ds.md`).
//  Para los covers, el repo ya verifica presentación efectiva con el `onAppear` del contenido real
//  (`SignOutRelaunchNetModifier` + `RelaunchNetLogic`). Un alert no tiene contenido propio que
//  aparezca, así que la única señal disponible es la de UIKit.
//
//  **Qué mide exactamente, y qué NO.** Contesta «¿hay ALGUNA presentación modal viva?», no «¿está
//  presentado MI alert?». Es deliberadamente conservador: quien lo consulta lo usa para decidir si
//  DESARMAR su propia presentación, y confundirse hacia «sí hay algo» sólo cuesta un reintento de
//  menos; confundirse hacia «no hay nada» tiraría un aviso que sí está en pantalla. No mira clases
//  concretas (`UIAlertController` y compañía): la presentación de SwiftUI cambia de envoltorio entre
//  versiones de iOS, y la cadena `presentedViewController` no.
//

import UIKit

@MainActor
enum ModalPresentationProbe {

    /// `true` si alguna ventana de alguna escena tiene algo presentado por encima de su raíz.
    ///
    /// Recorre TODAS las escenas conectadas y todas sus ventanas, no sólo la `key`: en iPad con dos
    /// ventanas, y durante las transiciones de escena, la que hospeda la presentación no siempre es la
    /// que responde `isKeyWindow`.
    static var isAnythingPresented: Bool {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.rootViewController?.presentedViewController != nil {
                return true
            }
        }
        return false
    }
}
