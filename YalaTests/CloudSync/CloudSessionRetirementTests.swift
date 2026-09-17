//
//  CloudSessionRetirementTests.swift
//  YalaTests
//
//  El retiro de la sesión en la nube de quien usó ANTES este teléfono
//  (`previous-person-cloud-session-survives-fresh-start-and-reinstall`, decisión de Jürgen 2026-09-17:
//  **las dos mitades**).
//
//  Lo que estos tests cargan, y por qué cada uno existe:
//
//   1. **El ORDEN dentro del ejecutor.** `AuthClient` nace con `autoRefreshToken: true`: purgar el
//      llavero sin parar antes al SDK deja su refresco en vuelo REPONIENDO la sesión sobre lo recién
//      borrado. Un test que solo mirara el estado final no distingue «se hizo en orden» de «se hizo al
//      revés y el refresco no llegó a saltar en esta corrida».
//   2. **El arm se conserva si la purga FALLA.** Es la diferencia entre un residuo temporal y uno
//      permanente, y es exactamente donde `SecondarySessionRetirement` pagó su hallazgo de review.
//   3. **El arm se escribe ANTES que la marca de instalación.** Al revés, un kill entre las dos deja la
//      marca puesta y el arm perdido: la sesión de la persona anterior sobrevive para siempre.
//   4. **El relevo arma, y el cursor de Grupos NO cambia de signo.** Es la medición que Jürgen pidió
//      antes de aprobar esta mitad.
//
//  `UserDefaults` SIEMPRE aislado (`makeIsolatedDefaults`): las keys llevan prefijo `cloudSync.` y
//  escribirlas en el dominio real contaminaría a las suites vecinas, que es la lección que
//  `HandoverGroupsDomainTests` lleva en su cabecera.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Retiro de la sesión de la persona anterior", .serialized)
struct CloudSessionRetirementTests {

    // MARK: - El primer arranque tras instalar

    @Test func firstLaunchAfterInstall_arms_andTheSecondDoesNot() {
        let defaults = makeIsolatedDefaults()

        #expect(CloudSessionRetirement.armIfFirstLaunchAfterInstall(
            defaults: defaults, hasPriorInstallEvidence: false))
        #expect(defaults.bool(forKey: CloudSessionRetirement.armedKey))
        #expect(defaults.bool(forKey: CloudSessionRetirement.installSeenKey))

        // Segundo arranque: nada que armar. Y lo que importa es que NO re-arme incluso con el arm ya
        // consumido — si lo hiciera, cerraría la sesión que la persona nueva acaba de abrir, en cada boot.
        defaults.removeObject(forKey: CloudSessionRetirement.armedKey)
        #expect(!CloudSessionRetirement.armIfFirstLaunchAfterInstall(
            defaults: defaults, hasPriorInstallEvidence: false))
        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey))
    }

    /// **El caso que decide si esta versión se puede publicar.** `installSeenKey` NACE con este cambio,
    /// así que en CADA teléfono del parque está ausente: sin la evidencia de instalación previa, la
    /// primera actualización armaría el retiro para todo el mundo y cerraría la sesión de quien no lo
    /// pidió. La marca se escribe igual, para que solo un arranque se lo pregunte.
    @Test func anUpdateOverALiveInstall_armsNothing_butMarksTheContainer() {
        let defaults = makeIsolatedDefaults()

        #expect(!CloudSessionRetirement.armIfFirstLaunchAfterInstall(
            defaults: defaults, hasPriorInstallEvidence: true))

        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey), """
            REGRESIÓN DE PARQUE: «no hay marca» significa «primera vez que corre este código», no «app
            recién instalada». Armar aquí cierra la sesión de todos los usuarios de la nube el día del
            update.
            """)
        #expect(defaults.bool(forKey: CloudSessionRetirement.installSeenKey), """
            sin la marca, el arranque siguiente vuelve a hacerse la pregunta — y bastaría con que la
            evidencia fallara una vez (un «Vaciar datos» por medio) para armar sobre una instalación viva.
            """)
    }

    /// **La marca de instalación se escribe en el contenedor; el llavero no está ahí.** Restaurar el
    /// teléfono desde una copia de seguridad repone las DOS cosas, así que ahí la marca ya está y no se
    /// arma nada: es la misma persona.
    @Test func aContainerThatAlreadyBooted_armsNothing() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: CloudSessionRetirement.installSeenKey)

        #expect(!CloudSessionRetirement.armIfFirstLaunchAfterInstall(
            defaults: defaults, hasPriorInstallEvidence: false))
        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey))
    }

    // MARK: - El ejecutor

    @Test func withoutArm_itDoesNothing() async {
        let defaults = makeIsolatedDefaults()
        let spy = Spy()

        let consumed = await CloudSessionRetirement.retireIfArmed(
            defaults: defaults, signOut: { spy.record("signOut") },
            purgeKeychain: { spy.record("purge"); return true }, isKeychainEmpty: { true })

        #expect(!consumed)
        #expect(spy.steps.isEmpty, """
            sin arm no se toca ni al SDK ni al llavero: un sign-out incondicional aquí cerraría la sesión
            de quien ya firmó con la suya.
            """)
    }

    /// El orden: parar al SDK **antes** de tocar el llavero. Ver el punto 1 de la cabecera.
    @Test func itStopsTheSDKBeforeTouchingTheKeychain() async {
        let defaults = makeIsolatedDefaults()
        CloudSessionRetirement.arm(defaults: defaults)
        let spy = Spy()

        let consumed = await CloudSessionRetirement.retireIfArmed(
            defaults: defaults, signOut: { spy.record("signOut") },
            purgeKeychain: { spy.record("purge"); return true }, isKeychainEmpty: { true })

        #expect(consumed)
        #expect(spy.steps == ["signOut", "purge"], """
            al revés, el auto-refresh del SDK repone la sesión sobre el llavero recién purgado y el retiro
            queda deshecho sin que nadie se entere. Orden observado: \(spy.steps)
            """)
        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey), "salió bien ⇒ se desarma")
    }

    /// Failure-safe: si el llavero no se deja barrer, el arm se CONSERVA y el arranque siguiente
    /// reintenta. Escribir el desarme igual dejaría la sesión de otra persona aquí para siempre.
    @Test func aKeychainThatRefusesToPurge_keepsTheArm() async {
        let defaults = makeIsolatedDefaults()
        CloudSessionRetirement.arm(defaults: defaults)

        let consumed = await CloudSessionRetirement.retireIfArmed(
            defaults: defaults, signOut: {}, purgeKeychain: { false }, isKeychainEmpty: { true })

        #expect(!consumed)
        #expect(defaults.bool(forKey: CloudSessionRetirement.armedKey), """
            REGRESIÓN: con el arm desarmado tras un fallo, ningún arranque vuelve a mirar y la sesión de
            la persona anterior se queda en el teléfono.
            """)
    }

    /// **El auto-refresh del SDK puede reponer la sesión DURANTE el `await`, y `signOut()` no lo para**
    /// (`stopAutoRefreshToken` no se llama en ningún sitio de este repo, medido). Si el retiro se diera por
    /// hecho, el arm se borraría y la sesión de la persona anterior quedaría resucitada **para siempre**,
    /// con un breadcrumb diciendo que todo fue bien. Lo cazó la review adversarial.
    @Test func aSessionResurrectedByTheSDKKeepsTheArm() async {
        let defaults = makeIsolatedDefaults()
        CloudSessionRetirement.arm(defaults: defaults)

        let consumed = await CloudSessionRetirement.retireIfArmed(
            defaults: defaults, signOut: {}, purgeKeychain: { true }, isKeychainEmpty: { false })

        #expect(!consumed)
        #expect(defaults.bool(forKey: CloudSessionRetirement.armedKey), """
            REGRESIÓN: el `SecItemDelete` salió bien y el llavero NO quedó vacío — alguien volvió a
            escribir. Desarmar aquí deja la sesión del anterior viva y sin que ningún arranque la mire.
            """)
    }

    // MARK: - El consumidor pre-mount

    /// El camino que de verdad cierra la reinstalación: síncrono, sin red y sin SDK construido.
    @Test func preMountPurge_consumesTheArm() {
        let defaults = makeIsolatedDefaults()
        CloudSessionRetirement.arm(defaults: defaults)
        var purgas = 0

        #expect(CloudSessionRetirement.purgeIfArmed(
            defaults: defaults, purgeKeychain: { purgas += 1; return true }))

        #expect(purgas == 1)
        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey))
    }

    @Test func preMountPurge_withoutArm_touchesNothing() {
        let defaults = makeIsolatedDefaults()
        var purgas = 0

        #expect(!CloudSessionRetirement.purgeIfArmed(
            defaults: defaults, purgeKeychain: { purgas += 1; return true }))

        #expect(purgas == 0, """
            este camino corre en CADA arranque del parque entero: purgar sin arm borraría el llavero de
            todo el mundo.
            """)
    }

    @Test func preMountPurge_thatFails_keepsTheArm() {
        let defaults = makeIsolatedDefaults()
        CloudSessionRetirement.arm(defaults: defaults)

        #expect(!CloudSessionRetirement.purgeIfArmed(defaults: defaults, purgeKeychain: { false }))
        #expect(defaults.bool(forKey: CloudSessionRetirement.armedKey))
    }

    @Test func retireForHandover_armsSynchronously() {
        let defaults = makeIsolatedDefaults()

        // Los seams se inyectan: con los de producción, este test ejecutaría un `signOut()` de verdad y un
        // `SecItemDelete` sobre el llavero del host, en un `Task` que sobrevive al caso.
        CloudSessionRetirement.retireForHandover(
            defaults: defaults, signOut: {}, purgeKeychain: { true }, isKeychainEmpty: { true })

        #expect(defaults.bool(forKey: CloudSessionRetirement.armedKey), """
            el arm tiene que quedar escrito ANTES de que el `Task` corra: es lo único que sobrevive a un
            kill entre el gesto y el retiro.
            """)
    }

    // MARK: - El relevo arma, y el cursor no cambia de signo

    /// La medición que Jürgen pidió antes de aprobar esta mitad: cerrar la sesión en «Empezar desde
    /// cero» **no invierte el signo del cursor de Grupos**. El par coherente sigue siendo
    /// «outbox muerto + cursor vivo», y ahora además el retiro queda armado.
    @Test func freshStart_armsTheRetirement_andStillKeepsTheCursor() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        context.insert(GroupSyncCursor(groupCursorsJSON: "{\"g1\":5}"))
        context.insert(GroupSyncOutbox(
            syncID: UUID(), groupID: "g1", entityType: "SplitExpense",
            op: .upsert, hlc: "hlc", fieldsJSON: "{\"amount\":300}", author: "anterior",
            rejectedReason: nil))
        try context.save()

        var disparos = 0
        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: defaults,
            retireCloudSession: { disparos += 1 }, resetSyncState: {})

        #expect(defaults.bool(forKey: CloudSessionRetirement.armedKey), """
            sin el arm, un kill después del borrado deja la sesión de la persona anterior viva y ningún
            arranque vuelve a mirarla.
            """)
        #expect(disparos == 1, "y se dispara en ESTE proceso: el relevo no relanza")
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncCursor>()) == 1, """
            REGRESIÓN `31dded30`: cerrar la sesión NO es motivo para purgar el cursor. Está indexado por
            `groupID`, un re-join ya lo resetea, y si el retiro falla es la única barrera que queda.
            """)
        let cursor = try context.fetch(FetchDescriptor<GroupSyncCursor>()).first
        #expect(cursor?.groupCursorsJSON == "{\"g1\":5}", "y conserva su CONTENIDO, no solo su fila")
    }

    private final class Spy {
        private(set) var steps: [String] = []
        func record(_ step: String) { steps.append(step) }
    }
}

// MARK: - Cableado de producción (source-scan)

/// Los dos disparadores y el único consumidor viven en sitios que ningún test de comportamiento
/// alcanza: el arranque PRE-MOUNT y el bootstrap. Estos scans nombran al culpable si alguien los
/// mueve — y el ORDEN dentro del bootstrap es lo que hace que el ticket quede cerrado en vez de
/// medio cerrado.
@Suite("Retiro de la sesión anterior · cableado (source-scan)")
struct CloudSessionRetirementWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func expectOrder(_ first: String, before second: String, in source: String,
                                    _ why: String,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try #require(source.range(of: first), "no está: \(first)")
        let b = try #require(source.range(of: second), "no está: \(second)")
        #expect(a.lowerBound < b.lowerBound, Comment(rawValue: why), sourceLocation: sourceLocation)
    }

    /// El arm del primer arranque va PRE-MOUNT, donde todavía no existe nada que pueda leer la sesión.
    @Test func theFirstLaunchArmAndPurgeLivePreMount_inThisOrder() throws {
        let src = try Self.code("Yala/Services/CloudSync/PersonalContainerSwap.swift")
        let make = try Self.body(of: "static func makeContainer() throws -> ModelContainer {", in: src)
        #expect(make.contains("CloudSessionRetirement.armIfFirstLaunchAfterInstall()"), """
            sin esto, la mitad de la REINSTALACIÓN no existe: el JWT sobrevive a borrar la app y ninguna
            puerta puede distinguirlo, porque tras reinstalar tampoco queda sello.
            """)
        try Self.expectOrder("CloudSessionRetirement.armIfFirstLaunchAfterInstall()",
                             before: "CloudSessionRetirement.purgeIfArmed()", in: make,
                             "consumir antes de armar deja la reinstalación para el arranque siguiente")
        try Self.expectOrder("CloudSessionRetirement.armIfFirstLaunchAfterInstall()",
                             before: "SwiftDataConfiguration.performSignOutWipeIfArmed()", in: make, """
                             ese hook BORRA los archivos del store, que son una de las dos evidencias de
                             instalación previa: leerla después la encuentra ausente y arma sobre una
                             instalación viva
                             """)
        try Self.expectOrder("CloudSessionRetirement.purgeIfArmed()",
                             before: "return try ModelContainer(", in: make, """
                             el purgado tiene que ir ANTES de construir nada: todo su diseño se apoya en
                             que `CloudAuthService.shared` no exista todavía, así que movido al final se
                             auto-fabrica la evidencia y pierde la garantía de que nadie repone
                             """)
    }

    /// **El bootstrap NO puede consumir el arm**, y eso hay que fijarlo: la primera versión lo hacía y el
    /// `await` del sign-out —que habla con el servidor sin tope propio— dejaba el `defer` de `bootstrap()`
    /// sin ejecutar, y con él el blocker `bootstrapPending`. Con un portal cautivo, el primerísimo
    /// arranque se quedaba sin montar el Welcome y sin drenar un solo intent. Lo cazó la review.
    @Test func theBootstrapDoesNotAwaitTheRetirement() throws {
        let src = try Self.code("Yala/App/AppBootstrapper.swift")
        let boot = try Self.body(of: "func bootstrap(container: ModelContainer) async {", in: src)
        #expect(!boot.contains("CloudSessionRetirement.retireIfArmed"), """
            REGRESIÓN: un `await` al retiro dentro de `bootstrap()` mete hasta 60 s de red delante de la
            primera pantalla. El consumo vive PRE-MOUNT, donde no hay red ni nada que bloquear.
            """)
    }

    /// **La evidencia de instalación previa se lee de verdad en producción.** Un `hasPriorInstallEvidence`
    /// cableado a `false` dejaría el unit test en verde y cerraría la sesión del parque entero.
    @Test func theProductionArmReadsPriorInstallEvidence() throws {
        let src = try Self.code("Yala/Services/CloudSync/CloudSessionRetirement.swift")
        let prod = try Self.body(of: "    static func armIfFirstLaunchAfterInstall() {", in: src)
        #expect(prod.contains("SwiftDataConfiguration.personalStoreFileExists()"))
        #expect(prod.contains("priorInstallEvidenceKeys.contains"))
        #expect(!prod.contains("hasPriorInstallEvidence: false"), """
            REGRESIÓN DE PARQUE: con la evidencia en `false`, la primera actualización arma el retiro en
            todos los teléfonos que ya tienen Yala.
            """)
    }

    /// **El arm del relevo va DESPUÉS de la transacción de borrado.** Si el wipe lanza, el relevo no
    /// ocurrió: cerrarle la sesión a quien sigue con sus datos intactos sería un daño nuevo. Y va ANTES del
    /// sello, que es el último efecto del escritor.
    ///
    /// Este test existía, lo borré sin querer al retirar el del bootstrap, y el mutante que mueve el arm
    /// delante del borrado sobrevivió con la suite entera en verde. Repuesto y re-verificado.
    @Test func theHandoverWriterArmsAfterTheDeletion() throws {
        let src = try Self.code("Yala/Utils/DataWipeService.swift")
        let firma = src.components(separatedBy: "static func wipeLocalGroupsDomain(")[1]
        let wipe = try Self.body(of: "    ) throws {\n", in: firma)
        try Self.expectOrder("try deleteLocalGroupsRows(in: context)",
                             before: "CloudSessionRetirement.arm(defaults: defaults)", in: wipe,
                             "un wipe que lanza no debe cerrarle la sesión a quien sigue con sus datos")
        try Self.expectOrder("CloudSessionRetirement.arm(defaults: defaults)",
                             before: "groupsDomainSealedForFreshStart", in: wipe,
                             "el arm es la raíz y el sello el cinturón; el sello se escribe al final")
    }

    /// **El disparo EN PROCESO del relevo.** El arm solo cura en el arranque siguiente; lo que cierra las
    /// puertas «a un toque» —el Welcome, «Activar Yala completo», la hoja de Grupos— es que el retiro corra
    /// en este mismo proceso. Vaciar el closure por defecto dejaba toda la suite en verde.
    @Test func theHandoverFiresTheRetirementInProcess() throws {
        let src = try Self.code("Yala/Utils/DataWipeService.swift")
        let firma = src.components(separatedBy: "static func wipeLocalGroupsDomain(")[1]
        let seam = try Self.body(of: "retireCloudSession: @MainActor () -> Void = {", in: firma)
        #expect(seam.contains("CloudSessionRetirement.retireIfArmed()"), """
            sin el disparo, el relevo solo deja el arm y la persona nueva llega a las puertas con la sesión
            del anterior todavía viva hasta que reabra la app.
            """)
        #expect(seam.contains("Task {"), "el retiro es asíncrono y el escritor no lo es")
    }

    /// **La QUINTA declaración de «empiezo de cero»**: con mount neutro, «Soy nuevo → privacidad total»
    /// sale por el relanzamiento y no por `onSelectPrivateAccount`. No pasa por ningún escritor común.
    @Test func theMirrorRelaunchBranchArmsTheRetirement() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let rama = try Self.body(of: "if destination == .privateOnboarding {", in: src)
        #expect(rama.contains("CloudSessionRetirement.arm(defaults: .standard)"), """
            sin esto, el camino que relanza para adjuntar el espejo aterriza en el onboarding con el
            llavero de la persona anterior intacto — el bug del ticket por la puerta que nadie miró.
            """)
    }

    /// Paridad con el productor real de la evidencia. `ReviewPromptService.firstLaunchDateKey` es
    /// `private`, así que una copia divergente dejaría la evidencia mirando una key muerta — y con ella,
    /// armando sobre instalaciones vivas.
    @Test func thePriorInstallEvidenceKeysMatchTheirProducers() throws {
        let review = try Self.code("Yala/App/Services/ReviewPromptService.swift")
        #expect(review.contains("firstLaunchDateKey = \"reviewFirstLaunchDate\""))
        let prefs = try Self.code("Yala/App/Services/AppPreferences.swift")
        #expect(prefs.contains("hasCompletedOnboarding = \"hasCompletedOnboarding\""))
        #expect(CloudSessionRetirement.priorInstallEvidenceKeys
            == ["reviewFirstLaunchDate", "hasCompletedOnboarding"])
    }

    /// **«No hay filas» no es «no hay handover».** El `guard` viejo colapsaba las dos preguntas y dejaba
    /// `.handover` sin purgar ni sellar en un teléfono vacío — la celda de la reinstalación.
    @Test func theICloudWipeSealsEvenWithNoLocalRows() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wipe = try Self.body(of: "private func performICloudCorpusWipe(_ scope: ICloudWipeScope) async -> String? {",
                                 in: src)
        let salida = try Self.body(of: "guard scope.deletesLocalRows, checkHasExistingData() else {", in: wipe)
        #expect(salida.contains("CloudSessionRetirement.retireForHandover()"), """
            sin filas no hay nada que borrar, pero el JWT de la persona anterior sobrevive al store vacío
            —una reinstalación es exactamente esa celda— y ahí es donde el ticket lo pierde.
            """)
        #expect(!salida.contains("wipeLocalGroupsDomain"), """
            REGRESIÓN cazada por dos lentes: sellar aquí le quita la asociación de Grupos de su Apple ID,
            para siempre, a quien reinstala su PROPIA app y a quien contesta al aviso del espejo tardío —
            que es la MISMA persona por definición.
            """)
    }

    /// La rama de «Soy nuevo» SIN datos locales: no pasa por el escritor común, así que retira la sesión
    /// por su cuenta. Y **no sella**, que es la asimetría deliberada.
    @Test func freshPrivateOnboardingWithoutData_retiresTheSession_butDoesNotSeal() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let fn = try Self.body(of: "private func startFreshPrivateOnboarding() {", in: src)
        #expect(fn.contains("CloudSessionRetirement.retireForHandover()"), """
            sin esto, quien reinstala y dice «soy nuevo» entra al onboarding con la sesión de la persona
            anterior intacta — el camino que este ticket mide como «reinstalación sin sello».
            """)
        #expect(!fn.contains(AppPreferences.Keys.groupsDomainSealedForFreshStart), """
            sellar aquí es irreversible en este teléfono y se lo comería quien reinstala su PROPIA app:
            le quitaría la asociación de Grupos de su Apple ID para siempre. Se mira el TOKEN DEL SELLO y
            no `wipeLocalGroupsDomain`, porque esa llamada nunca estuvo en esta función —la aserción
            vieja no podía fallar y lo cazó la review.
            """)
        #expect(!fn.contains("wipeLocalGroupsDomain"))
        // Y lo que este teléfono recordaba de la cuenta anterior sí se olvida: el correo del anterior en
        // la fila de Ajustes y el «vuelve a tu cuenta» del empty state de Grupos no son suyos.
        #expect(fn.contains("GroupsAccountAssociation.localKey"))
        #expect(fn.contains("GroupsSessionHistoryMarker.key"))
    }

    /// El barrido del llavero es del SERVICE entero, no de una lista de `account`. Bajo
    /// `com.yala.cloudauth` viven cinco credenciales de la persona que firmó y una lista es como diverge
    /// de lo que ese service acabe guardando mañana.
    @Test func theKeychainPurgeTakesTheWholeService() throws {
        let src = try Self.code("Yala/Services/CloudSync/CloudAuthKeychainStorage.swift")
        let purge = try Self.body(of: "func purgeAll() -> Bool {", in: src)
        #expect(purge.contains("kSecAttrService as String: service"))
        #expect(!purge.contains("kSecAttrAccount"), """
            con `kSecAttrAccount` esto vuelve a ser una lista de keys: el par SIWA, el par Google y el
            perfil capturado de la persona anterior se quedarían en el teléfono.
            """)
        #expect(purge.contains("errSecItemNotFound"), "no haber nada es ÉXITO, no un fallo que conserve el arm")
    }
}
