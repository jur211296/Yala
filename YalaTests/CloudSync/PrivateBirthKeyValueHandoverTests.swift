//
//  PrivateBirthKeyValueHandoverTests.swift
//  YalaTests / CloudSync
//
//  **Lo que se elige al «Activar Yala completo → privado» llega al iCloud-KV del Apple ID, y el arranque siguiente no
//  lo revierte** (ticket `full-activation-local-state-never-reaches-the-apple-id-kv`; decisión de Jürgen del
//  2026-09-30: subir al nacer la sesión privada, solo en la rama privada nueva).
//
//  **Una sola `@Suite` de nivel superior, con el nombre del fichero**: `-only-testing` filtra por TIPO.
//   · EL HUECO — el control: sin la subida, la puerta se traga lo elegido y el merge lo revierte;
//   · LA SUBIDA — con la marca, el estado local está en el KV y el merge de producción no cambia NADA;
//   · EL KILL — antes del eje se descarta sin subir, y una Restauración posterior no sube;
//   · QUIÉN SUBE — solo `.freshPrivate`, y el orden kill-safe del plan intacto;
//   · EL CABLEADO — la marca antes del eje, la subida después, el arranque antes del merge, y los defaults de
//     producción de `consumeIfArmed` (todos los casos de arriba los inyectan).
//
//  Todo contra un dominio y un store PROPIOS, con la puerta de producción (`OwnerKeyValueStore`) delante del espía:
//  nada de aquí toca `.standard` ni el iCloud-KV del simulador.
//

import Foundation
import Testing

@testable import Yala

/// Store espía detrás de la puerta: GUARDA lo escrito, para que el merge lea lo que de verdad llegó. `onWrite` deja
/// mirar el estado del teléfono en el instante de cada escritura.
private final class HandoverSpyStore: OwnerKeyValueWriting {
    var values: [String: Any] = [:]
    var writes: [String] = []
    var removals: [String] = []
    var synchronizeCount = 0
    var onWrite: (() -> Void)?

    private func wrote(_ key: String) { writes.append(key); onWrite?() }

    func setBool(_ value: Bool, forKey key: String) { values[key] = value; wrote(key) }
    func setString(_ value: String, forKey key: String) { values[key] = value; wrote(key) }
    func setDouble(_ value: Double, forKey key: String) { values[key] = value; wrote(key) }
    func setInt(_ value: Int, forKey key: String) { values[key] = Int64(value); wrote(key) }
    func removeObject(forKey key: String) { values[key] = nil; removals.append(key); onWrite?() }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func longLong(forKey key: String) -> Int64 { values[key] as? Int64 ?? 0 }
    func object(forKey key: String) -> Any? { values[key] }
    @discardableResult func synchronize() -> Bool { synchronizeCount += 1; return true }
}

@MainActor
@Suite("iCloud-KV del Apple ID · lo elegido al activar Yala completo en privado")
struct PrivateBirthKeyValueHandoverTests {

    // MARK: - El escenario

    /// Un teléfono en la ventana de la activación: el neutro ya levantado, el eje en `false`, y debajo un Apple ID
    /// que tuvo una vida privada con otras preferencias.
    @MainActor
    private struct Phone {
        let name = "test.privateBirthHandover.\(UUID().uuidString)"
        let languageName = "test.privateBirthHandover.lang.\(UUID().uuidString)"
        let defaults: UserDefaults
        let languageSuite: UserDefaults
        let spy: HandoverSpyStore
        let store: OwnerKeyValueStore

        init() throws {
            let domain = try #require(UserDefaults(suiteName: name))
            let backing = HandoverSpyStore()
            defaults = domain
            languageSuite = try #require(UserDefaults(suiteName: languageName))
            spy = backing
            store = OwnerKeyValueStore(backing: backing, decision: { OwnerKeyValueGate.current(domain) })
            // La celda de la activación tras relanzar: `clearGroupsOnlyNeutralMount` ya corrió, el eje sigue apagado.
            PrivateSessionMark.set(false, defaults)
            // La vida anterior del Apple ID.
            spy.values = [
                "userName": "Ana", "defaultCurrencyCode": "EUR", "defaultPeriod": "thisYear",
                "expensesOnlyMode": true, "financialMindset": "saver", "includeGroupTransactionsInFeed": false,
                "decimalPlaces": Int64(0), "colorfulIcons": false, "firstWeekday": Int64(1),
                "appLanguageOverride": "de", "cloudConsentAcceptedAt": Int64(1_700_000_000),
            ]
        }

        func tearDown() {
            defaults.removePersistentDomain(forName: name)
            languageSuite.removePersistentDomain(forName: languageName)
        }

        /// Lo que hace `PreferenceSyncService.set` en `.icloud`: local, y el KV por la puerta.
        func choose(_ value: Any, _ key: String) {
            defaults.set(value, forKey: key)
            switch value {
            case let s as String: store.setString(s, forKey: key)
            case let b as Bool: store.setBool(b, forKey: key)
            case let i as Int: store.setInt(i, forKey: key)
            default: Issue.record("tipo no previsto para \(key)")
            }
        }

        /// El onboarding de la activación (`.persistOnboarding`) y la respuesta del historial, con el eje en `false`.
        func persistOnboarding() {
            choose("Luis", "userName")
            choose("PEN", "defaultCurrencyCode")
            choose("thisMonth", "defaultPeriod")
            choose(false, "expensesOnlyMode")
            choose("cashFlow", "financialMindset")
            choose(true, "includeGroupTransactionsInFeed")
            choose(3, "decimalPlaces")
            languageSuite.set("pt-BR", forKey: "appLanguageOverride")
            // `flipMasterToggleIfNeeded` en solo-grupos: el centinela en local, su espejo tragado por la puerta.
            defaults.set(true, forKey: ScheduledPaymentNotificationService.masterToggleFlipKey)
            store.setBool(true, forKey: ScheduledPaymentNotificationService.masterToggleFlipKey)
        }

        /// Las claves que el merge de producción CAMBIARÍA en local: lo que `applyRemoteValues` revertiría. Usa los
        /// mismos lectores y la misma decisión que él, sobre TODAS las claves: una ausente en local que el merge
        /// rellena con la vida anterior también es una reversión. Todas menos el consentimiento de la nube, que la
        /// subida no retira a propósito: el que el merge trae de otra vida solo es una marca de tiempo que aceptar
        /// de nuevo sobrescribe (`CloudConsentRegistrar`), y nadie lo lee para saltarse la pantalla.
        func keysTheMergeWouldRevert() -> [String] {
            PrefSyncKey.allCases.filter { !PrivateBirthKeyValueHandover.neverRemovedKeys.contains($0) }.compactMap { key in
                let local = key == .appLanguageOverride
                    ? PrivateBirthKeyValueHandover.presentValue(key, in: languageSuite)
                    : PreferenceSyncService.readLocal(key, from: defaults)
                let decision = PreferenceMergeLogic.decide(
                    key: key, remote: PreferenceSyncService.readRemote(key, from: store), local: local)
                switch decision.write {
                case .skip: return nil
                case .set(let value): return value == local ? nil : key.rawValue
                case .remove: return local == nil ? nil : key.rawValue
                }
            }
        }

        @discardableResult
        func consume(prefsByKeyValue: Bool = true) -> PrivateBirthKeyValueHandover.Outcome {
            PrivateBirthKeyValueHandover.consumeIfArmed(
                defaults: defaults, languageSuite: languageSuite, store: store,
                preferencesTravelByKeyValue: prefsByKeyValue)
        }

        /// La activación privada nueva tal como la hace `completeFullActivation`: marca, eje.
        func armAndLightTheAxis() {
            PrivateBirthKeyValueHandover.arm(defaults)
            PrivateSessionMark.set(true, defaults)
        }
    }

    // MARK: - El hueco

    /// El control que hace discriminante a todo lo demás: sin subida, lo elegido no llega y el merge lo pisa.
    @Test("el hueco: sin la subida, la puerta se traga lo elegido y el arranque siguiente lo revierte")
    func withoutHandover_theMergeRevertsTheChoice() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.persistOnboarding()
        #expect(phone.spy.writes.isEmpty, "con el eje en `false` la puerta está cerrada: nada llega al KV")

        PrivateSessionMark.set(true, phone.defaults)  // el eje, sin subida detrás
        let reverted = phone.keysTheMergeWouldRevert()
        #expect(reverted.contains("userName"), "el nombre de la vida anterior vuelve")
        #expect(reverted.contains("defaultCurrencyCode"))
        #expect(reverted.contains("appLanguageOverride"))
        #expect(phone.spy.values["userName"] as? String == "Ana")
    }

    // MARK: - La subida

    @Test("activación privada nueva: lo elegido está en el KV, y el merge de producción no revierte nada")
    func freshPrivate_handsOver_andTheNextBootKeepsIt() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.persistOnboarding()
        phone.armAndLightTheAxis()

        #expect(phone.consume() == .handedOver)
        #expect(phone.spy.values["userName"] as? String == "Luis")
        #expect(phone.spy.values["defaultCurrencyCode"] as? String == "PEN")
        #expect(phone.spy.values["defaultPeriod"] as? String == "thisMonth")
        #expect(phone.spy.values["expensesOnlyMode"] as? Bool == false)
        #expect(phone.spy.values["includeGroupTransactionsInFeed"] as? Bool == true, "la respuesta del historial")
        #expect(phone.spy.values["decimalPlaces"] as? Int64 == 3)
        #expect(phone.spy.values["appLanguageOverride"] as? String == "pt-BR", "el idioma sale de SU suite")
        #expect(phone.spy.values[ScheduledPaymentNotificationService.masterToggleFlipKey] as? Bool == true,
                "el espejo del interruptor maestro: sin él, reinstalar vuelve a voltear un OFF deliberado")
        #expect(phone.spy.synchronizeCount == 1)
        #expect(phone.keysTheMergeWouldRevert().isEmpty, "el arranque siguiente aplicaría el remoto encima")
        #expect(!PrivateBirthKeyValueHandover.isArmed(phone.defaults), "la deuda pagada no se vuelve a pagar")
        #expect(phone.consume() == .nothingOwed)
    }

    /// Una clave que falta en local es el valor por defecto de ESTE teléfono. Saltarla dejaba que el merge le trajera
    /// la de la vida anterior del Apple ID (review adversarial del 2026-09-30).
    @Test("una clave que falta en local se retira del KV, sin inventar un valor; el consentimiento no se toca")
    func absentKeys_areRemoved_butNotTheConsent() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.persistOnboarding()
        phone.armAndLightTheAxis()
        phone.consume()

        #expect(phone.spy.removals.contains("colorfulIcons"), "no la eligió nadie en este teléfono")
        #expect(phone.spy.values["colorfulIcons"] == nil)
        #expect(phone.spy.removals.contains("firstWeekday"))
        #expect(!phone.spy.writes.contains("firstWeekday"), "un entero ausente no sube como cero")
        #expect(!phone.spy.removals.contains("cloudConsentAcceptedAt"), "un registro de consentimiento no se borra")
        #expect(phone.spy.values["cloudConsentAcceptedAt"] as? Int64 == 1_700_000_000)
        #expect(Set(phone.spy.writes) == [
            "userName", "defaultCurrencyCode", "defaultPeriod", "expensesOnlyMode", "financialMindset",
            "includeGroupTransactionsInFeed", "decimalPlaces", "appLanguageOverride",
            ScheduledPaymentNotificationService.masterToggleFlipKey,
        ])
        let everythingElse = Set(PrefSyncKey.allCases.map(\.rawValue))
            .subtracting(phone.spy.writes).subtracting(PrivateBirthKeyValueHandover.neverRemovedKeys.map(\.rawValue))
        #expect(Set(phone.spy.removals) == everythingElse, "cada clave ausente, retirada")
        #expect(phone.spy.removals.count == everythingElse.count, "ninguna dos veces")
    }

    /// «Idioma del sistema» es la AUSENCIA del override, y `LanguageManager` la escribe como `removeObject`.
    @Test("sin idioma elegido en este teléfono, el del Apple ID se retira y no vuelve")
    func systemLanguage_removesTheOldOverride() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.defaults.set("Luis", forKey: "userName")
        phone.armAndLightTheAxis()
        #expect(phone.keysTheMergeWouldRevert().contains("appLanguageOverride"), "control: el alemán volvería")

        phone.consume()
        #expect(phone.spy.removals.contains("appLanguageOverride"))
        #expect(phone.keysTheMergeWouldRevert().isEmpty)
    }

    /// Las 36 claves, cada una con un valor local distinto del remoto: una lista cerrada de claves (la del onboarding)
    /// en vez de `allCases` saldría aquí, y no en los casos de ocho claves.
    @Test("todas las claves sincronizadas suben, no solo las del onboarding")
    func everyKey_travels() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        for key in PrefSyncKey.allCases {
            let domain = key == .appLanguageOverride ? phone.languageSuite : phone.defaults
            switch key.kind {
            case .string:
                domain.set("local-\(key.rawValue)", forKey: key.rawValue)
                phone.spy.values[key.rawValue] = "remoto-\(key.rawValue)"
            case .bool:
                domain.set(true, forKey: key.rawValue)
                phone.spy.values[key.rawValue] = false
            case .int:
                domain.set(7, forKey: key.rawValue)
                phone.spy.values[key.rawValue] = Int64(3)
            }
        }
        phone.armAndLightTheAxis()
        let revertible = Set(PrefSyncKey.allCases.map(\.rawValue))
            .subtracting(PrivateBirthKeyValueHandover.neverRemovedKeys.map(\.rawValue))
        #expect(Set(phone.keysTheMergeWouldRevert()) == revertible, "control: sin subir, el merge las revierte todas")

        phone.consume()
        #expect(Set(phone.spy.writes) == Set(PrefSyncKey.allCases.map(\.rawValue)))
        #expect(phone.spy.removals.isEmpty)
        #expect(phone.keysTheMergeWouldRevert().isEmpty)
    }

    /// Retirar la marca antes de escribir haría que un kill a mitad perdiera la subida para siempre.
    @Test("la marca se retira DESPUÉS de escribir: durante cada escritura sigue puesta")
    func theMarkOutlivesEveryWrite() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.persistOnboarding()
        phone.armAndLightTheAxis()
        var armedDuringWrites: [Bool] = []
        let defaults = phone.defaults
        phone.spy.onWrite = { armedDuringWrites.append(PrivateBirthKeyValueHandover.isArmed(defaults)) }

        phone.consume()
        #expect(!armedDuringWrites.isEmpty)
        #expect(armedDuringWrites.allSatisfy { $0 }, "un kill a mitad dejaría la subida sin deuda que la repita")
        #expect(!PrivateBirthKeyValueHandover.isArmed(phone.defaults))
    }

    @Test("sin el centinela del interruptor maestro en local, no se escribe su espejo")
    func masterToggle_onlyWhenFlipped() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.defaults.set("Luis", forKey: "userName")
        phone.armAndLightTheAxis()
        phone.consume()
        #expect(phone.spy.writes == ["userName"])
        #expect(phone.spy.values[ScheduledPaymentNotificationService.masterToggleFlipKey] == nil)
    }

    @Test("si las preferencias no viajan por el KV, ni suben ni se retiran; el espejo del interruptor sí")
    func cloudBehavior_skipsPreferences() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.persistOnboarding()
        phone.armAndLightTheAxis()
        #expect(phone.consume(prefsByKeyValue: false) == .handedOver)
        #expect(phone.spy.writes == [ScheduledPaymentNotificationService.masterToggleFlipKey])
        #expect(phone.spy.removals.isEmpty)
    }

    // MARK: - El kill

    /// Kill entre la marca y el eje: el arranque encuentra la deuda con la puerta cerrada. La descarta sin subir, y
    /// no queda para una Restauración posterior, donde valen las del Apple ID.
    @Test("kill antes del eje: el arranque descarta sin subir, y una Restauración posterior no sube")
    func killBeforeTheAxis_discards_andRestoreDoesNotUpload() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.persistOnboarding()
        PrivateBirthKeyValueHandover.arm(phone.defaults)

        #expect(phone.consume() == .discardedGateClosed)
        #expect(phone.spy.writes.isEmpty)
        #expect(phone.spy.removals.isEmpty)
        #expect(!PrivateBirthKeyValueHandover.isArmed(phone.defaults), "la marca no sobrevive a un arranque")

        // Restaurar después: el eje se enciende sin marca apuntada (`handsLocalStateToAppleID(.restored) == false`).
        PrivateSessionMark.set(true, phone.defaults)
        #expect(phone.consume() == .nothingOwed)
        #expect(phone.spy.writes.isEmpty, "en Restaurar no se sube nada desde este camino")
        #expect(phone.spy.removals.isEmpty)
        #expect(phone.spy.values["userName"] as? String == "Ana")
    }

    /// Kill entre el eje y la subida: el arranque siguiente, ANTES del merge, paga la deuda.
    @Test("kill entre el eje y la subida: el arranque siguiente sube antes de aplicar el remoto")
    func killAfterTheAxis_theBootHandsOver() throws {
        let phone = try Phone()
        defer { phone.tearDown() }
        phone.persistOnboarding()
        phone.armAndLightTheAxis()
        #expect(!phone.keysTheMergeWouldRevert().isEmpty, "control: sin pagar, el merge revertiría")

        #expect(phone.consume() == .handedOver)
        #expect(phone.keysTheMergeWouldRevert().isEmpty)
    }

    // MARK: - Quién sube

    @Test("solo la rama privada nueva sube; Restaurar y la nube, no")
    func onlyFreshPrivateHandsOver() {
        let summary = FullModeActivationLogic.buildSummary(
            userName: "Luis", groupCurrency: "PEN", defaultCurrency: "PEN", userCategoriesCount: 0)
        #expect(FullModeActivationFlowLogic.handsLocalStateToAppleID(.freshPrivate))
        #expect(!FullModeActivationFlowLogic.handsLocalStateToAppleID(.restored(summary)), "valen las del Apple ID")
        #expect(!FullModeActivationFlowLogic.handsLocalStateToAppleID(.freshCloud), "van al outbox del backend")
        #expect(!FullModeActivationFlowLogic.handsLocalStateToAppleID(nil), "Restaurar sin onboarding, o el legado")
    }

    @Test("el orden kill-safe del plan sigue: persistir antes de completar, en los tres recorridos")
    func commitPlan_persistsBeforeCompleting() throws {
        let summary = FullModeActivationLogic.buildSummary(
            userName: nil, groupCurrency: nil, defaultCurrency: nil, userCategoriesCount: 0)
        for source in [FullModeActivationFlowLogic.OnboardingSource.freshPrivate, .freshCloud, .restored(summary)] {
            let plan = FullModeActivationFlowLogic.commitPlan(for: source)
            let persist = try #require(plan.firstIndex(of: .persistOnboarding))
            let complete = try #require(plan.firstIndex(of: .completeActivation))
            #expect(persist < complete, "\(source): el eje encendido sin el onboarding guardado")
        }
    }

    // MARK: - El cableado

    private static let view = "Yala/App/Views/Groups/FullModeActivationView.swift"

    @Test("la marca, solo en la rama privada nueva y ANTES del eje; la subida, DESPUÉS y sin condición")
    func completeFullActivation_armsBeforeTheAxis_andPaysAfter() throws {
        let src = try Self.code(Self.view)
        let complete = try Self.body(of: "private func completeFullActivation() {", in: src)
        let gate = "if FullModeActivationFlowLogic.handsLocalStateToAppleID(pendingSource) {"
        let branch = try Self.body(of: gate, in: complete)
        #expect(branch.trimmingCharacters(in: .whitespacesAndNewlines) == "PrivateBirthKeyValueHandover.arm()",
                "la marca sin su condición subiría también en Restaurar")
        try Self.expectOrder(gate, before: "sessionState.hasPrivateSession = true", in: complete,
                             "un kill entre el eje y la marca dejaría el remoto ganando en el arranque siguiente")
        try Self.expectOrder("sessionState.hasPrivateSession = true",
                             before: "PrivateBirthKeyValueHandover.consumeIfArmed()", in: complete,
                             "con el eje apagado la puerta está cerrada: la subida se descartaría")
        #expect(Self.count("PrivateBirthKeyValueHandover.arm(", in: src) == 1,
                "otro sitio de la activación apunta la subida: en Restaurar subiría lo local encima del Apple ID")
        #expect(try Self.depth(of: "PrivateBirthKeyValueHandover.consumeIfArmed()", in: complete) == 0,
                "la subida dentro de una condición puede no correr tras encender el eje")
    }

    @Test("el arranque paga la deuda después del backfill del eje, ANTES del merge de preferencias y sin condición")
    func boot_paysBeforeTheMerge() throws {
        let boot = try Self.body(
            of: "func bootstrap(container: ModelContainer) async {",
            in: try Self.code("Yala/App/AppBootstrapper.swift"))
        let pay = "PrivateBirthKeyValueHandover.consumeIfArmed()"
        try Self.expectOrder("PrivateSessionMark.backfillIfNeeded(", before: pay, in: boot,
                             "antes del backfill, un eje ausente se leería distinto")
        try Self.expectOrder(pay, before: "PreferenceSyncService.shared.bootstrap()", in: boot,
                             "detrás del merge, las preferencias viejas del Apple ID ya habrían pisado las elegidas")
        #expect(Self.count(pay, in: boot) == 1)
        #expect(try Self.depth(of: pay, in: boot) == 0,
                "condicionada, la deuda podría quedar viva para una Restauración posterior")
    }

    /// Todos los casos de comportamiento inyectan los cuatro parámetros: sin esto, un default equivocado —el idioma
    /// de `.standard`, o `preferencesTravelByKeyValue` en `false`— dejaría a producción sin subir con todo en verde.
    @Test("los valores por defecto de consumeIfArmed son los de producción")
    func consumeIfArmed_defaultsAreProduction() throws {
        let src = try Self.normalized("Yala/Services/CloudSync/PrivateBirthKeyValueHandover.swift")
        #expect(src.contains(
            "static func consumeIfArmed( defaults: UserDefaults = .standard, "
            + "languageSuite: UserDefaults = LanguageManager.sharedDefaults, "
            + "store: OwnerKeyValueWriting = OwnerKeyValueStore.shared, "
            + "preferencesTravelByKeyValue: Bool = "
            + "PrefsSyncBehavior.resolve(storageMode: CloudSyncFlags.storageMode) == .icloudKeyValue ) -> Outcome {"
        ), "cambió la firma de producción de consumeIfArmed")
    }

    @Test("solo la activación apunta la deuda")
    func onlyTheActivationArms() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala")
        let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var writers: [String] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            guard url.lastPathComponent != "PrivateBirthKeyValueHandover.swift" else { continue }
            let text = try Self.code(at: url)
            if text.contains("PrivateBirthKeyValueHandover.arm(") || text.contains("privateBirthKeyValueHandoverPending") {
                writers.append(url.lastPathComponent)
            }
        }
        #expect(writers == ["FullModeActivationView.swift"], "otro sitio apunta la subida: \(writers)")
    }

    // MARK: - Fuente

    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try code(at: root.appendingPathComponent(path))
    }

    /// Sin líneas de comentario: documentar un invariante no puede hacer que se «cumpla».
    private static func code(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El código en una sola línea, trimmeado, para fijar una firma sin depender de la indentación.
    private static func normalized(_ path: String) throws -> String {
        try code(path)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
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
    }

    /// Cuántas llaves abiertas hay antes de `needle` dentro de un cuerpo: 0 es el nivel de la función.
    private static func depth(of needle: String, in body: String) throws -> Int {
        let at = try #require(body.range(of: needle), "no encontrado: \(needle)")
        return body[..<at.lowerBound].reduce(0) { $1 == "{" ? $0 + 1 : ($1 == "}" ? $0 - 1 : $0) }
    }

    private static func expectOrder(_ first: String, before second: String, in source: String, _ porque: String,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try #require(source.range(of: first), "no encontrado: \(first)")
        let b = try #require(source.range(of: second), "no encontrado: \(second)")
        #expect(a.lowerBound < b.lowerBound, Comment(rawValue: porque), sourceLocation: sourceLocation)
    }
}
