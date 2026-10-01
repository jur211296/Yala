//
//  GroupsOnlySignUpPreferenceReset.swift
//  Yala
//
//  **Las dos altas solo-grupos empiezan sin las preferencias del dueño del Apple ID.**
//  Ticket `neutral-boot-hands-owner-prefs-to-whoever-signs-in-next`.
//
//  Tras «Cerrar sesión», el arranque siguiente borra las preferencias locales y, en ese mismo arranque,
//  `PreferenceSyncService.bootstrap()` aplica las 36 del iCloud-KV del Apple ID. **Tiene que hacerlo**: en ese
//  instante nadie ha elegido todavía, y de ahí sale el `userName` con el que «Restaurar desde iCloud» va directo a
//  la app (`ICloudAccountSummary.isFullyPrefilled`). Cerrar ahí la puerta del KV rompería Restaurar y el alta
//  personal para toda la población (cabecera de `OwnerKeyValueStore`).
//
//  El precio era que quien entraba después por un grupo —en un móvil prestado, el caso normal del ADR
//  2026-09-09— se encontraba en local el idioma, la divisa, el Panel, los avisos y el resto de ajustes del dueño.
//  Las altas solo pisaban nombre, divisa y periodo.
//
//  **Decisión de Jürgen (opción 2 del ticket): se reinician al EMPEZAR cada alta solo-grupos**, que es el
//  instante en que se sabe que la sesión no es la del Apple ID. Todas salvo el consentimiento de la nube, que ningún
//  camino borra (ver `removeLocal`). Las dos puertas llaman aquí justo después de
//  `armGroupsOnlyNeutralMount` y antes de escribir lo suyo:
//   · invitación: `GroupInviteOnboardingView.performSilentSetup`;
//   · organizador: `GroupsOrganizerOnboarding.writePreferences`, por su writer.
//  Coste aceptado: quien es solo-grupos en SU propio teléfono empieza con los valores por defecto. Los suyos
//  siguen en el KV del Apple ID y vuelven con «Restaurar».
//
//  **Solo LOCAL, nunca el KV.** Lo que está en el iCloud-KV es del dueño y lo leen sus otros dispositivos. El
//  orden lo protege dos veces: con el neutro armado y sin el eje en `true`, `OwnerKeyValueGate` está cerrada —ni se
//  escribe ni se vuelve a aplicar lo del KV—, y aquí no se pasa por ningún escritor que llegue a él. Con el eje en
//  `true` (tras «Vaciar datos», que conserva la marca) la puerta sigue abierta, y lo que protege es lo segundo.
//
//  **Quitar la key no basta, y por eso hay dos mitades.** La app no lee solo `UserDefaults`: tiene COPIAS en
//  memoria que se cargaron con los valores del dueño. `AppPreferences` relee por presencia —una key que
//  desaparece deja la propiedad como estaba—, `SessionState` guarda el modo solo-gastos y el enfoque, y el idioma
//  se resuelve al recibir `languageDidChange`. Sin la segunda mitad, la persona seguiría viendo los ajustes del
//  dueño hasta relanzar la app.
//

import Foundation
import WidgetKit

@MainActor
enum GroupsOnlySignUpPreferenceReset {

    /// Los almacenes donde viven en local las preferencias sincronizadas. Separados porque el idioma NO vive en
    /// `.standard`: vive en la suite del App Group, que es donde lo escribe el merge y donde lo leen widget y share
    /// extension (`LanguageManager.sharedDefaults`).
    struct Stores {
        let standard: UserDefaults
        let language: UserDefaults
        /// Espejos del App Group que leen los widgets. `nil` si el App Group no está disponible.
        let appGroup: UserDefaults?

        static var live: Stores {
            Stores(standard: .standard,
                   language: LanguageManager.sharedDefaults,
                   appGroup: UserDefaults(suiteName: SharedContainerService.appGroupIdentifier))
        }
    }

    /// La mitad de los almacenes, sin efectos sobre el proceso vivo: así se puede afirmar sobre stores aislados.
    ///
    /// - Las 36 de `PrefSyncKey.allCases`, iteradas y no copiadas —es la lista con la que `bootstrap()` las aplica, y
    ///   una lista a mano se quedaría corta con la key 37—, **menos el consentimiento de la nube**
    ///   (`keptConsentKeys`). Es un registro de trazabilidad y ningún camino lo borra (la misma excepción que
    ///   `PrivateBirthKeyValueHandover.neverRemovedKeys`). Y no siempre es del dueño: «Primera vez → nube» lo registra
    ///   al aceptar y, si la cuenta resulta ser solo de grupos, acaba en el alta del organizador; borrarlo ahí se
    ///   llevaba el de quien entra. Lo que se queda del dueño lo sustituye el consentimiento que pide cualquier
    ///   activación de la nube posterior.
    /// - El centinela del Panel (`panelPrefsMigratedV2`), per-device, porque su valor tiene que CASAR con las 8 keys
    ///   del Panel: con ellas fuera y el centinela puesto, el Panel leería «enséñalo todo» en vez del curado de una
    ///   instalación nueva (`AppPreferences.isAwaitingDefaultsSeed`).
    /// - Los espejos del App Group que esas keys alimentan: `expensesOnlyMode` y `firstWeekday` (los que limpia el
    ///   borrado de preferencias de `DataWipeService`) y `defaultPeriod`, que escribe la foto de los widgets
    ///   (`WidgetDataCache.saveSnapshot`) y el widget lee.
    ///
    /// - Returns: las keys que estaban presentes, para que quien llama sepa qué copias en memoria avisar.
    @discardableResult
    static func removeLocal(from stores: Stores) -> Set<PrefSyncKey> {
        var removed: Set<PrefSyncKey> = []
        for key in PrefSyncKey.allCases where !keptConsentKeys.contains(key) {
            let store = key == .appLanguageOverride ? stores.language : stores.standard
            if store.object(forKey: key.rawValue) != nil { removed.insert(key) }
            store.removeObject(forKey: key.rawValue)
        }
        stores.standard.removeObject(forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        stores.appGroup?.removeObject(forKey: AppPreferences.Keys.expensesOnlyMode)
        stores.appGroup?.removeObject(forKey: "firstWeekday")
        stores.appGroup?.removeObject(forKey: "defaultPeriod")
        return removed
    }

    /// El consentimiento de la nube: se queda (el porqué, en `removeLocal`). Es el mismo conjunto que no se retira del
    /// KV al nacer la sesión privada, y se toma de ahí para que las dos excepciones no diverjan.
    static let keptConsentKeys: Set<PrefSyncKey> = PrivateBirthKeyValueHandover.neverRemovedKeys

    /// El reset de producción: almacenes y copias en memoria. Lo llaman las dos altas solo-grupos, después de armar
    /// el neutro y antes de escribir nombre, divisa y periodo.
    static func resetLive() {
        let session = SessionState.shared

        // 1 · Las copias que ESCRIBEN al asignarse, ANTES de quitar las keys: su `didSet` persiste el valor (y el de
        // solo-gastos, además, su espejo del App Group), así que asignarlas después volvería a dejar la key puesta.
        // Asignadas antes, el paso 2 se lleva lo que escriban.
        if session.isExpensesOnlyMode { session.isExpensesOnlyMode = false }
        session.financialMindset = SessionState.defaultFinancialMindset

        // 2 · Los almacenes.
        let removed = removeLocal(from: .live)

        // 3 · Las copias que NO escriben. `AppPreferences` relee por presencia, así que una key quitada no le
        // devuelve su valor de fábrica: hay que dárselo.
        AppBootstrapper.shared.appPreferences.resetSyncedMirrorToFactoryDefaults()
        session.formattingVersion += 1
        if removed.contains(.appLanguageOverride) {
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
        WidgetCenter.shared.reloadAllTimelines()

        #if DEBUG
        print("GroupsOnlySignUpPreferenceReset: \(removed.count) preferencias del Apple ID retiradas en local")
        #endif
    }
}
