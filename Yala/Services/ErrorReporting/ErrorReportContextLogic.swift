//
//  ErrorReportContextLogic.swift
//  Yala
//
//  Con qué entorno y con qué usuario anónimo llega a Sentry un aviso, sin depender del SDK (testeable en unit).
//

import Foundation

nonisolated enum ErrorReportContextLogic {

    /// Cómo se compiló la app. `development` y `debug` salen de los flags de compilación; una build `release` puede ser
    /// la de la App Store o la de TestFlight, y eso solo se sabe en tiempo de ejecución.
    enum BuildFlavor: Equatable {
        case development
        case debug
        case release
    }

    static let production = "production"
    static let testFlight = "testflight"

    /// El entorno del aviso. TestFlight va aparte desde el 2026-11-21: la 2.3 (5) de TestFlight llegaba como
    /// `production` y sus cuelgues se mezclaban con los de la App Store.
    static func environment(flavor: BuildFlavor, receiptFileName: String?) -> String {
        switch flavor {
        case .development: return "development"
        case .debug: return "debug"
        case .release: return isTestFlight(receiptFileName: receiptFileName) ? testFlight : production
        }
    }

    /// Una app instalada desde TestFlight tiene el recibo en `…/StoreKit/sandboxReceipt`; la de la App Store, en
    /// `…/StoreKit/receipt`. Es la misma comprobación que hace el SDK de Sentry para su `build_type` («test»).
    static func isTestFlight(receiptFileName: String?) -> Bool {
        receiptFileName == "sandboxReceipt"
    }

    /// Cuelgues y «el sistema la mató por memoria» (WatchdogTermination) solo de las builds que usa la gente: App
    /// Store y TestFlight. En las de desarrollo eran ruido de las pruebas en el iPhone de QA (YALA-IOS-B y YALA-IOS-D,
    /// 2026-11-05/06): Sentry da por muerte por RAM cualquier cierre en primer plano sin crash, y cada
    /// `devicectl … --terminate-existing` de una sesión lo era; los cuelgues caían mientras Device MCP leía la pantalla
    /// por accesibilidad. Los crashes de desarrollo siguen llegando (así salieron YALA-IOS-C y E).
    static func tracksHangsAndWatchdog(environment: String) -> Bool {
        environment == production || environment == testFlight
    }

    /// Clave de `UserDefaults.standard` con el id anónimo de la instalación.
    static let installIDKey = "sentry.anonymousInstallID"

    /// El id con el que Sentry cuenta «usuarios afectados». Es un UUID aleatorio de esta instalación: no sale de la
    /// cuenta, ni de iCloud, ni del correo, ni del aparato, y una reinstalación da otro. Si lo guardado no es un UUID
    /// (vacío, o una clave pisada por otra cosa), se genera uno nuevo y hay que guardarlo.
    static func installID(stored: String?, makeNew: () -> UUID = UUID.init) -> (id: String, isNew: Bool) {
        if let stored, let uuid = UUID(uuidString: stored) {
            return (uuid.uuidString, false)
        }
        return (makeNew().uuidString, true)
    }
}
