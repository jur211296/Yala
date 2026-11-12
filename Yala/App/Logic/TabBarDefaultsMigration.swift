//
//  TabBarDefaultsMigration.swift
//  Yala
//
//  Y23-15 (bienvenida 2.3, docs/onboarding-2-3/SPEC.md): las instalaciones nuevas arrancan con Panel · Grupos ·
//  Registros, y Presupuestos, Pagos planificados y Estadísticas pasan a vivir en «Más». La ficha lo limita a las
//  instalaciones NUEVAS: a quien ya usa Yala no se le mueve la barra.
//
//  La barra guardada (`tabBarConfiguration`) solo existe si la persona la tocó en el editor de «Más». Quien nunca la
//  tocó no tiene nada escrito y leía el valor por defecto; si ese valor cambia sin más, a esa persona también se le
//  mueve. Por eso, la PRIMERA vez que arranca este código y antes de que se pinte nada:
//
//   · con la barra ya guardada → no se toca (la configuró ella);
//   · sin barra guardada y con el alta terminada → se le escribe la de antes (`legacyDefault`), tal cual la veía;
//   · sin barra guardada y sin alta → es una instalación nueva: lee el valor nuevo y queda apuntada como tal
//     (`isFreshInstall`), que es lo que mira la guía de «días después».
//
//  Corre una sola vez por instalación (centinela local, no sincronizado: la barra es de cada aparato).
//

import Foundation

@MainActor
enum TabBarDefaultsMigration {

    /// Centinela: la decisión ya se tomó en esta instalación.
    static let sentinelKey = "tabBarDefaults23.migrated"
    /// La instalación empezó con este código (alta sin terminar en su primer arranque).
    static let freshInstallKey = "onboarding23.freshInstall"

    enum Outcome: Equatable {
        /// Ya se decidió en un arranque anterior.
        case alreadyDecided
        /// La persona tenía su barra guardada: no se toca.
        case keptStored
        /// Usaba Yala con la barra de siempre sin haberla tocado: se le deja escrita.
        case pinnedLegacy
        /// Instalación nueva: el valor por defecto nuevo.
        case freshInstall
    }

    /// La regla, sin efectos.
    static func decide(alreadyDecided: Bool, storedJSON: String?, hasCompletedOnboarding: Bool) -> Outcome {
        if alreadyDecided { return .alreadyDecided }
        if let storedJSON, !storedJSON.isEmpty { return .keptStored }
        return hasCompletedOnboarding ? .pinnedLegacy : .freshInstall
    }

    /// Aplica la regla una vez. Se llama desde `AppPreferences.init`, antes de que ninguna vista lea la barra.
    @discardableResult
    static func runIfNeeded(defaults: UserDefaults = .standard) -> Outcome {
        let outcome = decide(
            alreadyDecided: defaults.bool(forKey: sentinelKey),
            storedJSON: defaults.string(forKey: TabBarConfiguration.storageKey),
            hasCompletedOnboarding: defaults.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
        )
        switch outcome {
        case .alreadyDecided:
            return outcome
        case .keptStored:
            break
        case .pinnedLegacy:
            defaults.set(TabBarConfiguration.legacyDefault.toJSON(), forKey: TabBarConfiguration.storageKey)
        case .freshInstall:
            defaults.set(true, forKey: freshInstallKey)
        }
        defaults.set(true, forKey: sentinelKey)
        #if DEBUG
        print("TabBarDefaultsMigration: \(outcome)")
        #endif
        return outcome
    }

    /// Si esta instalación empezó con la bienvenida de 2.3.
    static func isFreshInstall(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: freshInstallKey)
    }

    /// XCUITest (`-uitest-reset`): deja la instalación como una de antes de 2.3 (barra de siempre) o, con
    /// `-uitest-fresh-install`, como una nueva. Las pruebas eligen Estadísticas y Planificación por la barra en una
    /// veintena de ficheros; la instalación nueva se prueba a propósito.
    static func applyForUITest(freshInstall: Bool, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: sentinelKey)
        if freshInstall {
            defaults.removeObject(forKey: TabBarConfiguration.storageKey)
            defaults.set(true, forKey: freshInstallKey)
        } else {
            defaults.set(TabBarConfiguration.legacyDefault.toJSON(), forKey: TabBarConfiguration.storageKey)
            defaults.removeObject(forKey: freshInstallKey)
        }
    }
}
