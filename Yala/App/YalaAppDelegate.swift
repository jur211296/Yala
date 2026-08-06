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
        // CKSyncEngine requires APNs registration for silent push notifications.
        // The engine handles push routing internally via CKDatabaseSubscription.
        application.registerForRemoteNotifications()
        return true
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
            PushBreadcrumb.received(kind: .yala(kind: yala["kind"] as? String))
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
