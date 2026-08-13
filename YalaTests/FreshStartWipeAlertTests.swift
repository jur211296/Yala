//
//  FreshStartWipeAlertTests.swift
//  YalaTests
//
//  «Es mi primera vez en Yala» — los DOS defectos del mismo alert.
//
//  **Defecto 1 · se limpiaba antes de preguntar.** `startFreshPrivateOnboarding` llamaba a
//  `OnboardingResetHelper.clearResidualPreferencesForFreshStart()` en su PRIMERA línea, ANTES del
//  `if hasExistingData` que decide si se pregunta ⇒ tocar «Cancelar» en el alert no deshacía nada y
//  el usuario perdía `userName` y `defaultCurrencyCode`. Y el efecto es DIFERIDO —
//  `AppPreferences.loadFromDefaults()` solo corre en el `init` y descarta los vacíos — así que el
//  nombre en memoria sobrevive hasta el siguiente arranque en frío: lo que la persona percibe es que
//  su nombre desaparece SOLO, un arranque después de haber cancelado.
//
//  **Defecto 2 · el borrado fallaba en silencio.** El `catch` de los dos wipes imprimía bajo
//  `#if DEBUG` y seguía igual a `showOnboarding = true`: la app metía al usuario en un onboarding «de
//  cero» sobre datos que NO se borraron, sin un mensaje y sin canario.
//
//  **Por qué el pin del defecto 1 es un source-scan y no un test de comportamiento:** los dos lados de
//  la decisión viven en vistas SwiftUI —el `if` en `ContentView.startFreshPrivateOnboarding`, el
//  `onConfirm` en `ShellDataAlertsModifier`— y ninguno es invocable desde aquí. Lo que decide es DÓNDE
//  está la llamada respecto del `if`, que es exactamente la clase de invariante que este repo pinnea
//  con un escáner (molde `SecondaryOwnerDomainWiringTests` / `AttestWiringTests`). Un test de la tabla
//  de decisión sería verde con el bug puesto, porque la tabla nunca estuvo mal: mal estaba el orden.
//
//  MUTACIONES verificadas a exit 65: (1) devolver la limpieza a la primera línea de
//  `startFreshPrivateOnboarding`; (2) quitarla del `onConfirm` del alert; (3) devolver el `catch` a
//  seguir hacia el onboarding; (4) quitar el canario.
//

import Foundation
import Testing

@testable import Yala

@Suite("Welcome · «empiezo de cero»: se limpia cuando se BORRA, no cuando se pregunta")
struct FreshStartWipeAlertTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código SIN líneas de comentario: el porqué de cada pieza se explica ahí nombrándola, y contar
    /// prosa haría que documentar el invariante lo satisficiera solo.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador (molde `SecondaryOwnerDomainWiringTests`).
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker))
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    private static let contentViewPath = "Yala/App/ContentView.swift"
    private static let alertsPath = "Yala/App/Views/Shared/ShellDataAlertsModifier.swift"
    private static let clearCall = "OnboardingResetHelper.clearResidualPreferencesForFreshStart()"

    // MARK: - Defecto 1 · el orden

    /// LA aserción del defecto 1. Con el bug puesto, la limpieza es la primera línea de la función y
    /// cae ANTES del `if`, así que «Cancelar» deja `userName`/`defaultCurrencyCode` ya borrados.
    @Test("la limpieza de residuales NO corre antes de decidir si se pregunta")
    func startFresh_doesNotClearBeforeAsking() throws {
        let fresh = try Self.body(
            of: "private func startFreshPrivateOnboarding() {",
            in: Self.code(Self.contentViewPath))

        let gate = try #require(
            fresh.range(of: "if hasExistingData"),
            """
            `startFreshPrivateOnboarding` dejó de consultar `hasExistingData`: sin esa pregunta no \
            hay alert que cancelar y el borrado de residuales es incondicional.
            """)

        if let clear = fresh.range(of: Self.clearCall) {
            #expect(clear.lowerBound > gate.lowerBound, """
                La limpieza de residuales volvió a correr ANTES del `if hasExistingData`. Cancelar el \
                alert ya no la deshace: el usuario pierde `userName` y `defaultCurrencyCode`, y el \
                efecto no se ve hasta el siguiente arranque en frío (`loadFromDefaults` solo corre en \
                el `init` y descarta los vacíos). Se limpia cuando se BORRA, no cuando se pregunta.
                """)
        }
    }

    /// La otra mitad: el camino que SÍ borra tiene que limpiar. Sin esto, mover la llamada «para
    /// arreglar el orden» y no reponerla en el confirm dejaría el onboarding con el nombre viejo
    /// pre-rellenado, que es el bug original que `OnboardingResetHelper` existe para evitar.
    @Test("el confirm destructivo del alert SÍ limpia los residuales")
    func confirmBranch_clearsResiduals() throws {
        let alerts = try Self.code(Self.alertsPath)
        let freshStartAlert = try Self.body(
            of: "isPresented: $showFreshStartWipeAlert) {", in: alerts)

        #expect(freshStartAlert.contains(Self.clearCall), """
            El botón destructivo de «empiezo de cero» ya no limpia las prefs residuales. El usuario \
            nuevo hereda el `userName` y la divisa del anterior en el onboarding — que es el motivo \
            por el que `OnboardingResetHelper` existe.
            """)
    }

    /// La rama sin datos no pregunta, así que es la OTRA que borra de verdad (no hay nada que
    /// confirmar) y también tiene que limpiar.
    @Test("la rama sin datos existentes limpia antes de abrir el onboarding")
    func noDataBranch_clearsResiduals() throws {
        let fresh = try Self.body(
            of: "private func startFreshPrivateOnboarding() {",
            in: Self.code(Self.contentViewPath))
        let elseRange = try #require(fresh.range(of: "} else {"))
        let tail = String(fresh[elseRange.upperBound...])

        #expect(tail.contains(Self.clearCall), """
            La rama `else` (sin datos que confirmar) abre el onboarding sin limpiar los residuales: \
            el nombre y la divisa de la instalación anterior sobreviven al «empiezo de cero».
            """)
    }

    // MARK: - Defecto 2 · el fallo del wipe tiene superficie

    /// Con el bug puesto, el `catch` solo imprime bajo `#if DEBUG` y el flujo continúa a
    /// `showOnboarding = true`: la app miente sobre un borrado que no ocurrió.
    @Test("si el wipe lanza, NO se navega al onboarding")
    func wipeFailure_doesNotProceedToOnboarding() throws {
        let alerts = try Self.code(Self.alertsPath)
        let freshStartAlert = try Self.body(
            of: "isPresented: $showFreshStartWipeAlert) {", in: alerts)
        let catchBody = try Self.body(of: "} catch {", in: freshStartAlert)

        #expect(catchBody.contains("showFreshStartWipeFailedAlert = true"), """
            El fallo del wipe volvió a ser mudo. Hace falta superficie: hoy la app mete al usuario en \
            un onboarding «de cero» sobre los datos que NO se borraron.
            """)

        // El `catch` tiene que CORTAR el flujo: la navegación va DENTRO del `do`, o sea ANTES del
        // `} catch {`. Con el bug vivía después y corría igual con el wipe fallido.
        let catchStart = try #require(freshStartAlert.range(of: "} catch {"))
        let nav = try #require(
            freshStartAlert.range(of: "showOnboarding = true"),
            "El camino que SÍ borra dejó de abrir el onboarding.")
        #expect(nav.lowerBound < catchStart.lowerBound, """
            `showOnboarding = true` volvió a estar fuera del `do`: corre también cuando el wipe \
            lanzó. La navegación al onboarding tiene que colgar del camino que SÍ borró.
            """)
    }

    /// Canario FUERA de `#if DEBUG`, misma familia que `attestKeyDiscardedAfterAssertFailure`: sin él
    /// este fallo es invisible en producción, que es exactamente como lleva vivo lo que lleve.
    @Test("el fallo del wipe emite canario en los DOS alerts que borran")
    func wipeFailure_emitsCanaryInBothWipingAlerts() throws {
        let alerts = try Self.code(Self.alertsPath)

        let emisiones = alerts.components(separatedBy: ".freshStartWipeFailed").count - 1
        #expect(emisiones == 2, """
            Se esperaban 2 emisiones de `.freshStartWipeFailed` (el alert de «empiezo de cero» y el \
            «Empezar de cero» de la oferta de restaurar: los DOS wipes del fichero), y hay \
            \(emisiones). El conteo es lo que hace que esto envejezca bien — un tercer camino que \
            borre rompe el test y obliga a decidir, en vez de aparecer mudo.
            """)

        #expect(!alerts.contains("#if DEBUG"), """
            El fichero volvió a tener un camino solo-Debug. La observación de un wipe fallido tiene \
            que existir en producción o no existe.
            """)
    }

    /// El canario tiene que estar declarado en el inventario de eventos, o `MetricsService.canary`
    /// no compila — pero declarado sin emisor es la otra mitad del mismo fallo.
    @Test("`freshStartWipeFailed` está en el inventario de canarios")
    func canaryIsDeclared() throws {
        let metrics = try Self.code("Yala/Services/Metrics/MetricsService.swift")
        #expect(metrics.contains("case freshStartWipeFailed"))
    }

    // MARK: - La matriz de readiness

    /// Toda presentación nueva del anchor de `ContentView` entra en la matriz (regla 3 de
    /// Presentaciones): si no, un intent del router puede drenar por debajo del alert de fallo.
    @Test("el alert de wipe fallido es blocker de la matriz de readiness")
    func failureAlertBlocksTheMatrix() throws {
        let logic = try Self.code("Yala/App/Logic/ContentViewReadinessLogic.swift")
        #expect(logic.contains("showFreshStartWipeFailedAlert"), """
            El alert de «no pudimos borrar tus datos» no está en `ContentViewReadinessLogic`: un \
            intent del router presentaría por debajo de él sobre el mismo anchor.
            """)
    }
}
