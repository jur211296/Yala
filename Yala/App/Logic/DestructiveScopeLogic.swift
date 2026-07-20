//
//  DestructiveScopeLogic.swift
//  Yala
//
//  Lógica PURA de la "hoja de alcance" destructiva (D4, §3.1/§3.3 del estudio MODO-NUBE-GESTION-DATOS-UX,
//  ratificada 2026-07-19). Decide la ESTRUCTURA del sheet de confirmación — qué filas (📱 dispositivo /
//  ☁️ iCloud|cuenta de Yala / 👥 grupos) aparecen y con qué tono, qué etiqueta lleva la fila ☁️, qué
//  líneas condicionales extra y si hay acción secundaria — para las 6 operaciones destructivas. NO decide
//  el texto localizado (eso lo mapea `DestructiveScopeSheet.Config.make` a partir de este modelo).
//
//  Es SOLO capa de presentación: los servicios (`DataWipeService`, `CloudSessionSignOut`,
//  `AccountDeletionService`, `performDeleteFrozenCopy`) NO se tocan. `nonisolated enum` sin estado ni
//  dependencias de UI/SwiftData — testeable por tabla (operación × etiqueta ☁️ × deuda × huella).
//
//  Reutiliza `AccountDeletionMessageLogic.lines(...)` (D5) para las líneas condicionales de eliminar-cuenta:
//  la decisión de qué avisos aparecen (deudas, desvío cruzado, copia iCloud congelada, huella legacy) sigue
//  viviendo en un solo sitio; aquí solo se descarta `.base` (que se reparte en las 3 filas).
//

import Foundation

nonisolated enum DestructiveScopeLogic {

    /// Las 11 variantes visuales concretas de la hoja (una por operación × escenario). El callsite resuelve
    /// cuál corresponde a partir de su contexto (`storageMode`, path de sign-out, `isGroupInviteMode`).
    enum Operation: Equatable, CaseIterable {
        /// Vaciar mis datos — vida personal completa (escenarios 1/2/3/4/5b).
        case wipeDataFull
        /// Vaciar mis datos — group-invite legado (5a): solo perfil + preferencias.
        case wipeDataGroupsOnly
        /// Eliminar mi cuenta — Modo Nube (`.cloud`): la vida personal vive en la cuenta de Yala.
        case deleteAccountCloud
        /// Eliminar mi cuenta — solo-grupos backend (5b): personal en `.icloud`, cuenta backend para grupos.
        case deleteAccountGroupsOnly
        /// Cerrar sesión — privado `.privateReset` (VIVO): no se borra nada, vuelta al Welcome in-session.
        case signOutPrivate
        /// Cerrar sesión — `.cloud` (`.cloudSecureSignOut`): wipe por archivos al boot, datos seguros en la cuenta.
        case signOutCloud
        /// Cerrar sesión — sesión SECUNDARIA M1: borra los archivos `-Secondary`; los del dueño intactos.
        case signOutSecondary
        /// Cerrar sesión de grupos — `.groupsOnlySignOut`: olvida los grupos; la vida personal intacta.
        case signOutGroupsOnly
        /// Salir de Yala — solo-grupos legado 5a (`.privateReset`): vuelta al Welcome, grupos en su iCloud.
        case exitYalaLegacy
        /// Salir de Yala — split D2 (`.privateReset` forzado): vuelta al Welcome + boot-wipe de grupos encadenado.
        case exitYalaGroups
        /// Borrar mi copia congelada (grupos, G6-C5): borra la zona CloudKit vieja; la verdad vive en el backend.
        case deleteFrozenCopy
    }

    /// Etiqueta de la fila ☁️ — mata C2 de raíz (el copy no caduca por modo). El callsite la calcula con
    /// `cloudLabel(storageMode:)` cuando la fila representa "dónde viven los datos" (Vaciar, sign-out), o la
    /// fija (`deleteAccount*` = siempre la cuenta de Yala; `deleteFrozenCopy` = siempre iCloud).
    enum CloudLabel: Equatable { case icloud, cloudAccount }

    enum Location: Equatable { case device, cloud, groups }

    /// Tono del detalle de cada fila. `.destructive` = se borra (destacado, rojo); `.preserved` = no se toca
    /// (secundario); `.neutral` = cambia pero sobrevive (p.ej. "sigues apareciendo como «Usuario eliminado»").
    enum Tone: Equatable { case destructive, preserved, neutral }

    /// Líneas condicionales que van BAJO las 3 filas. Las 4 primeras espejan `AccountDeletionMessageLogic.Line`
    /// (D5); `.multiDeviceResidual` es exclusiva de Vaciar en `.cloud` (D9 — declarar el residual en copy).
    enum ExtraLine: Equatable {
        case debtWarning, crossRefer, frozenICloud, legacyFootprint, multiDeviceResidual
    }

    /// Acciones secundarias SEGURAS de la hoja (steer-away de la destrucción), EN ORDEN de aparición. La
    /// lógica pura decide el CONJUNTO y el ORDEN (fiel a "la ESTRUCTURA la decide DestructiveScopeLogic");
    /// la factory mapea cada kind a su label/id/handler/caption. `.viewGroups` = "Ver mis grupos" (→ tab
    /// Grupos; eliminar-cuenta o Vaciar con deuda); `.exportBefore` = "Exportar antes" (red de seguridad
    /// §m.4 — SOLO Vaciar completo, donde existe el wizard personal).
    enum SecondaryKind: Equatable { case viewGroups, exportBefore }

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

    /// Etiqueta de la fila ☁️ según dónde viven los datos: `.cloud` → cuenta de Yala; resto → iCloud.
    static func cloudLabel(storageMode: StorageMode) -> CloudLabel {
        storageMode == .cloud ? .cloudAccount : .icloud
    }

    /// Operación de Vaciar según el modo de la app (C4, §3.3.1). `isGroupInviteMode` es el ÚNICO
    /// discriminante: distingue "sin vida personal" (5a legado group-invite → solo perfil + prefs) de
    /// "con vida personal" (todo lo demás → corpus personal completo). Una sesión backend viva NUNCA baja
    /// el scope a `.wipeDataGroupsOnly` — un 5b (onboarding `completed` + sesión solo-grupos) tiene
    /// `isGroupInviteMode == false` ⇒ `.wipeDataFull` (ve el copy personal completo, con la fila 👥
    /// reflejando sus grupos backend vía `accountDeletionGroupsSummary`); incluso un group-invite CON
    /// sesión backend viva (D6, [FLAG]) sigue siendo `.wipeDataGroupsOnly` porque no tiene vida personal.
    /// Por eso NO se recibe la sesión como parámetro (sería inerte). La presencia de vida personal la
    /// determina el onboarding (`OnboardingMode`), no la sesión.
    static func wipeOperation(isGroupInviteMode: Bool) -> Operation {
        isGroupInviteMode ? .wipeDataGroupsOnly : .wipeDataFull
    }

    /// Modelo estructural de la hoja para una operación. `cloudLabel` la pasa el callsite; `hasOutstandingDebt`
    /// / `hasLegacyCloudKitFootprint` solo influyen en `deleteAccount*` (resto los ignora).
    static func model(
        operation: Operation,
        cloudLabel: CloudLabel,
        hasOutstandingDebt: Bool = false,
        hasLegacyCloudKitFootprint: Bool = false
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
                // D9: en `.cloud` declarar el residual multi-device. VIVO `.icloud` → byte-idéntico (sin línea).
                extraLines: cloudLabel == .cloudAccount ? [.multiDeviceResidual] : [],
                // "Exportar antes" SIEMPRE (red de seguridad §m.4); con deuda, "Ver mis grupos" va PRIMERO
                // (protege a terceros: saldar antes de destruir).
                secondaryActions: hasOutstandingDebt ? [.viewGroups, .exportBefore] : [.exportBefore])

        case .wipeDataGroupsOnly:
            // 5a: solo perfil + preferencias (se restablecen; el iCloud KV de prefs también). Grupos intactos.
            // Sin nota de conservación: no hay cuenta backend ni Pro que mencionar; la fila 👥 ya lo dice.
            return Model(
                rows: [.init(location: .device, tone: .destructive),
                       .init(location: .cloud, tone: .destructive),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: false,
                extraLines: [],
                // 5a: sin export (no hay wizard personal; los grupos se exportan desde la fila de Ajustes).
                // Con deuda de grupos (CloudKit legacy) sí ofrece "Ver mis grupos".
                secondaryActions: hasOutstandingDebt ? [.viewGroups] : [])

        case .deleteAccountCloud, .deleteAccountGroupsOnly:
            let isCloud = (operation == .deleteAccountCloud)
            // `.cloud`: la vida personal muere en device + cuenta. Solo-grupos backend (5b): el personal en
            // `.icloud` NO se toca (📱 preserved), muere la cuenta backend (☁️ destructive). 👥 = anonimización.
            let deviceTone: Tone = isCloud ? .destructive : .preserved
            return Model(
                rows: [.init(location: .device, tone: deviceTone),
                       .init(location: .cloud, tone: .destructive),
                       .init(location: .groups, tone: .neutral)],
                cloudLabel: cloudLabel,
                hasConservationNote: false,
                // Reutiliza la decisión D5 (`AccountDeletionMessageLogic`), descartando `.base` (repartida en filas).
                extraLines: AccountDeletionMessageLogic.lines(
                    isCloud: isCloud,
                    hasOutstandingDebt: hasOutstandingDebt,
                    hasLegacyCloudKitFootprint: hasLegacyCloudKitFootprint
                ).compactMap(Self.mapDeleteAccountLine),
                secondaryActions: hasOutstandingDebt ? [.viewGroups] : [])

        case .signOutPrivate:
            // No se borra NADA: reset de onboarding in-session → Welcome. Todo preservado.
            return Model(
                rows: [.init(location: .device, tone: .preserved),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
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

        case .signOutSecondary:
            // M1: los datos de la sesión secundaria se eliminan del device (siguen en su cuenta); los del
            // dueño intactos (lo dice la nota de conservación).
            return Model(
                rows: [.init(location: .device, tone: .neutral),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
                secondaryActions: [])

        case .signOutGroupsOnly:
            // Olvida los grupos (👥 neutral: siguen en la cuenta, re-descargables); la vida personal intacta.
            return Model(
                rows: [.init(location: .device, tone: .preserved),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .neutral)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
                secondaryActions: [])

        case .exitYalaLegacy:
            // 5a: vuelta al Welcome; no se toca nada (datos y grupos siguen en su iCloud).
            return Model(
                rows: [.init(location: .device, tone: .preserved),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .preserved)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
                secondaryActions: [])

        case .exitYalaGroups:
            // Split D2: vuelta al Welcome + boot-wipe de grupos encadenado. Personal intacto; olvida grupos.
            return Model(
                rows: [.init(location: .device, tone: .preserved),
                       .init(location: .cloud, tone: .preserved),
                       .init(location: .groups, tone: .neutral)],
                cloudLabel: cloudLabel,
                hasConservationNote: true,
                extraLines: [],
                secondaryActions: [])

        case .deleteFrozenCopy:
            // G6-C5: borra la copia CloudKit congelada (☁️ destructive); el grupo sigue en el backend
            // (👥 preserved); nada del device se pierde (📱 preserved). "No pierdes nada" (nota).
            return Model(
                rows: [.init(location: .device, tone: .preserved),
                       .init(location: .cloud, tone: .destructive),
                       .init(location: .groups, tone: .preserved)],
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
