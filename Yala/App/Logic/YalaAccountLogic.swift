//
//  YalaAccountLogic.swift
//  Yala
//
//  Lógica PURA de la pantalla "Tu cuenta de Yala" (§3.3.5 del estudio MODO-NUBE-GESTION-DATOS-UX).
//  Decide QUÉ muestra el mapa/explainer del enlace privado ↔ nube: el método de entrada, dónde viven
//  los datos y cuáles de los TRES desenlaces (Cerrar sesión / Volver a iCloud / Eliminar cuenta) aplican.
//  NO implementa mecánica: cada desenlace enlaza al flujo EXISTENTE (la vista cablea las acciones).
//
//  Es SOLO capa de presentación. `nonisolated enum` sin estado ni dependencias de UI/SwiftData —
//  testeable por tabla (provider × storageMode × canDeleteAccount).
//
//  H4: la fusión Apple↔Google del mismo email verificado es server-side y NO detectable client-side
//  (`storedProvider()` solo devuelve el ÚLTIMO método usado; SIWA guarda `appleUserID`, Google el `sub`,
//  sin accessor combinado, cliente mono-provider por diseño). Por eso `showLinkingNote` es SIEMPRE `true`:
//  una nota general siempre-verdadera ("si usas el mismo correo, ambos abren esta misma cuenta"), decisión
//  owner 2026-07-20 — NO condicional a una fusión que no se puede detectar.
//

import Foundation

nonisolated enum YalaAccountLogic {

    /// Método de entrada mostrado (derivado de `CloudAuthService.storedProvider()`, string del wire del
    /// ÚLTIMO sign-in). `.unknown` = sin provider persistido (línea genérica, sin nombrar proveedor).
    enum Method: Equatable { case apple, google, unknown }

    /// Dónde viven los datos: `.cloud` (Modo Nube — la vida personal vive en la cuenta de Yala) vs
    /// `.groupsOnly` (personal en `.icloud`; la cuenta solo se usa para Grupos — el «equipo» del ADR) vs
    /// `.groupsOnlyNoPrivate` (solo grupos SIN sesión privada: no hay datos personales en ninguna parte —
    /// paso 9; esta pantalla es la puerta de su «Eliminar mi cuenta» y el copy del «equipo» le mentía).
    enum DataLocation: Equatable { case cloud, groupsOnly, groupsOnlyNoPrivate }

    /// Los desenlaces del enlace (§2.3), EN ORDEN de escalera de gravedad (reversible → irreversible).
    enum Exit: Equatable { case signOut, returnToICloud, deleteAccount }

    struct Model: Equatable {
        let method: Method
        /// Q1 (owner 2026-07-20): SIEMPRE `true` — nota general del vínculo Apple↔Google (H4 no detectable).
        let showLinkingNote: Bool
        let dataLocation: DataLocation
        /// Desenlaces aplicables, EN ORDEN. `signOut` siempre; `returnToICloud` solo en `.cloud`
        /// (la Reversa solo aplica si se migró); `deleteAccount` solo si `canDeleteAccount`.
        let exits: [Exit]
    }

    /// Mapea el string del wire (`"apple"`/`"google"`/`nil`/otro) al método mostrado.
    static func method(fromProvider raw: String?) -> Method {
        switch raw {
        case CloudSignInProvider.apple.rawValue:  return .apple
        case CloudSignInProvider.google.rawValue: return .google
        default:                                   return .unknown
        }
    }

    /// Modelo de la pantalla. `canDeleteAccount` lo deriva el callsite de `AccountDeletionRowLogic.shouldShow(...)`
    /// —toda sesión en la nube salvo la visita M1—, así que la pantalla nunca ofrece un borrado que el servicio
    /// no haría. `hasPrivateSession` es el mismo eje que el cierre de sesión y va SIN valor por defecto a
    /// propósito: con `true` implícito, un solo-grupos leería el «dónde viven» del «equipo».
    static func model(provider raw: String?, storageMode: StorageMode, canDeleteAccount: Bool,
                      hasPrivateSession: Bool) -> Model {
        let isCloud = (storageMode == .cloud)
        var exits: [Exit] = [.signOut]
        if isCloud { exits.append(.returnToICloud) }
        if canDeleteAccount { exits.append(.deleteAccount) }
        let location: DataLocation = isCloud ? .cloud : (hasPrivateSession ? .groupsOnly : .groupsOnlyNoPrivate)
        return Model(
            method: method(fromProvider: raw),
            showLinkingNote: true,
            dataLocation: location,
            exits: exits)
    }
}
