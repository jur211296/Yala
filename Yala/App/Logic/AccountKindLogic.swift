//
//  AccountKindLogic.swift
//  Yala
//
//  El TIPO de una cuenta en la nube —¿lleva finanzas personales, o solo grupos?— y las reglas puras
//  que deciden qué se cree la app cuando el servidor no lo dice.
//
//  POR QUÉ EXISTE. Hasta g15_01 la app deducía «dónde viven mis datos» de `storageMode`, una
//  preferencia LOCAL que en un móvil recién instalado no existe: por eso «Ya tengo cuenta» adoptaba
//  como completa a quien solo tenía grupos, y «Vengo por un grupo» trataba como solo-grupos a quien
//  tenía años de datos en la nube. Ahora lo dice el backend (`GET /account/exists` → `kind`).
//
//  QUÉ NO HACE ESTE FICHERO, Y ES DELIBERADO: no rutea. Qué pantalla se abre con cada `kind` es el
//  ticket `cloud-sign-in-discovers-account-kind` (el bloque [I] del ADR 2026-09-09 §7). Aquí solo
//  vive el dato y la regla de qué creerse.
//
//  ADR 2026-09-09 «Sesiones — dos ejes (privada × nube)» §11.
//

import Foundation

/// Qué lleva una cuenta en la nube. Los dos valores del dominio del servidor (`profiles.kind`).
enum AccountKind: String, Codable, Equatable, Sendable {
    /// Finanzas personales (nació en la nube, o activó Yala completo en la nube). Además puede tener grupos.
    case complete
    /// Solo grupos: nació por «Vengo por un grupo», o es la cuenta asociada a una sesión privada.
    case groupsOnly = "groups_only"
}

/// Lo que la app recuerda del tipo de cuenta entre lanzamientos, **sellado con el dueño**.
///
/// El sello NO es decorativo: sin él, la caché escrita por una cuenta se aplicaría a la siguiente que
/// entre en el dispositivo. Es el mismo contrato que `AccountEntitlementSnapshot.userID`, y por el
/// mismo motivo.
nonisolated struct AccountKindSnapshot: Codable, Equatable, Sendable {
    /// El `sub` de la cuenta a la que pertenece este dato. Si no coincide con la sesión viva, el
    /// snapshot no vale para nada.
    let userID: String
    let kind: AccountKind
    /// Cuándo lo dijo el servidor. Sirve para diagnosticar, no para caducar: un dato viejo del dueño
    /// correcto es mejor que ninguno, y la corrección llega por refresco, no por expiración.
    let refreshedAt: Date
}

/// Las reglas de qué creerse. Puras a propósito: el caller resuelve la sesión viva y la pasa.
enum AccountKindLogic {
    /// Qué tipo asume la app AHORA MISMO, dado lo cacheado y quién ha iniciado sesión.
    ///
    /// **`groupsOnly` cuando no hay nada que creer** — decisión de Jürgen del 2026-09-09: el
    /// fail-safe apunta a la opción MENOS invasiva, porque equivocarse hacia `complete` significa
    /// enseñarle a alguien un Panel y unas cuentas que no son suyas, y equivocarse hacia `groupsOnly`
    /// solo significa enseñarle de menos hasta el siguiente refresco.
    ///
    /// **Y por eso el default no basta:** la app tiene que CORREGIRSE cuando una llamada posterior sí
    /// traiga el dato. De eso se encarga `AccountKindService`; aquí solo se decide qué mostrar
    /// mientras tanto.
    static func resolve(cached: AccountKindSnapshot?, sessionUserID: String?) -> AccountKind {
        guard let sessionUserID, !sessionUserID.isEmpty else { return .groupsOnly }
        guard let cached, cached.userID == sessionUserID else { return .groupsOnly }
        return cached.kind
    }

    /// ¿Hay que reescribir lo cacheado con lo que acaba de decir el servidor?
    ///
    /// Devuelve `nil` cuando no se escribe nada, y el snapshot a guardar cuando sí. Se separa del
    /// store para que el caso difícil —el servidor calla— sea una decisión con nombre y con test, en
    /// vez de un `if` enterrado en un servicio.
    ///
    /// **Que el servidor calle NO borra lo que ya sabíamos.** Un gateway viejo, o uno caído, no es
    /// una prueba de que la cuenta haya dejado de ser completa; borrar ahí convertiría un fail-safe
    /// transitorio en una degradación permanente y silenciosa.
    static func snapshotToPersist(
        remote: AccountKind?,
        sessionUserID: String?,
        cached: AccountKindSnapshot?,
        now: Date
    ) -> AccountKindSnapshot? {
        guard let sessionUserID, !sessionUserID.isEmpty else { return nil }
        guard let remote else { return nil }
        if let cached, cached.userID == sessionUserID, cached.kind == remote { return nil }
        return AccountKindSnapshot(userID: sessionUserID, kind: remote, refreshedAt: now)
    }
}
