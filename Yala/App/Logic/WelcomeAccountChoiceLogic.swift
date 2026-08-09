//
//  WelcomeAccountChoiceLogic.swift
//  Yala
//
//  Pure-logic del Welcome Chooser de 2 niveles (decisión owner 2026-07-12):
//  qué opciones muestra cada sub-chooser y cuándo hacer bypass (una sola opción
//  visible → no se muestra pantalla intermedia).
//
//  El botón de nube se oculta con backend no configurado (prod DARK hoy) y bajo
//  UITest (SIWA no funciona en sim; determinismo de los XCUITests existentes).
//
//  **A4 de D-A7 (2026-08-09): `visibleNewOptions` GANA SU CONSUMIDOR** — `WelcomeNewChooserView`
//  vía `WelcomeFlowContainer` — y `bornCloudEnabled` se cablea a la constante COMPILADA
//  `CloudSyncFlags.bornCloudChoiceEnabled`, hoy `true`. El plan de julio que decía «born-cloud
//  está DIFERIDO ⇒ `bornCloudEnabled` queda cableado a `false` en el callsite» queda OBSOLETO:
//  la palanca de release es el PERCENT remoto (`CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT`, hoy
//  `"0"` en producción y fail-closed), igual que con Grupos — así A5 puede ejercitar el alta en
//  staging/DEV sin recompilar, y prod sigue sin ver la card.
//

import Foundation

nonisolated enum WelcomeAccountChoiceLogic {

    /// Sub-opciones de "Soy nuevo".
    enum NewOption: Equatable, CaseIterable {
        case privateAccount
        case cloudAccount
    }

    /// Sub-opciones de "Ya tengo cuenta". `cloudSignIn` = Apple; `googleSignIn` = Google
    /// (sesión 2 — mismo gate: ambas solo con backend configurado y fuera de uitest).
    enum ExistingOption: Equatable, CaseIterable {
        case restoreICloud
        case cloudSignIn
        case googleSignIn
    }

    /// `remoteCloudEnabled`/`remoteOnboardingChoiceEnabled` = flags remote-config (DIFERIDOS #34,
    /// §j.1): la card born-cloud exige AMBOS (el sub-flag de elección es un escalón POSTERIOR del
    /// rollout del flag padre). Kill-switch = corta la ENTRADA: sin flag remoto no hay alta nueva.
    static func visibleNewOptions(
        isConfigured: Bool,
        isUITest: Bool,
        bornCloudEnabled: Bool,
        remoteCloudEnabled: Bool,
        remoteOnboardingChoiceEnabled: Bool
    ) -> [NewOption] {
        var options: [NewOption] = [.privateAccount]
        if isConfigured && !isUITest && bornCloudEnabled
            && remoteCloudEnabled && remoteOnboardingChoiceEnabled {
            options.append(.cloudAccount)
        }
        return options
    }

    /// `remoteCloudEnabled` (DIFERIDOS #34): con el kill-switch OFF las cards de sign-in nube se
    /// ocultan (bypass a restore, = prod DARK de hoy). Residual ratificado por el owner: un usuario
    /// nube que REINSTALA bajo el kill no ve la card → no re-entra hasta re-encendido.
    static func visibleExistingOptions(
        isConfigured: Bool,
        isUITest: Bool,
        remoteCloudEnabled: Bool
    ) -> [ExistingOption] {
        var options: [ExistingOption] = [.restoreICloud]
        if isConfigured && !isUITest && remoteCloudEnabled {
            options += [.cloudSignIn, .googleSignIn]
        }
        return options
    }

    /// Bypass del sub-chooser: con una sola opción visible se navega directo a ella.
    static func bypass<Option>(_ options: [Option]) -> Option? {
        options.count == 1 ? options.first : nil
    }

    // MARK: - Rama "Soy nuevo": el faro va ANTES de la elección (A26, §k.2)

    /// Destino de la rama "Soy nuevo". El orden de esta función ES el contrato: el faro se
    /// consulta ANTES de ofrecer nada.
    enum NewBranchRoute: Equatable {
        /// El faro de iCloud-KV dice que este Apple ID YA tiene una cuenta nube ⇒ se encamina al
        /// returning-user que ya existe (§k.4), JAMÁS a la elección: un born-cloud en su 2º device
        /// que eligiera "iCloud privado" arrancaría un dataset divergente que no se reúne con nada
        /// (A26). El provider sale del propio faro.
        case cloudSignIn(CloudSignInProvider)
        /// Bypass: una sola opción visible ⇒ no se monta pantalla intermedia (el recorrido de hoy).
        case single(NewOption)
        /// Dos o más opciones ⇒ sub-chooser.
        case chooser
    }

    /// `cloudEntryAvailable` es la disponibilidad de la MISMA pantalla a la que encamina el faro —
    /// la card `.cloudSignIn` de `visibleExistingOptions`—, no un gate nuevo: sin backend
    /// configurado el sign-in no puede completar (callejón), bajo uitest rompería el determinismo,
    /// y con el kill-switch remoto puesto la política ya ratificada es que la re-entrada nube no se
    /// ofrece (residual del owner en `visibleExistingOptions`). El callsite lo DERIVA de
    /// `visibleExistingOptions` en vez de re-escribir los tres términos.
    ///
    /// **Residual, declarado y no escondido:** bajo el kill remoto un born-cloud en su 2º device
    /// vuelve a poder divergir — es el mismo residual que ya acepta la card de re-entrada, ampliado
    /// a este camino. Sin kill (el caso normal) el faro cierra A26.
    static func routeNewBranch(
        beaconLinked: Bool,
        beaconProvider: String?,
        cloudEntryAvailable: Bool,
        options: [NewOption]
    ) -> NewBranchRoute {
        if beaconLinked && cloudEntryAvailable {
            // Provider desconocido/ausente ⇒ `.apple` (el faro solo ENCAMINA; si el método no casa,
            // `ProviderMismatchLogic` lo dice en la pantalla de destino).
            return .cloudSignIn(CloudSignInProvider(rawValue: beaconProvider ?? "") ?? .apple)
        }
        if let single = bypass(options) { return .single(single) }
        return .chooser
    }
}

/// Adaptador de LECTURA del faro para la rama "Soy nuevo" (A4 de D-A7). Existe para que el callsite
/// no lea `CloudBeacon` a mano y para que el test pueda inyectar el store KV (`BeaconKeyValueStore`):
/// la decisión sigue siendo pura y vive arriba; esto solo la alimenta.
@MainActor
enum WelcomeNewBranchRouter {
    static func route(
        beacon: CloudBeacon,
        cloudEntryAvailable: Bool,
        options: [WelcomeAccountChoiceLogic.NewOption]
    ) -> WelcomeAccountChoiceLogic.NewBranchRoute {
        WelcomeAccountChoiceLogic.routeNewBranch(
            beaconLinked: beacon.isCloudAccountLinked,
            beaconProvider: beacon.linkedProvider,
            cloudEntryAvailable: cloudEntryAvailable,
            options: options)
    }
}
