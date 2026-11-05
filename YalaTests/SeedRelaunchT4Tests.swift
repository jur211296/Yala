//
//  SeedRelaunchT4Tests.swift
//  YalaTests
//
//  Lote T4 de la cola 2.3: datos de prueba y relanzar. La regla de relanzamiento de `-uitest-seed`, el reset del Panel
//  que no escribía, los dos perfiles nuevos de Grupos y la cuenta «QA FX» idempotente. Los recorridos en pantalla
//  están en `SeedRelaunchT4UITests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct SeedRelaunchT4Tests {

    // MARK: - Card 3 · relanzar con la misma siembra

    @Test func reset_alwaysSeeds() {
        #expect(UITestSeedRelaunch.decide(requested: "grupos", lastSeeded: "grupos", storeHasCorpus: true, reset: true) == .seed)
    }

    @Test func emptyStore_seeds_evenWithTheMarkSet() {
        // Un almacén vaciado a mano con la marca puesta no se queda sin corpus: el guard mira el almacén.
        #expect(UITestSeedRelaunch.decide(requested: "grupos", lastSeeded: "grupos", storeHasCorpus: false, reset: false) == .seed)
    }

    @Test func sameProfileWithCorpus_doesNotSeedAgain() {
        #expect(UITestSeedRelaunch.decide(requested: "realista", lastSeeded: "realista", storeHasCorpus: true, reset: false)
            == .skipAlreadySeeded)
    }

    @Test func otherProfileWithCorpus_seedsOverAndSaysWhichWasThere() {
        #expect(UITestSeedRelaunch.decide(requested: "grupos", lastSeeded: "minimal", storeHasCorpus: true, reset: false)
            == .seedOverExisting(previous: "minimal"))
        #expect(UITestSeedRelaunch.decide(requested: "grupos", lastSeeded: nil, storeHasCorpus: true, reset: false)
            == .seedOverExisting(previous: nil))
    }

    @Test func storeHasCorpus_seesGroupsAndAccounts_butNotAnEmptyStore() throws {
        let context = try makeTestContext()
        #expect(UITestSeedRelaunch.storeHasCorpus(in: context) == false)
        context.insert(SplitGroup(name: "G", iconName: "airplane", currencyCode: "PEN", isOwner: true))
        try context.save()
        #expect(UITestSeedRelaunch.storeHasCorpus(in: context) == true)

        let other = try makeTestContext()
        _ = DevSeedAccounts.create(in: other)
        try other.save()
        #expect(UITestSeedRelaunch.storeHasCorpus(in: other) == true)
    }

    @Test func foreignCurrencyAccount_isIdempotent() throws {
        let context = try makeTestContext()
        DevSeedForeignCurrencyAccount.create(currencyCode: "JPY", subcategoryLookup: [:], in: context)
        DevSeedForeignCurrencyAccount.create(currencyCode: "JPY", subcategoryLookup: [:], in: context)
        try context.save()
        let name = DevSeedForeignCurrencyAccount.accountName
        let accounts = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.name == name }))
        #expect(accounts.count == 1, "Un segundo arranque plantó otra «QA FX».")
    }

    // MARK: - Card 4 · el reset del Panel que no escribía

    /// Lo que deja en disco una corrida anterior: los predeterminados sembrados y el centinela.
    private func defaultsWithAPreviousRun() -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: "SeedRelaunchT4Panel")
        let previous = AppPreferences(defaults: defaults)
        previous.reseedPanelDefaultsAfterDiskWipe()
        return defaults
    }

    private func wipePanelKeys(_ defaults: UserDefaults) {
        for key in AppPreferences.Keys.panelDefaultsUITestResetKeys { defaults.removeObject(forKey: key) }
    }

    /// El control que reproduce el bug: sembrar a secas sobre una copia en memoria que ya valía lo mismo no escribe.
    /// Si este caso deja de cumplirse, el arreglo de abajo sobra y hay que revisarlo.
    @Test func plainSeedOverAnUnchangedMirror_writesNothing() {
        let defaults = defaultsWithAPreviousRun()
        let prefs = AppPreferences(defaults: defaults)
        wipePanelKeys(defaults)

        prefs.setupDefaultsForNewUser()
        prefs.panelPrefsMigratedV2 = true

        #expect(defaults.string(forKey: AppPreferences.Keys.panelSectionsHidden) == nil)
        #expect(defaults.object(forKey: AppPreferences.Keys.panelPrefsMigratedV2) == nil)
    }

    @Test func reseedAfterDiskWipe_writesTheDefaultsAndTheSentinel() {
        let defaults = defaultsWithAPreviousRun()
        let prefs = AppPreferences(defaults: defaults)
        wipePanelKeys(defaults)

        prefs.reseedPanelDefaultsAfterDiskWipe()

        #expect(defaults.string(forKey: AppPreferences.Keys.panelSectionsHidden)
            == PanelDefaults.hiddenSectionRawValues.joined(separator: ","))
        #expect(defaults.bool(forKey: AppPreferences.Keys.panelPrefsMigratedV2) == true)
        #expect(prefs.panelSectionsHidden == PanelDefaults.hiddenSectionRawValues)
    }

    /// El arranque siguiente sin reset: con el blob de tamaños en disco (lo escribe el Panel), la migración ya no toma
    /// la rama de actualización y las secciones ocultas siguen ocultas.
    @Test func nextLaunchWithoutReset_keepsTheNewUserSections() throws {
        let defaults = defaultsWithAPreviousRun()
        let prefs = AppPreferences(defaults: defaults)
        wipePanelKeys(defaults)
        prefs.reseedPanelDefaultsAfterDiskWipe()
        let blob = try JSONEncoder().encode([WidgetConfig(id: UUID(), type: .trend, isVisible: true, size: .medium)])
        defaults.set(blob, forKey: PanelPreferencesMigration.legacyKey)

        let relaunched = AppPreferences(defaults: defaults)

        #expect(relaunched.resolvedSectionsHidden == PanelDefaults.hiddenSectionRawValues)
    }

    // MARK: - Cards 1 y 2 · perfiles nuevos de Grupos

    @Test func heirProfile_identifiesCoMembers_andNeverMe() throws {
        let context = try makeTestContext()
        DevSeedGroups.create(in: context, identifiedCoMembers: true)
        let members = try context.fetch(FetchDescriptor<SplitMember>())
        let others = members.filter { !$0.isCurrentUser }
        #expect(!others.isEmpty)
        #expect(others.allSatisfy { $0.userID != nil && $0.memberKey != nil })
        #expect(members.filter(\.isCurrentUser).allSatisfy { $0.userID == nil && $0.memberKey == nil })
    }

    @Test func groupsProfile_keepsCoMembersWithoutIdentity() throws {
        let context = try makeTestContext()
        DevSeedGroups.create(in: context)
        let members = try context.fetch(FetchDescriptor<SplitMember>())
        #expect(members.allSatisfy { $0.userID == nil && $0.memberKey == nil })
    }

    @Test func rejectedProfile_leavesMeRejected_andWithoutTheFlag() throws {
        let context = try makeTestContext()
        DevSeedGroups.createAsRejectedMember(in: context)
        let members = try context.fetch(FetchDescriptor<SplitMember>())
        let me = try #require(members.first { $0.cloudKitUserRecordID == "uitest-current-user" })
        #expect(me.memberStatus == .rejected)
        #expect(me.isCurrentUser == false)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
    }

    @Test func newProfiles_parseAndSeedGroups() {
        #expect(DevSeedProfile(rawValue: "grupos-con-heredero") == .gruposConHeredero)
        #expect(DevSeedProfile(rawValue: "grupos-rechazado") == .gruposRechazado)
        #expect(DevSeedProfile.gruposConHeredero.seedsGroups)
        #expect(DevSeedProfile.gruposRechazado.seedsGroups)
    }
}
