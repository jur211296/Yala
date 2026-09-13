//
//  DestructiveScopeLogic.swift
//  Yala
//
//  Lógica PURA de la "hoja de alcance" destructiva (D4, §3.1/§3.3 del estudio MODO-NUBE-GESTION-DATOS-UX,
//  ratificada 2026-07-19). Decide la ESTRUCTURA del sheet de confirmación — qué filas (📱 dispositivo /
//  ☁️ iCloud|cuenta de Yala / 👥 grupos) aparecen y con qué tono, qué etiqueta lleva la fila ☁️, qué
//  líneas condicionales extra y si hay acción secundaria. NO decide el texto localizado (eso lo mapea
//  `DestructiveScopeSheet.Config.make` a partir de este modelo).
//
//  **Paso 9 del rediseño de sesiones (2026-09-11, ADR 2026-09-09 «Sesiones — dos ejes» §5-6).** Dos
//  botones en Ajustes —«Cerrar sesión» y «Vaciar datos»— y un verbo por sesión en las cuatro celdas. Las
//  operaciones de abajo son UNA por celda × lo que cambia el texto de su confirmación, que es donde vive
//  el detalle de qué se borra y qué queda (decisión de Jürgen: nada de subtítulos por fila). Se retiraron
//  `exitYalaLegacy` y `exitYalaGroups` («Salir de Yala en este dispositivo») y `deleteFrozenCopy`, que
//  no tenía ningún call-site.
//
//  Es SOLO capa de presentación: los servicios (`DataWipeService`, `CloudSessionSignOut`,
//  `AccountDeletionService`) NO se deciden aquí. `nonisolated enum` sin estado ni dependencias de
//  UI/SwiftData — testeable por tabla (operación × etiqueta ☁️ × deuda × huella).
//
//  Reutiliza `AccountDeletionMessageLogic.lines(...)` (D5) para las líneas condicionales de eliminar-cuenta:
//  la decisión de qué avisos aparecen (deudas, desvío cruzado, copia iCloud congelada, huella legacy) sigue
//  viviendo en un solo sitio; aquí solo se descarta `.base` (que se reparte en las 3 filas).
//

import Foundation

nonisolated enum DestructiveScopeLogic {

    /// Una variante por celda del ADR × lo que cambia su texto. El callsite la resuelve con
    /// `wipeOperation`, `signOutOperation` y `deleteAccountOperation` (abajo), no a mano.
    enum Operation: Equatable, CaseIterable {
        // MARK: Vaciar datos — «grupos, nunca»
        /// Privada o nube (C · D · E): la vida personal entera. En privada se borra también de iCloud, y
        /// con él de cualquier dispositivo con ese Apple ID (la hoja lo nombra: decisión de Jürgen).
        case wipeDataFull
        /// Solo grupos (F) con un store que no espeja: perfil + preferencias. No hay vida personal que vaciar
        /// ni nada que viaje a otro dispositivo (`wipeOperation`).
        case wipeDataGroupsOnly

        // MARK: Eliminar mi cuenta — vive dentro de «Tu cuenta de Yala»
        /// Nube completa (E): la vida personal vive en la cuenta de Yala.
        case deleteAccountCloud
        /// La cuenta de grupos de una sesión PRIVADA (D): lo personal, que vive en iCloud, no se toca.
        case deleteAccountGroupsOnly
        /// Solo grupos SIN sesión privada (F): la cuenta, y con ella lo que haya en este dispositivo.
        case deleteAccountGroupsOnlyNoPrivate

        // MARK: Cerrar sesión — el mismo verbo en las cuatro celdas
        /// Privada (C) con copia en iCloud: se borra de este dispositivo tras subir lo pendiente.
        case signOutPrivate
        /// Privada (C) SIN iCloud activo: no hay copia en ninguna parte y se borra para siempre.
        case signOutPrivateNoCopy
        /// «Equipo» (D) con copia en iCloud: lo personal queda en iCloud y los grupos en la cuenta.
        case signOutPrivateWithGroups
        /// «Equipo» (D) SIN iCloud activo: lo personal se pierde; los grupos quedan en la cuenta.
        case signOutPrivateWithGroupsNoCopy
        /// Nube completa (E): datos seguros en la cuenta; el dispositivo vuelve a recién instalado.
        case signOutCloud
        /// Solo grupos (F): los grupos siguen en la cuenta; el dispositivo vuelve a recién instalado.
        case signOutGroupsOnly
    }

    /// Etiqueta de la fila ☁️ — mata C2 de raíz (el copy no caduca por modo).
    enum CloudLabel: Equatable { case icloud, cloudAccount }

    enum Location: Equatable { case device, cloud, groups }

    /// Tono del detalle de cada fila. `.destructive` = se borra (destacado, rojo); `.preserved` = no se toca
    /// (secundario); `.neutral` = cambia pero sobrevive (p.ej. "sigues apareciendo como «Usuario eliminado»").
    enum Tone: Equatable { case destructive, preserved, neutral }

    /// Líneas condicionales que van BAJO las 3 filas. Las 4 primeras espejan `AccountDeletionMessageLogic.Line`
    /// (D5); `.multiDeviceResidual` es exclusiva de Vaciar en `.cloud` (D9 — declarar el residual en copy);
    /// `.noICloudCopy` es exclusiva del cierre privado sin iCloud (decisión de Jürgen: se avisa de que no hay
    /// copia en ninguna parte).
    enum ExtraLine: Equatable {
        case debtWarning, crossRefer, frozenICloud, legacyFootprint, multiDeviceResidual, noICloudCopy
    }

    /// Acciones secundarias SEGURAS de la hoja (steer-away de la destrucción), EN ORDEN de aparición. La
    /// lógica pura decide el CONJUNTO y el ORDEN (fiel a "la ESTRUCTURA la decide DestructiveScopeLogic");
    /// la factory mapea cada kind a su label/id/handler/caption. `.viewGroups` = "Ver mis grupos" (→ tab
    /// Grupos; eliminar-cuenta o Vaciar con deuda); `.exportBefore` = "Exportar antes" (red de seguridad
    /// §m.4 — SOLO Vaciar completo, donde existe el wizard personal).
    /// `.leaveAllGroups` = "También salir de mis grupos" (batch D10 — SOLO Vaciar completo, sin deudas, con
    /// grupos y flag ON).
    enum SecondaryKind: Equatable { case viewGroups, exportBefore, leaveAllGroups }

    struct RowSpec: Equatable {
        let location: Location
        let tone: Tone
    }

    struct Model: Equatable {
        /// SIEMPRE 3, en orden `device → cloud → groups` (las 3 filas escaneables del diseño).
        let rows: [RowSpec]
        /// Etiqueta de la fila ☁️ (eco del parámetro — el callsite ya la resolvió).
        let cloudLabel: CloudLabel
        /// ¿Hay nota de conservación ("qué se conserva / vuelta atrás")? El texto lo pone el factory por operación.
        let hasConservationNote: Bool
        /// Líneas condicionales EN ORDEN.
        let extraLines: [ExtraLine]
        /// Acciones secundarias SEGURAS EN ORDEN (steer-away). Vacío = solo [destructiva][Cancelar].
        let secondaryActions: [SecondaryKind]
    }

    // MARK: - Qué operación le toca a cada celda

    /// Etiqueta de la fila ☁️ según dónde viven los datos: `.cloud` → cuenta de Yala; resto → iCloud.
    static func cloudLabel(storageMode: StorageMode) -> CloudLabel {
        storageMode == .cloud ? .cloudAccount : .icloud
    }

    /// Etiqueta de la fila ☁️ para una operación concreta. Por defecto sigue a `storageMode`, salvo las
    /// operaciones cuya fila ☁️ habla SIEMPRE de la cuenta de Yala: eliminar cuenta (se borra la cuenta del
    /// backend) y los cierres de una sesión en la nube cuyo dispositivo está en `.icloud` — solo grupos (F)
    /// y la visita M1 —, donde lo que queda a salvo es la cuenta y no un iCloud que no guarda nada suyo.
    static func cloudLabel(for operation: Operation, storageMode: StorageMode) -> CloudLabel {
        switch operation {
        case .deleteAccountCloud, .deleteAccountGroupsOnly, .deleteAccountGroupsOnlyNoPrivate,
             .signOutGroupsOnly:
            return .cloudAccount
        case .wipeDataFull, .wipeDataGroupsOnly, .signOutPrivate, .signOutPrivateNoCopy,
             .signOutPrivateWithGroups, .signOutPrivateWithGroupsNoCopy, .signOutCloud:
            return cloudLabel(storageMode: storageMode)
        }
    }

    /// Operación de Vaciar según la sesión (C4, §3.3.1) y lo que el store tiene debajo.
    ///
    /// `hasPrivateSession` es EL EJE 1 del ADR 2026-09-09 y distingue "sin vida personal" (solo grupos →
    /// perfil + prefs) de "con vida personal" (todo lo demás → corpus personal completo). Una sesión
    /// backend viva NUNCA baja el scope: el «equipo» (D, onboarding completado + sesión solo-grupos) tiene
    /// `hasPrivateSession == true` ⇒ `.wipeDataFull`, con la fila 👥 reflejando sus grupos. Por eso NO se
    /// recibe la sesión como parámetro.
    ///
    /// El callsite lo lee de `PrivateSessionMark.hasPrivateSession` —la lectura que ante una marca
    /// AUSENTE responde `true`—, y aquí eso significa barrer de más, que es el lado barato: la hoja
    /// nombra todo lo que va a borrar antes de que nadie confirme.
    ///
    /// **`personalMountAttachesMirror` sube el scope de un solo-grupos cuyo store ESPEJA** (review adversarial
    /// del paso 9). «Vaciar datos» borra FILAS, y con el espejo montado esos borrados se exportan: salen de
    /// iCloud y de todos los dispositivos del Apple ID. Pasa, por ejemplo, en una instalación anterior al
    /// paso 5, y ahí la hoja de solo grupos decía «No se tocan» sobre un borrado que cruzaba a todos los
    /// dispositivos. Con espejo, la hoja es la completa, que lo nombra.
    static func wipeOperation(hasPrivateSession: Bool, personalMountAttachesMirror: Bool) -> Operation {
        !hasPrivateSession && !personalMountAttachesMirror ? .wipeDataGroupsOnly : .wipeDataFull
    }

    /// ¿«Vaciar datos» avisa a los OTROS dispositivos del Apple ID para que se vacíen también? Solo desde una
    /// sesión PRIVADA (C · D), que es la única cuyos datos son los del Apple ID.
    ///
    /// **La señal viaja por el iCloud KV del Apple ID** (`PreferenceSyncService.signalWipeInitiated` escribe
    /// `lastWipeTimestamp`), y todo dispositivo con el onboarding hecho la obedece borrando FILAS — con el
    /// espejo montado, eso borra además su iCloud. Emitida desde una sesión en la nube (E) o solo-grupos (F)
    /// —la persona que usa el móvil prestado del dueño, el caso que el ADR 2026-09-09 hace normal— vaciaba
    /// el iPad privado del dueño y su iCloud. Lo medió la review adversarial del plan del paso 9. La nube ya
    /// propaga su vaciado por la cuenta (el motor sube los borrados); F no borra nada fuera de este teléfono.
    /// **Y es el ÚNICO consumidor del eje 1 que lee `confirmedPrivateSession` y no `hasPrivateSession`**
    /// (ADR 2026-09-09, eje 1). Los otros ocho, ante una marca ausente, fallan hacia «hay vida personal
    /// que proteger» y con eso conservan o esperan de más — barato. Éste no: su `true` sale de este
    /// teléfono y ordena a los DEMÁS dispositivos del Apple ID vaciarse, así que fallar hacia `true`
    /// reintroduce exactamente el daño que esta función existe para impedir. Por eso su entrada es la
    /// lectura que ante la ausencia responde `false`: sin marca no se afirma que la sesión sea privada,
    /// y sin esa afirmación no se toca nada fuera de aquí.
    static func wipeSignalsAppleIDDevices(confirmedPrivateSession: Bool, storageMode: StorageMode) -> Bool {
        confirmedPrivateSession && storageMode == .icloud
    }

    /// Operación de la hoja de «Cerrar sesión» para el camino que el coordinador va a recorrer.
    ///
    /// `hasICloudCopy` solo afecta a las dos celdas privadas: sin iCloud activo no hay copia en ninguna
    /// parte, y la hoja lo tiene que decir antes del gesto (decisión de Jürgen: no se bloquea, se avisa, con
    /// confirmación reforzada). Lo decide `PrivateSignOutExportGateLogic.copyChannel` AL TOCAR, y viaja con
    /// la confirmación: la ejecución no lo recalcula a peor.
    ///
    /// `forgetsBackendGroups`: la privada sin sesión (C) cuyo store de grupos guarda filas del canal backend
    /// —una sesión de grupos que caducó— las OLVIDA al cerrar (`CloudSessionSignOut.hasBackendGroupRows`). Su
    /// hoja es entonces la del «equipo», que dice la verdad sobre ellos: este dispositivo los olvida y siguen
    /// en la cuenta. La privada pura decía «No se tocan» sobre un store que el cierre borraba (review
    /// adversarial del paso 9). Sin valor por defecto: la vista tiene que preguntarlo.
    static func signOutOperation(path: CloudSignOutFlowLogic.Path, hasICloudCopy: Bool,
                                 forgetsBackendGroups: Bool) -> Operation {
        switch path {
        case .privateSignOut where forgetsBackendGroups:
            return hasICloudCopy ? .signOutPrivateWithGroups : .signOutPrivateWithGroupsNoCopy
        case .privateSignOut:
            return hasICloudCopy ? .signOutPrivate : .signOutPrivateNoCopy
        case .privateWithGroupsSignOut:
            return hasICloudCopy ? .signOutPrivateWithGroups : .signOutPrivateWithGroupsNoCopy
        case .cloudSecureSignOut:
            return .signOutCloud
        case .groupsOnlySignOut:
            return .signOutGroupsOnly
        }
    }

    /// Operación de «Eliminar mi cuenta»: la cuenta de la nube completa (E), la de grupos de una sesión
    /// privada (D, lo personal no se toca) o la de un solo-grupos sin sesión privada (F, se va también lo
    /// local). Misma decisión que el cierre local de `AccountDeletionService`.
    static func deleteAccountOperation(storageMode: StorageMode, hasPrivateSession: Bool) -> Operation {
        if storageMode == .cloud { return .deleteAccountCloud }
        return hasPrivateSession ? .deleteAccountGroupsOnly : .deleteAccountGroupsOnlyNoPrivate
    }

    /// ¿La confirmación de la hoja necesita un SEGUNDO gesto? Solo los cierres sin copia en iCloud: son los
    /// únicos «Cerrar sesión» que destruyen algo que no existe en ninguna otra parte (confirmación reforzada,
    /// decisión de Jürgen del 2026-09-09).
    static func requiresNoCopyConfirmation(_ operation: Operation) -> Bool {
        operation == .signOutPrivateNoCopy || operation == .signOutPrivateWithGroupsNoCopy
    }

    // MARK: - A dónde lleva «Vaciar datos»

    /// Dónde aterriza la app tras «Vaciar datos» (ticket §7, fila H de la matriz de escenarios).
    enum WipeLanding: Equatable {
        /// Con vida personal (C · D · E): directo al onboarding personal, sin pasar por el Welcome — la
        /// sesión en la nube y los grupos, si los hay, siguen puestos. Al terminar, la celda es la de antes.
        case personalOnboarding
        /// Solo grupos (F): la app sigue enseñando sus grupos. No hay vida personal que volver a crear.
        case groupsShell
    }

    static func wipeLanding(hasPrivateSession: Bool) -> WipeLanding {
        hasPrivateSession ? .personalOnboarding : .groupsShell
    }

    // MARK: - El modelo de la hoja

    /// Modelo estructural de la hoja para una operación. `cloudLabel` la pasa el callsite; `hasOutstandingDebt`
    /// / `hasLegacyCloudKitFootprint` solo influyen en `deleteAccount*` y en las secundarias de Vaciar.
    static func model(
        operation: Operation,
        cloudLabel: CloudLabel,
        hasOutstandingDebt: Bool = false,
        hasLegacyCloudKitFootprint: Bool = false,
        canLeaveAllGroups: Bool = false
    ) -> Model {
        switch operation {
        case .wipeDataFull:
            // 📱 y ☁️ se borran de verdad (el export a iCloud es el invariante (a) usado a favor); 👥 intactos.
            return Model(
                rows: [.init(location: .device, tone: .destructive),
                       .init(location: .cloud, tone: .destructive),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                // D9: en `.cloud` declarar el residual multi-device. `.icloud` → sin línea: su fila ☁️ ya
                // nombra todos los dispositivos del Apple ID.
                extraLines: cloudLabel == .cloudAccount ? [.multiDeviceResidual] : [],
                // "Exportar antes" SIEMPRE (red de seguridad §m.4); con deuda, "Ver mis grupos" va PRIMERO
                // (protege a terceros: saldar antes de destruir); sin deuda y con grupos+flag (D10),
                // "También salir de mis grupos" va PRIMERO (el batch no se ofrece con deuda).
                secondaryActions: {
                    if hasOutstandingDebt { return [.viewGroups, .exportBefore] }
                    if canLeaveAllGroups { return [.leaveAllGroups, .exportBefore] }
                    return [.exportBefore]
                }())

        case .wipeDataGroupsOnly:
            // Solo grupos: perfil + preferencias, en ESTE dispositivo. Desde el paso 9 no se avisa a los demás
            // dispositivos del Apple ID (`wipeSignalsAppleIDDevices`), así que la fila ☁️ no se toca. Sin nota
            // de conservación: no hay cuenta personal ni Pro que mencionar; la fila 👥 ya lo dice.
            return Model(
                rows: [.init(location: .device, tone: .destructive),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: false,
                extraLines: [],
                // Sin export (no hay wizard personal; los grupos se exportan desde la fila de Ajustes).
                // Con deuda de grupos sí ofrece "Ver mis grupos".
                secondaryActions: hasOutstandingDebt ? [.viewGroups] : [])

        case .deleteAccountCloud, .deleteAccountGroupsOnly, .deleteAccountGroupsOnlyNoPrivate:
            let isCloud = (operation == .deleteAccountCloud)
            // `.cloud`: la vida personal muere en device + cuenta. D: el personal en `.icloud` NO se toca
            // (📱 preserved). F: no hay vida privada que conservar y el dispositivo vuelve a recién instalado
            // (📱 destructive). ☁️ muere siempre la cuenta; 👥 = anonimización.
            let deviceTone: Tone = (operation == .deleteAccountGroupsOnly) ? .preserved : .destructive
            return Model(
                rows: [.init(location: .device, tone: deviceTone),
                       .init(location: .cloud, tone: .destructive),
                       .init(location: .groups, tone: .neutral)],
                cloudLabel: cloudLabel,
                hasConservationNote: false,
                // Reutiliza la decisión D5 (`AccountDeletionMessageLogic`), descartando `.base` (repartida en
                // filas). `isCloud` es false en las dos de grupos: la copia congelada de iCloud del cutover
                // solo existe para quien migró su vida personal a la nube.
                extraLines: AccountDeletionMessageLogic.lines(
                    isCloud: isCloud,
                    hasOutstandingDebt: hasOutstandingDebt,
                    hasLegacyCloudKitFootprint: hasLegacyCloudKitFootprint
                ).compactMap(Self.mapDeleteAccountLine),
                secondaryActions: hasOutstandingDebt ? [.viewGroups] : [])

        case .signOutPrivate:
            // Se borra de este dispositivo (📱 neutral: cambia, pero sin pérdida — antes se sube lo pendiente);
            // iCloud intacto (☁️ preserved); sin cuenta de grupos (👥 preserved: no se tocan).
            return Model(
                rows: [.init(location: .device, tone: .neutral),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
                secondaryActions: [])

        case .signOutPrivateNoCopy:
            // Sin iCloud activo: lo de este dispositivo es la única copia (📱 y ☁️ destructive — la ☁️ dice que
            // no hay copia). Sin nota de conservación: no hay vuelta atrás que prometer.
            return Model(
                rows: [.init(location: .device, tone: .destructive),
                       .init(location: .cloud, tone: .destructive),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: false,
                extraLines: [.noICloudCopy],
                secondaryActions: [])

        case .signOutPrivateWithGroups:
            // «Equipo»: lo personal queda en iCloud y los grupos en la cuenta (👥 neutral: el dispositivo los
            // olvida, siguen en la cuenta).
            return Model(
                rows: [.init(location: .device, tone: .neutral),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .neutral)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
                secondaryActions: [])

        case .signOutPrivateWithGroupsNoCopy:
            // «Equipo» sin iCloud: lo personal se pierde; los grupos siguen en la cuenta.
            return Model(
                rows: [.init(location: .device, tone: .destructive),
                       .init(location: .cloud, tone: .destructive),
                       .init(location: .groups, tone: .neutral)],
                cloudLabel: cloudLabel,
                hasConservationNote: false,
                extraLines: [.noICloudCopy],
                secondaryActions: [])

        case .signOutCloud:
            // El device se resetea a "recién instalado" (wipe por archivos al boot) pero los datos están
            // seguros en la cuenta → 📱 neutral (cambia, sin pérdida); ☁️/👥 preserved.
            return Model(
                rows: [.init(location: .device, tone: .neutral),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
                secondaryActions: [])

        case .signOutGroupsOnly:
            // Solo grupos: el dispositivo vuelve a recién instalado (📱 neutral); la cuenta sigue (☁️
            // preserved); el dispositivo olvida los grupos, que siguen en la cuenta (👥 neutral).
            return Model(
                rows: [.init(location: .device, tone: .neutral),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .neutral)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
                secondaryActions: [])

        }
    }

    /// Mapea una `AccountDeletionMessageLogic.Line` (D5) a la `ExtraLine` de la hoja, descartando `.base`
    /// (que en la hoja se reparte en las 3 filas). El orden lo preserva el `compactMap` del callsite.
    private static func mapDeleteAccountLine(_ line: AccountDeletionMessageLogic.Line) -> ExtraLine? {
        switch line {
        case .base:            return nil
        case .debtWarning:     return .debtWarning
        case .crossRefer:      return .crossRefer
        case .frozenICloud:    return .frozenICloud
        case .legacyFootprint: return .legacyFootprint
        }
    }
}
