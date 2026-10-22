//
//  CrossAccountEntryGuardLogicTests.swift
//  YalaTests
//
//  Matriz COMPLETA del guard. Tres términos: datos locales, claim de la misma cuenta y
//  restauración en curso.
//

import Foundation
import Testing

@testable import Yala

@Suite("Guard cross-cuenta del sign-in en Welcome (F0-C)")
struct CrossAccountEntryGuardLogicTests {

    /// Atajo de la matriz histórica: los combos se afirman con la restauración APAGADA, que es el
    /// estado de todo el mundo salvo la ventana de segundos del restore.
    private static func decide(
        hasLocalData: Bool, sameAccountClaimExists: Bool
    ) -> CrossAccountEntryGuardLogic.Decision {
        CrossAccountEntryGuardLogic.decide(
            hasLocalData: hasLocalData, sameAccountClaimExists: sameAccountClaimExists,
            restoreInProgress: false)
    }

    // MARK: - El dueño que está bajando SUS datos

    /// EL caso del ticket. El dueño cambia de móvil o reinstala, entra por «Restaurar desde iCloud» y
    /// —con la descarga a medias— toca «atrás» y entra por la card de su cuenta:
    ///
    ///  · `hasLocalData` es `true` por las filas que él mismo está bajando (`RestoreProgressView` las
    ///    cuenta en vivo, así que no es una hipótesis: es lo que la pantalla muestra),
    ///  · y no hay claim que las reclame, porque `CloudClaimActionStore` vive en `UserDefaults` y
    ///    murió con la reinstalación — que es justo la mitad del escenario.
    ///
    /// Sin el término de la restauración, el guard clasifica como AJENAS unas filas que el propio
    /// dueño acaba de pedir.
    @Test("restaurando de iCloud, sus propias filas no cuentan como corpus de otro humano")
    func ownerRestoringOwnData_isNotForeign() {
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: false,
            restoreInProgress: true
        ) == .proceed, """
            El dueño que restaura de iCloud y vuelve atrás con el import a medias tiene BLOQUEADA la \
            entrada a su propia cuenta, y el texto le dice que estos datos son de otro.
            """)
    }

    /// El contrapeso, y es el que sostiene el fix entero: **la MISMA entrada, con la señal apagada,
    /// sigue bloqueando**. Es lo que separa «el dueño está bajando sus datos» de «este device tiene
    /// datos de otro humano», dos mundos que el detector de filas no puede distinguir por su cuenta.
    ///
    /// Su mutante es el que importa: cablear `restoreInProgress` a `true` fijo —o encender la señal en
    /// un sitio que no sea el restore— desarma el guard cross-cuenta ENTERO y deja pasar a cualquiera
    /// que firme sobre el corpus de otra persona.
    @Test("con la señal APAGADA la misma celda sigue bloqueando: el fix no es un pase libre")
    func withoutTheSignal_theSameCellStillBlocks() {
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: false,
            restoreInProgress: false
        ) == .blockedForeignData, """
            La señal dejó de ser el término que decide: sin restauración en curso, unas filas locales \
            sin claim son corpus de otro humano y el guard tiene que cerrar.
            """)
    }

    @Test
    func cleanDevice_proceeds_always() {
        // Sin datos locales → adopt clásico, haya o no claim.
        for claim in [true, false] {
            #expect(Self.decide(
                hasLocalData: false, sameAccountClaimExists: claim
            ) == .proceed)
        }
    }

    @Test
    func localData_sameAccount_proceeds() {
        // Re-entrada de la MISMA cuenta: el claim-store sobrevive el sign-out a propósito.
        #expect(Self.decide(
            hasLocalData: true, sameAccountClaimExists: true
        ) == .proceed)
    }

    @Test
    func localData_foreignAccount_blocks() {
        // El caso Pia: datos locales sin claim de esta cuenta ⇒ bloqueado.
        #expect(Self.decide(
            hasLocalData: true, sameAccountClaimExists: false
        ) == .blockedForeignData)
    }
}

/// El banner de «Descargando tus datos…» cubría SOLO a la invitada, y su propio docblock nombraba el
/// daño que evita: «el store nace VACÍO […] vería una app en cero sin explicación». **Tras el
/// relanzamiento del adopt, el store personal del DUEÑO nace igual de vacío** y se puebla con el pull
/// desde el cursor 0 — mismo hecho, misma pantalla en blanco, y el primer término del gate lo excluía.
///
/// El gate nuevo lee el MUNDO y no el camino: se ve vacío + el motor está hidratando. Eso hace que el
/// banner llegue a quien vuelve sin tener que enumerar por qué ruta llegó.
///
/// **Y desde el 2026-09-17 se rinde con el veredicto de App Attest terminal** (ticket
/// `cloud-hydration-spinner-never-gives-up-without-attest`): sin attest no baja nada, y giraba para siempre al
/// lado del aviso que dice que este teléfono no puede sincronizar.
@Suite("CloudHydrationLogic · visibilidad del banner")
struct CloudHydrationLogicTests {

    typealias L = CloudHydrationLogic

    /// El primer pull cerrado apaga el banner, mire lo que mire el resto.
    @Test("con el primer pull cerrado no hay nada que explicar")
    func firstPullCompleted_silencesTheBanner() {
        #expect(!L.showBanner(
            firstPullCompleted: true, cloudEngineActive: true, storeLooksEmpty: true,
            attestVerdictIsTerminal: false))
    }

    /// LA aserción del ticket de re-entrada: el dueño que acaba de adoptar y relanzar.
    @Test("el dueño que vuelve, con el store aún vacío y el motor sin cerrar su primer pull")
    func returningOwnerIsCovered() {
        #expect(L.showBanner(
            firstPullCompleted: false,
            cloudEngineActive: true, storeLooksEmpty: true,
            attestVerdictIsTerminal: false), """
            Quien vuelve en un móvil nuevo sigue viendo la app vacía SIN explicación: es el mismo \
            hecho que el banner ya cubría para la invitada, por la otra puerta.
            """)
    }

    /// Los dos falsos positivos que el gate tiene que seguir evitando: el usuario con sus datos ya
    /// bajados (que no está esperando nada) y el que ni siquiera tiene motor de nube.
    @Test("no sale para quien ya tiene datos ni para quien no tiene motor")
    func noFalsePositives() {
        #expect(!L.showBanner(
            firstPullCompleted: false,
            cloudEngineActive: true, storeLooksEmpty: false,
            attestVerdictIsTerminal: false),
            "con datos en pantalla, «descargando tus datos» es ruido")
        #expect(!L.showBanner(
            firstPullCompleted: false,
            cloudEngineActive: false, storeLooksEmpty: true,
            attestVerdictIsTerminal: false),
            "sin motor de nube no hay ninguna descarga en curso que explicar")
    }

    /// LA aserción de `cloud-hydration-spinner-never-gives-up-without-attest`: el mismo teléfono que el caso del
    /// dueño que vuelve —nube, store vacío, primer pull sin cerrar—, pero sin App Attest desde hace un día.
    @Test("con el veredicto de attest terminal, «Descargando tus datos…» se rinde")
    func terminalAttestVerdict_silencesTheSpinner() {
        #expect(!L.showBanner(
            firstPullCompleted: false,
            cloudEngineActive: true, storeLooksEmpty: true,
            attestVerdictIsTerminal: true), """
            el spinner sigue girando con el veredicto de attest terminal. Ahí no baja nada —una descarga exige \
            token y un token borra la racha—, y gira al lado del aviso que dice que este teléfono no puede \
            sincronizar.
            """)
    }

    /// **El veredicto esconde el banner, pero no acaba la vigilancia.** La racha se borra en cuanto la puerta del
    /// motor consigue un token —una racha heredada de una copia de iCloud, o un attest que vuelve— y la descarga
    /// empieza justo después. Aquí se fija que `keepsWatching` le responde «sí» a este teléfono. Que el sondeo
    /// termine SOLO por ella, y no por el veredicto, vive en la vista: lo fija `CloudHydrationBannerWiringTests`.
    @Test("el mismo teléfono SIGUE vigilado: si un token borra la racha, el banner vuelve")
    func terminalAttestVerdict_doesNotEndTheWatch() {
        #expect(L.keepsWatching(
            firstPullCompleted: false,
            cloudEngineActive: true, storeLooksEmpty: true), """
            la hidratación dejó de vigilarse: una racha que el primer ciclo borra al conseguir token dejaría la \
            descarga real sin banner.
            """)
    }

    /// La tabla entera, las dos funciones. Recorrerla completa es lo que mata al mutante que sustituye un `&&` por
    /// un `||`, invierte el término del veredicto o se deja un operando fuera.
    @Test("La tabla: el banner son los cuatro términos; la vigilancia, los tres que no son el veredicto")
    func fullTable() {
        for primerPull in [true, false] {
            for nube in [true, false] {
                for vacio in [true, false] {
                    let vigila = !primerPull && nube && vacio
                    #expect(L.keepsWatching(firstPullCompleted: primerPull,
                                            cloudEngineActive: nube,
                                            storeLooksEmpty: vacio) == vigila, """
                        keepsWatching primerPull=\(primerPull) nube=\(nube) vacío=\(vacio) debía dar \(vigila)
                        """)
                    for terminal in [true, false] {
                        let esperado = vigila && !terminal
                        #expect(L.showBanner(firstPullCompleted: primerPull,
                                             cloudEngineActive: nube,
                                             storeLooksEmpty: vacio,
                                             attestVerdictIsTerminal: terminal) == esperado, """
                            showBanner primerPull=\(primerPull) nube=\(nube) vacío=\(vacio) \
                            terminal=\(terminal) debía dar \(esperado)
                            """)
                    }
                }
            }
        }
    }

    /// **Documentación ejecutable del criterio del encargo, no cobertura nueva**: los mutantes de `showBanner` los
    /// mata antes `fullTable`, y los de `showsNotice` su propia tabla. Dice, en el idioma del ticket, que las dos
    /// DECISIONES puras no dicen «sí» a la vez con el mismo veredicto. Los dos leen `GroupsAttestStreakStore.isTerminal()`
    /// (aquí lo fija `CloudHydrationBannerWiringTests`; en el aviso, `CloudAttestNoticeWiringTests`).
    ///
    /// **Lo que no ve, porque vive en el cableado y no en la decisión:** el banner lee el veredicto en cada tick y
    /// el aviso en tres momentos. Con una escritura de la racha coinciden como mucho un tick; si el veredicto cambia
    /// por el reloj con la app delante, el aviso espera a su siguiente refresco y en ese rato no sale ninguno.
    /// Residual aceptado, escrito en `.claude/rules/gateway-attest.md`.
    @Test("las dos decisiones, con el mismo veredicto, nunca dicen «sí» a la vez")
    func neverTogetherWithTheAttestNotice() {
        for terminal in [true, false] {
            for enLaNube in [true, false] {
                for estable in [true, false] {
                    for sesion in [true, false] {
                        for primerPull in [true, false] {
                            for vacio in [true, false] {
                                let aviso = CloudAttestNoticeLogic.showsNotice(
                                    verdictIsTerminal: terminal,
                                    personalDataLivesInCloud: enLaNube,
                                    channelIsStable: estable,
                                    hasLiveSession: sesion)
                                let spinner = L.showBanner(
                                    firstPullCompleted: primerPull,
                                    cloudEngineActive: enLaNube,
                                    storeLooksEmpty: vacio,
                                    attestVerdictIsTerminal: terminal)
                                #expect(!(aviso && spinner), """
                                    el spinner y el aviso de attest salen a la vez: terminal=\(terminal) \
                                    enLaNube=\(enLaNube) estable=\(estable) sesión=\(sesion) \
                                    primerPull=\(primerPull) vacío=\(vacio)
                                    """)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// **Por qué source-scan.** La decisión pura ya está arriba; lo que ninguna tabla ve es de dónde sale el veredicto y
/// cuándo termina el sondeo, y eso vive en el `.task` de una `View`. Ver el banner exige `storageMode == .cloud`, y no
/// hay seam de uitest que lo ponga (precedente en `CloudAttestNoticeTests`). Tres mutantes dejan la suite de arriba
/// **entera en verde**: pasar `attestVerdictIsTerminal: false` fijo, volver a terminar el sondeo con el primer
/// `false` (`guard visible`), y leer el veredicto una vez fuera del bucle. Por eso se fija el cuerpo ENTERO y no dos
/// literales.
@Suite("CloudHydrationBanner · el sondeo (source-scan)")
struct CloudHydrationBannerWiringTests {

    private static let bannerPath = "Yala/App/Views/Shared/CloudHydrationBanner.swift"

    /// El fichero, sin las líneas de comentario: documentar el sondeo no puede ponerlo rojo.
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

    /// El cuerpo del `.task`, entero. Lo comparten los dos casos: uno fija lo que hace y el otro, dónde cuelga.
    private static let pinnedPoll = """
        while !Task.isCancelled {
            let firstPullCompleted = SyncQuiescenceCoordinator.shared.hasCompletedFirstPull
            let cloudEngineActive = CloudSyncFlags.storageMode == .cloud
            guard CloudHydrationLogic.keepsWatching(
                firstPullCompleted: firstPullCompleted,
                cloudEngineActive: cloudEngineActive,
                storeLooksEmpty: storeLooksEmpty) else {
                visible = false
                return
            }
            visible = CloudHydrationLogic.showBanner(
                firstPullCompleted: firstPullCompleted,
                cloudEngineActive: cloudEngineActive,
                storeLooksEmpty: storeLooksEmpty,
                attestVerdictIsTerminal: GroupsAttestStreakStore.isTerminal())
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
        """

    private static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    @Test("MUTACIÓN: el sondeo lee el veredicto VIVO en cada tick y solo termina por lo que no es el veredicto")
    func thePollReadsTheVerdictLiveAndOnlyEndsForOtherReasons() throws {
        let banner = try Self.source(Self.bannerPath)
        let task = Self.squashed(try Self.body(of: ".task {", in: banner))
        #expect(task == Self.squashed(Self.pinnedPoll), """
            el sondeo del banner cambió. Tres cosas que no se pueden perder: (1) el veredicto se lee VIVO en cada \
            tick —fijo a `false`, el spinner vuelve a girar al lado del aviso; leído una vez, no se entera de que \
            el reloj cruzó las 24 h—; (2) el sondeo solo termina por `keepsWatching`, que no mira el veredicto —si \
            terminara con el primer `false`, una racha que el primer ciclo borra dejaría la descarga real sin \
            banner—; (3) al terminar se esconde. Si el cambio es a propósito, actualiza este cuerpo y el porqué.
            """)
    }

    /// El caso de arriba fija QUÉ hace el primer `.task` del fichero, no DÓNDE cuelga ni quién más escribe
    /// `visible` (lo cazó la review del 2026-09-17). Movido dentro de `if visible {`, no arranca nunca y el banner no
    /// sale jamás. Y un segundo `.task` u `.onAppear` que escriba `visible` le quitaría la palabra. Las dos cosas
    /// dejaban la suite en verde.
    @Test("MUTACIÓN: el sondeo cuelga de la raíz del body, es el único y es el único que escribe `visible`")
    func thePollHangsFromTheRootAndIsTheOnlyWriter() throws {
        let banner = try Self.source(Self.bannerPath)
        let body = Self.squashed(try Self.body(of: "var body: some View {", in: banner))
        #expect(body.hasSuffix(Self.squashed(".task {\n\(Self.pinnedPoll)\n}")), """
            el `.task` del sondeo dejó de ser el último modificador de la raíz del body. Dentro de `if visible {` no \
            arranca nunca, porque `visible` nace en `false`, y el banner no sale jamás.
            """)
        #expect(Self.occurrences(of: ".task", in: banner) == 1, "hay más de un `.task` en el banner")
        for hook in [".onAppear", ".onChange", ".onReceive"] {
            #expect(Self.occurrences(of: hook, in: banner) == 0, """
                el banner ganó un `\(hook)`: si escribe `visible` o el veredicto, compite con el sondeo, que es quien \
                decide.
                """)
        }
        // Tres: la declaración del `@State` y las dos asignaciones del sondeo.
        #expect(Self.occurrences(of: "visible =", in: banner) == 3, """
            `visible` tiene un escritor fuera del sondeo: el banner puede salir o esconderse sin pasar por \
            `showBanner` ni por `keepsWatching`.
            """)
    }
}

/// La pantalla de datos ajenos era un CALLEJÓN: pintaba «su dueño puede volver a entrar cuando quiera»
/// —una salida que no es del que está mirando— y ni una acción. El `welcomeBackButton` de la toolbar
/// existe, pero es una flecha de 44 pt en una pantalla que acaba de decirle a alguien que no puede
/// entrar a su cuenta: no es una salida, es la ausencia de una.
///
/// Esto NO toca el veredicto del guard (eso es la otra pieza): la pantalla sigue apareciendo cuando
/// tiene que aparecer, y lo único que cambia es que ahora dice qué hacer y ofrece por dónde.
@Suite("Welcome · la pantalla de datos ajenos ofrece salida (source-scan)")
struct WelcomeCloudBlockedExitTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    /// Código SIN líneas de comentario: el docblock de esta rama nombra a propósito lo que arregla, y
    /// contar la prosa haría que documentar el invariante lo «cumpliera».
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let signInView = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"

    /// La rama de un `switch` no abre llaves, así que el corte va de su `case` al siguiente
    /// (molde `GroupsOrganizerWiringTests.rama`).
    private static func branch(_ caso: String, in source: String) -> String? {
        guard let start = source.range(of: "case .\(caso):") else { return nil }
        let resto = source[start.upperBound...]
        guard let next = resto.range(of: "\n        case .") else { return String(resto) }
        return String(resto[..<next.lowerBound])
    }

    @Test("la rama pinta el caso del dueño que está restaurando, y no solo el del dueño ausente")
    func blockedBranchNamesTheRestoreCase() throws {
        let view = try Self.code(Self.signInView)
        let rama = try #require(
            Self.branch("blockedForeignData", in: view),
            "`WelcomeCloudSignInView` dejó de tener la rama `.blockedForeignData`.")

        #expect(rama.contains("L10n.Welcome.Cloud.blockedRestoreHint"), """
            La pantalla vuelve a describir UN solo mundo: el del dispositivo con datos de otro humano. \
            El dueño que restauró de iCloud y tocó «atrás» con el import a medias aterriza aquí \
            —`hasLocalDataNow` ya cuenta las filas que él mismo está bajando— y lee que sus datos son \
            de otra cuenta, sin nada que le diga qué hacer.
            """)
    }

    @Test("MUTACIÓN: hay una salida EXPLÍCITA, no solo la flecha de la toolbar")
    func blockedBranchOffersAnExplicitWayBack() throws {
        let view = try Self.code(Self.signInView)
        let rama = try #require(Self.branch("blockedForeignData", in: view))

        #expect(rama.contains("onBack()"), """
            La rama volvió a quedarse sin acción. `canGoBack` incluye `.blockedForeignData`, así que la \
            flecha de la toolbar sigue ahí — pero una pantalla que bloquea la entrada a una cuenta tiene \
            que ofrecer su vuelta como botón, no esconderla en una esquina.
            """)
        #expect(rama.contains("welcome_cloud_blocked_back"), """
            El botón de vuelta perdió su `accessibilityIdentifier`: el device-QA se ancla a él (esta \
            fase exige un sign-in REAL y no hay XCUITest que la alcance).
            """)
    }
}
