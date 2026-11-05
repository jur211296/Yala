//
//  WelcomeNeutralMountUntilChosenTests.swift
//  YalaTests / CloudSync
//
//  Lote N1 de la 2.3 (bienvenida), dos cards que se cierran juntas porque comparten el montaje:
//   · zlbn — «Cerrar Yala en la bienvenida antes de elegir hace que el siguiente arranque baje tu iCloud privado».
//     Decisión de Jürgen del 2026-10-26: el montaje neutro dura hasta que se elija, no un arranque.
//   · z5dd — «Volver atrás desde el acceso a la nube deja el Welcome como ya elegido, y si la app se cierra ahí se salta
//     la comprobación de iCloud». El «Volver» devuelve el chooser a «no elegido».
//
//  Bajo `-uitest` cada arranque purga `hasShownWelcomeChooser` (`UITestEphemeralDefaults.applyOnboardingAlreadySeen`) y
//  el store es otro, así que un XCUITest que relance no puede ver ninguna de las dos: aquí se simula el arranque con las
//  mismas funciones puras que usa `SwiftDataConfiguration.personalConfiguration`, y el cableado se fija por source-scan.
//

import Foundation
import Testing

@testable import Yala

@Suite("Bienvenida · el montaje neutro dura hasta que se elija")
struct WelcomeNeutralMountUntilChosenTests {

    private typealias Mount = SwiftDataConfiguration.PersonalStoreDecision

    /// Un arranque como el de producción: el archivo del store existe o no, se asienta el neutro de la instalación nueva
    /// y se decide el montaje, en ese orden (`personalConfiguration`).
    private static func launch(storeFileExists: Bool, _ defaults: UserDefaults) -> Mount {
        let fresh = SwiftDataConfiguration.isFreshInstallForNeutralMount(
            personalStoreFileExists: storeFileExists,
            persistedMode: StorageModePersistence.read(defaults),
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(defaults),
            hasShownWelcomeChooser: defaults.bool(forKey: "hasShownWelcomeChooser"))
        StorageModePersistence.settleFreshInstallNeutralMount(
            freshInstall: fresh,
            hasCompletedOnboarding: defaults.bool(forKey: "hasCompletedOnboarding"),
            defaults)
        return SwiftDataConfiguration.personalStoreDecision(
            storageMode: StorageModePersistence.read(defaults),
            mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(defaults),
            iCloudAvailable: true,
            freshInstall: fresh,
            neutralDurable: SwiftDataConfiguration.shouldMountNeutralDurable(defaults))
    }

    // MARK: - zlbn · cerrar antes de elegir

    @Test("MUTACIÓN zlbn: cerrar en la bienvenida sin elegir y reabrir sigue montando NEUTRO, también al tercer arranque")
    func closingBeforeChoosing_keepsTheNeutralMount() {
        let defaults = makeIsolatedDefaults(prefix: "welcome.neutral.close")
        #expect(Self.launch(storeFileExists: false, defaults) == .neutralNoMirror, "primer arranque: neutro de siempre")
        // El primer montaje creó el archivo: los siguientes ya no son «instalación nueva».
        #expect(Self.launch(storeFileExists: true, defaults) == .neutralNoMirror,
                "segundo arranque sin elegir: con el bug montaba el espejo y bajaba el iCloud privado")
        #expect(Self.launch(storeFileExists: true, defaults) == .neutralNoMirror)
    }

    @Test("Control: sin el arma del primer arranque, el segundo adjunta el espejo (el bug de la card)")
    func control_withoutTheFreshArm_theSecondLaunchMirrors() {
        let defaults = makeIsolatedDefaults(prefix: "welcome.neutral.control")
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: true, freshInstall: false,
            neutralDurable: SwiftDataConfiguration.shouldMountNeutralDurable(defaults)) == .iCloudMirror)
    }

    @Test("Elegir hace inerte el neutro (el relanzamiento al espejo no gira) y terminar el alta lo retira")
    func choosing_makesItInert_andFinishingRetiresIt() {
        let defaults = makeIsolatedDefaults(prefix: "welcome.neutral.choose")
        _ = Self.launch(storeFileExists: false, defaults)
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        #expect(Self.launch(storeFileExists: true, defaults) == .iCloudMirror)
        #expect(StorageModePersistence.isNeutralMountArmed(defaults), "inerte, todavía no retirado")
        defaults.set(true, forKey: "hasCompletedOnboarding")
        #expect(Self.launch(storeFileExists: true, defaults) == .iCloudMirror)
        #expect(!StorageModePersistence.isNeutralMountArmed(defaults))
        #expect(!defaults.bool(forKey: StorageModePersistence.freshInstallOwnsNeutralMountKey))
        // Algo que vuelva a bajar el chooser después (un vaciado remoto) ya no monta neutro por un arma vieja.
        defaults.set(false, forKey: "hasShownWelcomeChooser")
        #expect(Self.launch(storeFileExists: true, defaults) == .iCloudMirror)
    }

    @Test("El neutro de otro dueño (cierre de sesión) no lo toma ni lo retira la instalación nueva")
    func anotherOwnersArm_isNeitherTakenNorRetired() {
        let defaults = makeIsolatedDefaults(prefix: "welcome.neutral.owner")
        StorageModePersistence.armNeutralMount(defaults)
        StorageModePersistence.settleFreshInstallNeutralMount(freshInstall: true, hasCompletedOnboarding: false, defaults)
        #expect(!defaults.bool(forKey: StorageModePersistence.freshInstallOwnsNeutralMountKey))
        StorageModePersistence.settleFreshInstallNeutralMount(freshInstall: false, hasCompletedOnboarding: true, defaults)
        #expect(StorageModePersistence.isNeutralMountArmed(defaults), "el del cierre de sesión se queda")
    }

    @Test("Un dueño que llega después se queda el neutro: el cierre de sesión borra la marca de la instalación nueva")
    func aLaterOwner_takesItOver() {
        let defaults = makeIsolatedDefaults(prefix: "welcome.neutral.takeover")
        StorageModePersistence.settleFreshInstallNeutralMount(freshInstall: true, hasCompletedOnboarding: false, defaults)
        #expect(defaults.bool(forKey: StorageModePersistence.freshInstallOwnsNeutralMountKey))
        StorageModePersistence.armNeutralMount(defaults)
        #expect(!defaults.bool(forKey: StorageModePersistence.freshInstallOwnsNeutralMountKey))
        StorageModePersistence.settleFreshInstallNeutralMount(freshInstall: false, hasCompletedOnboarding: true, defaults)
        #expect(StorageModePersistence.isNeutralMountArmed(defaults))
    }

    // MARK: - z5dd · «Volver» desde el acceso a la nube

    @Test("z5dd: elegir la nube, volver y cerrar la app: el arranque siguiente monta neutro y abre la bienvenida")
    func cloudEntryBackThenClose_keepsTheICloudCheck() {
        let defaults = makeIsolatedDefaults(prefix: "welcome.neutral.back")
        _ = Self.launch(storeFileExists: false, defaults)
        // La entrada al cover de nube marca el chooser al encaminar; su «Volver» lo devuelve a `false` (scan de abajo).
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        #expect(Self.launch(storeFileExists: true, defaults) == .iCloudMirror,
                "control: con el chooser aún marcado, el arranque monta el espejo")
        defaults.set(false, forKey: "hasShownWelcomeChooser")
        #expect(Self.launch(storeFileExists: true, defaults) == .neutralNoMirror)
    }

    // MARK: - Cableado

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Sin las líneas de comentario: un `// hasShownWelcomeChooser = false` no puede contar como el arreglo.
    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("El montaje asienta el neutro de la instalación nueva ANTES de leer el durable")
    func personalConfiguration_settlesBeforeDeciding() throws {
        let config = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let settle = try #require(config.range(of: "StorageModePersistence.settleFreshInstallNeutralMount("))
        let decide = try #require(config.range(of: "neutralDurable: shouldMountNeutralDurable())"))
        #expect(settle.lowerBound < decide.lowerBound)
    }

    @Test("MUTACIÓN z5dd: los «Volver» de la entrada a la nube y de Restaurar bajan el chooser antes de reabrir el Welcome")
    func backFromTheCoversResetsTheChooser() throws {
        let view = try Self.source("Yala/App/ContentView.swift")
        // Entrada a la nube: el `onBack:` que sigue a `onCreateAnotherAccount:`, hasta el cierre de su closure.
        let another = try #require(view.range(of: "onCreateAnotherAccount: {"))
        let backStart = try #require(view.range(of: "onBack: {", range: another.upperBound..<view.endIndex))
        let backEnd = try #require(view.range(of: "showWelcomeFlow = true", range: backStart.upperBound..<view.endIndex))
        let cloudBack = String(view[backStart.upperBound..<backEnd.lowerBound])
        #expect(cloudBack.contains("hasShownWelcomeChooser = false"))
        // Restaurar: el `onBack:` que lee `welcomeRestoreOrigin`.
        let restoreStart = try #require(view.range(of: "let back = welcomeRestoreOrigin ??"))
        let restoreEnd = try #require(view.range(
            of: "returnToWelcomeChooser(dismissing: $showWelcomeRestore, step: back)",
            range: restoreStart.upperBound..<view.endIndex))
        #expect(view[restoreStart.upperBound..<restoreEnd.lowerBound].contains("hasShownWelcomeChooser = false"))
    }
}
