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
            // Sin backend configurado: JAMÁS visible, da igual el resto. Ya NO es el estado de producción
            // (D-R1 paso 1 la configuró), pero la rama del gate sigue existiendo y hay que pinnearla.
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

    /// **CHIP M3 · la celda que el override abre, y las 8 que NO toca.**
    ///
    /// El default `false` es lo que hace que la tabla de arriba siga midiendo lo mismo, así que aquí hay
    /// que ejercitar el parámetro EXPLÍCITO en los dos valores: con `true` y sin secundaria el veredicto no
    /// puede cambiar ni una celda — si cambiara, un build DEV estaría enseñando la fila del dueño donde
    /// producción la oculta, y el panel dejaría de ser una puerta de servicio para ser otra pantalla.
    @Test func devPanelOverride_opensOnlyTheSecondaryCell() {
        // Secundaria: el override ES el veredicto, y NO mira los otros tres términos. Un build DEV con el
        // backend sin configurar y el kill remoto puesto tiene que llegar al panel igual — el descriptor y
        // el wipe secundario no dependen de nada de eso.
        for configured in [true, false] {
            for remote in [true, false] {
                for engaged in [true, false] {
                    #expect(StorageRowGateLogic.isVisible(
                        isConfigured: configured, isSecondaryActive: true,
                        remoteEnabled: remote, isEngaged: engaged,
                        devPanelOverride: true) == true,
                            "override ON en secundaria ⇒ visible (configured=\(configured) remote=\(remote) engaged=\(engaged))")
                    #expect(StorageRowGateLogic.isVisible(
                        isConfigured: configured, isSecondaryActive: true,
                        remoteEnabled: remote, isEngaged: engaged,
                        devPanelOverride: false) == false,
                            "sin override, secundaria sigue oculta SIEMPRE (M1)")
                }
            }
        }

        // FUERA de secundaria el override es INERTE: pasarlo no puede abrir ni cerrar ninguna de las 8
        // celdas del dueño. Sin esta mitad, un override que devolviera `true` a secas pasaría la de arriba.
        for configured in [true, false] {
            for remote in [true, false] {
                for engaged in [true, false] {
                    let sinOverride = StorageRowGateLogic.isVisible(
                        isConfigured: configured, isSecondaryActive: false,
                        remoteEnabled: remote, isEngaged: engaged)
                    let conOverride = StorageRowGateLogic.isVisible(
                        isConfigured: configured, isSecondaryActive: false,
                        remoteEnabled: remote, isEngaged: engaged,
                        devPanelOverride: true)
                    #expect(sinOverride == conOverride, """
                        el override DEV movió una celda del DUEÑO (configured=\(configured) \
                        remote=\(remote) engaged=\(engaged)): solo puede abrir la de secundaria.
                        """)
                }
            }
        }
    }

    /// La constante que decide en producción. En la suite de unit tests el host es la app, así que su valor
    /// depende del scheme — pero lo que hay que pinnear no es el valor: es que el `#if` viva en UN solo
    /// sitio y sea el que el call-site consulta (eso lo comprueba `StorageRowDevPanelWiringTests`).
    @Test func devPanelOverrideAvailable_matchesTheBuildFlavour() {
        #if DEV_BUILD
        #expect(StorageRowGateLogic.devPanelOverrideAvailable)
        #else
        #expect(!StorageRowGateLogic.devPanelOverrideAvailable, """
            la llave DEV del panel quedó encendida en un build de PRODUCCIÓN: la fila de Almacenamiento \
            aparecería en sesión secundaria, que es justo lo que M1 oculta porque describe al DUEÑO.
            """)
        #endif
    }
}

/// **CHIP M3 · cableado del acceso al panel y del cuarto trigger del net (source-scan).**
///
/// Las tres afirmaciones de este chip son de QUIÉN LLAMA, y ninguna la puede hacer un test de
/// comportamiento desde aquí: la fila vive en una vista SwiftUI, el emisor de la señal en otra, y el
/// receptor es un `ViewModifier` privado de `ContentView`. Sin estos scans, quitar cualquiera de los tres
/// cableados deja la suite entera en verde con el QA de sim soft-lockeado otra vez. Molde `AttestWiringTests`.
@Suite("M3 · cableado del panel DEBUG en secundaria y de la señal del descriptor (source-scan)")
struct StorageRowDevPanelWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código SIN líneas de comentario: los docblocks de esta familia NOMBRAN lo que prohíben, y contar la
    /// prosa haría que documentar el invariante lo satisficiera solo.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("la fila pasa la constante del gate, nunca un `#if` a mano ni un `true`")
    func profileRowPassesTheGateConstant() throws {
        let profile = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains("devPanelOverride: StorageRowGateLogic.devPanelOverrideAvailable"), """
            la fila de Almacenamiento dejó de pasar la llave DEV del gate. O el panel volvió a ser \
            inalcanzable en sesión secundaria (M1-4: descriptor puesto y solo lldb para salir), o alguien \
            metió un `#if DEV_BUILD` suelto en la vista, que es el sitio donde nadie lo audita.
            """)
        #expect(!profile.contains("devPanelOverride: true"), """
            un `true` literal en el call-site enciende la fila también en PRODUCCIÓN. La llave tiene que \
            salir de `devPanelOverrideAvailable`, que es la única que sabe del sabor del build.
            """)
    }

    @Test("los dos botones del descriptor emiten la señal, y DESPUÉS de escribirlo")
    func debugPanelPostsTheSignalAfterWriting() throws {
        let panel = try Self.code("Yala/App/Views/Settings/CloudSyncDebugView.swift")

        let activate = try #require(panel.range(of: "SecondarySessionStore.activate(userID: \"guest-debug\")"))
        let clear = try #require(panel.range(of: "SecondarySessionStore.clear()"))
        // Dos posts, uno por botón: el de armar y el de desarmar. Sin el segundo, limpiar el descriptor
        // deja el cover terminal puesto sobre una condición que ya no existe.
        let posts = panel.components(separatedBy: "DevSecondaryDescriptorSignal.post()").count - 1
        #expect(posts == 2, """
            el panel emite \(posts) señales del descriptor y tienen que ser 2 (activar FAKE y limpiar). \
            La que falta deja el net leyendo el estado anterior hasta el próximo foreground.
            """)

        // El ORDEN: la señal después de la escritura. Emitirla antes hace que el receptor re-evalúe la
        // condición VIEJA, que es exactamente el bug que este trigger cierra.
        let firstPost = try #require(panel.range(of: "DevSecondaryDescriptorSignal.post()"))
        #expect(activate.upperBound < firstPost.lowerBound)
        let postAfterClear = try #require(
            panel.range(of: "DevSecondaryDescriptorSignal.post()",
                        range: clear.upperBound..<panel.endIndex),
            "el botón de limpiar el descriptor no emite ninguna señal DESPUÉS de limpiarlo")
        #expect(clear.upperBound < postAfterClear.lowerBound)
    }

    @Test("el net secundario monta el cuarto trigger, y el signout NO")
    func secondaryNetReceivesTheSignal() throws {
        let content = try Self.code("Yala/App/ContentView.swift")
        #expect(content.contains("DevSecondaryDescriptorReevaluation(onSignal: reevaluate)"), """
            el net de la ventana de entrada secundaria perdió el trigger del panel: activar el descriptor \
            vuelve a dejar la app navegable sobre el store del DUEÑO hasta la siguiente re-evaluación.
            """)
        // UN solo call-site: el modifier es del net SECUNDARIO. Colgarlo también del net de sign-out le
        // daría un cuarto trigger a una red cuya condición (`CloudSessionSignOut.phase`) esta señal no
        // toca — armaría o retiraría su cover terminal por un evento que no es suyo.
        let mounts = content.components(separatedBy: "DevSecondaryDescriptorReevaluation(").count - 1
        #expect(mounts == 1, "el trigger del panel se montó \(mounts) veces; es del net secundario y de nadie más")

        // La re-evaluación decide con la condición VIVA y en los DOS sentidos. Si solo supiera armar, el
        // botón «limpiar descriptor» dejaría el cover puesto y el panel detrás — sin salida, que es
        // literalmente el soft-lock que M1-4 reporta.
        #expect(content.contains("if isArmedUnmounted {"),
                "`reevaluate` dejó de preguntar por la condición viva")
    }

    @Test("el atajo de QA no entra al binario de producción")
    func theSignalIsDevOnly() throws {
        let signal = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala/App/Logic/DevSecondaryDescriptorSignal.swift"),
            encoding: .utf8)
        #expect(signal.contains("#if DEV_BUILD"), """
            `DevSecondaryDescriptorSignal` dejó de estar bajo `DEV_BUILD`. La invariante del chip es que \
            ningún atajo de QA viaje en el binario de producción.
            """)
        let content = try Self.code("Yala/App/ContentView.swift")
        #expect(content.contains("#if DEV_BUILD"),
                "el receptor tiene que compilarse solo en builds DEV; en producción es `content` y nada más")
    }
}
