//
//  ICloudAsideEntryTests.swift
//  YalaTests / CloudSync
//
//  **Entrar con Google o Apple dejando el iCloud privado aparte** (opción B de Jürgen, 2026-11-10, card «Entrar con
//  Google bloqueado por tus propios datos de iCloud privado»).
//
//  Lo que tiene que ser verdad, en el orden en que pasa:
//   1. La entrada a la cuenta solo deja iCloud aparte cuando el corpus tiene COPIA en iCloud y el teléfono borra por
//      archivos (`ICloudAsideEntryLogic`). Sin copia, o en la nube, el bloqueo de siempre.
//   2. La vuelta al neutro espera al export (nunca «sin copia»), y el borrado del arranque solo borra ARCHIVOS antes del
//      mount: no hay espejo montado que lleve el borrado a iCloud.
//   3. Tras el borrado el teléfono monta NEUTRO —sin espejo— y el destino sobrevive para volver a la entrada con el mismo
//      método. Si el borrado no pudo, deja el testigo y no hay bucle.
//   4. El teléfono ajeno: la pantalla no ofrece descartar lo que no llegó a iCloud.
//
//  La mitad que vive en vistas (`CloudSessionSignOut.shared`, `WelcomeGroupsGateView`) se fija por source-scan, como sus
//  hermanos de la puerta de Grupos; el recorrido de verdad, con un iCloud real, es device-QA en el iPhone 14.
//

import Foundation
import Testing

@testable import Yala

@Suite("Entrar con otra cuenta dejando el iCloud privado aparte · decisión y borrado")
struct ICloudAsideEntryTests {

    typealias Destination = WelcomeMirrorRelaunchLogic.Destination
    typealias Path = CloudSignOutFlowLogic.Path

    // MARK: - 1 · Cuándo se deja aparte

    /// La tabla entera. El único `.leaveICloudAside` es una celda que borra por archivos CON copia en iCloud: es lo
    /// que hace verdad «tus datos siguen en iCloud» para el dueño y para el teléfono ajeno.
    @Test("Solo se deja aparte con copia en iCloud y una celda que borra por archivos",
          arguments: [Path.privateSignOut, .privateWithGroupsSignOut, .groupsOnlySignOut, .cloudSecureSignOut])
    func exitTable(cell: Path) {
        let withCopy = ICloudAsideEntryLogic.exit(exitCell: cell, copyChannel: .iCloud, hasLegacyCloudKitGroups: false)
        let withoutCopy = ICloudAsideEntryLogic.exit(exitCell: cell, copyChannel: .none, hasLegacyCloudKitGroups: false)
        #expect(withoutCopy == .staysBlocked, """
            Sin copia en iCloud lo que se borraría no está en ningún otro sitio, y en un teléfono prestado no es de quien \
            entra. Celda=\(cell).
            """)
        #expect(withCopy == (cell == .cloudSecureSignOut ? .staysBlocked : .leaveICloudAside), """
            El cierre de la nube no borra por archivos y no hay iCloud privado que dejar aparte; las otras tres celdas \
            sí. Celda=\(cell).
            """)
        #expect(ICloudAsideEntryLogic.exit(exitCell: cell, copyChannel: .iCloud, hasLegacyCloudKitGroups: true)
                    == .staysBlocked, """
            Los grupos de la era CloudKit que nunca migraron no están en iCloud ni en el servidor: la vuelta al neutro \
            se los llevaría para siempre. Celda=\(cell).
            """)
    }

    /// **El dueño y el teléfono ajeno salen por el mismo sitio, y es a propósito**: la decisión no tiene término de
    /// «de quién son», porque el guard no lo sabe. Lo que protege al teléfono ajeno es que la salida no sube, no mezcla
    /// y no borra iCloud, no que se le reconozca.
    @Test("Lo que se deja aparte espera al export: la vuelta al neutro nunca va «sin copia»",
          arguments: [Path.privateSignOut, .privateWithGroupsSignOut, .groupsOnlySignOut])
    func leavingAsideWaitsForTheExport(cell: Path) throws {
        #expect(ICloudAsideEntryLogic.exit(exitCell: cell, copyChannel: .iCloud, hasLegacyCloudKitGroups: false)
                    == .leaveICloudAside)
        let plan = try #require(CloudSignOutFlowLogic.exitPlan(
            path: cell, confirmedWithoutICloudCopy: false, mountAttachesMirror: true))
        #expect(plan.waitsForExport, """
            El cierre que deja iCloud aparte tiene que esperar a que lo último llegue a iCloud antes de borrar la copia \
            local: si no, lo escrito en el teléfono y aún no exportado se perdería. Celda=\(cell).
            """)
    }

    // MARK: - Destinos

    @Test("Cada método vuelve a sí mismo tras reabrir", arguments: [CloudSignInProvider.apple, .google])
    func destinationRoundTrip(provider: CloudSignInProvider) {
        let destination = ICloudAsideEntryLogic.destination(after: provider)
        #expect(ICloudAsideEntryLogic.provider(resuming: destination) == provider)
        #expect(!WelcomeMirrorRelaunchLogic.requiresMirror(destination),
                "pedir el espejo volvería a bajar el iCloud que se quiso dejar fuera")
        #expect(GroupsGateWipeFailureMarker.armedByTheGroupsGate(pendingDestination: destination),
                "si el borrado no pudo, la puerta tiene que decirlo y no volver a armarlo")
        #expect(FullModeActivationResumeStore.step(for: destination) == nil)
    }

    @Test("Ningún otro destino retoma la entrada con otra cuenta")
    func otherDestinationsDoNotResumeTheEntry() {
        let own: Set<Destination> = [.cloudSignInAppleKeepingICloudAside, .cloudSignInGoogleKeepingICloudAside]
        for destination in Destination.allCases where !own.contains(destination) {
            #expect(ICloudAsideEntryLogic.provider(resuming: destination) == nil, "destino=\(destination)")
        }
    }

    // MARK: - El propósito de la puerta

    @Test("La puerta de la entrada con otra cuenta persiste su destino y no deja descartar nada",
          arguments: [CloudSignInProvider.apple, .google])
    func gatePurpose(provider: CloudSignInProvider) {
        let purpose = WelcomeGroupsGateView.Purpose.enterCloudAccount(provider: provider, fromExistingChooser: true)
        #expect(purpose.destinationAfterNeutralReturn == ICloudAsideEntryLogic.destination(after: provider))
        #expect(purpose.isCloudAccountEntry)
        #expect(purpose.invitedGroupID == nil)
        #expect(!purpose.mayDiscardUnsavedChanges, """
            Quien entra con otra cuenta puede estar en un teléfono prestado: «Continuar igualmente» descartaría lo que su \
            dueño escribió y no llegó a iCloud.
            """)
    }

    @Test("Solo el organizador puede descartar lo que no llegó a subir")
    func onlyTheOrganizerMayDiscard() {
        #expect(WelcomeGroupsGateView.Purpose.createGroup.mayDiscardUnsavedChanges)
        #expect(!WelcomeGroupsGateView.Purpose.acceptInvite(groupID: "zona").mayDiscardUnsavedChanges)
        #expect(!WelcomeGroupsGateView.Purpose.createGroup.isCloudAccountEntry)
        #expect(!WelcomeGroupsGateView.Purpose.acceptInvite(groupID: "zona").isCloudAccountEntry)
    }

    // MARK: - 2 y 3 · El borrado del arranque y el mount siguiente

    /// Un teléfono al que la entrada con otra cuenta acaba de devolver al neutro: modo `.icloud`, el chooser ya visto
    /// («Ya tengo una cuenta»), borrado armado y el destino que el coordinador escribe pegado al arm.
    private func armedByTheEntry(prefix: String, provider: CloudSignInProvider) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: prefix)
        StorageModePersistence.write(.icloud, defaults: defaults)
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        StorageModePersistence.armSignOutWipe(defaults)
        WelcomePendingDestinationStore.set(ICloudAsideEntryLogic.destination(after: provider), defaults: defaults)
        return defaults
    }

    /// Qué monta el arranque siguiente con lo que dejó el borrado, con iCloud disponible (el teléfono sigue con su Apple
    /// ID): exactamente la decisión de producción, alimentada con lo que hay en `defaults`.
    private func nextMount(_ defaults: UserDefaults) -> SwiftDataConfiguration.PersonalStoreDecision {
        let mode = StorageModePersistence.read(defaults)
        let armed = defaults.bool(forKey: StorageModePersistence.mirrorOffArmedKey)
        let durable = SwiftDataConfiguration.shouldMountNeutralDurable(
            neutralMountArmed: StorageModePersistence.isNeutralMountArmed(defaults),
            hasShownWelcomeChooser: defaults.bool(forKey: "hasShownWelcomeChooser"),
            groupsOnlySessionArmed: false,
            persistedMode: mode,
            mirrorOffArmed: armed)
        return SwiftDataConfiguration.personalStoreDecision(
            storageMode: mode, mirrorOffArmed: armed, iCloudAvailable: true,
            freshInstall: false, neutralDurable: durable)
    }

    /// **El camino del encargo, de punta a punta en lo que se deja medir sin archivos**: el borrado se lleva SOLO los
    /// archivos locales (personal y sync-meta, y grupos si se marcó), antes del mount; el teléfono vuelve a «recién
    /// instalado» y el arranque siguiente monta NEUTRO, sin espejo. Sin espejo montado ningún borrado llega a iCloud,
    /// y el corpus de iCloud no vuelve a bajar: la entrada encuentra el teléfono vacío.
    @Test("Tras el borrado el teléfono monta neutro, sin espejo, y el destino sigue para volver a la entrada",
          arguments: [CloudSignInProvider.apple, .google])
    func wipeLeavesANeutralPhoneAndTheDestination(provider: CloudSignInProvider) {
        let defaults = armedByTheEntry(prefix: "icloud-aside.ok.\(provider.rawValue)", provider: provider)
        // Control: antes del borrado este teléfono montaría el espejo y volvería a bajar su iCloud.
        #expect(nextMount(defaults) == .iCloudMirror)

        var deleted: [String] = []
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in deleted.append(name); return true },
            resetPrefs: { DataWipeService.removeUserPreferenceKeys(from: defaults) },
            cancelNotifications: {})

        #expect(deleted == [SwiftDataConfiguration.databaseName, SwiftDataConfiguration.syncMetaDatabaseName],
                "solo archivos locales: el borrado no toca ninguna zona de iCloud")
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults))
        #expect(StorageModePersistence.read(defaults) == .icloud)
        let mount = nextMount(defaults)
        #expect(mount == .neutralNoMirror, """
            Tras dejar iCloud aparte el arranque tiene que montar sin espejo: con él, el iCloud del teléfono volvería a \
            bajar, la entrada lo encontraría otra vez y pediría el mismo borrado.
            """)
        #expect(!mount.attachesCloudKitMirror)
        #expect(WelcomePendingDestinationStore.peek(defaults) == ICloudAsideEntryLogic.destination(after: provider),
                "sin el destino, el arranque cae en el recorrido normal y la persona pierde a dónde iba")
        #expect(!GroupsGateWipeFailureMarker.isPending(defaults))
    }

    /// **Por qué importa que el barrido de preferencias olvide el chooser**: es el término que hace durable el neutro.
    /// Si sobreviviera, el arranque siguiente montaría el espejo sobre el store vacío y bajaría el iCloud otra vez.
    @Test("Control: sin olvidar el chooser, el arranque siguiente volvería a montar el espejo")
    func withoutForgettingTheChooser_theMirrorWouldComeBack() {
        let defaults = armedByTheEntry(prefix: "icloud-aside.control", provider: .google)
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true }, resetPrefs: {}, cancelNotifications: {})
        #expect(nextMount(defaults) == .iCloudMirror)
    }

    /// Si un archivo no se deja borrar, el arranque desarma —con el espejo montado, reintentar se llevaría cambios que
    /// nadie esperó a exportar— y deja el testigo: la puerta dirá «no pudimos» en vez de volver a armar en bucle.
    @Test("Si el borrado no pudo, desarma y deja el testigo", arguments: [CloudSignInProvider.apple, .google])
    func abortLeavesTheWitness(provider: CloudSignInProvider) {
        let defaults = armedByTheEntry(prefix: "icloud-aside.abort.\(provider.rawValue)", provider: provider)
        var resets = 0
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in false }, resetPrefs: { resets += 1 }, cancelNotifications: {})
        #expect(GroupsGateWipeFailureMarker.isPending(defaults))
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults))
        #expect(resets == 0, "el store sigue vivo: nada de su vida se barre")
        #expect(nextMount(defaults) == .iCloudMirror, "los datos siguen aquí y en iCloud, como antes de intentarlo")
    }
}

// MARK: - 4 · Cableado (source-scan)

@Suite("Entrar con otra cuenta dejando el iCloud privado aparte · cableado (source-scan)")
struct ICloudAsideEntryWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CloudSync
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    /// Código sin líneas de comentario: los docblocks nombran a propósito lo que prohíben.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

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

    private static func flat(_ body: String) -> String {
        body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let signInView = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
    private static let gateView = "Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift"
    private static let container = "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"
    private static let contentView = "Yala/App/ContentView.swift"

    /// **La entrada suelta la sesión ANTES de decidir, y decide con la celda y la copia de verdad.** Con la sesión viva
    /// la celda sería otra, y un default en la copia dejaría borrar sin ella.
    @Test("La rama bloqueada de la entrada suelta la sesión y luego elige entre dejar aparte o bloquear")
    func signInBranchLeavesICloudAsideOrBlocks() throws {
        let src = Self.flat(try Self.code(Self.signInView))
        let decide = "switch ICloudAsideEntryLogic.exit( exitCell: WelcomeGroupsGateView.exitCell(), "
            + "copyChannel: WelcomeGroupsGateView.copyChannelNow, "
            + "hasLegacyCloudKitGroups: CloudSessionSignOut.hasLegacyCloudKitGroupRows(context: modelContext)) { "
            + "case .leaveICloudAside: onLeaveICloudAside(provider) "
            + "case .staysBlocked: phase = .blockedForeignData }"
        let branch = try #require(src.range(of: "case .blockedForeignData: await CloudAuthService.shared.signOut() "),
                                  "la rama del guard ya no suelta la sesión lo primero")
        let decision = try #require(src.range(of: decide), "la rama ya no decide con la celda y la copia de verdad")
        #expect(branch.upperBound <= decision.lowerBound)
        #expect(!src.contains("case .blockedForeignData: await CloudAuthService.shared.signOut() phase = .blockedForeignData"),
                "volvió el bloqueo incondicional sobre el iCloud privado")
    }

    /// **La puerta de esta entrada nunca borra sin copia** y lee el testigo antes de armar.
    @Test("La puerta de la entrada con otra cuenta solo arma con copia y mira el testigo antes")
    func gateEntryPhaseOnlyArmsWithACopy() throws {
        let body = Self.flat(try #require(Self.bodyOf("private func cloudAccountEntryPhase() -> Phase {",
                                                      in: try Self.code(Self.gateView))))
        #expect(body.hasPrefix("guard CloudSessionSignOut.shared.phase == .idle else { return .unavailable }"))
        let witness = try #require(body.range(of:
            "if celda != .cloudSecureSignOut, GroupsGateWipeFailureMarker.isPending() { return .wipeFailed }"))
        let arm = try #require(body.range(of: "return .returningToNeutral(withoutICloudCopy: false, intento: intento)"))
        #expect(witness.upperBound <= arm.lowerBound)
        #expect(body.contains("case .staysBlocked: return .unavailable"))
        #expect(body.contains("exitCell: celda, copyChannel: Self.copyChannelNow, "
            + "hasLegacyCloudKitGroups: CloudSessionSignOut.hasLegacyCloudKitGroupRows(context: modelContext))"),
                "la puerta decide distinto que la entrada: un canal sin el seam o sin el término de los grupos viejos")
        let channel = Self.flat(try #require(Self.bodyOf("static var copyChannelNow: PrivateSignOutExportGateLogic.CopyChannel {",
                                                         in: try Self.code(Self.gateView))))
        #expect(channel.contains("mountAttachesMirror: mountAttachesMirrorNow"),
                "sin el seam, bajo -uitest el canal diría .iCloud sobre un store que no espeja")
        #expect(!body.contains("confirmingNoBackup") && !body.contains("withoutICloudCopy: true"),
                "esta entrada no ofrece borrar lo que no está en iCloud")
    }

    @Test("La puerta que deja pasar retira el testigo y mide con el detector del guard")
    func gateProceedClearsTheWitness() throws {
        let body = Self.flat(try #require(Self.bodyOf("private func evaluateCloudAccountEntry() {",
                                                      in: try Self.code(Self.gateView))))
        #expect(body.hasPrefix("guard hasLocalDataNow() else { GroupsGateWipeFailureMarker.clear() onProceed() return }"))
        let container = Self.flat(try Self.code(Self.container))
        #expect(container.contains("hasLocalDataNow: { purpose.isCloudAccountEntry ? hasLocalDataNow() : welcomeDeviceDataNow() }"),
                "con el detector del Welcome la puerta podría dejar pasar lo que el guard vuelve a bloquear: un bucle")
        #expect(container.contains("if case .enterCloudAccount(let provider, let fromExistingChooser) = purpose { "
            + "onGroupsGateCloudAccountProceed(provider, fromExistingChooser) }"))
        // «Volver» vuelve a donde se abrió la entrada: con el faro o desde Grupos, al chooser, como el bloqueo de antes.
        let back = Self.flat(try #require(Self.bodyOf(
            "private func groupsGateBackStep(_ purpose: WelcomeGroupsGateView.Purpose) -> WelcomeFlowStep {",
            in: try Self.code(Self.container))))
        #expect(back == "guard case .enterCloudAccount(_, let fromExistingChooser) = purpose else { return .groupsChooser } "
            + "return fromExistingChooser ? WelcomeBackStepLogic.existingBranchOrigin(options: visibleExistingOptions) : .chooser")
    }

    /// **Ninguna salida que descarte cambios se le ofrece a quien puede no ser el dueño.** Los tres sitios de la puerta
    /// que lo ofrecían con `invitedGroupID == nil` —que también es verdad para esta entrada— leen ahora la propiedad.
    @Test("Las salidas que descartan cambios solo las ve el organizador")
    func discardExitsAreOnlyForTheOrganizer() throws {
        let src = try Self.code(Self.gateView)
        #expect(!src.contains("purpose.invitedGroupID == nil"))
        #expect(src.components(separatedBy: "purpose.mayDiscardUnsavedChanges").count - 1 == 3)
    }

    @Test("El arranque retoma la puerta de la entrada con otra cuenta, con su método")
    func bootResumesTheGate() throws {
        let src = Self.flat(try Self.code(Self.contentView))
        #expect(src.contains("case .cloudSignInAppleKeepingICloudAside, .cloudSignInGoogleKeepingICloudAside: "
            + "if let provider = ICloudAsideEntryLogic.provider(resuming: pending) { "
            + "welcomeFlowInitialStep = .groupsGate(purpose: .enterCloudAccount( "
            + "provider: provider, fromExistingChooser: true))"))
        #expect(src.contains("onLeaveICloudAside: { provider in "
            + "welcomeFlowInitialStep = .groupsGate(purpose: .enterCloudAccount( "
            + "provider: provider, fromExistingChooser: cloudSignInFromExistingChooser)) "
            + "showWelcomeFlow = true showWelcomeCloudSignIn = false }"))
        #expect(src.contains("cloudSignInFromExistingChooser = fromExistingChooser"),
                "la vuelta a la entrada tiene que conservar de dónde se abrió")
    }

    /// **La espera agotada de esta entrada no promete «si continúas»**: no hay botón de continuar (quien entra puede no
    /// ser el dueño). Su texto con cifra interpola y nunca sale crudo.
    @Test("La espera agotada usa su propio texto, sin «si continúas»")
    func stalledCopyIsItsOwn() throws {
        let body = L10n.Welcome.Groups.cloudAsideStalledBody(7)
        #expect(body.contains("7") && !body.contains("%d") && !body.contains("welcome.groups."))
        #expect(!L10n.Welcome.Groups.cloudAsideStalledBodyUnknown.contains("welcome.groups."))
        let stalled = Self.flat(try #require(Self.bodyOf("private func stalledBody(pending: Int) -> String {",
                                                         in: try Self.code(Self.gateView))))
        #expect(stalled.hasPrefix("if purpose.isCloudAccountEntry { return pending > 0 "
            + "? L10n.Welcome.Groups.cloudAsideStalledBody(pending) : L10n.Welcome.Groups.cloudAsideStalledBodyUnknown }"))
    }
}
