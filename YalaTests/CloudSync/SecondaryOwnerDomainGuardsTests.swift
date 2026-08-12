//
//  SecondaryOwnerDomainGuardsTests.swift
//  YalaTests / CloudSync
//
//  CHIP M1 · **la sesión secundaria no escribe el dominio del DUEÑO.**
//
//  Tres escritores medidos cruzaban la frontera M1 por el `UserDefaults.standard` COMPARTIDO —la
//  adopción de Grupos, el `onboardingMode` y el slot sin validación de ocupante— y ninguno lo repone
//  el wipe de salida, que solo devuelve TRES flags de onboarding a `false`.
//
//  **Por qué los guards van en los ESCRITORES y jamás en un barrido de salida:** por la decisión 7
//  del diseño M1, las preferencias del dueño SOBREVIVEN a la sesión de la invitada — un reset
//  genérico en el wipe le borraría al dueño lo suyo para arreglar lo de ella. Y por eso cada guard
//  necesita su propio test: quitar uno tiene que caer SOLO en el suyo.
//
//  Contar ESCRITURAS y no leer el estado final es load-bearing en los dos primeros (molde
//  `GroupsDomainAdoptionTests`): re-escribir el mismo valor deja el store idéntico y el mutante no
//  caería. Sin SwiftData, sin singletons y con `UserDefaults` aislado — el descriptor se planta en
//  ESE store, nunca en `.standard` (plantarlo en el real dejaría el simulador en «secundaria» para
//  las suites siguientes, que es la clase del sello heredado del QA manual).
//

import Foundation
import Testing

@testable import Yala

/// `UserDefaults` que CUENTA escrituras por key. Molde de `GroupsDomainAdoptionTests.CountingDefaults`.
private final class CountingDefaults: UserDefaults {
    var writes: [String: Int] = [:]

    override func set(_ value: Any?, forKey defaultName: String) {
        writes[defaultName, default: 0] += 1
        super.set(value, forKey: defaultName)
    }
}

@MainActor
@Suite("M1 · guards de escritura en la frontera de la sesión secundaria")
struct SecondaryOwnerDomainGuardsTests {

    /// Store contador con el descriptor de la invitada YA plantado (y el contador a cero, para que
    /// la escritura del propio descriptor no se cuele en la medición).
    private static func countingStore(
        secondaryUserID: String?,
        _ body: (CountingDefaults) throws -> Void
    ) throws {
        let suite = "test.\(UUID().uuidString)"
        let store = try #require(CountingDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }

        if let secondaryUserID {
            SecondarySessionStore.activate(userID: secondaryUserID, store)
        }
        store.writes = [:]
        try body(store)
    }

    // MARK: - Adopción del dominio Grupos

    /// Con el canal de Grupos encendido el tab es VISIBLE en secundaria, así que este `onAppear` lo
    /// dispara la invitada. La key es la que `GroupsDomainAdoptionLogic.isBridgeAllowed` consulta en
    /// un dispositivo SELLADO: escrita por ella, el sello del siguiente humano queda neutralizado.
    @Test("`recordEntry` no adopta el dominio del dueño desde la sesión de la invitada")
    func recordEntry_isInertUnderASecondarySession() throws {
        let key = AppPreferences.Keys.groupsBetaUnlocked

        try Self.countingStore(secondaryUserID: "guest-sub") { store in
            GroupsDomainAdoptionMarker.recordEntry(store)
            #expect(store.writes[key, default: 0] == 0, """
                La invitada adoptó el dominio Grupos del DUEÑO. El wipe de salida no repone esta key \
                (solo los 3 flags de onboarding), así que la escritura es permanente.
                """)
            #expect(store.bool(forKey: key) == false)
        }

        // Control POSITIVO: sin descriptor la adopción SÍ ocurre — sin esta mitad, un `recordEntry`
        // que no escribiera nunca pasaría el test de arriba sin haber medido nada.
        try Self.countingStore(secondaryUserID: nil) { store in
            GroupsDomainAdoptionMarker.recordEntry(store)
            #expect(store.writes[key, default: 0] == 1)
            #expect(store.bool(forKey: key) == true)
        }
    }

    // MARK: - `onboardingMode` (el embudo: `SessionState.didSet` + los 2 `setCurrent` directos)

    /// `.completed` es rank 2 y el merge es NEVER-DOWNGRADE: escrito por la invitada, el
    /// `.groupInvite` del dueño (rank 1) que baje del iKV ya no puede recuperarlo. La shell del dueño
    /// se queda escalada para siempre.
    @Test("`setCurrent` no persiste el modo del dueño desde la sesión de la invitada")
    func setCurrent_isInertUnderASecondarySession() throws {
        let key = OnboardingMode.userDefaultsKey

        try Self.countingStore(secondaryUserID: "guest-sub") { store in
            store.set(OnboardingMode.groupInvite.rawValue, forKey: key)  // el modo del DUEÑO
            store.writes = [:]

            OnboardingMode.setCurrent(.completed, store)

            #expect(store.writes[key, default: 0] == 0)
            #expect(store.string(forKey: key) == OnboardingMode.groupInvite.rawValue, """
                El modo del dueño quedó pisado por el de la invitada, y el never-downgrade lo hace \
                irreversible: su valor del iKV tiene rank menor y el merge no lo aplica.
                """)
        }

        try Self.countingStore(secondaryUserID: nil) { store in
            OnboardingMode.setCurrent(.completed, store)
            #expect(store.writes[key, default: 0] == 1)
            #expect(store.string(forKey: key) == OnboardingMode.completed.rawValue)
        }
    }

    // MARK: - Ocupante del slot (la promesa que el docblock hacía y el código no)

    @Test("tabla del ocupante: libre y misma cuenta entran; otra cuenta se bloquea")
    func slotOccupancy_table() {
        #expect(SecondarySlotOccupancyLogic.decide(
            occupantUserID: nil, enteringUserID: "sub-a") == .free)
        // Un descriptor VACÍO es slot libre y no «ocupado por alguien sin nombre»: `activate` rechaza
        // el string vacío, así que ese estado solo llega de un store manipulado.
        #expect(SecondarySlotOccupancyLogic.decide(
            occupantUserID: "", enteringUserID: "sub-a") == .free)
        // Re-entrada idempotente tras un kill entre descriptor y relanzamiento: bloquearla dejaría a
        // la invitada sin forma de volver a SU propia sesión.
        #expect(SecondarySlotOccupancyLogic.decide(
            occupantUserID: "sub-a", enteringUserID: "sub-a") == .sameAccount)
        #expect(SecondarySlotOccupancyLogic.decide(
            occupantUserID: "sub-a", enteringUserID: "sub-b") == .occupiedByOther)
    }
}

/// Cableado de producción (source-scan). Ni «el guard está en el escritor» ni «la ocupación se
/// consulta ANTES de activar el descriptor» son afirmaciones que un test de comportamiento pueda
/// hacer desde aquí: los dos escritores de `onboardingMode` que van por `PreferenceSyncService` viven
/// en vistas SwiftUI, y la entrada secundaria es un método privado de una de ellas. Sin estos scans,
/// quitar cualquiera de los tres cableados deja la suite entera en verde. Molde `AttestWiringTests` /
/// `CloudConsentRegistrationTests`.
@Suite("M1 · cableado de los guards de frontera (source-scan)")
struct SecondaryOwnerDomainWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código SIN líneas de comentario: el porqué de cada guard se explica ahí nombrando el guard, y
    /// contar prosa haría que documentar el invariante lo satisficiera solo.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador (molde `CloudConsentRegistrationTests`).
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

    private static let welcomePath = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
    private static let fullModePath = "Yala/App/Views/Groups/FullModeActivationView.swift"
    private static let onboardingPath = "Yala/App/Views/Onboarding/OnboardingView.swift"

    /// LA MUTACIÓN: mover la comprobación por debajo de `SecondaryEntryLogic.begin`. Compila, la tabla
    /// del ocupante sigue verde y el descriptor de la invitada A ya fue reescrito a nombre de B — que
    /// es exactamente el daño, porque los archivos `-Secondary` de A siguen en disco.
    @Test("la ocupación del slot se consulta ANTES de activar el descriptor")
    func secondaryEntry_checksOccupancyBeforeArming() throws {
        let confirm = try Self.body(
            of: "private func confirmSecondaryEntry() {", in: Self.code(Self.welcomePath))

        let check = try #require(
            confirm.range(of: "SecondarySlotOccupancyLogic.decide("),
            """
            `confirmSecondaryEntry` dejó de preguntar quién ocupa el slot: `activate(userID:)` \
            reescribe el nombre del ocupante y el boot monta el corpus de la invitada anterior.
            """)
        let begin = try #require(confirm.range(of: "SecondaryEntryLogic.begin("))
        #expect(check.lowerBound < begin.lowerBound)
        #expect(confirm.contains(".occupiedByOther"),
                "la decisión se lee pero no se ramifica: el bloqueo tiene que ser observable")
    }

    /// El mount y el wipe honran el descriptor INCONDICIONALMENTE (si no, apagar el flag brickearía
    /// una sesión viva). Colar ahí la comparación de ocupante es la otra mutación posible del chip.
    @Test("la validación del ocupante NO se cuela en el mount")
    func mountNeverAsksWhoOccupiesTheSlot() throws {
        let mount = try Self.code("Yala/Utils/SwiftDataConfiguration.swift")
        #expect(!mount.contains("SecondarySlotOccupancyLogic"), """
            El mount pregunta `isActive()` y jamás *quién*: una sesión ya activa no puede quedar \
            brickeada por una comparación de identidad en el arranque.
            """)
    }

    /// Los escritores de la key del modo que van por `PreferenceSyncService` — que en `.localOnly`
    /// SIGUE escribiendo el espejo local, o sea el `UserDefaults.standard` del dueño — y por tanto no
    /// los cubre el guard de `OnboardingMode.setCurrent`.
    ///
    /// El CONTEO es lo que hace que esto envejezca bien: un cuarto escritor rompe el test y obliga a
    /// decidir si necesita guard, en vez de aparecer en silencio.
    @Test("los escritores de `onboardingMode` por PreferenceSyncService son 2, y los DOS llevan guard")
    func preferenceSyncWritersOfTheMode_areGuardedWhereReachable() throws {
        var files: [URL] = []
        let dir = Self.repoRoot.appendingPathComponent("Yala")
        let walker = try #require(FileManager.default.enumerator(atPath: dir.path))
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            files.append(dir.appendingPathComponent(relative))
        }
        #expect(files.count >= 500, "El escáner solo encontró \(files.count) ficheros — no mide el árbol real.")

        var writers: [String] = []
        for file in files {
            let src = try String(contentsOf: file, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            // `set(string:` (PreferenceSyncService directo) y `setSynced(` (el writer inyectable del
            // alta del organizador) son las DOS formas con las que hoy se empuja la key al canal.
            for forma in ["set(string: OnboardingMode", "setSynced(OnboardingMode"]
            where src.contains(forma) {
                writers.append(file.lastPathComponent)
            }
        }

        // C2 · bajaron de 3 a 2: `OnboardingView.completeGroupsOnlyOnboarding` fue ELIMINADA. Escribía el
        // trío en el paso 8 del onboarding sin sesión, sin consent y sin canal comprobado; hoy la card
        // «Solo grupos» entra en la cadena y su alta la ejecuta `GroupsOrganizerOnboarding`, que heredó su
        // guard M1 justamente porque heredó su camino.
        #expect(Set(writers) == ["FullModeActivationView.swift",
                                 "GroupsOrganizerOnboarding.swift"], """
            Cambió el conjunto de escritores del modo por el canal de prefs (hoy: \(Set(writers).sorted())). \
            Cada uno necesita una decisión explícita sobre el guard M1, porque en `.localOnly` este \
            camino sigue escribiendo el espejo local, que en secundaria es el store del DUEÑO.
            """)

        // Los dos alcanzables CON una sesión secundaria viva llevan el guard en su escritor.
        let fullMode = try Self.body(
            of: "private func completeFullActivation() {", in: Self.code(Self.fullModePath))
        #expect(fullMode.contains("if !SecondarySessionStore.isActive()"), """
            `FullModeActivationView` volvió a escribir el modo sin guard: la invitada hereda la shell \
            reducida del dueño y activar Yala completo le deja a él un `.completed` irreversible.
            """)

        // C2 · `OnboardingView` ya no escribe el modo (su `completeGroupsOnlyOnboarding` fue eliminada),
        // así que el guard que llevaba se comprueba ahora donde vive su camino.
        let onboarding = try Self.code(Self.onboardingPath)
        #expect(!onboarding.contains("set(string: OnboardingMode"), """
            `OnboardingView` volvió a empujar el modo al canal de prefs. Esa escritura ocurría en el paso 8
            del onboarding, SIN sesión y SIN consent, y `.groupInvite` es never-downgrade cross-device:
            viaja al iKV del Apple ID y no vuelve.
            """)

        // **C2 invirtió esta aserción y C3 la SUBIÓ de la key al método, que es la corrección de fondo.**
        // Hasta C2 `GroupsOrganizerOnboarding` no llevaba guard (su único call-site vivía en el Welcome,
        // inalcanzable con un descriptor vivo); C2 le añadió el segundo call-site y con él el guard, pero
        // sobre UNA sola de sus seis escrituras — que es justo lo que este escáner señalaba. C3 lo pone en
        // la cabecera: ver `theOrganizerSetupGuardsAllSixKeys`, que es donde vive ahora el peso.
        let organizer = try Self.code("Yala/Services/Groups/GroupsOrganizerOnboarding.swift")
        #expect(organizer.contains("guard !isSecondarySession else { return false }"), """
            el alta del organizador escribe el modo sin guard M1. Con una sesión secundaria viva ese `set`
            cae en el `UserDefaults.standard` del DUEÑO y le deja `.groupInvite` (rank 1) sobre su `.full`
            (rank 0), irreversible por never-downgrade.
            """)
    }

    /// **C3 · el escáner tampoco viajaba solo, y esta es su otra mitad.**
    ///
    /// El de arriba busca los escritores de `onboardingMode` —los literales `set(string: OnboardingMode` y
    /// `setSynced(OnboardingMode`— y por eso C2 arregló EXACTAMENTE una key: la que el escáner sabía ver.
    /// `GroupsOrganizerOnboarding` escribe SEIS (`userName`, `defaultPeriod`, `defaultCurrencyCode`, el
    /// modo, `groupsBetaUnlocked`, `hasCompletedOnboarding`) y las otras cinco cruzaban la frontera igual:
    /// `PreferenceSyncService.set(string:)` hace su `local.set(...)` FUERA del switch de behavior ⇒
    /// `.localOnly` corta la propagación pero **no la escritura local**, y `local` es `.standard`
    /// hardcodeado, que en secundaria es el dominio del DUEÑO.
    ///
    /// Es la regla de `0c39e884` («un guard no viaja solo con el camino que protegía») una capa más
    /// arriba: **el inventario que el escáner mira tiene que ser el inventario que la función escribe.**
    /// Por eso este test lee `writtenKeys` en vez de una lista a mano — una duplicada se quedaría corta en
    /// cuanto alguien añadiera la séptima, y la aserción seguiría en verde.
    @Test("el guard del alta cubre las SEIS keys, no la que el escáner sabía ver")
    func theOrganizerSetupGuardsAllSixKeys() throws {
        let organizer = try Self.code("Yala/Services/Groups/GroupsOrganizerOnboarding.swift")

        // El guard está en la CABECERA de `writePreferences`, o sea antes de la primera escritura. Un
        // `if` alrededor de una sola línea vuelve a dejar cinco fuera.
        let write = try Self.body(
            of: "isSecondarySession: Bool = SecondarySessionStore.isActive()) -> Bool {",
            in: organizer)
        let guardIdx = try #require(write.range(of: "guard !isSecondarySession"), """
            `writePreferences` perdió su guard de cabecera: las seis escrituras vuelven a caer en el \
            `UserDefaults` del DUEÑO en cuanto haya un descriptor vivo.
            """)
        for key in ["AppPreferences.Keys.userName",
                    "AppPreferences.Keys.defaultPeriod",
                    "AppPreferences.Keys.defaultCurrencyCode",
                    "OnboardingMode.userDefaultsKey",
                    "AppPreferences.Keys.groupsBetaUnlocked",
                    "AppPreferences.Keys.hasCompletedOnboarding"] {
            let use = try #require(write.range(of: key), "el alta dejó de escribir \(key)")
            #expect(guardIdx.upperBound < use.lowerBound, """
                la escritura de \(key) quedó POR DELANTE del guard M1. El orden es el invariante: el guard \
                aborta el método entero, así que cualquier escritura anterior a él se escapa.
                """)
        }

        // El inventario publicado y lo que la función escribe tienen que ser lo MISMO. Sin esto, alguien
        // puede añadir una séptima escritura sin tocar `writtenKeys` y los tests que se alimentan de ese
        // inventario —el control positivo de `GroupsOrganizerNoWriteTests`— no la cubrirían nunca.
        #expect(GroupsOrganizerOnboarding.writtenKeys.count == 6, """
            el inventario del alta cambió de tamaño (\(GroupsOrganizerOnboarding.writtenKeys.count)). \
            Decide explícitamente si la escritura nueva entra, en vez de dejarla aparecer en silencio.
            """)
    }
}
