//
//  SpikeS6Harness.swift
//  Yala
//
//  Harness DEBUG device-only del spike S6 (Modo Nube Fase 4). NO es código de producción: vive
//  entero bajo `#if DEBUG`, no se cablea a ningún path de la app ni al motor CloudSync, y se invoca
//  EXCLUSIVAMENTE desde la sección "Spike S6" del panel `CloudSyncDebugView` (DEV_BUILD).
//
//  Qué responde S6 (ARQUITECTURA §5 spike list; cierre SERIO 3 v3, §h.1/§h.3):
//   1. Re-montar el mirror `.private` sobre un CloudKit congelado NO-trivial (el dev del owner, con
//      Grupos VIVO sobre el mismo `mainContext`) → ¿el import/reconciliación inicial transcurre sin
//      romper nada?
//   2. ¿Esperar `isImportQuiescent` ANTES del primer `delete`+`save()` de un reverseReconcile
//      simulado EVITA el `_assertionFailure`/SIGTRAP?
//   3. ¿Un kill en cada sub-estado journaleado (`deletingZombies`/`rebindingUUIDs`/`dedupHealed`)
//      retoma limpio: sin re-aplicar borrados, sin zombies residuales?
//
//  NO se intenta reproducir el SIGTRAP (variante sin gate) — sería invitar un crash-loop sobre el
//  device del owner. El spike es la prueba POSITIVA del gate + la resumibilidad.
//
//  REGLA DEL REPO (harness): NUNCA `try?` que silencia. Aquí CADA error se CAPTURA y se MUESTRA como
//  texto (en el log del panel o en la cabecera de estado) — mostrar el error verbatim ES el punto.
//
//  Journal-then-execute (espeja la máquina de migración real de I10/I11, que será @Model): el estado
//  del sub-paso se ESCRIBE (journal en `UserDefaults`, keys `spikeS6.*`) ANTES de ejecutarlo. Retomar
//  tras un kill = EJECUTAR el sub-estado journaleado-pero-no-completado (idempotente); los COMPLETOS
//  se saltan. `UserDefaults` basta para un spike.
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
@Observable
final class SpikeS6Harness {

    // MARK: - Sub-estados del reverseReconcile (orden = orden de ejecución)

    enum SubState: String, CaseIterable {
        case deletingZombies
        case rebindingUUIDs
        case dedupHealed
    }

    // MARK: - Journal keys (`spikeS6.*` en UserDefaults.standard)

    private enum Keys {
        static let subState = "spikeS6.subState"          // último sub-estado journaleado (o "done")
        static let completedPrefix = "spikeS6.completed."  // + rawValue → Bool "ya ejecutado"
        static let killToggle = "spikeS6.killAfterNextJournal"
        static let dedupHealedAt = "spikeS6.dedupHealedAt"
    }

    // MARK: - Notes de las TXs del spike (JAMÁS tocan datos reales del owner)

    /// TX zombie: la escribe FASE 0/A, la borra `deletingZombies`. El match es por IGUALDAD EXACTA
    /// contra las variantes conocidas (base / " (editada offline)" / " (rebound)") — GOTCHA device
    /// (round 2): `localizedStandardContains` sobre `note` opcional genera `TERNARY(...) CONTAINS[cdl]`
    /// que el SQL de SwiftData NO implementa → NSInvalidArgumentException NO atrapable (crash real en
    /// el device del owner). La igualdad (`$0.note == x`) está probada en device por el harness S5.
    static let zombieNote = "🧟 SPIKE-S6 — zombie"
    /// TX marker: la crea/muta/borra `rebindingUUIDs` (trabajo idempotente sin tocar datos reales).
    static let markerNote = "🧪 SPIKE-S6 — marker"

    // MARK: - Log

    /// Log acumulado que el panel muestra (monoespaciado, scrolleable). Cada línea con timestamp.
    private(set) var log: String = ""
    var isWorking = false

    // MARK: - Cabecera de estado viva (la refresca el panel cada ~1s en DEBUG)

    private(set) var quiescentNow: Bool = false
    private(set) var zombieCount: Int = 0
    private(set) var markerCount: Int = 0
    private(set) var journaledSubState: String = "—"
    private(set) var headerError: String?

    /// Modo mirror deducido del arg de launch (constante durante el proceso).
    var mirrorOff: Bool { SwiftDataConfiguration.isSpikeS6MirrorOff }

    // MARK: - Toggle de kill (persistido: debe sobrevivir al kill+relaunch)

    var killAfterNextJournal: Bool {
        didSet { UserDefaults.standard.set(killAfterNextJournal, forKey: Keys.killToggle) }
    }

    init() {
        // Asignación en init NO dispara didSet → sin escritura redundante.
        killAfterNextJournal = UserDefaults.standard.bool(forKey: Keys.killToggle)
        journaledSubState = journaledRaw ?? "—"
    }

    // MARK: - Log helpers

    private func line(_ text: String) {
        let ts = Self.timestampFormatter.string(from: Date())
        log += "[\(ts)] \(text)\n"
    }

    private func section(_ title: String) {
        log += "\n──────── \(title) ────────\n"
    }

    func clearLog() { log = "" }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    // MARK: - Journal helpers

    private var journaledRaw: String? { UserDefaults.standard.string(forKey: Keys.subState) }
    private func isCompleted(_ s: SubState) -> Bool {
        UserDefaults.standard.bool(forKey: Keys.completedPrefix + s.rawValue)
    }
    private func markCompleted(_ s: SubState) {
        UserDefaults.standard.set(true, forKey: Keys.completedPrefix + s.rawValue)
    }
    private func journalSubState(_ s: SubState) {
        UserDefaults.standard.set(s.rawValue, forKey: Keys.subState)
        journaledSubState = s.rawValue
    }

    // MARK: - Cabecera de estado

    /// Refresca la cabecera viva. El conteo puede lanzar → se CAPTURA en `headerError` (mostrado en la
    /// cabecera), NUNCA silenciado; no se loguea cada tick para no spamear el log.
    func refreshHeader(context: ModelContext) {
        quiescentNow = iCloudSyncService.shared.isImportQuiescent
        journaledSubState = journaledRaw ?? "—"
        do {
            zombieCount = try count(matching: Self.zombieNote, context: context)
            markerCount = try count(matching: Self.markerNote, context: context)
            headerError = nil
        } catch {
            headerError = "conteo falló: \(error)"
        }
    }

    // MARK: - FASE 0 · Preparar zombies (mirror ON)

    /// Crea 3 TXs 🧟 (0.01, primera cuenta) + save. El mirror las exporta a CloudKit → serán el estado
    /// CONGELADO que verá el remontaje.
    func prepareZombies(context: ModelContext) {
        isWorking = true; defer { isWorking = false }
        section("FASE 0 · Preparar zombies (mirror ON)")
        if mirrorOff {
            line("⚠️ El arg -spike-s6-mirror-off ESTÁ presente (mirror OFF). La FASE 0 se hace con el")
            line("   mirror ON para exportar a CloudKit. QUITA el arg y relanza antes de esto.")
        }
        do {
            let account = try context.fetch(FetchDescriptor<Account>()).first
            for _ in 1...3 {
                let tx = TransactionItem(
                    date: .now, amount: 0.01,
                    currencyCode: account?.currencyCode ?? "USD",
                    note: Self.zombieNote, account: account
                )
                context.insert(tx)
            }
            try context.save()
            line("✅ 3 TXs 🧟 creadas + guardadas (cuenta=\(account?.name ?? "«sin cuenta»")).")
            line("⏳ Espera ~60s: el mirror exporta a CloudKit en segundo plano.")
            line("   Luego AÑADE el arg -spike-s6-mirror-off al scheme y relanza → botón [A].")
            refreshHeader(context: context)
        } catch {
            line("❌ Error creando zombies: \(error)")
        }
    }

    // MARK: - FASE A · Divergencia offline (mirror OFF)

    /// Edita las 3 zombies (note += " (editada offline)") y crea 2 🧟 más + save. CloudKit queda
    /// CONGELADO con el estado viejo (3 sin editar, sin las 2 nuevas) — la precondición de la reversa.
    func divergeOffline(context: ModelContext) {
        isWorking = true; defer { isWorking = false }
        section("FASE A · Divergencia offline (mirror OFF)")
        if !mirrorOff {
            line("⚠️ El arg -spike-s6-mirror-off NO está presente (mirror ON). La FASE A simula edición")
            line("   OFFLINE — sin el arg se exportará de inmediato en vez de quedar divergente.")
        }
        do {
            // Editar SOLO las que aún no llevan el sufijo (idempotente ante re-taps).
            let all = try fetch(matching: Self.zombieNote, context: context)
            var edited = 0
            for tx in all where (tx.note ?? "") == Self.zombieNote {
                tx.note = Self.zombieNote + " (editada offline)"
                edited += 1
            }
            // Crear 2 nuevas.
            let account = try context.fetch(FetchDescriptor<Account>()).first
            for _ in 1...2 {
                let tx = TransactionItem(
                    date: .now, amount: 0.01,
                    currencyCode: account?.currencyCode ?? "USD",
                    note: Self.zombieNote, account: account
                )
                context.insert(tx)
            }
            try context.save()
            line("✅ \(edited) zombie(s) editada(s) + 2 nueva(s) + guardado (total esperado: 5 🧟 local).")
            line("   CloudKit CONGELADO con el estado viejo (3 sin editar, sin las 2 nuevas).")
            line("   Ahora QUITA el arg -spike-s6-mirror-off y relanza → REMONTAJE → botón [B].")
            refreshHeader(context: context)
        } catch {
            line("❌ Error en divergencia offline: \(error)")
        }
    }

    // MARK: - FASE B · reverseReconcile simulado (gateado + resumible)

    /// Espera quiescencia y corre los 3 sub-estados journal-then-execute. Con el toggle de kill ON,
    /// tras journalear un sub-estado NUEVO alerta "🔪 MATA LA APP AHORA" y NO ejecuta. Al relanzar,
    /// el sub-estado journaleado-pero-no-completado SE EJECUTA (idempotente); los COMPLETOS se saltan.
    func runReverseReconcile(context: ModelContext) async {
        isWorking = true; defer { isWorking = false }
        section("FASE B · reverseReconcile simulado (gateado)")
        if mirrorOff {
            line("🔴 El arg -spike-s6-mirror-off SIGUE presente (mirror OFF). El REMONTAJE requiere")
            line("   QUITAR el arg y relanzar (el mirror debe re-montar). Aborto.")
            return
        }

        // a. awaitQuiescence — si no llega, NO procede (eso también es dato).
        let quiescent = await awaitQuiescence()
        if !quiescent {
            line("🔴 No se alcanzó quiescencia en 120s. NO procedo (esto ES un dato del spike:")
            line("   el remontaje no asentó el import a tiempo). Reintenta [B] en unos segundos.")
            return
        }

        // b/c/d. Sub-estados en orden, journal-then-execute con skip de completos.
        for s in SubState.allCases {
            if isCompleted(s) {
                line("↩️ RETOMADO: SALTO \(s.rawValue) — ya COMPLETO, no re-aplico.")
                continue
            }
            let resumingJournaled = (journaledRaw == s.rawValue)
            if resumingJournaled {
                // Journaleado en un run anterior pero no completado (kill entre journal y execute).
                // El kill de ESTE sub-estado ya ocurrió → lo ejecuto directo (ignoro el toggle aquí,
                // o entraríamos en bucle infinito de journal→kill sobre el mismo sub-estado).
                line("↩️ RETOMADO: \(s.rawValue) estaba JOURNALEADO sin ejecutar → lo EJECUTO ahora.")
            } else {
                // Sub-estado NUEVO: journal PRIMERO (journal-then-execute).
                journalSubState(s)
                line("📓 Journaleé sub-estado NUEVO: \(s.rawValue).")
                if killAfterNextJournal {
                    line("🔪 MATA LA APP AHORA (swipe up) y relanza. Journaleé \(s.rawValue) SIN ejecutarlo.")
                    line("   Al relanzar, pulsa [B]: retomará y EJECUTARÁ \(s.rawValue) (no lo duplica).")
                    return
                }
            }
            do {
                try execute(s, context: context)
                markCompleted(s)
                line("✅ EJECUTADO \(s.rawValue) + marcado COMPLETO.")
            } catch {
                line("❌ Error ejecutando \(s.rawValue): \(error) — dejo el journal para retomar.")
                return
            }
        }

        // e. done — limpia el journal del spike + resumen.
        UserDefaults.standard.set("done", forKey: Keys.subState)
        line("🏁 done — reverseReconcile completo sin SIGTRAP.")
        UserDefaults.standard.removeObject(forKey: Keys.subState)
        for s in SubState.allCases {
            UserDefaults.standard.removeObject(forKey: Keys.completedPrefix + s.rawValue)
        }
        journaledSubState = "—"
        line("🧹 journal de sub-estados limpiado (re-pulsar [B] re-corre idempotente).")
        refreshHeader(context: context)
        line("   Ejecuta [Verificar invariantes] para confirmar 0 🧟 y 0 🧪.")
    }

    /// Espera `isImportQuiescent` con ticks logueados (0.5s, tope 120s). Devuelve si llegó.
    private func awaitQuiescence() async -> Bool {
        line("⏳ awaitQuiescence: esperando isImportQuiescent (tick 0.5s, tope 120s)…")
        let start = Date()
        let deadline: TimeInterval = 120
        var tick = 0
        while Date().timeIntervalSince(start) < deadline {
            if iCloudSyncService.shared.isImportQuiescent {
                let elapsed = String(format: "%.1f", Date().timeIntervalSince(start))
                line("✅ quiescencia alcanzada tras \(elapsed)s (\(tick) tick(s)).")
                return true
            }
            tick += 1
            line("   tick \(tick): aún NO quiescente (import en curso o dentro de la ventana de quietud).")
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                line("   (sleep cancelado: \(error)) — abandono awaitQuiescence.")
                return iCloudSyncService.shared.isImportQuiescent
            }
        }
        line("⏱️ tope de 120s alcanzado SIN quiescencia.")
        return false
    }

    /// Trabajo real de cada sub-estado. Sin `await` (todo es SwiftData síncrono en el mainContext).
    private func execute(_ s: SubState, context: ModelContext) throws {
        switch s {
        case .deletingZombies:
            let zombies = try fetch(matching: Self.zombieNote, context: context)
            line("   deletingZombies: \(zombies.count) 🧟 a borrar.")
            for tx in zombies { context.delete(tx) }
            try context.save()
            line("   deletingZombies: borradas + save() OK (primer delete+save gateado por quiescencia).")

        case .rebindingUUIDs:
            // Idempotente: limpia markers residuales de un run parcial anterior antes del ciclo.
            let leftovers = try fetch(matching: Self.markerNote, context: context)
            if !leftovers.isEmpty {
                line("   rebindingUUIDs: \(leftovers.count) 🧪 residual(es) — limpio antes del ciclo.")
                for tx in leftovers { context.delete(tx) }
                try context.save()
            }
            let account = try context.fetch(FetchDescriptor<Account>()).first
            let tx = TransactionItem(
                date: .now, amount: 0.01,
                currencyCode: account?.currencyCode ?? "USD",
                note: Self.markerNote, account: account
            )
            context.insert(tx)
            try context.save()
            line("   rebindingUUIDs: 🧪 marker creado + save().")
            tx.note = Self.markerNote + " (rebound)"
            try context.save()
            line("   rebindingUUIDs: campo inocuo (note) regenerado + save().")
            context.delete(tx)
            try context.save()
            line("   rebindingUUIDs: marker borrado + save() (rebind idempotente, sin tocar datos reales).")

        case .dedupHealed:
            let ts = Self.timestampFormatter.string(from: Date())
            UserDefaults.standard.set(ts, forKey: Keys.dedupHealedAt)
            line("   dedupHealed: no-op con marca temporal \(ts).")
        }
    }

    // MARK: - Verificar invariantes

    /// Cuenta 🧟 (0 tras done) y 🧪 residuales (0), y vuelca el journal.
    func verifyInvariants(context: ModelContext) {
        isWorking = true; defer { isWorking = false }
        section("Verificar invariantes")
        do {
            let z = try count(matching: Self.zombieNote, context: context)
            let m = try count(matching: Self.markerNote, context: context)
            line("🧟 zombies: \(z)   (esperado 0 tras done)")
            line("🧪 markers: \(m)   (esperado 0)")
            line("📓 journal.subState = \(journaledRaw ?? "—")")
            for s in SubState.allCases {
                line("   completed.\(s.rawValue) = \(isCompleted(s))")
            }
            if let d = UserDefaults.standard.string(forKey: Keys.dedupHealedAt) {
                line("   dedupHealedAt = \(d)")
            }
            line(z == 0 && m == 0 ? "✅ invariantes OK." : "🔴 residuos presentes — revisa arriba.")
            refreshHeader(context: context)
        } catch {
            line("❌ Error verificando invariantes: \(error)")
        }
    }

    // MARK: - Reset spike

    /// Borra el journal + TXs 🧟/🧪 residuales (para re-correr limpio). NO borra el toggle de kill
    /// (es preferencia del owner).
    func resetSpike(context: ModelContext) {
        isWorking = true; defer { isWorking = false }
        section("Reset spike")
        do {
            let zombies = try fetch(matching: Self.zombieNote, context: context)
            let markers = try fetch(matching: Self.markerNote, context: context)
            for tx in zombies { context.delete(tx) }
            for tx in markers { context.delete(tx) }
            if !zombies.isEmpty || !markers.isEmpty { try context.save() }
            line("🧹 borradas \(zombies.count) 🧟 + \(markers.count) 🧪.")
            UserDefaults.standard.removeObject(forKey: Keys.subState)
            for s in SubState.allCases {
                UserDefaults.standard.removeObject(forKey: Keys.completedPrefix + s.rawValue)
            }
            UserDefaults.standard.removeObject(forKey: Keys.dedupHealedAt)
            journaledSubState = "—"
            line("🧹 journal borrado (subState + completed.* + dedupHealedAt).")
            refreshHeader(context: context)
            line("   Listo para re-correr desde FASE 0.")
        } catch {
            line("❌ Error en reset: \(error)")
        }
    }

    // MARK: - Fetch/count helpers (predicado CONCRETO por tipo — regla #Predicate de CLAUDE.md)

    /// Match por IGUALDAD EXACTA contra las 3 variantes que el propio harness produce (ver GOTCHA en
    /// las constantes de note: CONTAINS[cdl] sobre opcional crashea en SQL generation, no atrapable).
    private func descriptor(forBaseNote base: String) -> FetchDescriptor<TransactionItem> {
        let a = base
        let b = base + " (editada offline)"
        let c = base + " (rebound)"
        return FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { tx in
                tx.note == a || tx.note == b || tx.note == c
            }
        )
    }

    private func count(matching baseNote: String, context: ModelContext) throws -> Int {
        try context.fetchCount(descriptor(forBaseNote: baseNote))
    }

    private func fetch(matching baseNote: String, context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(descriptor(forBaseNote: baseNote))
    }
}
#endif
