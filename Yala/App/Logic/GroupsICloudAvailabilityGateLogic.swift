//
//  GroupsICloudAvailabilityGateLogic.swift
//  Yala
//
//  Pure decision logic para el gate proactivo "Grupos necesita iCloud" (ARQUITECTURA
//  Modo Nube §i.8(c)2, riesgo A21; paquete de endurecimiento Grupos-v1 2026-07-13).
//  Grupos vive en CloudKit (CKShare exige cuenta iCloud del OS): sin cuenta, el tab
//  mostraba spinner/empty-state mudo y crear/unirse fallaba con errores genéricos.
//  Con el Modo Nube existen por primera vez usuarios reales sin iCloud desde el día
//  uno (born-cloud / independientes) — el gate hace la restricción transparente.
//
//  Patrón GroupsBetaGateLogic (pure-logic, tabla en tests). Corre EN SERIE después
//  del beta gate en MainTabView.viewForTab(.groups).
//

import Foundation

nonisolated enum GroupsICloudAvailabilityGateLogic {

    /// Decide si mostrar el gate "Grupos necesita iCloud" en lugar del contenido.
    /// - Parameters:
    ///   - isAccountAvailable: `iCloudSyncService.shared.isAccountAvailable` (token de
    ///     ubiquity en vivo). OJO reactividad: es COMPUTED — la vista debe leer además
    ///     `status` (stored) para registrar la dependencia @Observable.
    ///   - isUITest: `UITestHooks.isActive`. Exención OBLIGATORIA: el sim no tiene
    ///     cuenta iCloud y los XCUITests de Grupos (GroupsSmokeUITests,
    ///     DeeplinkRoutingUITests) lanzan sin `-uitest-fake-icloud` — sin la exención
    ///     el gate los interceptaría a todos. El QA agentic (agent-device, sin
    ///     `-uitest`) se cubre aparte con el arg DEBUG standalone `-fake-icloud`.
    static func shouldShowGate(isAccountAvailable: Bool, isUITest: Bool) -> Bool {
        !isAccountAvailable && !isUITest
    }
}
