//
//  ReturningUserBeginnerTips.swift
//  Yala
//
//  Quien vuelve por «Ya tengo una cuenta» con sus datos no ve los tips de principiante.
//
//  Decisión de Jürgen (2026-10-22, card «Quien entra por "Ya tengo una cuenta" vuelve a ver todos los tips»): el
//  criterio es **llegar con datos**. Si su iCloud o su cuenta en la nube trae al menos un movimiento, las guías de cada
//  pestaña y los tours de principiante se dan por vistos; si llega vacío, los ve como alguien nuevo.
//
//  Por qué en dos tiempos: la entrada (`completeOnboardingAsRestoreSkip`, restaurar con datos o adoptar una cuenta de
//  la nube) termina cuando los datos pueden estar todavía bajando. Al entrar se apunta la hora (`armOnReentry`); y
//  quien tenga ocasión de enseñar un tip —el arranque, cada vuelta a primer plano, cada guía al aparecer, el tour de
//  Ajustes— pregunta antes si ya llegó algo de ANTES de esa hora (`settleIfPending`). «De antes» es lo que distingue
//  lo que la persona trajo de lo que apunta ella misma después: su primer gasto en una cuenta vacía no apaga los tips.
//  Pasados 7 días sin que llegue nada, se deja de preguntar.
//
//  El estado de los tips es local (`UserDefaults` y TipKit) y los borrados lo reinician
//  (`DataWipeService.removeUserPreferenceKeys`); por eso volvían a salir tras reinstalar o cerrar sesión.
//

import Foundation
import SwiftData

enum ReturningUserBeginnerTips {

    /// La hora de la entrada por «Ya tengo una cuenta» que aún no se ha resuelto. Ausente = nada pendiente.
    static let pendingKey = "beginnerTips.reentryPendingSince"

    /// Las guías contextuales de cada pestaña (`ContextualGuideBanner`), las mismas que reinicia un borrado.
    static let guideIDs = ["panel", "trends", "categories", "records", "budgets", "scheduled",
                           "accounts", "transaction", "comparative", "cashflow", "insights", "inbox",
                           "budgetEditor", "scheduledEditor"]

    /// Los tours y avisos de principiante que no son guías.
    static let tourKeys = ["hasSeenSettingsTour", "hasSeenCashFlowSetupTour", "hasSeenCashFlowTableTour",
                           "hasSeenChatContextHint", AppPreferences.Keys.hasSeenTodayFXCoachMark]

    /// Todas las marcas de «visto» que se ponen a quien vuelve con datos.
    static var seenKeys: [String] { guideIDs.map { "guide.\($0).dismissed" } + tourKeys }

    /// Tras la entrada, 7 días esperando a que lleguen los datos; después se deja de preguntar.
    static let patience: TimeInterval = 7 * 24 * 3600

    enum Decision: Equatable {
        /// Llegó algo de antes de la entrada: los tips de principiante se dan por vistos.
        case markSeen
        /// Aún no llegó nada: se vuelve a preguntar más tarde.
        case keepWaiting
        /// Pasó el plazo sin datos: llegó vacío, ve los tips como alguien nuevo.
        case giveUp
        /// No hay ninguna entrada pendiente.
        case nothingPending
    }

    static func decide(pendingSince: Date?, broughtData: Bool, now: Date) -> Decision {
        guard let pendingSince else { return .nothingPending }
        if broughtData { return .markSeen }
        return now.timeIntervalSince(pendingSince) > patience ? .giveUp : .keepWaiting
    }

    /// La entrada por «Ya tengo una cuenta» acaba de terminar. Una entrada nueva sustituye a la anterior.
    static func armOnReentry(now: Date = .now, defaults: UserDefaults = .standard) {
        defaults.set(now.timeIntervalSince1970, forKey: pendingKey)
    }

    /// Si hay una entrada pendiente y ya llegó algún movimiento anterior a ella, marca los tips como vistos y retira
    /// «Primeros pasos». Barato sin nada pendiente: una lectura de `UserDefaults`.
    ///
    /// **«Primeros pasos» también** (card ds09, 2026-10-28): en el 2.º iPhone de Jürgen salió «1 de 7» tras volver por «Ya
    /// tengo una cuenta» con el 1.º en 7 de 7. Su progreso es local, como el de los tips, y el borrado lo reinicia
    /// (`SetupChecklistManager.resetAll`); el criterio es el mismo —llegar con datos—, así que se resuelve en el mismo sitio.
    /// `dismissSetupChecklist` se inyecta para que los tests no escriban en el `UserDefaults` del proceso; `nil` es el de verdad.
    @MainActor
    @discardableResult
    static func settleIfPending(context: ModelContext, now: Date = .now, defaults: UserDefaults = .standard,
                                dismissSetupChecklist: (() -> Void)? = nil)
        -> Decision {
        guard let raw = defaults.object(forKey: pendingKey) as? Double else { return .nothingPending }
        let since = Date(timeIntervalSince1970: raw)
        var descriptor = FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.createdAt < since })
        descriptor.fetchLimit = 1
        let broughtData: Bool
        do {
            broughtData = try context.fetchCount(descriptor) > 0
        } catch {
            #if DEBUG
            print("ReturningUserBeginnerTips: Error leyendo los movimientos: \(error)")
            #endif
            return .keepWaiting
        }
        let decision = decide(pendingSince: since, broughtData: broughtData, now: now)
        switch decision {
        case .markSeen:
            for key in seenKeys { defaults.set(true, forKey: key) }
            if let dismissSetupChecklist { dismissSetupChecklist() } else { SetupChecklistManager.shared.dismissCompleted() }
            defaults.removeObject(forKey: pendingKey)
        case .giveUp:
            defaults.removeObject(forKey: pendingKey)
        case .keepWaiting, .nothingPending:
            break
        }
        return decision
    }
}
