//
//  GroupsOrganizerOnboarding.swift
//  Yala
//
//  G3 de Grupos-first · **el alta del organizador: el paso 7 de la rama, y el ÚNICO sitio donde escribe.**
//
//  Es el calco funcional de `OnboardingView.completeGroupsOnlyOnboarding` —mismo modo, mismos seeds,
//  mismo aterrizaje— extraído aquí en vez de reusado porque aquel es un método PRIVADO de una vista de
//  8 steps cuyo planner decide por `selectedUsageMode` (que solo se fija en el step `.purpose`, un step
//  que esta rama no recorre): reusarlo exigía arrastrar el planner entero, el `OnboardingPrefillResolver`
//  y el gate de la card de propósito para pedir un campo.
//
//  **Qué es «el trío» y por qué el ORDEN de la rama es load-bearing.** Las tres escrituras que hacen la
//  shell son `onboardingMode = .groupInvite`, `groupsBetaUnlocked = true` y `hasCompletedOnboarding = true`.
//  La primera es **never-downgrade cross-device** (rank 1 > 0, `PreferenceMergeLogic`) y viaja al iKV del
//  Apple ID: escrita antes de confirmar la puerta, no vuelve — se propaga a los otros dispositivos de ese
//  Apple ID y deja al usuario con la shell reducida a Grupos y sin grupo que enseñar. Por eso este tipo se
//  invoca DESPUÉS de `GroupsOrganizerGateLogic` y de la cadena sign-in → consent, nunca antes, y por eso
//  un source-scan pinnea que tenga un solo call-site de producción.
//
//  **La divisa NO se escribe aquí todavía.** Es el chip G4 («la divisa por región del organizador»), que
//  añade `defaultCurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()` a este mismo alta siguiendo
//  el precedente vivo de `GroupInviteOnboardingView` («grupo primero, región después»). Mientras tanto la
//  key queda ausente y `AppPreferences` cae a su default; es editable en el grupo desde el primer minuto.
//

import SwiftData
import SwiftUI

// MARK: - El canal de escritura, inyectable

/// El mínimo que el alta necesita escribir, con los dos canales SEPARADOS a propósito: mezclarlos es
/// cómo una preferencia per-device acaba viajando a la cuenta (regla de `swiftdata-cloudkit.md`).
///
/// Existe inyectable —molde de `BeaconKeyValueStore`, el protocolo con el que G0 hizo testeable el
/// handover— para que «con la puerta cerrada no se escribe nada» sea una afirmación comprobable sobre un
/// STORE y no sobre una pantalla, que es lo que el criterio de hecho del chip pide.
@MainActor
protocol GroupsOrganizerPreferenceWriting {
    /// Preferencia SINCRONIZADA: iKV en `.icloud`, outbox de prefs en `.cloud`.
    func setSynced(_ value: String, forKey key: String)
    /// Preferencia PER-DEVICE: jamás viaja.
    func setLocal(_ value: Bool, forKey key: String)
}

/// El canal de producción: `PreferenceSyncService` para lo sincronizado, `UserDefaults` para lo del device.
@MainActor
struct LiveGroupsOrganizerPreferenceWriter: GroupsOrganizerPreferenceWriting {
    var sync: PreferenceSyncService = .shared
    var defaults: UserDefaults = .standard

    func setSynced(_ value: String, forKey key: String) {
        sync.set(string: value, forKey: key)
    }

    func setLocal(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}

// MARK: - El alta

@MainActor
enum GroupsOrganizerOnboarding {

    /// Las cinco keys que este alta escribe. Publicadas para que el test pueda afirmar su AUSENCIA en el
    /// camino bloqueado con el mismo inventario que usa el camino que sí escribe — una lista duplicada a
    /// mano en el test se quedaría corta en cuanto alguien añadiera una escritura aquí.
    static let writtenKeys: [String] = [
        AppPreferences.Keys.userName,
        AppPreferences.Keys.defaultPeriod,
        OnboardingMode.userDefaultsKey,
        AppPreferences.Keys.groupsBetaUnlocked,
        AppPreferences.Keys.hasCompletedOnboarding
    ]

    /// Solo las preferencias, sin SwiftData. Separada de `completeSetup` para poder ejercitarla contra un
    /// writer espía sin montar un `ModelContainer` — no es una división cosmética: es la mitad que el test
    /// del gate usa como CONTROL POSITIVO de que sabe detectar una escritura.
    static func writePreferences(displayName: String, writer: any GroupsOrganizerPreferenceWriting) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = trimmed.isEmpty ? L10n.Profile.defaultName : trimmed

        writer.setSynced(effectiveName, forKey: AppPreferences.Keys.userName)
        writer.setSynced(DetailPeriod.thisMonth.rawValue, forKey: AppPreferences.Keys.defaultPeriod)

        // Modo Solo Grupos: reusa `.groupInvite`. Push EXPLÍCITO al canal sincronizado (dual-write, mismo
        // patrón que `completeGroupsOnlyOnboarding` y `FullModeActivationView`) — el `didSet` de
        // `onboardingMode` solo escribe local, así que sin esto no hay paridad cross-device.
        writer.setSynced(OnboardingMode.groupInvite.rawValue, forKey: OnboardingMode.userDefaultsKey)

        // Adopción explícita del dominio Grupos. `.groupInvite` ya la implica por el segundo término de
        // `GroupsDomainAdoptionLogic.isDomainOpen`, pero ese término muere si el usuario activa Yala
        // completo más tarde; la key es per-device y permanente (mismo trato que la entrada por invitación).
        writer.setLocal(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        writer.setLocal(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
    }

    /// El alta completa: preferencias, espejo en memoria, seeds y aterrizaje en el tab Grupos.
    ///
    /// - Important: **el único call-site de producción vive en `GroupsOrganizerNameView`**, detrás de la
    ///   puerta y de la cadena sign-in → consent. Pinneado por source-scan; moverlo antes es la mutación
    ///   (b) del chip.
    /// - Parameter writer: `nil` = el canal de producción. Va opcional y no con un default construido en
    ///   la firma porque `LiveGroupsOrganizerPreferenceWriter` es `@MainActor` (sus dos dependencias lo son)
    ///   y un default se evalúa en contexto nonisolated.
    static func completeSetup(displayName: String,
                              context: ModelContext,
                              writer: (any GroupsOrganizerPreferenceWriting)? = nil) {
        let sessionState = SessionState.shared
        writePreferences(displayName: displayName,
                         writer: writer ?? LiveGroupsOrganizerPreferenceWriter())

        // Espejo en memoria: el proceso vivo tiene que ver el modo nuevo YA (el tab bar se reduce a
        // [.groups] en el mismo render), no en el próximo arranque.
        sessionState.onboardingMode = .groupInvite
        sessionState.selectedPeriod = .thisMonth

        // Seeds idénticos al camino del invitado: categorías personales (para tener subcategorías en los
        // gastos de grupo) + las de sistema del bridge. Sin cuenta ni presupuesto personal.
        seedCategoriesIfNeeded(in: context)
        seedSystemGroupCategoriesIfNeeded(in: context)
        NotificationService.shared.seedDefaultNotificationsIfNeeded(context: context)

        do {
            SaveBreadcrumb.willSave("GroupsOrganizerOnboarding.completeSetup")
            try context.save()
            SaveBreadcrumb.didSave("GroupsOrganizerOnboarding.completeSetup")
        } catch {
            #if DEBUG
            print("GroupsOrganizerOnboarding: Error saving organizer setup: \(error)")
            #endif
        }

        // KPI registros/día — mismo evento que el alta solo-grupos del onboarding, con su propio modo para
        // poder separar las dos puertas de entrada al mismo shell.
        MetricsService.localRegistrationCompleted(mode: "groupsOrganizer")
        PreferenceSyncService.shared.signalOnboardingCompleted()

        // Aterrizar en el tab Grupos: con `.groupInvite` el tab bar se reduce a [.groups] y el
        // `selectedMainTab` persistido (.panel) no está montado (gotcha bde61bb2).
        sessionState.selectedMainTab = .groups
    }
}
