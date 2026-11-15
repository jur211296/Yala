//
//  ChangeAccountG1Tests.swift
//  YalaTests
//
//  G1 de la revisión 2.3 (decisión 55): la cuenta de los grupos pasa a una fila con «Cambiar de cuenta», y el aviso de
//  «Activar la nube» parado ofrece esa salida como botón. Aquí, las dos tablas puras: qué avisos la ofrecen y cómo se
//  nombra la cuenta. Que la hoja de consecuencias salga siempre lo fija `GroupsAssociationRowUITests` y
//  `StorageMigrationIdentityBlockUITests`.
//

import Testing
@testable import Yala

@MainActor
@Suite("G1 · Cambiar de cuenta")
struct ChangeAccountG1Tests {

    // MARK: - Qué avisos ofrecen «Cambiar de cuenta»

    /// Los tres motivos que se arreglan soltando la cuenta de los grupos la ofrecen; los otros dos no: volver a la nube con
    /// una cuenta que volvió a iCloud no existe, y una activación a medias se arregla esperando.
    @Test(arguments: StorageMigrationIdentityGateLogic.Block.allCases)
    func cadaMotivo_ofreceCambiarSoloSiSeArreglaSoltandoLaCuenta(reason: StorageMigrationIdentityGateLogic.Block) {
        let esperado: Bool
        switch reason {
        case .accountHasPersonalData, .anotherGroupsAccountAssociated, .sessionFromBeforeFreshStart: esperado = true
        case .accountReturnedToICloud, .migrationInProgressOnAnotherDevice: esperado = false
        }
        #expect(MigrationBlockChangeAccountLogic.offersChangeAccount(
            reason: reason, offersAnotherAccount: false, offersDetachingStaleAssociation: false,
            groupsAccountCanBeReleased: true) == esperado)
    }

    /// Sin una cuenta que la pantalla pueda soltar ahora, el botón abriría nada: no se ofrece en ningún motivo.
    @Test(arguments: StorageMigrationIdentityGateLogic.Block.allCases)
    func sinCuentaQueSoltar_noSeOfrece(reason: StorageMigrationIdentityGateLogic.Block) {
        #expect(!MigrationBlockChangeAccountLogic.offersChangeAccount(
            reason: reason, offersAnotherAccount: false, offersDetachingStaleAssociation: false,
            groupsAccountCanBeReleased: false))
    }

    /// Con «Desasociarla y seguir» el aviso ya suelta la asociación: no se suma otra salida. Con «Usar otra cuenta» y una
    /// cuenta con datos propios, la salida es elegir otra; soltar la de los grupos no lo arregla.
    @Test func conOtraSalidaQueYaLoArregla_noSeSuma() {
        #expect(!MigrationBlockChangeAccountLogic.offersChangeAccount(
            reason: .anotherGroupsAccountAssociated, offersAnotherAccount: true, offersDetachingStaleAssociation: true,
            groupsAccountCanBeReleased: true))
        #expect(!MigrationBlockChangeAccountLogic.offersChangeAccount(
            reason: .accountHasPersonalData, offersAnotherAccount: true, offersDetachingStaleAssociation: false,
            groupsAccountCanBeReleased: true))
    }

    /// Hallazgo de la review adversarial: «Ya usas otra cuenta para tus grupos» dice «toca antes «Cambiar de cuenta»»
    /// también cuando el intento abrió la sesión y el aviso trae «Usar otra cuenta». Con la asociación puesta cualquier otra
    /// cuenta se pararía igual, así que el botón que el texto nombra tiene que estar.
    @Test func otraCuentaDeGrupos_conUsarOtra_ofreceTambienCambiar() {
        #expect(MigrationBlockChangeAccountLogic.offersChangeAccount(
            reason: .anotherGroupsAccountAssociated, offersAnotherAccount: true, offersDetachingStaleAssociation: false,
            groupsAccountCanBeReleased: true))
    }

    // MARK: - Cómo se nombra la cuenta en la fila

    @Test func lineaDeLaCuenta_marcaYCorreo() {
        #expect(GroupsAssociationLogic.accountLine(email: "lucia@icloud.com", provider: CloudSignInProvider.apple.rawValue) == "Apple · lucia@icloud.com")
        #expect(GroupsAssociationLogic.accountLine(email: "lucia@gmail.com", provider: CloudSignInProvider.google.rawValue) == "Google · lucia@gmail.com")
    }

    /// Lo que falta no se inventa: solo el correo, solo la marca, o nada.
    @Test func lineaDeLaCuenta_conLoQueHay() {
        #expect(GroupsAssociationLogic.accountLine(email: " lucia@icloud.com ", provider: nil) == "lucia@icloud.com")
        #expect(GroupsAssociationLogic.accountLine(email: nil, provider: CloudSignInProvider.apple.rawValue) == "Apple")
        #expect(GroupsAssociationLogic.accountLine(email: "  ", provider: "otro") == nil)
        #expect(GroupsAssociationLogic.accountLine(email: nil, provider: nil) == nil)
    }
}
