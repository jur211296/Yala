//
//  TutorialPermissionMoments.swift
//  Yala
//
//  Y23-17 (bienvenida 2.3, docs/onboarding-2-3/SPEC.md): dentro de Primeros pasos, un permiso se pide SOLO cuando la
//  persona elige usar esa función, y nunca antes. Los momentos viven en los flujos de los pasos 1 a 4 (sus lotes); aquí
//  está la regla de cada uno y el lado con efectos, para que esos flujos solo pregunten qué toca y lo hagan:
//
//   · Voz o foto (paso 2): primero el aviso de IA de Yala («Yala lo apunta por ti», `AIConsentAlertModifier`), una sola
//     vez; después, en voz, el aviso de iOS del micrófono. En foto, el de la cámara lo saca iOS al elegir «Cámara».
//     Fotos/carrete NO se pide nunca: el selector del sistema no lo necesita.
//   · «Sí, recuérdame» (la tarjeta de crédito del paso 1 y el aviso del presupuesto del paso 3): si iOS nunca preguntó,
//     su aviso; si ya respondió, nada (el aviso de iOS sale UNA vez por app).
//   · Pagos planificados (paso 4), al elegir un aviso: si iOS nunca preguntó, la hoja de la app «¿Te avisamos antes de
//     cada pago?» y luego el de iOS; si se negó, la alerta «Activa las notificaciones» con «Ir a Configuración».
//     «No me lo recuerdes» no gasta nada; «No permitir» de iOS sí.
//
//  Los textos de iOS son los de `InfoPlist.strings`; la hoja y la alerta son las de siempre (`NotificationPrimerSheet`,
//  `tutorialNotificationRetry`).
//

import AVFoundation
import SwiftUI
import UserNotifications

/// La regla de cada momento, sin efectos.
nonisolated enum TutorialPermissionLogic {

    /// La manera de anotar que la persona eligió probar.
    enum AIEntry: Equatable {
        case voice
        case photo
    }

    /// Lo que se pide antes de abrir la manera elegida, en orden.
    enum Ask: Equatable {
        /// El aviso de IA de Yala.
        case aiNotice
        /// El aviso de iOS del micrófono.
        case microphone
    }

    /// Qué hace falta pedir al elegir voz o foto. El de la cámara no va aquí: lo saca iOS al elegir «Cámara» dentro de
    /// la foto, que es cuando la persona elige usarla (elegir «Fotos» o «Archivo» no lo necesita).
    static func asks(
        for entry: AIEntry,
        aiConsentAccepted: Bool,
        microphoneUndetermined: Bool
    ) -> [Ask] {
        var asks: [Ask] = []
        if !aiConsentAccepted { asks.append(.aiNotice) }
        if entry == .voice, microphoneUndetermined { asks.append(.microphone) }
        return asks
    }

    /// Qué sale para las notificaciones.
    enum NotificationAsk: Equatable {
        /// Nada: no eligió aviso, o iOS ya respondió que sí.
        case nothing
        /// El aviso de iOS.
        case systemPrompt
        /// La hoja de la app «¿Te avisamos antes de cada pago?» y, si dice que sí, el aviso de iOS.
        case appSheetThenSystem
        /// La alerta «Activa las notificaciones» con «Ir a Configuración».
        case settingsAlert
    }

    /// «Sí, recuérdame» (pasos 1 y 3). Si iOS ya respondió, no se repite: ni el aviso ni una alerta.
    static func afterYesRemindMe(status: UNAuthorizationStatus) -> NotificationAsk {
        status == .notDetermined ? .systemPrompt : .nothing
    }

    /// Paso 4, al elegir el aviso del pago. Sin aviso elegido no se pide nada.
    static func scheduledPaymentReminder(wantsReminder: Bool, status: UNAuthorizationStatus) -> NotificationAsk {
        guard wantsReminder else { return .nothing }
        switch status {
        case .notDetermined: return .appSheetThenSystem
        case .denied: return .settingsAlert
        default: return .nothing
        }
    }

    /// El respaldo de las notificaciones al tercer registro (`NotificationPrimerContext.records`) pide sin que la persona
    /// haya elegido un aviso. Mientras aprende a registrar (paso 2) se apuntan hasta cuatro de prueba, así que ahí se
    /// calla; resuelto ese paso, vuelve (el one-shot no se gasta).
    static func recordsFallbackAllowed(learningToRecord: Bool) -> Bool {
        !learningToRecord
    }
}

/// El lado con efectos. Lo llaman los flujos de los pasos 1 a 4.
@MainActor
enum TutorialPermissionMoments {

    /// Lo que hace falta pedir al elegir voz o foto (`TutorialPermissionLogic.asks`).
    static func asks(for entry: TutorialPermissionLogic.AIEntry, aiConsentAccepted: Bool) -> [TutorialPermissionLogic.Ask] {
        TutorialPermissionLogic.asks(
            for: entry,
            aiConsentAccepted: aiConsentAccepted,
            microphoneUndetermined: AVAudioApplication.shared.recordPermission == .undetermined)
    }

    /// El aviso de iOS del micrófono. Devuelve si quedó concedido.
    static func requestMicrophone() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// «Sí, recuérdame»: pide el permiso de iOS si nunca se pidió. Devuelve si las notificaciones quedan permitidas.
    @discardableResult
    static func remindMeChosen() async -> Bool {
        let status = await NotificationService.shared.checkPermissionStatus()
        switch TutorialPermissionLogic.afterYesRemindMe(status: status) {
        case .systemPrompt:
            return await NotificationService.shared.requestPermission()
        default:
            return status == .authorized || status == .provisional || status == .ephemeral
        }
    }

    /// Paso 4: qué enseñar al elegir el aviso del pago.
    static func scheduledPaymentReminderAsk(wantsReminder: Bool) async -> TutorialPermissionLogic.NotificationAsk {
        guard wantsReminder else { return .nothing }
        let status = await NotificationService.shared.checkPermissionStatus()
        return TutorialPermissionLogic.scheduledPaymentReminder(wantsReminder: wantsReminder, status: status)
    }

    /// Si el respaldo del tercer registro puede salir ahora.
    static var recordsFallbackAllowed: Bool {
        TutorialPermissionLogic.recordsFallbackAllowed(learningToRecord: SetupChecklistManager.shared.isLearningToRecord)
    }
}

extension View {
    /// Paso 4: presenta lo que toque para el aviso de un pago (`TutorialPermissionMoments.scheduledPaymentReminderAsk`).
    /// La hoja es `NotificationPrimerSheet` en su versión de pagos, que ya termina en el aviso de iOS; la alerta lleva a
    /// Configuración. Un solo modificador, para no alargar la cadena del `body` de quien la use.
    func tutorialNotificationRetry(ask: Binding<TutorialPermissionLogic.NotificationAsk>) -> some View {
        modifier(TutorialNotificationRetryModifier(ask: ask))
    }
}

private struct TutorialNotificationRetryModifier: ViewModifier {
    @Binding var ask: TutorialPermissionLogic.NotificationAsk
    @Environment(\.openURL) private var openURL
    @State private var showsSheet = false
    @State private var showsAlert = false

    func body(content: Content) -> some View {
        content
            .notificationPrimerSheet(isPresented: $showsSheet, context: .scheduledPayment, onDismiss: { ask = .nothing })
            .alert(L10n.Notifications.permissionRequired, isPresented: $showsAlert) {
                Button(L10n.Notifications.openSettings) { openSettings() }
                Button(L10n.Common.cancel, role: .cancel) { ask = .nothing }
            }
            .onChange(of: ask) { _, newAsk in present(newAsk) }
    }

    private func present(_ newAsk: TutorialPermissionLogic.NotificationAsk) {
        showsSheet = newAsk == .appSheetThenSystem
        showsAlert = newAsk == .settingsAlert
    }

    private func openSettings() {
        ask = .nothing
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
