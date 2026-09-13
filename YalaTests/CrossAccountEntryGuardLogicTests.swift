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
@Suite("CloudHydrationLogic · visibilidad del banner")
struct CloudHydrationLogicTests {

    /// El primer pull cerrado apaga el banner, mire lo que mire el resto.
    @Test("con el primer pull cerrado no hay nada que explicar")
    func firstPullCompleted_silencesTheBanner() {
        #expect(!CloudHydrationLogic.showBanner(
            firstPullCompleted: true, cloudEngineActive: true, storeLooksEmpty: true))
    }

    /// LA aserción del ticket de re-entrada: el dueño que acaba de adoptar y relanzar.
    @Test("el dueño que vuelve, con el store aún vacío y el motor sin cerrar su primer pull")
    func returningOwnerIsCovered() {
        #expect(CloudHydrationLogic.showBanner(
            firstPullCompleted: false,
            cloudEngineActive: true, storeLooksEmpty: true), """
            Quien vuelve en un móvil nuevo sigue viendo la app vacía SIN explicación: es el mismo \
            hecho que el banner ya cubría para la invitada, por la otra puerta.
            """)
    }

    /// Los dos falsos positivos que el gate tiene que seguir evitando: el usuario con sus datos ya
    /// bajados (que no está esperando nada) y el que ni siquiera tiene motor de nube.
    @Test("no sale para quien ya tiene datos ni para quien no tiene motor")
    func noFalsePositives() {
        #expect(!CloudHydrationLogic.showBanner(
            firstPullCompleted: false,
            cloudEngineActive: true, storeLooksEmpty: false),
            "con datos en pantalla, «descargando tus datos» es ruido")
        #expect(!CloudHydrationLogic.showBanner(
            firstPullCompleted: false,
            cloudEngineActive: false, storeLooksEmpty: true),
            "sin motor de nube no hay ninguna descarga en curso que explicar")
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
