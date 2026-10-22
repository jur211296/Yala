//
//  CloudHydrationBanner.swift
//  Yala
//
//  Banner de HIDRATACIÓN: el store nace VACÍO y el runtime lo puebla con el pull normal (cursor 0).
//  Mientras el primer pull no complete, la persona vería una app "en cero" sin explicación — este banner
//  (molde del joinBanner de GroupsContainerView) muestra la fase REAL.
//
//  **A quién sirve, que no es a quien lo creó.** Nació en M1 para la sesión de visita y cubría medio
//  problema: tras el relanzamiento del adopt, el store personal del DUEÑO nace igual de vacío y se puebla
//  igual desde el cursor 0, así que quien cambia de móvil entra con su cuenta, reinicia, y se encuentra
//  Yala en blanco sin una palabra. Era el mismo hecho por la otra puerta, y el término de M1 lo excluía.
//
//  Desde el 2026-08-12 el gate lee el MUNDO y no el camino: **se ve vacío + el motor está hidratando**.
//  Así llega a quien vuelve sin tener que enumerar por qué ruta llegó, que es justo lo que dejó fuera a la
//  re-entrada. Al retirarse M1 (2026-09-13) se fue el primer término y quedó lo que de verdad decide; el
//  nombre cambió con él, porque «secundario» ya no describe nada.
//
//  Los tres falsos positivos que evita: quien ya tiene sus datos en pantalla (no espera nada), quien no
//  tiene motor de nube (no hay ninguna descarga que explicar) y, desde el 2026-09-17, **el teléfono que no
//  consigue App Attest**: con el veredicto terminal el motor no baja nada, y el aviso de attest ya explica
//  por qué (ticket `cloud-hydration-spinner-never-gives-up-without-attest`). Antes giraba para siempre al
//  lado de ese aviso, diciendo que descargaba lo que el aviso decía que no iba a llegar.
//
//  Poll de 1s (molde del refresh de StorageSettingsView): `hasCompletedFirstPull` no es
//  @Observable, y el veredicto tampoco —vive en `UserDefaults` y depende del reloj—. Costo cero para el
//  modo privado: sin motor, el task sale en el primero.
//
import SwiftUI

/// Decisión pura del banner (testeable en tabla).
nonisolated enum CloudHydrationLogic {
    /// ¿Se enseña «Descargando tus datos…» AHORA? Sin parámetros por defecto a propósito: quien llame se
    /// pronuncia sobre los cuatro, como en `CloudAttestNoticeLogic.showsNotice`.
    ///
    /// - Parameters:
    ///   - firstPullCompleted: `SyncQuiescenceCoordinator.hasCompletedFirstPull`, señal GENÉRICA del
    ///     motor. Es de sesión de proceso, por eso sola no basta para el dueño: en un arranque normal
    ///     empieza en `false` y el banner saldría cada vez.
    ///   - cloudEngineActive: hay motor que pueda estar descargando algo (`storageMode == .cloud`).
    ///   - storeLooksEmpty: la app se ve en cero. Es el término que convierte «el motor arranca» en «la
    ///     pantalla que estás mirando está vacía y por eso te lo explico».
    ///   - attestVerdictIsTerminal: `GroupsAttestStreakStore.isTerminal()`, **a secas**. Basta porque la
    ///     descarga que este banner explica es el pull del MOTOR, y ése exige token:
    ///     `CloudSyncRuntime.performCycle` pasa por su puerta antes de subir y de bajar, y un token conseguido
    ///     borra la racha (`resolveAttest` → `recordAcceptance`). Con el veredicto terminal, por tanto, el
    ///     motor no está bajando nada. **No es `CloudAttestNotice.isShowing`**: sus otras condiciones dicen a
    ///     quién le es cierta la FRASE del aviso, no si el motor baja algo, y atarse a ellas devolvería el
    ///     spinner donde el veredicto ya dice que no baja nada (sin sesión, por ejemplo). En la población del
    ///     ticket —nube, sesión, canal estable— las dos coinciden, y el aviso queda como la única voz.
    ///
    ///     Lo que NO cubre, medido en la review del 2026-09-17: los pulls de la MIGRACIÓN
    ///     (`MigrationWorkExecutor.verify` y el drenaje de la vuelta a iCloud) piden el token con `try?` y no
    ///     tocan la racha, así que en una vuelta a iCloud retomada tras relanzar el banner puede esconderse
    ///     mientras ese drenaje baja datos. Antes giraba hasta relanzar, también después de bajarlos.
    static func showBanner(
        firstPullCompleted: Bool,
        cloudEngineActive: Bool,
        storeLooksEmpty: Bool,
        attestVerdictIsTerminal: Bool
    ) -> Bool {
        keepsWatching(
            firstPullCompleted: firstPullCompleted,
            cloudEngineActive: cloudEngineActive,
            storeLooksEmpty: storeLooksEmpty)
            && !attestVerdictIsTerminal
    }

    /// ¿Sigue habiendo algo que vigilar? Decide cuándo TERMINA el sondeo, y **el veredicto no entra, a
    /// propósito**. Esconde el banner, pero no acaba la espera: la racha se borra en cuanto la puerta del motor
    /// consigue un token, y la descarga empieza justo después. Pasa al arrancar con una racha heredada de una
    /// copia de iCloud, o cuando el attest vuelve. Si el veredicto terminara el sondeo, nadie volvería a mirar y
    /// esa descarga iría entera sin banner.
    ///
    /// `storeLooksEmpty` llega CONGELADO al valor con que montó el `.task` (no se reinicia cuando el shell lo
    /// vuelve a medir), así que «con datos en pantalla» solo termina el sondeo si ya los había al montar. Es
    /// anterior a este término y tiene ticket: `cloud-hydration-banner-does-not-see-data-that-arrives-after-mount`.
    static func keepsWatching(
        firstPullCompleted: Bool,
        cloudEngineActive: Bool,
        storeLooksEmpty: Bool
    ) -> Bool {
        guard !firstPullCompleted else { return false }
        return cloudEngineActive && storeLooksEmpty
    }
}

struct CloudHydrationBanner: View {
    /// «La app se ve vacía», tal como lo mide el shell (`ContentView.checkHasExistingData`). Se recibe
    /// del anchor en vez de re-contarlo aquí: es el MISMO detector que decide el alert del Welcome, y
    /// dos detectores distintos de «hay datos» es como divergen.
    var storeLooksEmpty: Bool

    @State private var visible = false

    var body: some View {
        Group {
            if visible {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.Welcome.Cloud.hydrationBanner)
                        .font(DS.Typography.caption)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .glassEffect()
                .accessibilityIdentifier("cloud_hydration_banner")
                .padding(.top, DS.Spacing.xs)
                .allowsHitTesting(false)
            }
        }
        .task {
            while !Task.isCancelled {
                let firstPullCompleted = SyncQuiescenceCoordinator.shared.hasCompletedFirstPull
                let cloudEngineActive = CloudSyncFlags.storageMode == .cloud
                // Modo privado, hidratación completa o datos en pantalla al montar → terminar el poll.
                guard CloudHydrationLogic.keepsWatching(
                    firstPullCompleted: firstPullCompleted,
                    cloudEngineActive: cloudEngineActive,
                    storeLooksEmpty: storeLooksEmpty) else {
                    visible = false
                    return
                }
                // El veredicto se lee VIVO en cada tick, y no en un `@State` con `.cloudAttestVerdictWatcher`.
                // Ese `@State` se refresca al montar la vista que lo lleva, y el del Panel y el de este overlay
                // montan en momentos distintos: el aviso podía salir con el spinner aún girando. Así el spinner
                // se va como mucho un tick después de que el veredicto se vuelva terminal, y vuelve igual de
                // rápido cuando un token borra la racha. Residual aceptado: si el veredicto cambia por el RELOJ
                // (las 24 h se cumplen con la app delante), nadie escribe la racha y el aviso espera a su
                // siguiente refresco; en ese rato no sale ninguno de los dos.
                visible = CloudHydrationLogic.showBanner(
                    firstPullCompleted: firstPullCompleted,
                    cloudEngineActive: cloudEngineActive,
                    storeLooksEmpty: storeLooksEmpty,
                    attestVerdictIsTerminal: GroupsAttestStreakStore.isTerminal())
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
}
