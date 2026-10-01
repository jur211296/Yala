//
//  GroupsOnlySignUpPreferenceResetTests.swift
//  YalaTests / Groups
//
//  Ticket `neutral-boot-hands-owner-prefs-to-whoever-signs-in-next`.
//
//  Tras «Cerrar sesión», el arranque neutro aplica las 36 preferencias del iCloud-KV del Apple ID —tiene que
//  hacerlo: es de donde «Restaurar» saca el nombre—, y quien entra después por un grupo se las encontraba en
//  local. El arreglo las reinicia al EMPEZAR cada alta solo-grupos, que es el instante en que se sabe que la
//  sesión no es del Apple ID.
//
//  Cuatro suites, y ninguna cubre a las otras (`-only-testing` filtra por TIPO: pídelas las cuatro):
//   (1) el alta del organizador, de punta a punta sobre stores aislados — la medición del ticket;
//   (2) la mitad de los ALMACENES (`removeLocal`): qué quita, dónde, y qué NO toca;
//   (3) la mitad de las COPIAS: el espejo de `AppPreferences` vuelve a fábrica sin escribir;
//   (4) el cableado: las dos puertas, el orden y el censo, porque la invitación vive en una vista.
//

import Foundation
import Testing

@testable import Yala

// MARK: - El escenario: un teléfono tras el arranque neutro

/// Lo que deja `PreferenceSyncService.bootstrap()` en local tras el arranque neutro: las 36 del dueño, con
/// valores que no coinciden con ningún default. El idioma va a su suite y no a `.standard`, porque ahí lo
/// escribe el merge (`applyMergeDecision`) y ahí lo lee la app.
@MainActor
private func seedOwnerPreferences(standard: UserDefaults, language: UserDefaults) {
    for key in PrefSyncKey.allCases {
        let k = key.rawValue
        if key == .appLanguageOverride {
            language.set("de", forKey: k)
            continue
        }
        switch key.kind {
        case .string: standard.set("owner-\(k)", forKey: k)
        case .bool:   standard.set(true, forKey: k)
        case .int:    standard.set(7, forKey: k)
        }
    }
}

/// Las del dueño que siguen en local: por presencia, que es como las mira el merge y como las mira el
/// inventario de lo que sube `PrivateBirthKeyValueHandover`.
private func syncedKeysPresent(standard: UserDefaults, language: UserDefaults) -> [String] {
    PrefSyncKey.allCases.compactMap { key in
        let store = key == .appLanguageOverride ? language : standard
        return store.object(forKey: key.rawValue) != nil ? key.rawValue : nil
    }
}

// MARK: - (1) La medición: el alta del organizador

@Suite("solo-grupos · el alta del organizador no hereda las preferencias del dueño")
@MainActor
struct GroupsOnlySignUpOrganizerInheritanceTests {

    @Test("tras el alta del organizador no queda ninguna de las 36 del dueño, salvo lo que el alta escribe")
    func organizerSignUp_leavesNoOwnerPreference() {
        let standard = makeIsolatedDefaults(prefix: "neutral.organizer.std")
        let language = makeIsolatedDefaults(prefix: "neutral.organizer.lang")
        seedOwnerPreferences(standard: standard, language: language)
        // CONTROL: el escenario siembra las 36. Sin él, «no queda ninguna» pasaría con una siembra rota.
        #expect(syncedKeysPresent(standard: standard, language: language).count == PrefSyncKey.allCases.count)
        let writer = OwnerSeededSpyWriter(defaults: standard, language: language)

        GroupsOrganizerOnboarding.writePreferences(
            displayName: "Ana", writer: writer, regionCode: "US", defaults: standard)

        // Las tres que el alta escribe A PROPÓSITO están, con el valor de quien entra.
        #expect(standard.string(forKey: PrefSyncKey.userName.rawValue) == "Ana")
        #expect(standard.string(forKey: PrefSyncKey.defaultPeriod.rawValue) == DetailPeriod.thisMonth.rawValue)
        #expect(standard.string(forKey: PrefSyncKey.defaultCurrencyCode.rawValue) == CurrencyCode.usd.rawValue,
                "la divisa del organizador sigue siendo la del dueño, no la de su región")

        // Lo que se queda a propósito: las tres que el alta escribe y el consentimiento de la nube, que ningún camino
        // borra (`GroupsOnlySignUpPreferenceReset.keptConsentKeys`).
        let written = Set([
            PrefSyncKey.userName.rawValue, PrefSyncKey.defaultPeriod.rawValue,
            PrefSyncKey.defaultCurrencyCode.rawValue
        ]).union(GroupsOnlySignUpPreferenceReset.keptConsentKeys.map(\.rawValue))
        let left = syncedKeysPresent(standard: standard, language: language).filter { !written.contains($0) }
        #expect(left.isEmpty, "el organizador hereda del dueño: \(left)")
    }

    /// El ORDEN, contado y no inferido del estado final: un reset DESPUÉS de las escrituras se llevaría el nombre
    /// y la divisa, y uno ANTES del arm correría con la puerta del KV abierta.
    @Test("el reset va después del arm y antes de la primera escritura del alta")
    func organizerSignUp_resetsBetweenTheArmAndTheFirstWrite() {
        let standard = makeIsolatedDefaults(prefix: "neutral.organizer.order")
        let language = makeIsolatedDefaults(prefix: "neutral.organizer.order.lang")
        let writer = OwnerSeededSpyWriter(defaults: standard, language: language)

        GroupsOrganizerOnboarding.writePreferences(
            displayName: "Ana", writer: writer, regionCode: "US", defaults: standard)

        #expect(writer.events.first == "reset", "el alta escribió antes de retirar lo del dueño: \(writer.events)")
        #expect(writer.events.filter { $0 == "reset" }.count == 1)
        #expect(writer.armedAtReset == true, "el reset corrió sin el neutro armado: la puerta del KV seguía abierta")
    }
}

// MARK: - (2) La mitad de los almacenes

@Suite("solo-grupos · el reset retira en local lo sincronizado, y nada más")
@MainActor
struct GroupsOnlySignUpPreferenceRemovalTests {

    private func stores(_ prefix: String) -> GroupsOnlySignUpPreferenceReset.Stores {
        .init(standard: makeIsolatedDefaults(prefix: "\(prefix).std"),
              language: makeIsolatedDefaults(prefix: "\(prefix).lang"),
              appGroup: makeIsolatedDefaults(prefix: "\(prefix).group"))
    }

    @Test("quita las 36 menos el consentimiento, cada una de donde vive —el idioma de su suite—, y devuelve las que estaban")
    func removesTheThirtySixWhereTheyLive() {
        let s = stores("reset.36")
        seedOwnerPreferences(standard: s.standard, language: s.language)
        // Un idioma en `.standard` NO es el idioma: el reset no tiene por qué verlo, y quitarlo de ahí en vez de
        // la suite sería el mutante que deja la app en el idioma del dueño.
        s.standard.set("fr", forKey: PrefSyncKey.appLanguageOverride.rawValue)

        let removed = GroupsOnlySignUpPreferenceReset.removeLocal(from: s)

        #expect(removed == Set(PrefSyncKey.allCases).subtracting(GroupsOnlySignUpPreferenceReset.keptConsentKeys))
        #expect(Set(syncedKeysPresent(standard: s.standard, language: s.language))
                == Set(GroupsOnlySignUpPreferenceReset.keptConsentKeys.map(\.rawValue)))
        #expect(s.language.object(forKey: PrefSyncKey.appLanguageOverride.rawValue) == nil)
        #expect(s.standard.string(forKey: PrefSyncKey.appLanguageOverride.rawValue) == "fr",
                "el reset quitó el idioma de `.standard`, que no es donde vive")
    }

    /// La PRESENCIA del idioma también se mira en su suite: es lo que decide avisar con `languageDidChange`. Mirada
    /// en `.standard`, el override del dueño se quitaba sin aviso y la app seguía en su idioma hasta relanzar.
    @Test("el idioma cuenta como presente si está en su suite, aunque `.standard` no lo tenga")
    func reportsTheLanguageFromItsOwnSuite() {
        let s = stores("reset.lang")
        s.language.set("de", forKey: PrefSyncKey.appLanguageOverride.rawValue)

        let removed = GroupsOnlySignUpPreferenceReset.removeLocal(from: s)

        #expect(removed == [.appLanguageOverride])
        #expect(s.language.object(forKey: PrefSyncKey.appLanguageOverride.rawValue) == nil)
    }

    /// El consentimiento de la nube puede ser de quien entra: «Primera vez → nube» lo registra al aceptar y, si la
    /// cuenta resulta ser solo de grupos, acaba en el alta del organizador. Ningún camino lo borra.
    @Test("el consentimiento de la nube se queda")
    func keepsTheCloudConsent() {
        let s = stores("reset.consent")
        s.standard.set(1_700_000_000, forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue)
        s.standard.set(2, forKey: PrefSyncKey.cloudConsentTextVersion.rawValue)

        let removed = GroupsOnlySignUpPreferenceReset.removeLocal(from: s)

        #expect(removed.isEmpty)
        #expect(s.standard.integer(forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue) == 1_700_000_000)
        #expect(s.standard.integer(forKey: PrefSyncKey.cloudConsentTextVersion.rawValue) == 2)
        #expect(GroupsOnlySignUpPreferenceReset.keptConsentKeys == PrivateBirthKeyValueHandover.neverRemovedKeys)
    }

    @Test("lo que no estaba no sale en el resultado: el idioma solo avisa si había override")
    func reportsOnlyWhatWasPresent() {
        let s = stores("reset.partial")
        s.standard.set(3, forKey: PrefSyncKey.decimalPlaces.rawValue)

        let removed = GroupsOnlySignUpPreferenceReset.removeLocal(from: s)

        #expect(removed == [.decimalPlaces])
        #expect(!removed.contains(.appLanguageOverride))
    }

    @Test("el centinela del Panel y los espejos de los widgets se van con sus keys")
    func removesThePanelSentinelAndTheWidgetMirrors() {
        let s = stores("reset.mirrors")
        s.standard.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        s.appGroup?.set(true, forKey: AppPreferences.Keys.expensesOnlyMode)
        s.appGroup?.set(1, forKey: "firstWeekday")
        s.appGroup?.set("lastMonth", forKey: "defaultPeriod")

        GroupsOnlySignUpPreferenceReset.removeLocal(from: s)

        #expect(s.standard.object(forKey: AppPreferences.Keys.panelPrefsMigratedV2) == nil)
        #expect(s.appGroup?.object(forKey: AppPreferences.Keys.expensesOnlyMode) == nil)
        #expect(s.appGroup?.object(forKey: "firstWeekday") == nil)
        #expect(s.appGroup?.object(forKey: "defaultPeriod") == nil, "el widget sigue con el periodo del dueño")
    }

    /// Lo que el alta acaba de escribir —o el dispositivo decide— no es del dueño: el neutro que arma la primera
    /// línea del alta (si el reset se lo llevara, el arranque siguiente montaría el espejo) y lo per-device.
    @Test("no toca el neutro recién armado ni lo per-device")
    func leavesTheNeutralMountAndPerDeviceKeys() {
        let s = stores("reset.untouched")
        StorageModePersistence.armGroupsOnlyNeutralMount(s.standard)
        s.standard.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        s.standard.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        s.standard.set(true, forKey: AppPreferences.Keys.hasShownGroupsOnboarding)

        GroupsOnlySignUpPreferenceReset.removeLocal(from: s)

        #expect(StorageModePersistence.isGroupsOnlyNeutralMountArmed(s.standard))
        #expect(s.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding))
        #expect(s.standard.bool(forKey: AppPreferences.Keys.groupsBetaUnlocked))
        #expect(s.standard.bool(forKey: AppPreferences.Keys.hasShownGroupsOnboarding))
    }
}

// MARK: - (3) La mitad de las copias en memoria

/// `AppPreferences` relee por PRESENCIA: quitar la key deja la propiedad como estaba. El reset del espejo es lo
/// que la devuelve a fábrica, y fábrica se mide contra una instancia recién construida sobre un store vacío —no
/// contra literales copiados aquí, que divergirían en silencio de la declaración—.
@Suite("solo-grupos · el espejo de AppPreferences vuelve a fábrica sin escribir")
@MainActor
struct AppPreferencesSyncedMirrorResetTests {

    /// Cada key sincronizada con copia en `AppPreferences`, leída como valor comparable. Las cuatro de fuera tienen
    /// su copia en otro sitio o ninguna, y se declaran: si entra una key 37, este test exige decidir dónde vive.
    private static let mirrored: [PrefSyncKey: @MainActor (AppPreferences) -> AnyHashable] = [
        .defaultCurrencyCode: { $0.defaultCurrencyCode },
        .userName: { $0.userName },
        .defaultPeriod: { $0.defaultPeriod },
        .secondaryCurrencies: { $0.secondaryCurrencies },
        .userProfileIcon: { $0.userProfileIcon },
        .currencyDisplayFormat: { $0.currencyDisplayFormat },
        .voiceLanguage: { $0.voiceLanguage },
        .autoFocusField: { $0.autoFocusField },
        .accountsSortOrderNames: { $0.accountsSortOrderNames },
        .insightsTone: { $0.insightsTone },
        .insightsFocus: { $0.insightsFocus },
        .panelTendenciasOrder: { $0.panelTendenciasOrder },
        .panelTendenciasHidden: { $0.panelTendenciasHidden },
        .panelDistribucionOrder: { $0.panelDistribucionOrder },
        .panelDistribucionHidden: { $0.panelDistribucionHidden },
        .panelPlanificacionOrder: { $0.panelPlanificacionOrder },
        .panelPlanificacionHidden: { $0.panelPlanificacionHidden },
        .panelSectionsHidden: { $0.panelSectionsHidden },
        .panelSectionsOrder: { $0.panelSectionsOrder },
        .budgetAlertsEnabled: { $0.budgetAlertsEnabled },
        .expensesOnlyMode: { $0.expensesOnlyMode },
        .colorfulIcons: { $0.colorfulIcons },
        .showVariations: { $0.showVariations },
        .panelAccountsCollapsed: { $0.panelAccountsCollapsed },
        .includeGroupTransactionsInFeed: { $0.includeGroupTransactionsInFeed },
        .includeGroupsInPanelTotal: { $0.includeGroupsInPanelTotal },
        .includeGroupTransactionsInStats: { $0.includeGroupTransactionsInStats },
        .bridgeGroupExpensesToPersonalAccounts: { $0.bridgeGroupExpensesToPersonalAccounts },
        .groupSettlementRemindersEnabled: { $0.groupSettlementRemindersEnabled },
        .firstWeekday: { $0.firstWeekday },
        .decimalPlaces: { $0.decimalPlaces },
        .averageLineMode: { $0.averageLineMode },
    ]

    /// `financialMindset` vive en `SessionState`; el idioma, en `LanguageManager`; el consentimiento de la nube no
    /// tiene copia en memoria.
    private static let mirroredElsewhere: Set<PrefSyncKey> = [
        .financialMindset, .appLanguageOverride, .cloudConsentAcceptedAt, .cloudConsentTextVersion
    ]

    /// Un valor de dueño por key, válido para su tipo y distinto del de fábrica.
    private static func seedOwnerValues(_ d: UserDefaults) {
        d.set(CurrencyCode.eur.rawValue, forKey: AppPreferences.Keys.defaultCurrencyCode)
        d.set("Dueño", forKey: AppPreferences.Keys.userName)
        d.set(DetailPeriod.allCases.first { $0 != .thisMonth }?.rawValue, forKey: AppPreferences.Keys.defaultPeriod)
        d.set("USD,GBP", forKey: AppPreferences.Keys.secondaryCurrencies)
        d.set("star.fill", forKey: AppPreferences.Keys.userProfileIcon)
        d.set(CurrencyDisplayFormat.code.rawValue, forKey: AppPreferences.Keys.currencyDisplayFormat)
        d.set(VoiceLanguage.allCases.first { $0 != .system }?.rawValue, forKey: AppPreferences.Keys.voiceLanguage)
        d.set(AutoFocusField.amount.rawValue, forKey: AppPreferences.Keys.autoFocusField)
        d.set("Ahorros|Corriente", forKey: AppPreferences.Keys.accountsSortOrderNames)
        d.set(InsightTone.allCases.first { $0 != .normal }?.rawValue, forKey: AppPreferences.Keys.insightsTone)
        d.set(InsightFocus.allCases.first { $0 != .balanced }?.rawValue, forKey: AppPreferences.Keys.insightsFocus)
        for key in [AppPreferences.Keys.panelTendenciasOrder, AppPreferences.Keys.panelTendenciasHidden,
                    AppPreferences.Keys.panelDistribucionOrder, AppPreferences.Keys.panelDistribucionHidden,
                    AppPreferences.Keys.panelPlanificacionOrder, AppPreferences.Keys.panelPlanificacionHidden,
                    AppPreferences.Keys.panelSectionsHidden, AppPreferences.Keys.panelSectionsOrder] {
            d.set("a,b", forKey: key)
        }
        d.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        d.set(true, forKey: AppPreferences.Keys.budgetAlertsEnabled)
        d.set(true, forKey: AppPreferences.Keys.expensesOnlyMode)
        d.set(false, forKey: AppPreferences.Keys.colorfulIcons)
        d.set(false, forKey: AppPreferences.Keys.showVariations)
        d.set(false, forKey: AppPreferences.Keys.panelAccountsCollapsed)
        d.set(false, forKey: AppPreferences.Keys.includeGroupTransactionsInFeed)
        d.set(false, forKey: AppPreferences.Keys.includeGroupsInPanelTotal)
        d.set(false, forKey: AppPreferences.Keys.includeGroupTransactionsInStats)
        d.set(false, forKey: AppPreferences.Keys.bridgeGroupExpensesToPersonalAccounts)
        d.set(true, forKey: AppPreferences.Keys.groupSettlementRemindersEnabled)
        d.set(FirstWeekday.sunday.rawValue, forKey: AppPreferences.Keys.firstWeekday)
        d.set(0, forKey: AppPreferences.Keys.decimalPlaces)
        d.set(0, forKey: AppPreferences.Keys.averageLineMode)
    }

    @Test("la tabla cubre las 36: cada key sincronizada tiene su copia aquí o declara dónde vive")
    func theTableCoversEverySyncedKey() {
        #expect(Set(Self.mirrored.keys).isDisjoint(with: Self.mirroredElsewhere))
        #expect(Set(Self.mirrored.keys).union(Self.mirroredElsewhere) == Set(PrefSyncKey.allCases),
                "hay una key sincronizada sin decidir dónde vive su copia en memoria")
    }

    @Test("cada propiedad sincronizada —y el centinela del Panel— vuelve al valor de una instancia nueva")
    func everySyncedPropertyReturnsToFactory() {
        // La instancia de fábrica nace con el centinela del Panel puesto: sin él, el `init` corre la siembra del
        // Panel (y la siembra escribe por el canal sincronizado, en el `.standard` del simulador). Lo que se quiere
        // de ella es el valor DECLARADO de cada propiedad, no el sembrado.
        let factoryDefaults = makeIsolatedDefaults(prefix: "mirror.factory")
        factoryDefaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        let factory = AppPreferences(defaults: factoryDefaults)
        let ownerDefaults = makeIsolatedDefaults(prefix: "mirror.owner")
        Self.seedOwnerValues(ownerDefaults)
        let owner = AppPreferences(defaults: ownerDefaults)

        // CONTROL: el dueño difiere de fábrica en TODAS. Sin esto, una key que el seed no movió pasaría sola.
        for (key, read) in Self.mirrored {
            #expect(read(owner) != read(factory), "el seed no movió \(key.rawValue): el caso no mide nada")
        }
        #expect(owner.panelPrefsMigratedV2)

        owner.resetSyncedMirrorToFactoryDefaults()

        for (key, read) in Self.mirrored {
            #expect(read(owner) == read(factory), "\(key.rawValue) se quedó con el valor del dueño")
        }
        // El centinela vuelve a «sin sembrar», como en una instalación nueva: con las listas vacías y el centinela
        // puesto el Panel leería «enséñalo todo» en vez del curado.
        #expect(!owner.panelPrefsMigratedV2)
    }

    /// Cargar no escribe, y devolver a fábrica tampoco: un `persist*` aquí empujaría los valores de fábrica al
    /// canal de preferencias como si alguien los hubiera elegido.
    @Test("el reset del espejo no escribe en su store")
    func theMirrorResetDoesNotWrite() {
        let ownerDefaults = makeIsolatedDefaults(prefix: "mirror.nowrite")
        Self.seedOwnerValues(ownerDefaults)
        let owner = AppPreferences(defaults: ownerDefaults)
        let before = ownerDefaults.dictionaryRepresentation().filter { Self.isSeeded($0.key) }

        owner.resetSyncedMirrorToFactoryDefaults()

        let after = ownerDefaults.dictionaryRepresentation().filter { Self.isSeeded($0.key) }
        #expect(NSDictionary(dictionary: before).isEqual(to: after), "el reset del espejo escribió en el store")
    }

    private static func isSeeded(_ key: String) -> Bool {
        PrefSyncKey(rawValue: key) != nil || key == AppPreferences.Keys.panelPrefsMigratedV2
    }
}

// MARK: - (4) El cableado

/// La invitación vive en una vista privada y el reset de producción toca el proceso vivo: lo que queda por fijar
/// es dónde se llama, en qué orden y desde cuántos sitios. El comportamiento lo fijan las tres suites de arriba.
@Suite("solo-grupos · las dos puertas llaman al reset, en orden, y nadie más")
@MainActor
struct GroupsOnlySignUpPreferenceResetWiringTests {

    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de una función: desde su firma hasta la siguiente declaración del mismo nivel.
    private static func body(of signature: String, in code: String, nextDeclaration: String) throws -> String {
        let tail = try #require(code.components(separatedBy: signature).dropFirst().first,
                                "no encuentro `\(signature)`")
        return try #require(tail.components(separatedBy: nextDeclaration).first)
    }

    /// Las líneas de CÓDIGO de un cuerpo, recortadas y sin vacías: los comentarios `//` ya los quitó `code`.
    private static func codeLines(_ body: String) -> [String] {
        body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// La sentencia de código que sigue a `line`. Fijar la ADYACENCIA, y no solo el orden por offsets, es lo que caza
    /// un envoltorio: `Task { … }`, `DispatchQueue.main.async { … }`, `if … { … }` o `#if false` alrededor dejan
    /// otra línea en medio.
    private static func line(after line: String, in body: String) throws -> String {
        let lines = codeLines(body)
        let i = try #require(lines.firstIndex(of: line), "no encuentro `\(line)`")
        return try #require(lines.indices.contains(i + 1) ? lines[i + 1] : nil)
    }

    private static func offset(of needle: String, in haystack: String) -> Int? {
        haystack.range(of: needle).map { haystack.distance(from: haystack.startIndex, to: $0.lowerBound) }
    }

    private static let inviteView = "Yala/App/Views/Groups/GroupInviteOnboardingView.swift"
    private static let organizer = "Yala/Services/Groups/GroupsOrganizerOnboarding.swift"
    private static let reset = "Yala/Services/Groups/GroupsOnlySignUpPreferenceReset.swift"

    @Test("invitación: arm → reset → primera escritura, y una sola vez")
    func inviteSignUp_resetsBetweenTheArmAndTheFirstWrite() throws {
        let body = try Self.body(of: "private func performSilentSetup() {",
                                 in: try Self.code(Self.inviteView), nextDeclaration: "\n    private func ")
        #expect(try Self.line(after: "StorageModePersistence.armGroupsOnlyNeutralMount()", in: body)
                == "GroupsOnlySignUpPreferenceReset.resetLive()",
                "el reset no va justo detrás del arm, o va envuelto (una tarea aparte correría tras las escrituras)")
        let arm = try #require(Self.offset(of: "StorageModePersistence.armGroupsOnlyNeutralMount()", in: body))
        let reset = try #require(Self.offset(of: "GroupsOnlySignUpPreferenceReset.resetLive()", in: body),
                                 "el alta del invitado ya no retira lo del dueño")
        let firstWrite = try #require(Self.offset(of: "sync.set(", in: body))
        let shownFlag = try #require(Self.offset(of: "AppPreferences.Keys.hasShownGroupsOnboarding", in: body))

        #expect(arm < reset, "el reset corre con la puerta del KV abierta")
        #expect(reset < firstWrite, "el reset se lleva el nombre, la divisa o el periodo del invitado")
        #expect(reset < shownFlag)
        #expect(body.components(separatedBy: "GroupsOnlySignUpPreferenceReset.").count == 2)
    }

    @Test("invitación: quien ya tiene cuenta NO pasa por el reset")
    func joinOnly_doesNotReset() throws {
        let body = try Self.body(of: "private func performJoinOnlySetup() {",
                                 in: try Self.code(Self.inviteView), nextDeclaration: "\n    private func ")
        #expect(!body.contains("GroupsOnlySignUpPreferenceReset"), """
            el CTA de quien ya tiene cuenta borra sus preferencias: esas SON suyas, no del dueño de nadie.
            """)
    }

    @Test("invitación: el nombre del perfil solo se siembra a quien ya tiene cuenta")
    func inviteNameSeed_onlyForWhoeverAlreadyHasAnAccount() throws {
        let body = try Self.body(of: "private func seedNameFromProfileIfNeeded() {",
                                 in: try Self.code(Self.inviteView), nextDeclaration: "\n    private func ")
        // El cuerpo entero: un `if` o un `||` alrededor del guard pasarían un scan por orden.
        #expect(Self.codeLines(body) == [
            "guard !didSeedName else { return }",
            "didSeedName = true",
            "guard hasCompletedOnboarding else { return }",
            "guard userName.isEmpty else { return }",
            "userName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)",
            "}",
        ], "el invitado fresco vuelve a ver el nombre del dueño en el campo")
    }

    @Test("organizador: arm → reset del writer → primera escritura")
    func organizerSignUp_wiresTheResetThroughTheWriter() throws {
        let code = try Self.code(Self.organizer)
        let body = try Self.body(of: "static func writePreferences(", in: code, nextDeclaration: "\n    static func ")
        #expect(try Self.line(after: "StorageModePersistence.armGroupsOnlyNeutralMount(defaults)", in: body)
                == "writer.resetSyncedPreferences()")
        let reset = try #require(Self.offset(of: "writer.resetSyncedPreferences()", in: body))
        let firstWrite = try #require(Self.offset(of: "writer.setSynced(", in: body))
        #expect(reset < firstWrite)

        // El writer de producción llama al reset ENTERO (almacenes y copias), y nada más.
        let live = try Self.body(of: "func resetSyncedPreferences() {", in: code, nextDeclaration: "\n    }")
        #expect(Self.codeLines(live) == ["GroupsOnlySignUpPreferenceReset.resetLive()"])
    }

    /// El censo: el reset se llama desde las dos altas solo-grupos y desde ningún otro sitio. Restaurar y el alta
    /// personal SIGUEN aplicando el iCloud-KV —esa es la mitad de la decisión—, y un tercer llamador aquí sería
    /// el arreglo colándose en el camino que tenía que dejar intacto.
    @Test("censo: dos llamadores de producción, ninguno en Restaurar ni en el alta personal")
    func census_onlyTheTwoGroupsOnlySignUps() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let yala = root.appendingPathComponent("Yala")
        let files = try #require(FileManager.default.enumerator(at: yala, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        var callers: [String] = []
        for file in files {
            let relative = String(file.path.dropFirst(root.path.count + 1))
            guard relative != Self.reset else { continue }
            let code = try Self.code(relative)
            // Cualquier entrada al tipo —`resetLive`, `removeLocal`, `Stores.live`— y cualquier llamada al reset del
            // writer: un tercer camino no tiene por qué llamarlo con el mismo literal.
            if code.contains("GroupsOnlySignUpPreferenceReset.") { callers.append(relative) }
            if relative != Self.organizer, code.contains(".resetSyncedPreferences()") { callers.append(relative) }
        }
        #expect(callers.sorted() == [Self.inviteView, Self.organizer].sorted(), "llamadores del reset: \(callers)")
        // Y dentro del organizador, el reset del writer se llama una vez: desde `writePreferences`.
        let organizer = try Self.code(Self.organizer)
        #expect(organizer.components(separatedBy: "writer.resetSyncedPreferences()").count == 2)
        #expect(organizer.components(separatedBy: ".resetSyncedPreferences()").count == 2)
    }

    /// El cuerpo ENTERO, en orden: las copias que escriben al asignarse van ANTES de quitar las keys (si no, dejan
    /// la key puesta), y las que no escriben DESPUÉS. Un scan por orden dejaba pasar condiciones invertidas, un bloque
    /// asíncrono o una línea borrada (la recarga de widgets no la miraba nadie).
    @Test("resetLive: copias que escriben → almacenes → copias que no escriben, sentencia a sentencia")
    func resetLive_wholeBody() throws {
        let body = try Self.body(of: "static func resetLive() {", in: try Self.code(Self.reset),
                                 nextDeclaration: "\n    }\n")
        let lines = Self.codeLines(body).filter { !$0.hasPrefix("#if") && !$0.hasPrefix("#endif") && !$0.hasPrefix("print(") }
        #expect(lines == [
            "let session = SessionState.shared",
            "if session.isExpensesOnlyMode { session.isExpensesOnlyMode = false }",
            "session.financialMindset = SessionState.defaultFinancialMindset",
            "let removed = removeLocal(from: .live)",
            "AppBootstrapper.shared.appPreferences.resetSyncedMirrorToFactoryDefaults()",
            "session.formattingVersion += 1",
            "if removed.contains(.appLanguageOverride) {",
            "NotificationCenter.default.post(name: .languageDidChange, object: nil)",
            "}",
            "WidgetCenter.shared.reloadAllTimelines()",
        ], "el reset de producción cambió: \(lines)")
    }

    /// Los almacenes de producción: el idioma en la suite del App Group (la de `LanguageManager`), no en `.standard`.
    @Test("Stores.live apunta a los almacenes reales de cada key")
    func liveStores() throws {
        let body = try Self.body(of: "static var live: Stores {", in: try Self.code(Self.reset),
                                 nextDeclaration: "\n        }")
        #expect(Self.codeLines(body).joined(separator: " ") == """
            Stores(standard: .standard, language: LanguageManager.sharedDefaults, \
            appGroup: UserDefaults(suiteName: SharedContainerService.appGroupIdentifier))
            """)
    }

    /// La mitad que la decisión NO toca: sin ninguna marca, la puerta del iCloud-KV sigue abierta en el arranque
    /// neutro. Cerrarla rompería «Restaurar» (el nombre de `isFullyPrefilled` llega por ahí) y el alta personal.
    @Test("la puerta del iCloud-KV sigue abierta en el arranque neutro, y cerrada con el alta solo-grupos empezada")
    func theNeutralBootGateStaysOpen() {
        #expect(OwnerKeyValueGate.decide(groupsOnlySessionStarted: false, hasPrivateSession: true,
                                         confirmedPrivateSession: false) == .open)
        #expect(OwnerKeyValueGate.decide(groupsOnlySessionStarted: true, hasPrivateSession: true,
                                         confirmedPrivateSession: false) == .closed)
    }
}

// MARK: - Doble del canal de escritura

/// El espía del alta, sobre los MISMOS stores sembrados. Su reset es la mitad de los almacenes de producción
/// (`removeLocal`), así que lo que se mide es el código real; lo que no ejerce son las copias en memoria, que fija
/// la suite (3).
@MainActor
private final class OwnerSeededSpyWriter: GroupsOrganizerPreferenceWriting {
    let defaults: UserDefaults
    let language: UserDefaults
    private(set) var events: [String] = []
    private(set) var armedAtReset: Bool?

    init(defaults: UserDefaults, language: UserDefaults) {
        self.defaults = defaults
        self.language = language
    }

    func setSynced(_ value: String, forKey key: String) {
        events.append(key)
        defaults.set(value, forKey: key)
    }

    func setLocal(_ value: Bool, forKey key: String) {
        events.append(key)
        defaults.set(value, forKey: key)
    }

    func resetSyncedPreferences() {
        events.append("reset")
        armedAtReset = StorageModePersistence.isGroupsOnlyNeutralMountArmed(defaults)
        GroupsOnlySignUpPreferenceReset.removeLocal(from: .init(standard: defaults, language: language, appGroup: nil))
    }
}
