//
//  GroupsConsentPathLogic.swift
//  Yala
//
//  Por qué puerta se acepta el consentimiento de Grupos (card o8sc). Cada aceptación guarda en la cuenta la puerta por la
//  que entró la persona —`organizer`, `invite` o `tab`—, como diagnóstico de qué puerta produce los consentimientos
//  (`GroupsConsentView.path`). La hoja de la cadena solo elegía entre las dos primeras, así que quien aceptaba desde
//  «Un último paso» en la pestaña Grupos quedaba registrado como `invite` (QA guiado de 2.1, 19-oct, en staging).
//
//  Los productores del intent `.presentGroupsConsent` lo dicen con su zona: una invitación lleva la del grupo
//  (`GroupBackendInviteEntryHandler`), y los tres de la pestaña —el estado vacío, «Crear grupo» y el formulario— mandan
//  la vacía. La rama del organizador del Welcome no usa zona y tiene su propio flag, que manda.
//

import Foundation

nonisolated enum GroupsConsentPathLogic {

    static func path(organizerFlowActive: Bool, pendingJoinZone: String?) -> String {
        if organizerFlowActive { return "organizer" }
        if let zone = pendingJoinZone, !zone.isEmpty { return "invite" }
        return "tab"
    }
}
