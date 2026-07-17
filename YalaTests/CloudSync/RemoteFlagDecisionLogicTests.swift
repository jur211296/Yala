//
//  RemoteFlagDecisionLogicTests.swift
//  YalaTests / CloudSync
//
//  Pure-logic del remote-config (DIFERIDOS #34): bucket estable, decisión por percent con
//  `absentDefault` PARAMÉTRICO (ajuste A1 del review: los tests corren siempre bajo DEV_BUILD —
//  la rama prod fail-closed entra a la tabla por parámetro) y cadencia de refresh.
//

import Foundation
import Testing

@testable import Yala

@Suite("RemoteFlagDecisionLogic — bucket, percent y refresh (tabla)")
struct RemoteFlagDecisionLogicTests {

    // MARK: - Bucket estable

    @Test func bucket_goldenVectors_stability() {
        // GOLDEN de estabilidad cross-launch: FNV-1a mod 100 con vectores FIJOS. Si estos valores
        // cambian, TODA cohorte de rollout se re-baraja (usuarios entran/salen del %) — jamás
        // cambiar el hash sin migrar el seed.
        #expect(RemoteFlagDecisionLogic.stableBucket(seed: "00000000-0000-0000-0000-000000000000") == 89)
        #expect(RemoteFlagDecisionLogic.stableBucket(seed: "A5CA9791-EFCB-4B8C-88DC-5926E62F50D2") == 37)
        #expect(RemoteFlagDecisionLogic.stableBucket(seed: "seed-a") == 30)
        #expect(RemoteFlagDecisionLogic.stableBucket(seed: "seed-b") == 19)
    }

    @Test func bucket_deterministic_andInRange() {
        for _ in 0..<20 {
            let seed = UUID().uuidString
            let first = RemoteFlagDecisionLogic.stableBucket(seed: seed)
            #expect(first == RemoteFlagDecisionLogic.stableBucket(seed: seed))
            #expect((0..<100).contains(first))
        }
    }

    // MARK: - isEnabled (percent × bucket × absentDefault)

    @Test func isEnabled_table() {
        typealias Row = (percent: Int?, bucket: Int, absentDefault: Bool, expected: Bool)
        let rows: [Row] = [
            // percent presente: bucket < clamp(percent) — absentDefault IRRELEVANTE.
            (0, 0, true, false),     // 0% = OFF universal aunque el default fuera ON
            (0, 99, false, false),
            (100, 0, false, true),   // 100% = ON universal
            (100, 99, false, true),
            (50, 49, false, true),   // frontera: dentro
            (50, 50, false, false),  // frontera: fuera
            (1, 0, false, true),
            (1, 1, false, false),
            // clamp fuera de rango (el server ya clampa; el cliente NO confía)
            (150, 99, false, true),
            (-5, 0, true, false),
            // percent AUSENTE → absentDefault (prod false fail-closed / DEV true)
            (nil, 0, false, false),
            (nil, 0, true, true),
        ]
        for row in rows {
            #expect(
                RemoteFlagDecisionLogic.isEnabled(
                    percent: row.percent, bucket: row.bucket, absentDefault: row.absentDefault
                ) == row.expected,
                "percent=\(String(describing: row.percent)) bucket=\(row.bucket) absent=\(row.absentDefault)"
            )
        }
    }

    // MARK: - shouldRefresh

    @Test func shouldRefresh_table() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // Jamás fetcheado → sí.
        #expect(RemoteFlagDecisionLogic.shouldRefresh(lastFetchedAt: nil, now: now))
        // Fresco (1 h) → no.
        #expect(!RemoteFlagDecisionLogic.shouldRefresh(lastFetchedAt: now.addingTimeInterval(-3600), now: now))
        // Justo en el min-interval (6 h) → sí.
        #expect(RemoteFlagDecisionLogic.shouldRefresh(
            lastFetchedAt: now.addingTimeInterval(-RemoteFlagDecisionLogic.refreshMinInterval), now: now))
        // fetchedAt en el FUTURO (reloj movido hacia atrás) → futuro = stale, refresca YA
        // (fix del review: sin esto, un reloj mal adelantado congelaría el kill-switch).
        #expect(RemoteFlagDecisionLogic.shouldRefresh(lastFetchedAt: now.addingTimeInterval(600), now: now))
    }
}

@Suite("StorageRowGateLogic — visibilidad de la fila Almacenamiento (tabla 2⁴)")
struct StorageRowGateLogicTests {

    @Test func table() {
        typealias Row = (configured: Bool, secondary: Bool, remote: Bool, engaged: Bool, visible: Bool)
        let rows: [Row] = [
            // Sin backend configurado: JAMÁS visible (prod placeholder de hoy), da igual el resto.
            (false, false, true, true, false),
            (false, false, false, false, false),
            // Secundaria activa: oculta SIEMPRE (M1 — la fila es del DUEÑO).
            (true, true, true, true, false),
            (true, true, false, false, false),
            // Configurado + remoto ON: visible (engaged irrelevante).
            (true, false, true, false, true),
            (true, false, true, true, true),
            // Configurado + remoto OFF (kill-switch): SOLO engaged la conserva
            // (gestión + resume + REVERSA — decisión owner: el kill corta la ENTRADA).
            (true, false, false, true, true),
            (true, false, false, false, false),
        ]
        for row in rows {
            #expect(
                StorageRowGateLogic.isVisible(
                    isConfigured: row.configured,
                    isSecondaryActive: row.secondary,
                    remoteEnabled: row.remote,
                    isEngaged: row.engaged
                ) == row.visible,
                "configured=\(row.configured) secondary=\(row.secondary) remote=\(row.remote) engaged=\(row.engaged)"
            )
        }
    }
}
