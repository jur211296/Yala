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
    ///   - isBackendChannelEnabled: `CloudSyncFlags.groupsBackendEnabled`. Con el canal
    ///     ON el gate se RETIRA ENTERO: Grupos deja de vivir en CloudKit, así que la
    ///     cuenta iCloud del OS ya no es requisito y este muro bloquearía justo a la
    ///     población born-cloud / independiente que el Modo Nube existe para admitir.
    ///     NO es observable (compuesto de un `let` compilado y del snapshot de
    ///     remote-config, que no cambia dentro de un render) — no hace falta: la
    ///     dependencia que re-evalúa este branch la registra `status` en el call-site.
    ///   - isUITest: `UITestHooks.isActive`. Exención OBLIGATORIA: el sim no tiene
    ///     cuenta iCloud y los XCUITests de Grupos (GroupsSmokeUITests,
    ///     DeeplinkRoutingUITests) lanzan sin `-uitest-fake-icloud` — sin la exención
    ///     el gate los interceptaría a todos. El QA agentic (agent-device, sin
    ///     `-uitest`) se cubre aparte con el arg DEBUG standalone `-fake-icloud`.
    ///
    /// El canal se consulta AQUÍ y no en el call-site a propósito. Vivió como
    /// `else if !CloudSyncFlags.groupsBackendEnabled, shouldShowGate(...)` dentro del
    /// `@ViewBuilder` de `ContentView.viewForTab(.groups)` desde `7b5ff216`, donde
    /// ningún test podía alcanzarlo: los unitarios no ven el ViewBuilder y la exención
    /// `isUITest` deja fuera a los XCUITest por diseño. Borrar aquella condición dejaba
    /// la suite entera en VERDE y devolvía el muro a producción. Como decisión pura sí
    /// tiene tabla, y el cableado lo pinnea un source-scan.
    static func shouldShowGate(isAccountAvailable: Bool,
                               isBackendChannelEnabled: Bool,
                               isUITest: Bool) -> Bool {
        guard !isBackendChannelEnabled else { return false }
        return !isAccountAvailable && !isUITest
    }
}
