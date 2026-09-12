//
//  WelcomeSecondaryNoticeTests.swift
//  YalaTests
//
//  **La rama privada del Welcome en sesión secundaria: informa, y no promete lo que no hace.**
//
//  Dos hechos con una causa común y un solo commit:
//
//  1. «Es mi primera vez → privacidad total» llevaba a la visita al onboarding **sin decirle** que
//     estaba en el móvil de otra persona, mientras la rama de al lado —«Vengo por un grupo»— sí se lo
//     decía. La app se contradecía según por dónde entraras.
//  2. El onboarding privado en visita **ofrecía las categorías de ejemplo y no creaba ninguna**:
//     `seedCategoriesIfNeeded` retorna en su primera línea con el cinturón M1, así que la visita
//     respondía que sí y su store quedaba vacío.
//
//  **Casi todo lo de aquí es source-scan, y eso es una elección medida, no pereza.** Lo que hay que
//  proteger vive en dos `View` de SwiftUI —una rama de `handleNewOption` y tres términos de
//  `completeOnboarding`— que ningún test unitario puede llamar: son métodos privados de structs que
//  necesitan un `Environment` entero montado. El pure-logic que sí se puede ejecutar está en
//  `OnboardingStepPlanTests` (el skip del paso) y en la última suite de este fichero (la subcategoría de
//  saldo, que es lo que hace que el arreglo del seed no rompa el saldo inicial). Molde y helpers:
//  `GroupsOrganizerWiringTests`, el escáner de la rama hermana.
//
//  Los escáneres leen el código **sin las líneas de comentario**: los docblocks de estos ficheros nombran
//  a propósito lo que prohíben, y contar la prosa haría que documentar el invariante lo «cumpliera».
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("La rama privada avisa en sesión secundaria (source-scan)")
struct WelcomeSecondaryNoticeWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador. Acotar al CUERPO importa: sobre el fichero entero
    /// el container nombra el descriptor y el portal en varios sitios, y el escáner comprobaría que los
    /// símbolos EXISTEN, no que esta función los use.
    private static func bodyOf(_ marker: String, in source: String) -> String? {
        guard let start = source.range(of: marker) else { return nil }
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    private static let container = "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"
    private static let noticeView = "Yala/App/Views/Onboarding/WelcomeSecondaryNoticeView.swift"
    private static let onboarding = "Yala/App/Views/Onboarding/OnboardingView.swift"

    // MARK: - El aviso del Welcome

    @Test("la rama privada consulta el DESCRIPTOR, no el corpus")
    func privateBranchAsksForTheDescriptor() throws {
        let src = try Self.code(Self.container)
        let body = try #require(
            Self.bodyOf("private func handleNewOption(_ option: WelcomeAccountChoiceLogic.NewOption) {", in: src),
            "`handleNewOption` desapareció o cambió de firma")

        #expect(body.contains("SecondarySessionStore.isActive()"), """
            la rama privada dejó de mirar el descriptor. `hasLocalDataNow` mide el store de la INVITADA, \
            que en una sesión recién montada está VACÍO ⇒ el aviso no saldría justo en el caso que existe \
            para atender. Es el mismo predicado que usa la puerta de la rama organizador.
            """)
        #expect(body.contains("goTo(.privateSecondaryNotice)"), """
            la rama detecta la visita y no la lleva a ninguna parte. Un `if` que solo mide es peor que no \
            medir: parece cubierto y no lo está.
            """)
    }

    @Test("MUTACIÓN: el aviso va ANTES de salir del cover, no después")
    func theNoticeComesBeforeThePortal() throws {
        let src = try Self.code(Self.container)
        let body = try #require(
            Self.bodyOf("private func handleNewOption(_ option: WelcomeAccountChoiceLogic.NewOption) {", in: src))

        let notice = try #require(body.range(of: "goTo(.privateSecondaryNotice)"),
                                  "sin el desvío no hay nada que ordenar")
        // **Cambió el literal, no el invariante (2026-09-10, paso 4 del rediseño).** La rama privada ya no
        // sale directa por el portal: entra en la puerta que valida iCloud, y es ESA la que cruza
        // `leaveWelcome(to: .privateOnboarding)` en su `onProceed`. Lo que este test protege sigue siendo
        // lo mismo —que el aviso de sesión secundaria se evalúe ANTES de que la rama se vaya a ningún
        // sitio— así que lo que se busca es la salida de la rama, sea cual sea.
        let exit = try #require(body.range(of: "goTo(.privateICloudGate)"),
                                "la salida de la rama privada desapareció del switch")

        #expect(notice.lowerBound < exit.lowerBound, """
            el desvío al aviso quedó DESPUÉS de la salida por el portal, así que nunca se alcanza: \
            `leaveWelcome` ya sacó a la visita del cover. El orden es el arreglo entero.
            """)
    }

    @Test("el aviso continúa por el PORTAL, como todas las salidas del Welcome")
    func theNoticeContinuesThroughThePortal() throws {
        let src = try Self.code(Self.container)
        #expect(src.contains("case .privateSecondaryNotice:"), """
            el aviso es un STEP del container, no una presentación del anchor de `ContentView` — que \
            entraría en la matriz de readiness (regla 3 de Presentaciones).
            """)

        // El pin fuerte de esto lo tiene `NeutralMountRelaunchZeroTests.everyWelcomeExit_goesThroughThePortal`,
        // que comprueba TODAS las ocurrencias línea a línea. Aquí se ancla la del step nuevo: sin el
        // portal, la visita entra al onboarding sobre un store sin espejo y nadie se entera.
        let occurrences = src.components(separatedBy: "onSelectPrivateAccount()").count - 1
        #expect(occurrences == 2, """
            se esperaban DOS salidas a la rama privada —la directa y la del aviso— y hay \(occurrences). \
            Si bajó a una, el aviso dejó de continuar a ningún sitio y es un camino muerto.
            """)
    }

    @Test("el aviso no es un `.alert(` y su «volver» no es un camino muerto")
    func theNoticeIsAScreenWithTwoWaysOut() throws {
        let container = try Self.code(Self.container)
        #expect(!container.contains(".alert("), """
            `WelcomeHeroReentryTests` prohíbe `.alert(` en este fichero por source-scan, y un alert para \
            este aviso sería además un camino muerto en un flujo que el spec exige que no los tenga.
            """)

        let view = try Self.code(Self.noticeView)
        #expect(view.contains("onContinue()") && view.contains("welcomeBackButton"), """
            el aviso perdió una de sus dos salidas. Informa y no bloquea: seguir y volver tienen que \
            llevar los dos a algún sitio.
            """)
    }

    @Test("el «volver» se DERIVA del mismo término que decidió el sub-chooser")
    func theBackStepIsDerivedAndNotRemembered() throws {
        let src = try Self.code(Self.container)
        let body = try #require(
            Self.bodyOf("private var newBranchOriginStep: WelcomeFlowStep {", in: src),
            "`newBranchOriginStep` desapareció o cambió de firma")

        #expect(body.contains("WelcomeAccountChoiceLogic.bypass(visibleNewOptions)"), """
            el origen dejó de derivarse del MISMO término que `handleNewBranch` usa para decidir si \
            enseña el 2º nivel. Dos condiciones que deben coincidir y se calculan aparte divergen: al \
            volver, la visita vería una pantalla que nunca llegó a ver.
            """)
    }

    @Test("el copy es PROPIO y no el prestado de la rama de Grupos")
    func theCopyIsItsOwn() throws {
        let view = try Self.code(Self.noticeView)
        #expect(!view.contains("L10n.Welcome.Groups."), """
            el aviso pidió prestado el copy de la rama organizador. Nombran el mismo hecho —«estás de \
            visita»— pero la salida es la OPUESTA: allí el camino se acaba y aquí sigue, así que aquel \
            copy le diría a la visita que vuelva desde su dispositivo justo cuando la estamos dejando \
            continuar. Es el precedente de `welcome-copy-blames-owner`.
            """)
        for key in ["Private.secondaryTitle", "Private.secondaryBody", "Private.secondaryCta"] {
            #expect(view.contains("L10n.Welcome.\(key)"), "falta la key propia `\(key)` en el aviso")
        }
    }

    // MARK: - El seed que se dejó de prometer

    @Test("MUTACIÓN: `completeOnboarding` usa el término efectivo en sus TRES sitios")
    func completeOnboardingUsesTheEffectiveTerm() throws {
        let src = try Self.code(Self.onboarding)
        let body = try #require(Self.bodyOf("private func completeOnboarding() {", in: src),
                                "`completeOnboarding` desapareció o cambió de firma")

        for term in ["if willSeedCategories {",
                     "if !willSeedCategories && !expensesOnlyMode {",
                     "if wantsBudget && willSeedCategories {"] {
            #expect(body.contains(term), "`completeOnboarding` dejó de usar el término efectivo en: \(term)")
        }
        #expect(!body.contains("loadSeedCategories"), """
            `completeOnboarding` volvió a leer la respuesta CRUDA del usuario. En visita ese paso ni se \
            muestra, así que su valor es el default `true` y no una respuesta: el seed se llamaría, el \
            cinturón M1 lo cortaría y el store quedaría vacío después de haberlo prometido. \
            Y el segundo término es el que crea la subcategoría de «Ajuste de saldo» — sin él, el saldo \
            inicial que la visita teclea se descarta en silencio.
            """)
    }

    @Test("el término efectivo se apaga con el descriptor, no con otra cosa")
    func theEffectiveTermIsGatedByTheDescriptor() throws {
        let src = try Self.code(Self.onboarding)
        #expect(src.contains("private var willSeedCategories: Bool { loadSeedCategories && !isSecondarySession }"), """
            `willSeedCategories` cambió de forma. Es el único punto donde se decide qué va a pasar de \
            verdad con las categorías, y lo consumen el resumen y las tres ramas del alta.
            """)
        #expect(src.contains("private var isSecondarySession: Bool { SecondarySessionStore.isActive() }"), """
            el onboarding dejó de leer el descriptor. Contar filas del store diría que NO hay visita: el \
            store de la invitada está vacío en una sesión recién montada.
            """)
    }

    @Test("el paso de categorías se salta pasando el término REAL, no un literal")
    func theStepPlanGetsTheRealTerm() throws {
        let src = try Self.code(Self.onboarding)
        let body = try #require(Self.bodyOf("private var skippedSteps: Set<Step> {", in: src),
                                "`skippedSteps` desapareció o cambió de firma")
        #expect(body.contains("isSecondarySession: isSecondarySession"), """
            el plan de pasos dejó de recibir el término vivo. Con un literal el paso volvería a mostrarse \
            en visita, que es la mitad visible del bug: preguntar «¿quieres estas categorías?» y no crear \
            ninguna.
            """)
    }

    // MARK: - Lo que hay un tap después del CTA

    @Test("MUTACIÓN: el «empezar de cero» del CTA limpia el dominio local Y el iCloud KV")
    func theFreshStartClearsTheSessionDomain() throws {
        let src = try Self.code("Yala/App/Logic/OnboardingResetHelper.swift")
        let body = try #require(Self.bodyOf("static func clearResidualPreferencesForFreshStart() {", in: src),
                                "`clearResidualPreferencesForFreshStart` desapareció o cambió de firma")

        #expect(body.contains("let local = UserDefaults.standard"), """
            el barrido de «empezar de cero» ya no nombra su dominio local. Está a UN TAP del CTA de \
            `WelcomeSecondaryNoticeView` —`onSelectPrivateAccount` → `startFreshPrivateOnboarding` → aquí— \
            y tiene que barrer las DOS mitades: el dominio local y el iCloud KV. Hasta el 2026-09-12 la \
            mitad local iba al cajón de la sesión para no borrarle al dueño `userName` y \
            `defaultCurrencyCode`; retirada la puerta, el único dominio es `.standard` y lo que este \
            escaneo fija es que la línea siga existiendo. Sin esto, el copy de esa pantalla —«lo tuyo no \
            se mezcla con lo suyo»— es falso en la pantalla siguiente.
            """)
        #expect(body.contains("OwnerKeyValueStore.shared"), """
            la mitad iKV perdió su puerta. Las DOS mitades tienen que estar protegidas: durante meses \
            solo lo estuvo ésta, y por eso la local pasó desapercibida.
            """)
    }

    @Test("el resumen no promete categorías que no va a haber")
    func theConfirmationRowIsHiddenForTheGuest() throws {
        let src = try Self.code(Self.onboarding)
        let body = try #require(Self.bodyOf("private var confirmItemsCard: some View {", in: src),
                                "`confirmItemsCard` desapareció o cambió de firma")
        #expect(body.contains("if !isSecondarySession {"), """
            el resumen volvió a pintar la fila de categorías en visita. Es la SEGUNDA superficie que \
            promete el seed —la primera es el paso que ya se salta— y con el paso oculto diría \
            «Categorías predeterminadas» sin que el usuario haya elegido nada.
            """)
    }
}

/// **Lo que hace que dejar de sembrar no rompa el saldo inicial.**
///
/// Con `willSeedCategories == false` el alta entra por la rama que crea «Ajuste de saldo» a mano. Sin
/// esa subcategoría, `createOnboardingAccount` no encuentra dónde colgar el importe y lo descarta en
/// silencio (`findBalanceAdjustmentSubcategory` → `nil` → un `print` de DEBUG y nada más): la visita
/// teclea «tengo 500» y su cuenta nace en cero. Esto se ejecuta de verdad, no se escanea.
@Suite("El saldo inicial sobrevive sin el seed", .serialized) @MainActor
struct SecondarySessionInitialBalanceTests {

    @Test("sobre un store vacío, `ensureBalanceAdjustmentSubcategoryExists` la crea")
    func ensuresTheSubcategoryOnAnEmptyStore() throws {
        let context = try makeTestContext()

        #expect(InitialBalanceService.findBalanceAdjustmentSubcategory(context: context) == nil,
                "el store de la visita arranca vacío: sin seed no hay ninguna subcategoría")

        let created = InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context)
        #expect(created != nil, """
            la rama «sin seed» dejó de crear la subcategoría de ajuste. Es la única que queda en visita, \
            porque el seed retorna en su cinturón M1 — sin ella el saldo inicial se pierde sin avisar.
            """)
        #expect(InitialBalanceService.findBalanceAdjustmentSubcategory(context: context) != nil,
                "la creó pero no queda encontrable por el mismo lookup que usa el alta")
    }

    @Test("es idempotente: llamarla dos veces no duplica la subcategoría")
    func isIdempotent() throws {
        let context = try makeTestContext()

        _ = InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context)
        _ = InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context)

        let all = try context.fetch(FetchDescriptor<Subcategory>())
        let adjustments = all.filter { $0.name == L10n.Subcategory.balanceAdjustment }
        #expect(adjustments.count == 1, """
            duplicar «Ajuste de saldo» parte el saldo inicial en dos categorías distintas y lo hace \
            irreconciliable en el Panel. Encontradas: \(adjustments.count).
            """)
    }
}
