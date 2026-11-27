//
//  CompartidoInvitarYEntradaCableadoTests.swift
//  YalaTests
//
//  Lote 3 de Compartido: el cableado que la lógica pura no ve. Que Nuevo gasto, Voz, Foto e Yala IA de Personas usen las
//  MISMAS pantallas de Grupos (el selector `GroupPickerSheet` con «Escribir un nombre», no una pantalla nueva); que la
//  pestaña sin nadie con quien apuntar pregunte «¿Con quién?»; que la hoja de «Grupo» del + ya no corte el camino; y que
//  el enlace de una persona salga con su texto.
//

import Foundation
import Testing

@Suite("Compartido · invitar y entrar sin grupo: cableado (source-scan)")
struct CompartidoInvitarYEntradaCableadoTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios ni espacios repetidos: lo que se compila, no lo que se documenta.
    private func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("//") ? "" : trimmed
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    @Test func picker_offersWriteAName_onlyWithTheNewPersonCallback() throws {
        let picker = try code("Yala/App/Views/Groups/GroupPickerSheet.swift")
        #expect(picker.contains("if onNewPerson != nil { CompartidoNewPersonBox("))
        #expect(picker.contains("onNewPerson == nil ? L10n.Groups.selectGroup : L10n.Compartido.whoTitle"))
        // Una persona se pinta con su inicial y «Persona»; un grupo, como siempre.
        #expect(picker.contains("group.isPerson ? L10n.Compartido.personSubtitle"))
    }

    /// Las cuatro entradas de captura llegan al MISMO selector: el compositor de Nuevo gasto, el camino de Voz/Foto/IA y
    /// la pestaña sin nadie elegible. Ninguna pantalla de captura nueva para Personas.
    @Test func everyCaptureEntry_usesTheSamePicker_withWriteAName() throws {
        let composer = try code("Yala/App/Views/Groups/GroupExpenseComposerView.swift")
        let receipt = try code("Yala/App/Views/Groups/GroupReceiptEntry.swift")
        let flow = try code("Yala/App/Views/Compartido/CompartidoPersonFlow.swift")
        for (name, text) in [("composer", composer), ("receipt", receipt), ("flow", flow)] {
            #expect(text.contains("GroupPickerSheet("), "\(name)")
            #expect(text.contains("onNewPerson:"), "\(name)")
        }
        // Voz, Foto e Yala IA siguen siendo las de Grupos.
        #expect(receipt.contains("GroupVoiceCaptureView(") && receipt.contains("GroupPhotoCaptureView(")
                && receipt.contains("GroupAIChatView("))
    }

    @Test func tab_withNobodyToLogWith_asksWho_insteadOfANewGroupPill() throws {
        let tab = try code("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(tab.contains("if CompartidoEntradaLogic.start(eligibleCount: eligibles.count) == .askWho { personFlow.ask(.newExpense)"))
        #expect(tab.contains("if CompartidoEntradaLogic.start(eligibleCount: eligibles.count) == .askWho { personFlow.ask(.receipt(source))"))
        // La fila de captura ya no se cambia por «Nuevo grupo» sin grupo elegible.
        #expect(!tab.contains("accessibilityIdentifier: \"groups_action_new_group\""))
        // La entrada sin grupo: vista completa decidida por la lógica, y la tarjeta de pasos solo para lo demás.
        #expect(tab.contains("viewModel.archivedGroups.isEmpty && showsFullEmptyView { compartidoEmptyFullView"))
    }

    @Test func addPerson_opensTheNameSheet_notTheGroupForm() throws {
        let tab = try code("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(tab.contains("private func addPerson() { personFlow.showAddPerson = true }"))
    }

    @Test func groupNeededSheet_offersToLogWithAPerson_first() throws {
        let sheet = try code("Yala/App/Views/Groups/GroupNeededForExpenseSheet.swift")
        let withPerson = try #require(sheet.range(of: "group_needed_with_person"))
        let create = try #require(sheet.range(of: "group_needed_create"))
        #expect(withPerson.lowerBound < create.lowerBound)
        #expect(sheet.contains("navigation.navigateToGroupsAndComposeExpense()"))
    }

    @Test func createdSheet_ofAPerson_usesItsOwnTexts() throws {
        let sheet = try code("Yala/App/Views/Groups/GroupCreatedInviteSheet.swift")
        #expect(sheet.contains("group.isPerson ? L10n.Compartido.addedTitle(group.name) : L10n.UXL12.createdTitle(group.name)"))
        #expect(sheet.contains("group.isPerson ? L10n.Compartido.addedMessage(group.name) : L10n.UXL12.createdMessage"))
        #expect(sheet.contains("L10n.Compartido.shareMessage(inviter: name)"))
    }

    @Test func inviteOnboarding_ofAPerson_showsYalaNotAGroup() throws {
        let onboarding = try code("Yala/App/Views/Groups/GroupInviteOnboardingView.swift")
        #expect(onboarding.contains("if isPersonInvite { personCard } else { groupCard }"))
        #expect(onboarding.contains("isPersonInvite ? L10n.Compartido.inviteJoin : L10n.Groups.Invite.joinButton"))
        #expect(onboarding.contains("if inviteMetadata?.isPerson == true { return true }"))
    }

    /// La persona nace en el servidor con su sitio reservado (g38_01): el alta va por `createPersonGroup`, server-first.
    @Test func personCreation_goesThroughTheServerFirstRPC() throws {
        let alta = try code("Yala/App/Logic/Compartido/CompartidoPersonaAlta.swift")
        #expect(alta.contains(".createPersonGroup("))
        #expect(alta.contains("GroupsMembershipClient(attestProvider: AttestSessionProvider.live)"))
        let service = try code("Yala/Services/CloudSync/Groups/GroupBackendMembershipService.swift")
        // El RPC va ANTES de tocar el contexto.
        let rpc = try #require(service.range(of: "result = try await client.createPersonGroup("))
        let insert = try #require(service.range(of: "seat.id = personMemberID"))
        #expect(rpc.lowerBound < insert.lowerBound)
    }

    @Test func web_readsThePersonMark_andForwardsIt() throws {
        let web = try source("Web/src/pages/invite.astro")
        #expect(web.contains("const isPersonInvite = url.searchParams.get('k') === 'p';"))
        #expect(web.contains("['n', 'i', 'c', 'm', 'u', 'k']"))
    }
}
