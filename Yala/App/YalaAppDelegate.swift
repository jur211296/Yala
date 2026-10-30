//
//  YalaAppDelegate.swift
//  Yala
//
//  UIApplicationDelegate for:
//  - APNs registration (silent push)
//  - Clasificación de los push de CloudKit del store PERSONAL, que sigue espejado por
//    NSPersistentCloudKitContainer (la Fase 3 solo se llevó el transporte de GRUPOS)
//

import CloudKit
import UIKit

class YalaAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Avisos de errores y caídas (Sentry). Lo primero, para que una caída del resto del arranque también avise.
        ErrorReportingService.start()

        // El delegado de notificaciones, antes de que termine el lanzamiento (Apple lo exige): con la app cerrada, el
        // toque en una notificación se entrega justo después de este método, y sin delegado se pierde. Lo que el toque
        // pida antes de que acabe el arranque se aplaza en `DeferredIntentBuffer` y lo drena el paso 20.
        NotificationService.installAsCenterDelegate()
        #if DEBUG
        // Toque fingido con la app cerrada: llega aquí, justo después de instalar el delegado, como el real.
        if UITestHooks.inboxNotificationTapMode == "cold" {
            NotificationService.routeTap(deepLink: UITestHooks.notificationTapLink, targetSessionID: nil)
        }
        #endif

        // CKSyncEngine requires APNs registration for silent push notifications.
        // The engine handles push routing internally via CKDatabaseSubscription.
        application.registerForRemoteNotifications()

        // Accesos rápidos del icono (UX 2.2 · L15-15), en el idioma de Yala; se reponen si la persona lo cambia.
        HomeScreenQuickActions.install(on: application)
        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageDidChange, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in HomeScreenQuickActions.install() }
        }
        return true
    }

    private var languageObserver: NSObjectProtocol?

    // MARK: - Escenas: accesos rápidos del icono (UX 2.2 · L15-15)

    /// SwiftUI monta la ventana como siempre; esta configuración solo añade `YalaSceneDelegate`, que recibe el toque de
    /// un acceso rápido con la app abierta. Con la app cerrada el acceso llega aquí, en las opciones de conexión, y va por
    /// el mismo enlace (que espera al arranque si hace falta).
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        // Solo las ventanas de la app: una pantalla externa en espejo no recibe accesos rápidos.
        guard connectingSceneSession.role == .windowApplication else { return configuration }
        if let item = options.shortcutItem {
            HomeScreenQuickActions.performOnConnect(item, sessionID: connectingSceneSession.persistentIdentifier)
        }
        configuration.delegateClass = YalaSceneDelegate.self
        return configuration
    }

    /// Respaldo: si la escena no tiene `YalaSceneDelegate` (una ventana restaurada que se creó con una versión anterior),
    /// UIKit puede entregar el acceso aquí.
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(HomeScreenQuickActions.perform(shortcutItem, in: nil))
    }

    // MARK: - Remote Notifications (spike G0 Grupos→backend — semilla de G8)

    /// Key DEBUG-only con el device token hex para el panel CloudSyncDebugView (spike G0).
    /// Deliberadamente FUERA de la auditoría del wipe (`removeUserPreferenceKeys`): es
    /// diagnóstica y solo existe en builds DEBUG lanzados por Xcode.
    static let debugDeviceTokenKey = "debug.apnsDeviceToken"

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02hhx", $0) }.joined()
        PushBreadcrumb.tokenRegistered(token)
        #if DEBUG
        UserDefaults.standard.set(token, forKey: Self.debugDeviceTokenKey)
        #endif
        // G8-2: capturar el token para el canal de Grupos → backend (persiste local + dispara la subida
        // self-gateada por flag+sesión). Fuera del `#if DEBUG` — vive en prod DARK detrás del flag.
        Task { @MainActor in PushTokenRegistrar.shared.capture(token: token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushBreadcrumb.tokenFailed(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // 1) ¿Es de CloudKit? Clasificar PRIMERO y NO tocarlo: CKSyncEngine recibe sus push
        //    por su canal interno (CKDatabaseSubscription) — este handler no debe procesarlos.
        if CKNotification(fromRemoteNotificationDictionary: userInfo) != nil {
            PushBreadcrumb.received(kind: .cloudKit)
            completionHandler(.noData)
            return
        }
        // 2) ¿Es nuestro? Contrato con el gateway: key top-level "yala" (jamás "ck").
        if let yala = userInfo["yala"] as? [AnyHashable: Any] {
            let kind = yala["kind"] as? String
            PushBreadcrumb.received(kind: .yala(kind: kind))
            // Solo un kind que la app conoce baja los cambios de Grupos (card `x6p9`): el de depuración o uno nuevo
            // del gateway no disparan un ciclo que nadie pidió.
            guard GroupsPushKind.triggersGroupsSync(kind: kind) else {
                completionHandler(.noData)
                return
            }
            // G8-2: disparar UN ciclo del canal, acotado por timeout (iOS da ~30s; 20s de margen).
            // Con el flag OFF / sin sesión / canal no arrancado, `syncNowFromPush` retorna rápido →
            // `.noData`. ⚠️ Cambio observable byte-consciente: HOY esta rama devolvía `.newData`
            // incondicional; con flag OFF pasa a `.noData` — aceptable porque NINGÚN push con key `yala`
            // existe en producción con el flag OFF (solo el gateway los emite, fan-out staging-only). El
            // breadcrumb se conserva idéntico.
            Task { @MainActor in
                let result = await GroupsSyncClient.shared.syncNowFromPush(timeout: .seconds(20))
                completionHandler(result ? .newData : .noData)
            }
            return
        }
        // 3) Desconocido.
        PushBreadcrumb.received(kind: .unknown)
        completionHandler(.noData)
    }

    // MARK: - Universal Link Handling (GC-11)

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL,
              InviteLinkService.isInviteLink(url)
        else { return false }

        Task { @MainActor in
            AppBootstrapper.shared.handleInviteLink(url)
        }
        return true
    }
}
