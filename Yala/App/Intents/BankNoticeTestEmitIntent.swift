//
//  BankNoticeTestEmitIntent.swift
//  Yala
//
//  SOLO DEBUG (Yala Dev). Emite una notificación local con el texto de un aviso de banco, con retardo, para probar el
//  atajo del banco en un iPhone sin la app del banco (prueba B0, encargo del 2026-11-14). La automatización de Atajos
//  «Al recibir una notificación de Yala Dev» la recibe igual que la de BCP; el retardo deja bloquear el iPhone antes.
//  No existe en el build de la App Store.
//

#if DEBUG
import AppIntents
import UserNotifications

struct BankNoticeTestEmitIntent: AppIntent {

    static var title: LocalizedStringResource = "Emitir aviso de banco de prueba"
    static var description = IntentDescription("Solo Yala Dev: emite una notificación con el texto de un aviso de banco, para probar el atajo del banco.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Título", default: "Consumo con tu tarjeta")
    var noticeTitle: String

    @Parameter(title: "Texto", default: "Realizaste un consumo de S/ 12.50 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES.")
    var noticeBody: String

    @Parameter(title: "Segundos de espera", default: 10)
    var delaySeconds: Int

    func perform() async throws -> some IntentResult {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("BankNoticeTestEmitIntent: Error: \(error)")
            }
        }
        let content = UNMutableNotificationContent()
        content.title = noticeTitle
        content.body = noticeBody
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, delaySeconds)), repeats: false)
        let request = UNNotificationRequest(identifier: "bank-notice-test-\(UUID().uuidString)", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("BankNoticeTestEmitIntent: Error: \(error)")
        }
        return .result()
    }
}
#endif
