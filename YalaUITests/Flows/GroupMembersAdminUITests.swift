//
//  GroupMembersAdminUITests.swift
//  YalaUITests
//
//  Cobertura de la lista de miembros (`GroupMembersView` + `GroupMemberRow`) — la pantalla donde un
//  admin aprueba, rechaza, cambia de rol y expulsa. Todas esas acciones llaman a RPC del backend y
//  hasta el 2026-09-04 NINGUNA tenía prueba de interfaz.
//
//  Lo que estos casos ejercitan y ninguna otra suite podía: la RESOLUCIÓN DE IDENTIDAD. El perfil
//  `grupos-sin-flag` siembra el member propio SIN `isCurrentUser` —como llega de verdad por el pull
//  del canal backend, porque `GroupsSyncClient.applyMember` nunca escribe ese flag— y
//  `-uitest-icloud-identity` siembra la identidad por la que la app debe reconocerlo. Los demás
//  perfiles encienden el flag a mano, así que con ellos estos dos casos pasarían en verde con el
//  bug dentro.
//
//  COMPROBADO POR MUTACIÓN (regla de `.claude/rules/testing.md`): revertir
//  `GroupDetailViewModel.currentUserMember` al `first { $0.isCurrentUser }` de antes pone ROJO el
//  primer caso. Sin esa comprobación no habría forma de saber si esta suite prueba la decisión o
//  solo el flujo.
//

import XCTest

final class GroupMembersAdminUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Aterriza en la lista de miembros del grupo sembrado, con el member propio sin flag.
    private func launchToMembers() -> XCUIApplication {
        let app = XCUIApplication()
        // Deep link al TAB (`groups`), no al detalle con `seeded-first`: ese token se resuelve
        // contra el id que el seed publica, y en un ÚNICO lanzamiento el deep link se procesa antes
        // de que exista — por eso `GroupDetailDeeplinkColdLaunchUITests` hace dos launches. Aquí
        // basta con aterrizar en el tab y tocar la tarjeta, que ya está a la vista.
        //
        // Al tab se entra por deep link y no navegando desde «Más»: esa card vive en un `LazyVGrid`
        // que iOS 27.0 no materializa con swipes sintéticos (Lista Negra, 2026-07-29).
        app.launchForUITest(
            pro: true, seed: "grupos-sin-flag", deeplink: "groups", icloudIdentity: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons["group_card"].firstMatch
        XCTAssertTrue(
            card.waitForExistence(timeout: 20),
            "No se montó la lista de Grupos con el grupo sembrado (group_card ausente).")
        // `exists` NO implica alcanzable: el alert que acabamos de descartar sigue animando su
        // cierre y, mientras dure, la card está en el árbol pero sin punto de impacto — el tap se
        // sintetiza en {-1,-1} y se pierde SIN error de aserción, con un «Failed to tap» opaco.
        // Es la regla de `.claude/rules/testing.md`, y aquí se cumplió al pie de la letra.
        XCTAssertTrue(
            card.waitForHittable(timeout: 10),
            "La tarjeta del grupo existe pero no es alcanzable — algo la tapa (¿el alert sin terminar de cerrarse?).")
        card.tap()

        let membersButton = app.buttons["group_members_button"]
        XCTAssertTrue(
            membersButton.waitForExistence(timeout: 20),
            "No se abrió el detalle del grupo (group_members_button ausente).")
        membersButton.tap()
        return app
    }

    /// EL CASO. Mi member llegó por el pull SIN `isCurrentUser`; la app debe reconocerme igual por
    /// identidad y, siendo admin, ofrecerme las acciones sobre el miembro PENDIENTE.
    ///
    /// Con el resolvedor viejo (`first { $0.isCurrentUser }`) esto es nil ⇒ `isCurrentUserAdmin`
    /// false ⇒ ningún control de admin se pinta y el caso sale rojo. Ésa es la mutación.
    func test_adminWithoutFlag_isRecognised_andSeesActionsOnPendingMember() {
        let app = launchToMembers()

        let aprobarCarla = app.buttons["group_member_approve_Carla"]
        XCTAssertTrue(
            aprobarCarla.waitForExistence(timeout: 10),
            "La app no me reconoció como admin: sin `isCurrentUser`, la identidad debe resolverse por el recordName sembrado.")
        XCTAssertTrue(
            app.buttons["group_member_reject_Carla"].exists,
            "Falta la acción de rechazar junto a la de aprobar — se ofrecen las dos o ninguna.")
    }

    /// LA AUTO-EXPULSIÓN, que es la regresión que la review adversarial destapó el 2026-09-04.
    ///
    /// Al resolver identidad, `isCurrentUserAdmin` se enciende para un admin cuyo flag sigue
    /// apagado. Si la fila decidiera «esta soy yo» con ese flag —como hacía antes—, MI PROPIA fila
    /// mostraría «cambiar rol» y «quitar». Y el daño no sería cosmético: `removeMember` llama al
    /// RPC ANTES de `removeMemberLocal`, cuyo guard anti-self sigue leyendo el flag crudo
    /// (`GroupService:345`), así que el servidor me quitaría y el guard local lanzaría después.
    ///
    /// Este caso es la red: mi fila NO ofrece acciones, aunque yo sea admin y aunque mi flag esté
    /// apagado. Es la mitad que el test unitario no puede dar — aquél pinnea el criterio, éste que
    /// la pantalla lo usa.
    func test_ownRow_neverOffersAdminActions_evenWhenResolvedWithoutFlag() {
        let app = launchToMembers()

        // Primero confirmo que la pantalla está viva y me reconoce; si no, la ausencia de abajo no
        // probaría nada — sería una aserción negativa sobre un input que ya la garantiza.
        XCTAssertTrue(
            app.buttons["group_member_approve_Carla"].waitForExistence(timeout: 10),
            "Control positivo fallido: la app no me reconoció como admin, así que la ausencia de acciones sobre mi fila no significaría nada.")

        XCTAssertFalse(
            app.buttons["group_member_actions_Tú"].exists,
            "Mi propia fila ofrece acciones de administración — `removeMember` llama al RPC antes del guard anti-self, así que esto me expulsa de mi propio grupo.")
    }

    /// La dueña del grupo tampoco es expulsable, y eso no depende de la identidad: lo gobierna
    /// `!member.isGroupOwner`. Se afirma aquí para que un refactor de la condición no se lo lleve
    /// por delante creyendo que solo tocaba lo de `isSelf`.
    func test_groupOwnerRow_neverOffersAdminActions() {
        let app = launchToMembers()
        XCTAssertTrue(
            app.buttons["group_member_approve_Carla"].waitForExistence(timeout: 10),
            "Control positivo fallido: la app no me reconoció como admin.")
        XCTAssertFalse(
            app.buttons["group_member_actions_Ana"].exists,
            "La fila de la dueña ofrece acciones de administración: `isGroupOwner` debe seguir protegiéndola.")
    }
}
