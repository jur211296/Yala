//
//  WelcomeUnfinishedAccountEntry.swift
//  Yala
//
//  Card 7e60 (decisión de Jürgen, 2026-11-06): quien elige en el Welcome entrar en una cuenta («Ya tengo cuenta» —Google,
//  Apple o iCloud— o una cuenta en la nube nueva) y ve Yala cerrarse antes de terminar, al reabrir vuelve a «¿Qué quieres
//  hacer?». Hasta ahora caía en el Paso 1 del alta privada: elegir cualquier camino marca `hasShownWelcomeChooser`, y el
//  arranque leía esa marca como «eligió empezar de cero». Solo quien eligió «Es mi primera vez» en privado sigue allí.
//
//  La marca vive en `UserDefaults` porque el cierre mata el proceso. Se pone al elegir un camino de cuenta y se quita al
//  elegir el privado, al terminar el onboarding y en el borrado (`DataWipeService`).
//

import Foundation

enum WelcomeUnfinishedAccountEntry {

    static let key = "welcome.accountEntryUnfinished"

    static func mark(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    static func isMarked(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    /// El arranque, con el chooser ya visto y sin destino pendiente: ¿vuelve al chooser o sigue al alta privada?
    static func reopensAtChooser(hasShownWelcomeChooser: Bool, accountEntryUnfinished: Bool) -> Bool {
        hasShownWelcomeChooser && accountEntryUnfinished
    }
}
