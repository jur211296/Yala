//
//  RemoteFlagDecisionLogic.swift
//  Yala
//
//  Pure-logic de la decisión de flags remote-config (DIFERIDOS #34, §j.1/§j.2).
//
//  El wire trae PERCENTS de rollout 0-100 por flag (decisión owner 2026-07-17: escalón gradual
//  §j.2 desde el día 1). El cliente computa un bucket ESTABLE por instalación (seed UUID
//  persistido una vez) y queda dentro si `bucket < percent`. `absentDefault` es PARÁMETRO (ajuste
//  A1 del review): los tests corren siempre bajo DEV_BUILD y la rama prod (fail-closed → OFF)
//  debe entrar a la tabla; el valor compile-time lo pasa `CloudRemoteFlags`.
//
//  `nonisolated`: funciones puras sin estado; se leen desde getters de flags en cualquier actor.
//

import Foundation

nonisolated enum RemoteFlagDecisionLogic {

    /// Ventana mínima entre fetches del config (frescura del kill-switch sin spamear la red:
    /// boot + onAppear de las entradas re-verifican como mucho cada 6 h).
    static let refreshMinInterval: TimeInterval = 6 * 60 * 60

    /// Bucket estable 0-99 derivado del seed de instalación. FNV-1a sobre UTF-8 — NUNCA
    /// `hashValue` (randomizado por proceso: movería la cohorte del usuario en cada launch).
    /// La estabilidad cross-launch la garantiza el golden de vectores fijos del test.
    static func stableBucket(seed: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return Int(hash % 100)
    }

    /// Decisión de un flag: con percent presente, `bucket < clamp(percent, 0...100)`;
    /// sin percent (snapshot ausente / flag ausente en el wire) → `absentDefault`
    /// (prod: `false` fail-closed; DEV: `true` para no perder superficie de QA sin fetch previo).
    static func isEnabled(percent: Int?, bucket: Int, absentDefault: Bool) -> Bool {
        guard let percent else { return absentDefault }
        let clamped = min(100, max(0, percent))
        return bucket < clamped
    }

    /// **¿Sabemos qué dice el servidor de la nube, o solo no hemos podido preguntar?** A un GATE no le
    /// hace falta distinguirlo —`absentDefault` fail-closed le basta— pero a un MENSAJE sí: «la nube
    /// está apagada» y «no lo hemos podido comprobar» son hechos distintos, y el segundo es el de quien
    /// reinstala y abre sin red (el snapshot vive en el contenedor de la app y se va con ella). Su
    /// consumidor es `WelcomeRestoreEmptyOutcome`.
    ///
    /// Devuelve `true` —«lo sabemos»— en los dos casos donde la ausencia de snapshot NO es una
    /// comprobación fallida, y la marca va POSITIVA a propósito en los dos:
    ///  · `!backendConfigured`: `RemoteConfigClient.refreshIfDue` sale en su primera línea, así que
    ///    nunca habría snapshot y TODO el parque leería «no pudimos comprobar» para siempre. No hay a
    ///    quién preguntar ⇒ no hay comprobación pendiente. **Lo que NO cubre, y va dicho porque el
    ///    docblock prometía de más:** ese testigo es `CloudBackendConfig.isConfigured`, o sea Supabase,
    ///    y el fetch va a `ProxyConfig.baseURL`, o sea el Worker de Cloudflare. Son dos servicios. Si el
    ///    gateway desaparece con Supabase configurado, esta guarda no se abre y el mensaje sí sale para
    ///    todo el que reinstale — ticket `restore-unverified-message-depends-on-a-single-gateway-host`.
    ///    Hoy `isConfigured` es `true` en los dos schemes (URL y anon key literales), así que esta rama
    ///    no protege a nadie: existe para el día que alguien vacíe uno de los dos.
    ///  · `isTestHost`: el mismo corte que `CloudRemoteFlags.decide` y por el mismo motivo — el
    ///    `.standard` del simulador puede traer el snapshot de una corrida manual, así que la verdad
    ///    ahí no es `false`, es NO DETERMINISTA. Con el corte, bajo test el desenlace es el que ya
    ///    daba antes del ticket. **Medido, no deducido**: las 7 suites del Welcome y las 3 de esta
    ///    decisión pasan sin cambiar una aserción de las que ya existían. Lo que NO se afirma es que
    ///    el binario sea byte-idéntico — eso nadie lo ha medido.
    ///    **Precio, y va dicho:** `.cloudUnverified` es inalcanzable en unit y en XCUITest, así que
    ///    su única red de comportamiento es el device-QA del ticket. Un seam que forzara el predicado
    ///    dejaría ciego al test que lo usara (`.claude/rules/testing.md`, «un seam de QA que FUERZA el
    ///    resultado»), y la condición real —no tener snapshot— no se puede montar bajo test sin
    ///    escribir en el `.standard` del simulador. Mismo trato que el aviso del attest personal.
    static func isConfigKnown(hasSnapshot: Bool, backendConfigured: Bool, isTestHost: Bool) -> Bool {
        if isTestHost { return true }
        if !backendConfigured { return true }
        return hasSnapshot
    }

    /// ¿Toca re-fetchear el config? `nil` (jamás fetcheado) → sí; `fetchedAt` en el FUTURO
    /// (reloj movido hacia atrás) → sí (futuro = stale; fix del review adversarial — sin esto, un
    /// fetch con el reloj mal adelantado congelaría el kill-switch por el tamaño del error);
    /// si no, min-interval. `now` inyectado (regla del repo: nunca `Date()` en lógica testeada).
    static func shouldRefresh(lastFetchedAt: Date?, now: Date) -> Bool {
        guard let lastFetchedAt else { return true }
        if lastFetchedAt > now { return true }
        return now.timeIntervalSince(lastFetchedAt) >= refreshMinInterval
    }
}
