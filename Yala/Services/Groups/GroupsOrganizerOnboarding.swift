//
//  GroupsOrganizerOnboarding.swift
//  Yala
//
//  G3 de Grupos-first · **el alta del organizador: el paso 7 de la rama, y el ÚNICO sitio donde escribe.**
//
//  Nació como el calco funcional del alta que el onboarding de 8 steps hacía para su card «Solo grupos»
//  —mismo modo, mismos seeds, mismo aterrizaje—, extraído aquí en vez de reusado porque aquel era un
//  método privado de esa vista, cuyo planner decide por `selectedUsageMode`: reusarlo exigía arrastrar el
//  planner entero para pedir un campo. Aquel método se borró en C2, y la card, con su puerta, el
//  2026-09-10 (ADR 2026-09-09 §7).
//
//  **Qué es «el trío» y por qué el ORDEN de la rama es load-bearing.** Las tres escrituras que hacen la
//  shell son el eje 1 apagado (`SessionState.hasPrivateSession = false`, que persiste `PrivateSessionMark`),
//  `groupsBetaUnlocked = true` y `hasCompletedOnboarding = true`. Escritas antes de confirmar la puerta
//  dejan al usuario con la shell reducida a Grupos y sin grupo que enseñar. Por eso este tipo se
//  invoca DESPUÉS de `GroupsOrganizerGateLogic` y de la cadena sign-in → consent, nunca antes, y por eso
//  un source-scan pinnea que tenga un solo call-site de producción.
//
//  **La lección de la versión anterior:** hasta el 2026-09-13 la primera escritura era un flag de
//  onboarding never-downgrade que viajaba al iKV del Apple ID, así que además se propagaba a los otros
//  dispositivos de esa cuenta y no volvía. Hoy el eje es local y ese daño no existe; el orden se mantiene.
//
//  **La divisa (G4) es la de la REGIÓN, siempre.** `defaultCurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()`
//  sigue el precedente vivo de `GroupInviteOnboardingView` («grupo primero, región después»); el default global `.pen`
//  de `AppPreferences` NO se toca —79 lectores, 3 de ellos pre-onboarding y 2 tests que lo pinnean—. Hasta el
//  2026-10-01 se escribía solo si la key estaba AUSENTE, para no pisar una divisa que hubiera bajado del iCloud-KV.
//  Esa divisa era la del DUEÑO del Apple ID —la aplica el arranque neutro tras «Cerrar sesión»—, y el alta ahora
//  retira en local las 36 sincronizadas antes de escribir (`GroupsOnlySignUpPreferenceReset`, ticket
//  `neutral-boot-hands-owner-prefs-to-whoever-signs-in-next`), así que la condición ya no podía cumplirse nunca. Y
//  pisarla tampoco viaja al dueño: con el neutro armado y sin el eje en `true`, `OwnerKeyValueGate` está cerrada. La
//  divisa es editable en el grupo desde el primer minuto (`GroupFormView` / `GroupSettingsView`).
//

import Foundation
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
    /// Retira en local las preferencias sincronizadas que dejó el arranque neutro, que son las del dueño del Apple
    /// ID. Va por el writer para que el test lo ejerza sobre su store aislado: el de producción toca además las
    /// copias en memoria del proceso vivo (`GroupsOnlySignUpPreferenceReset.resetLive`).
    func resetSyncedPreferences()
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

    func resetSyncedPreferences() {
        GroupsOnlySignUpPreferenceReset.resetLive()
    }
}

// MARK: - El alta

@MainActor
enum GroupsOrganizerOnboarding {

    /// Las SIETE keys que este alta puede escribir. Publicadas para que el test pueda afirmar su AUSENCIA en
    /// el camino bloqueado con el mismo inventario que usa el camino que sí escribe — una lista duplicada a
    /// mano en el test se quedaría corta en cuanto alguien añadiera una escritura aquí.
    ///
    /// Las CINCO que viajan por el canal de PREFERENCIAS (el `writer`). Se publican aparte de
    /// `writtenKeys` porque el spy de los tests solo puede ver éstas: la sexta no pasa por el writer a
    /// propósito —no es una preferencia del usuario, es la decisión de mount de este teléfono, y
    /// propagarla apagaría el espejo en el otro device del mismo usuario.
    static let writtenPreferenceKeys: [String] = [
        AppPreferences.Keys.userName,
        AppPreferences.Keys.defaultPeriod,
        AppPreferences.Keys.defaultCurrencyCode,
        AppPreferences.Keys.groupsBetaUnlocked,
        AppPreferences.Keys.hasCompletedOnboarding
    ]

    static let writtenKeys: [String] = writtenPreferenceKeys + [
        // 2026-09-10 · la sexta, y entra en el inventario A PROPÓSITO: no es una preferencia del usuario
        // —es la decisión de MOUNT de este teléfono— pero la escribe el alta, que es lo que este
        // inventario existe para vigilar. Dejarla fuera la habría vuelto invisible para las redes que se
        // alimentan de aquí.
        StorageModePersistence.groupsOnlyNeutralMountKey
    ]

    /// Solo las preferencias, sin SwiftData. Separada de `completeSetup` para poder ejercitarla contra un
    /// writer espía sin montar un `ModelContainer` — no es una división cosmética: es la mitad que el test
    /// del gate usa como CONTROL POSITIVO de que sabe detectar una escritura.
    ///
    /// - Parameter regionCode: región ISO con la que se deriva la divisa. Default: la del dispositivo,
    ///   inyectable para tests deterministas (patrón canónico `now: Date = .now`; el mismo default que
    ///   `CurrencyDefaults.detectCurrencyFromRegion`, que es quien la traduce a divisa).
    @discardableResult
    static func writePreferences(displayName: String,
                                 writer: any GroupsOrganizerPreferenceWriting,
                                 regionCode: String = Locale.current.region?.identifier ?? "",
                                 defaults: UserDefaults = .standard) -> Bool {
        // **El neutro durable de la sesión solo-grupos** (paso 5 del rediseño). Sin esto, el arranque
        // SIGUIENTE monta `.iCloudMirror` sobre el store personal —el archivo ya existe, así que
        // `isFreshInstallForNeutralMount` deja de ser `true`— y se trae el contenedor privado del Apple ID
        // del teléfono, que es el bug del ticket.
        //
        // Local y no sincronizada a propósito: describe cómo monta ESTE teléfono, no qué eligió la
        // cuenta. Propagarla apagaría el espejo en el otro device del mismo usuario, que puede tener su
        // sesión privada viva.
        //
        // **`defaults` es inyectable y eso NO es cosmética de tests.** El host de `YalaTests` es la app,
        // así que comparte el `UserDefaults.standard` del simulador: con esta escritura clavada a
        // `.standard`, correr la suite dejaba la marca puesta y la app de ese simulador montaba neutro
        // para siempre — rompiendo cualquier QA visual posterior. Las siete llamadas de test pasan su
        // suite aislado, igual que ya hacen con el `writer`.
        StorageModePersistence.armGroupsOnlyNeutralMount(defaults)

        // **Lo que dejó el arranque neutro es del dueño del Apple ID, no de quien entra** (ticket
        // `neutral-boot-hands-owner-prefs-to-whoever-signs-in-next`). Va DESPUÉS del arm —sin el eje en `true`, con él
        // la puerta del KV se cierra y nada lo vuelve a aplicar— y ANTES de escribir lo de esta persona, que si no se
        // iría con lo demás.
        writer.resetSyncedPreferences()

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = trimmed.isEmpty ? L10n.Profile.defaultName : trimmed

        writer.setSynced(effectiveName, forKey: AppPreferences.Keys.userName)
        writer.setSynced(DetailPeriod.thisMonth.rawValue, forKey: AppPreferences.Keys.defaultPeriod)

        // G4 · la divisa por región, en silencio. El alta del organizador no pregunta la moneda (decisión del
        // owner: solo nombre) y sin esta línea nacería en `.pen` —el default global, que NO se cambia— fuera de
        // Perú. Sin condición: la única divisa que podía haber aquí era la del dueño, y el reset de arriba la quitó.
        let currency = CurrencyDefaults.detectCurrencyFromRegion(regionCode: regionCode)
        writer.setSynced(currency.rawValue, forKey: AppPreferences.Keys.defaultCurrencyCode)

        // Adopción explícita del dominio Grupos. El eje 1 apagado ya la implica por el segundo término de
        // `GroupsDomainAdoptionLogic.isDomainOpen`, pero ese término muere si el usuario activa Yala
        // completo más tarde; la key es per-device y permanente (mismo trato que la entrada por invitación).
        writer.setLocal(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        writer.setLocal(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)

        return true
    }

    /// El alta completa: preferencias, espejo en memoria, seeds y aterrizaje en el tab Grupos.
    ///
    /// - Important: **es UN call-site de producción, detrás de la cadena completa**:
    ///   `GroupsOrganizerNameView` (puerta A, Welcome). Hubo un segundo hasta el 2026-09-10 —el caso
    ///   `.presentName` con payload de `ContentView.advanceGroupsOrganizerFlow`, la puerta B de la card
    ///   «Solo grupos» del onboarding—, retirado con la card (ADR 2026-09-09 §7). Pinneado por source-scan
    ///   con conteo; moverlo antes de la cadena es la mutación (b) del chip.
    /// - Parameter writer: `nil` = el canal de producción. Va opcional y no con un default construido en
    ///   la firma porque `LiveGroupsOrganizerPreferenceWriter` es `@MainActor` (sus dos dependencias lo son)
    ///   y un default se evalúa en contexto nonisolated.
    static func completeSetup(displayName: String,
                              context: ModelContext,
                              writer: (any GroupsOrganizerPreferenceWriting)? = nil) {
        let sessionState = SessionState.shared
        // Si las preferencias no se escribieron, el alta NO ocurre: seguir con los seeds y el aterrizaje
        // en el tab dejaría al usuario dentro de un shell de Grupos que ninguna preferencia sostiene.
        guard writePreferences(displayName: displayName,
                               writer: writer ?? LiveGroupsOrganizerPreferenceWriter()) else { return }

        // El eje 1: el organizador viene a crear un grupo, no hay sesión privada en este dispositivo.
        // Asignar al espejo observable persiste la marca Y reduce el tab bar a [.groups] en el mismo
        // render — el proceso vivo tiene que verlo YA, no en el próximo arranque.
        sessionState.hasPrivateSession = false
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

        // KPI registros/día — el mismo evento que el alta del onboarding de 8 pasos, con su propio modo para
        // separar esta entrada de aquélla.
        MetricsService.localRegistrationCompleted(mode: "groupsOrganizer")
        PreferenceSyncService.shared.signalOnboardingCompleted()

        // Aterrizar en el tab Grupos: sin sesión privada el tab bar se reduce a [.groups] y el
        // `selectedMainTab` persistido (.panel) no está montado (gotcha bde61bb2).
        sessionState.selectedMainTab = .groups
    }
}
