//
//  HomeScreenQuickActions.swift
//  Yala
//
//  UX 2.2 · L15-15 (opción B, Jürgen 2026-10-18): al mantener pulsado el icono de Yala salían solo las opciones del
//  sistema. Ahora salen «Nuevo registro», «Registrar por voz» y «Foto o archivo», las tres entradas que ya existen como
//  widget y como atajo, y entran por su mismo enlace (`new-transaction`, `voice-entry`, `image-entry`): heredan la
//  puerta Pro, el consentimiento de IA, la espera al arranque y la shell de solo grupos.
//
//  Son dinámicas (`UIApplication.shortcutItems`) y no del Info.plist para que sigan el idioma elegido DENTRO de Yala:
//  las del Info.plist salen en el idioma del sistema. Se reponen al arrancar y al cambiar de idioma.
//

import UIKit

enum HomeScreenQuickActions {

    enum Action: String, CaseIterable {
        case newRecord = "pe.yala.quickaction.newRecord"
        case voice = "pe.yala.quickaction.voice"
        case image = "pe.yala.quickaction.image"

        /// El mismo enlace que el widget de entrada rápida.
        var deepLinkPath: String {
            switch self {
            case .newRecord: return "new-transaction"
            case .voice: return "voice-entry"
            case .image: return "image-entry"
            }
        }

        var systemImage: String {
            switch self {
            case .newRecord: return "square.and.pencil"
            case .voice: return "waveform"
            case .image: return "doc.viewfinder"
            }
        }

        @MainActor var title: String {
            switch self {
            case .newRecord: return L10n.UXL08D.quickActionNewRecord
            case .voice: return L10n.UXL08D.quickActionVoice
            case .image: return L10n.UXL08D.quickActionImage
            }
        }
    }

    /// El enlace de un acceso rápido, o `nil` si no es de Yala.
    static func url(forType type: String) -> URL? {
        guard let action = Action(rawValue: type) else { return nil }
        return WidgetURLHelper.url(for: action.deepLinkPath)
    }

    /// Repone los tres accesos con el idioma de ahora.
    @MainActor
    static func install(on application: UIApplication? = nil) {
        (application ?? .shared).shortcutItems = Action.allCases.map { action in
            UIApplicationShortcutItem(
                type: action.rawValue,
                localizedTitle: action.title,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: action.systemImage),
                userInfo: nil
            )
        }
    }

    /// Sesiones de escena cuyo acceso de arranque ya se atendió: llega en la configuración de una sesión nueva y otra vez
    /// en su conexión; una sesión restaurada solo lo trae en la conexión. Se atiende una vez.
    private static var handledSessionIDs: Set<String> = []

    /// El acceso con el que se abrió una ventana (app cerrada, o ventana restaurada).
    @MainActor
    static func performOnConnect(_ item: UIApplicationShortcutItem, sessionID: String) {
        guard handledSessionIDs.insert(sessionID).inserted else { return }
        perform(item, in: nil)
    }

    /// Abre lo que pide el acceso por el camino de los enlaces, en la ventana que lo recibió. `false` si no es nuestro.
    @MainActor
    @discardableResult
    static func perform(_ item: UIApplicationShortcutItem, in scene: UIScene?) -> Bool {
        guard let url = url(forType: item.type) else { return false }
        SceneRegistry.shared.noteFocused(scene: scene)
        AppBootstrapper.shared.handleIncomingURL(url)
        return true
    }
}

/// Recibe el toque de un acceso rápido con la app ya abierta. Con la app cerrada llega en las opciones de conexión de
/// la escena (`YalaAppDelegate.application(_:configurationForConnecting:options:)`). SwiftUI sigue montando la ventana:
/// esta clase solo añade el método que SwiftUI no expone.
final class YalaSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let item = connectionOptions.shortcutItem else { return }
        HomeScreenQuickActions.performOnConnect(item, sessionID: session.persistentIdentifier)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(HomeScreenQuickActions.perform(shortcutItem, in: windowScene))
    }
}
