//
//  MetricsUse.swift
//  Yala
//
//  «Usó esta función» (decisión 1 de la telemetría propia, opción C de Jürgen, 2026-11-06): un evento `use` por
//  función, COMO MUCHO UNO AL DÍA (día UTC, el mismo del ping). Cubre las funciones principales, la oferta de Pro, el
//  choque con un límite del plan gratis y los pasos del alta. Lo cuenta el panel (`panel/`) en personas distintas.
//
//  Privacidad: viaja el slug de la función y nada más — ni importes, ni nombres, ni textos. Cabe en lo que ya declara
//  `PrivacyInfo.xcprivacy` («interacción con el producto», no vinculada, analítica).
//
//  ⚠️ El slug es la serie del panel (`panel/src/labels.ts` le pone nombre): renombrar un case la rompe.
//

import Foundation

/// Las funciones que se miden. `rawValue` = el `n` del evento `use` (regex del gateway `[A-Za-z0-9_.-]{1,64}`).
nonisolated enum MetricsUseFeature: String, CaseIterable {
    // Funciones principales
    case registrarMovimiento
    case transferencia
    case panel
    case estadisticas
    case presupuestos
    case pagosProgramados
    case cuentas
    case grupos
    case preguntaYalaIA
    case leerFoto
    case notaDeVoz
    case siriAtajos
    case widget
    case exportar
    case importar

    // Pro
    case proOfertaVista
    case limiteGratisCuentas = "limiteGratis.cuentas"
    case limiteGratisPresupuestos = "limiteGratis.presupuestos"

    // Pasos del alta (embudo): bienvenida → camino → pasos del onboarding → termina
    case altaBienvenida = "alta.bienvenida"
    case altaCaminoPrivada = "alta.camino.privada"
    case altaCaminoNube = "alta.camino.nube"
    case altaCaminoRestaurar = "alta.camino.restaurar"
    case altaCaminoEntrar = "alta.camino.entrar"
    case altaCaminoGrupoCrear = "alta.camino.grupoCrear"
    case altaCaminoGrupoUnirse = "alta.camino.grupoUnirse"
    case altaPasoNombre = "alta.paso.name"
    case altaPasoProposito = "alta.paso.purpose"
    case altaPasoTipoCuenta = "alta.paso.accountType"
    case altaPasoMoneda = "alta.paso.currencyName"
    case altaPasoSaldo = "alta.paso.balance"
    case altaPasoCategorias = "alta.paso.categories"
    case altaPasoConfirmacion = "alta.paso.confirmation"
    case altaTermina = "alta.termina"

    // Después del alta (card 4b7h, 2026-11-13): el reinicio del camino privado y lo que la persona hace en sus primeros
    // días. **UNA VEZ POR INSTALACIÓN, no una al día** (`isOncePerInstall`), y los `primeros.*` solo en una instalación que
    // cerró el alta con esta versión (`requiresNewUser`): quien actualiza con años de datos no tiene «primer registro».
    // Qué mide cada uno y cuándo sale: `docs/telemetria/eventos-usuario-nuevo.md`.
    case altaReabrirPide = "alta.reabrir.pide"
    case altaReabrirVuelve = "alta.reabrir.vuelve"
    case primerosRegistro = "primeros.registro"
    case primerosPresupuesto = "primeros.presupuesto"
    case primerosPago = "primeros.pago"
    case primerosCuenta2 = "primeros.cuenta2"
    case primerosPasosVe = "primeros.pasos.ve"
    case primerosPasosCuenta = "primeros.pasos.cuenta"
    case primerosPasosRegistrar = "primeros.pasos.registrar"
    case primerosPasosPresupuesto = "primeros.pasos.presupuesto"
    case primerosPasosPagos = "primeros.pasos.pagos"
    case primerosPasosGrupo = "primeros.pasos.grupo"
    case primerosPasosDinero = "primeros.pasos.dinero"
    case primerosPasosInicio = "primeros.pasos.inicio"
    case primerosPasosCompleta = "primeros.pasos.completa"

    /// Sale una vez por instalación y no una al día (`MetricsOnceLogic`). Va por prefijo para que un evento nuevo de la
    /// familia herede la regla sin acordarse.
    var isOncePerInstall: Bool {
        rawValue.hasPrefix("primeros.") || rawValue.hasPrefix("alta.reabrir.")
    }

    /// Solo cuenta en una instalación que cerró el alta con esta versión o una posterior (`MetricsService.newUserKey`). El
    /// reinicio no: ocurre ANTES de terminar el alta.
    var requiresNewUser: Bool {
        rawValue.hasPrefix("primeros.")
    }

    /// «Reabre Yala» se le pidió a alguien que se está dando de alta: el onboarding privado o restaurar de iCloud. Las demás
    /// salidas que piden reabrir (activar Yala completo, volver al neutro por un grupo) no son el alta.
    static func relaunchAsked(destination: WelcomeMirrorRelaunchLogic.Destination?) -> MetricsUseFeature? {
        isSignUpRelaunch(destination) ? .altaReabrirPide : nil
    }

    /// Volvió a abrir Yala y el arranque retomó ese destino.
    static func relaunchReturned(destination: WelcomeMirrorRelaunchLogic.Destination?) -> MetricsUseFeature? {
        isSignUpRelaunch(destination) ? .altaReabrirVuelve : nil
    }

    private static func isSignUpRelaunch(_ destination: WelcomeMirrorRelaunchLogic.Destination?) -> Bool {
        destination == .privateOnboarding || destination == .restoreICloud
    }

    /// El paso del onboarding por su `trackingName` (`OnboardingStep`). `nil` si es uno que no se mide.
    static func onboardingStep(trackingName: String) -> MetricsUseFeature? {
        MetricsUseFeature(rawValue: "alta.paso.\(trackingName)")
    }

    /// El límite del plan gratis que se tocó. Solo los de cantidad (`ProFeature.freeLimit`): el resto son funciones Pro,
    /// y la prueba de voz y foto agotada la cuenta el servidor (`aiQuotaExhausted`).
    @MainActor static func freeLimit(_ feature: ProFeature) -> MetricsUseFeature? {
        switch feature {
        case .accounts: return .limiteGratisCuentas
        case .budgets: return .limiteGratisPresupuestos
        default: return nil
        }
    }

    /// Modos de `MetricsService.localRegistrationCompleted` que cierran un ALTA (embudo). `fullActivation` es pasar de
    /// solo grupos a Yala completo, no un alta.
    static func closesSignUp(mode: String) -> Bool {
        mode != "fullActivation"
    }
}

/// Decisión pura del «uno al día por función». Molde `MetricsPingLogic`: `now` inyectado.
nonisolated enum MetricsUseLogic {
    /// `true` si `feature` no se apuntó ya el día UTC de `now`. Un día FUTURO apuntado (reloj rebobinado) también
    /// emite, como el ping: mejor un doble raro que un silencio hasta que el reloj vuelva.
    static func shouldEmit(_ feature: MetricsUseFeature, lastDays: [String: String], now: Date) -> Bool {
        lastDays[feature.rawValue] != MetricsPingLogic.dayString(for: now)
    }
}

/// Decisión pura del «una vez por instalación» (card 4b7h). `emitted` = los slugs que esta instalación ya mandó.
nonisolated enum MetricsOnceLogic {
    static func shouldEmit(_ feature: MetricsUseFeature, emitted: Set<String>, isNewUser: Bool) -> Bool {
        guard !emitted.contains(feature.rawValue) else { return false }
        return !feature.requiresNewUser || isNewUser
    }
}

/// Qué función cuenta la página que se ve. Planificación cuenta por su chip (presupuestos o pagos programados); Más,
/// Buscar, Registros y Reportes no se miden (no están en la lista de la decisión).
@MainActor
enum MetricsUseTabLogic {
    static func feature(displayed tab: AppTab, planning: PlanningTab) -> MetricsUseFeature? {
        switch tab {
        case .panel: return .panel
        case .statistics: return .estadisticas
        case .planning: return planning == .budgets ? .presupuestos : .pagosProgramados
        case .groups: return .grupos
        case .more, .search, .records, .reports: return nil
        }
    }
}
