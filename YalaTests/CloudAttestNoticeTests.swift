//
//  CloudAttestNoticeTests.swift
//  YalaTests
//
//  El aviso FIJO del canal PERSONAL cuando el veredicto de App Attest es terminal (ticket
//  `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`, hermano del de Grupos).
//
//  Tres mitades, y ninguna cubre a las otras: la tabla de la decisión, que es pura; el CABLEADO de sus cuatro
//  entradas y de cuándo se vuelve a mirar, que vive en un `var body` de SwiftUI y solo alcanza un source-scan; y
//  las DOS superficies donde se pinta, que tienen que decir lo mismo — repetir el criterio o el copy en dos
//  vistas es exactamente cómo divergen.
//
//  **Por qué no hay XCUITest positivo.** Ver el aviso exige el device en `storageMode == .cloud`, y no hay seam de
//  uitest que lo ponga: escribir ese modo cambia el montaje del store personal. Es el mismo precedente que ya
//  documenta `SessionExitsPerCellUITests` («la E (nube completa) no tiene seam de `storageMode == .cloud` y la
//  cubre la tabla unitaria»). Lo que sí se mide en XCUI es el NEGATIVO —el teléfono en `.icloud`, que es todo el
//  mundo hoy— en `CloudAttestPanelBannerUITests`.
//

import Testing
import Foundation
@testable import Yala

// MARK: - 1 · La decisión

@Suite("Aviso de attest del canal personal · la decisión")
struct CloudAttestNoticeLogicTests {

    typealias L = CloudAttestNoticeLogic

    @Test("Las CUATRO condiciones a la vez, y solo las cuatro")
    func theNoticeNeedsAllFour() {
        #expect(L.showsNotice(verdictIsTerminal: true, personalDataLivesInCloud: true,
                              channelIsStable: true, hasLiveSession: true))
        // La tabla entera: con cualquiera de las cuatro caída, no hay aviso. Recorrerla completa es lo que mata al
        // mutante que sustituye un `&&` por un `||` o que se deja un operando fuera.
        for terminal in [true, false] {
            for enLaNube in [true, false] {
                for estable in [true, false] {
                    for sesion in [true, false] {
                        let esperado = terminal && enLaNube && estable && sesion
                        #expect(L.showsNotice(verdictIsTerminal: terminal,
                                              personalDataLivesInCloud: enLaNube,
                                              channelIsStable: estable,
                                              hasLiveSession: sesion) == esperado, """
                            terminal=\(terminal) enLaNube=\(enLaNube) estable=\(estable) sesión=\(sesion) \
                            debía dar \(esperado)
                            """)
                    }
                }
            }
        }
    }

    /// **Documentación ejecutable, no cobertura nueva**: las tres celdas de aquí ya las recorre el bucle de arriba.
    /// Se quedan porque nombran el daño —el aviso MINTIENDO— que las tres condiciones «de más» existen para
    /// impedir, y eso un bucle de booleanos no dice.
    @Test("Las tres poblaciones a las que el veredicto es cierto y la frase sería mentira")
    func theVerdictAloneIsNotEnough() {
        // **La población MAYORITARIA hoy.** La racha describe al TELÉFONO y la escriben los dos motores, así que
        // quien tiene sus datos en su iCloud privado puede arrastrar una racha entera de Grupos sin haber mandado
        // un solo movimiento personal a nuestro servidor. Decirle que «tus datos no suben» señala a un canal que
        // no usa.
        #expect(!L.showsNotice(verdictIsTerminal: true, personalDataLivesInCloud: false,
                               channelIsStable: true, hasLiveSession: true))
        // **Y la que cazó la lente adversarial: el canal EN VUELO.** Durante la reversa a iCloud el par sigue en
        // `.cloud`, así que sin este término alguien que está volviendo a iCloud PRECISAMENTE porque sus datos
        // dejaron de subir vería, a la vez, la barra «Volviendo a iCloud» en Ajustes y «usa otro teléfono» en el
        // Panel — el consejo contrario a lo que está haciendo. Mismo caso para el cutover y el relanzamiento
        // pendiente, donde lo único que arregla el estado es reabrir la app.
        #expect(!L.showsNotice(verdictIsTerminal: true, personalDataLivesInCloud: true,
                               channelIsStable: false, hasLiveSession: true))
        // Y sin sesión no hay cuenta a la que llegar: nada está sincronizando.
        #expect(!L.showsNotice(verdictIsTerminal: true, personalDataLivesInCloud: true,
                               channelIsStable: true, hasLiveSession: false))
    }

    @Test("Sin veredicto terminal no hay aviso, por muy en la nube que estén los datos")
    func noVerdictNoNotice() {
        #expect(!L.showsNotice(verdictIsTerminal: false, personalDataLivesInCloud: true,
                               channelIsStable: true, hasLiveSession: true))
    }
}

// MARK: - 2 · El cableado y las dos superficies (source-scan)

/// **Por qué source-scan y no vistas bajo test.** Las entradas se leen dentro de `PanelView` y
/// `StorageSettingsView`, dos `View` con `@Environment` y `ModelContext` vivos; y lo que hay que fijar no es lo que
/// la función pura devuelve —eso ya está arriba— sino de dónde salen sus argumentos, en qué momentos se vuelve a
/// preguntar y que las dos superficies digan lo mismo. Un mutante que cambie `hasLiveSession:` por `true`, que
/// devuelva el término del canal a un flag remoto, o que borre uno de los tres momentos del recálculo, deja la
/// suite de arriba **entera en verde**.
@Suite("Aviso de attest del canal personal · el cableado (source-scan)")
struct CloudAttestNoticeWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador que ACABA en `{`.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static let sharedPath = "Yala/App/Views/Shared/CloudAttestNoticeBanner.swift"
    private static let panelPath = "Yala/App/Views/Panel/PanelView.swift"
    private static let storagePath = "Yala/App/Views/Settings/StorageSettingsView.swift"

    @Test("MUTACIÓN: la decisión lee sus CUATRO fuentes canónicas, y el canal NO es un flag remoto")
    func theDecisionReadsAllFourSources() throws {
        let shared = try Self.source(Self.sharedPath)
        let gate = Self.squashed(try Self.body(
            of: "static func isShowing(verdictIsTerminal: Bool) -> Bool {", in: shared))
        #expect(gate.contains(Self.squashed("""
            CloudAttestNoticeLogic.showsNotice(
                verdictIsTerminal: verdictIsTerminal,
                personalDataLivesInCloud: CloudSyncFlags.storageMode == .cloud,
                channelIsStable: CloudMigrationController.shared?.uiState == .cloudActive,
                hasLiveSession: CloudAuthService.shared.hasSession)
            """)), """
            la decisión dejó de leer alguna de sus cuatro fuentes canónicas. Con `hasLiveSession:` fijo a `true`, el \
            Panel le cuenta una avería de la nube a quien ni siquiera tiene sesión; sin `channelIsStable:`, se la \
            cuenta a quien está volviendo a iCloud justo por eso.
            """)
        // **El canal va por el modo PERSISTIDO de este teléfono y no por un flag remoto**, por lo mismo que el
        // aviso de Grupos lee `groupsBackendCompiledCapability`: el término remoto es fail-closed ante un snapshot
        // ausente o corrupto, así que el primer arranque de un teléfono restaurado se quedaría sin aviso — que es
        // justo el bug que la review del hermano cazó vivo.
        #expect(!gate.contains("CloudRemoteFlags"), """
            el término del canal volvió a un flag REMOTO: con el snapshot de remote-config ausente se apaga solo, y \
            justo en el arranque donde más falta hace.
            """)
        // **El guard del veredicto va ANTES de la llamada, y es lo que impide leer el Keychain en cada re-render.**
        // `hasLiveSession` es un argumento, así que Swift lo evalúa antes de llamar y el `&&` de `showsNotice` no lo
        // cortocircuita. Sin esto, el body del Panel durante el scroll y el tick de 1 s de «Dónde viven tus datos»
        // pagan un `SecItemCopyMatching` cada vez, en el 100 % de teléfonos que nunca tendrán veredicto.
        #expect(gate.contains("guard verdictIsTerminal else { return false }"), """
            se retiró el cortocircuito del veredicto: `CloudAuthService.hasSession` baja al Keychain y pasa a leerse \
            en cada re-evaluación del body, también para quien nunca tendrá el aviso.
            """)
        // Y el `@State` guarda SOLO el veredicto: congelar ahí la sesión o el modo los deja rancios, porque nadie
        // los refresca (ni el sign-in ni el cutover disparan un `onAppear` de estas pantallas).
        let watcher = Self.squashed(try Self.body(of: "private func refresh() {", in: shared))
        #expect(watcher.contains("verdictIsTerminal = GroupsAttestStreakStore.isTerminal()"),
                "el recálculo dejó de leer el veredicto, que es lo único que no se puede leer reactivamente")
        #expect(!watcher.contains("hasSession") && !watcher.contains("storageMode")
                && !watcher.contains("uiState"), """
            la sesión, el modo o la fase se congelaron en el `@State`: ahí dejan de enterarse de un sign-in en \
            caliente o de un cutover, y el aviso se queda puesto (o ausente) sin nadie que lo corrija.
            """)
    }

    @Test("MUTACIÓN: el recálculo corre en los TRES momentos, cada uno anclado a su sitio")
    func theRefreshRunsAtEveryObservableMoment() throws {
        let shared = try Self.source(Self.sharedPath)
        let modifier = Self.squashed(try Self.body(
            of: "func body(content: Content) -> some View {", in: shared))
        // Cada momento se ancla por su SITIO: contar a secas no distingue uno de otro, y mover la llamada de
        // `.active` al `.onDisappear` dejaría el total igual con el salto de reloj ya perdido.
        #expect(modifier.contains(".onAppear { refresh() }"),
                "se perdió el recálculo al montar: la racha pudo escribirse en otro arranque o en otra pantalla")
        #expect(modifier.contains(Self.squashed("""
            .onReceive(NotificationCenter.default.publisher(
                for: GroupsAttestStreakStore.didChangeNotification)) { _ in
                refresh()
            }
            """)), """
            se perdió el aviso del STORE, que es el único momento que no depende de un gesto y el que cierra el \
            hueco de verdad: el 401 llega con la pantalla delante, y sin esto no sale hasta salir y volver.
            """)
        #expect(modifier.contains(Self.squashed("""
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { refresh() }
            }
            """)), """
            se perdió el recálculo al volver de background: el veredicto depende del RELOJ, así que una racha de \
            ayer se vuelve terminal sola y sin notificación que lo anuncie.
            """)
    }

    @Test("MUTACIÓN: el aviso dice el MISMO título que los gestos, y ofrece qué hacer")
    func theBannerSaysTheSameThingEverywhere() throws {
        let shared = try Self.source(Self.sharedPath)
        let banner = Self.squashed(try Self.body(of: "struct CloudAttestNoticeBanner: View {", in: shared))
        #expect(banner.contains("L10n.Settings.signOutAttestTitle"), """
            el aviso dejó de usar el MISMO título que el cierre de sesión: la avería pasaría a llamarse de dos \
            maneras distintas en dos pantallas de la misma app.
            """)
        #expect(banner.contains("L10n.Settings.attestTerminalBanner"),
                "el aviso perdió el cuerpo que dice qué pasa con lo apuntado y qué hacer")
        // **Sin `.accessibilityElement(children: .combine)`, y a propósito.** Lo llevaba, y una lente lo cazó: con
        // `.combine` no quedan textos hijos, así que una aserción por `app.staticTexts[...]` que funciona sobre el
        // hermano de Grupos no funcionaría aquí — justo la divergencia que este componente existe para evitar.
        #expect(!banner.contains("children: .combine"), """
            el aviso volvió a combinar sus hijos: deja de tener textos consultables y diverge del molde de Grupos,             que no combina.
            """)
        // Sin X y sin botón, a propósito: describe un estado que sigue ahí después de leerlo, y reintentar es lo
        // que lleva un día fallando.
        #expect(!banner.contains("Button"), """
            al aviso le salió un botón: no hay ninguna acción que arregle esto desde este teléfono, y una X solo \
            serviría para ocultar un estado que sigue ahí.
            """)
    }

    @Test("MUTACIÓN: las DOS superficies lo pintan, gateadas por la misma decisión")
    func bothSurfacesMountIt() throws {
        // (a) El Panel — donde está quien apunta gastos que no llegan.
        let panel = Self.squashed(try Self.source(Self.panelPath))
        #expect(panel.contains(Self.squashed("""
            if CloudAttestNotice.isShowing(verdictIsTerminal: attestVerdictIsTerminal) {
                CloudAttestNoticeBanner(accessibilityID: "panel_attest_terminal_banner")
            """)), """
            el Panel dejó de pintar el aviso, o dejó de gatearlo por la decisión compartida: se pintaría siempre \
            —también en el teléfono que sí sincroniza— o no se pintaría nunca.
            """)
        #expect(panel.contains(".cloudAttestVerdictWatcher($attestVerdictIsTerminal)"), """
            el Panel perdió el cableado del veredicto: el `@State` se queda en `false` para siempre y el aviso no \
            sale aunque el motor esté parado.
            """)

        // (b) «Dónde viven tus datos» — donde hasta este ticket se pintaba un check verde «Todo al día» con el
        // motor ya parado. Su rama va PRIMERA: re-firmar no arregla un attest roto.
        let storage = try Self.source(Self.storagePath)
        let section = Self.squashed(try Self.body(
            of: "private func syncStatusSection(_ controller: CloudMigrationController) -> some View {",
            in: storage))
        #expect(section.contains(Self.squashed("""
            if CloudAttestNotice.isShowing(verdictIsTerminal: attestVerdictIsTerminal) {
                CloudAttestNoticeBanner(accessibilityID: "storage_sync_attest_banner")
            } else if controller.syncNeedsSignIn {
            """)), """
            la sección de estado volvió a su `if` de dos ramas. `refreshSyncBanner` solo mira \
            `.stoppedUntilSignIn`, y el attest terminal deja el runtime en `.stoppedUntilRelaunch`: sin esta rama \
            cae al `else` y pinta un check verde «Todo al día» con los movimientos sin subir.
            """)
        #expect(Self.squashed(storage).contains(".cloudAttestVerdictWatcher($attestVerdictIsTerminal)"), """
            «Dónde viven tus datos» perdió el cableado del veredicto: su `@State` se queda en `false` y la sección \
            vuelve a decir que todo está al día.
            """)
    }
}
