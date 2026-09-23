//
//  StorageMigrationIdentityGateLogicTests.swift
//  YalaTests
//
//  La puerta de identidad de «Migrar a la nube» (ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`):
//  qué cuenta deja seguir hacia el claim, cuál para y con qué aviso, y qué textos ve la persona.
//
//  El bug que cierra: con una cuenta que ya tenía finanzas personales, «Migrar» terminaba en el adopt, que sube el corpus
//  local a esa cuenta. Estos casos fijan la fila de Ajustes de la tabla [I] de punta a punta —la tabla por sí sola ya
//  tiene su suite—, porque lo que importa aquí es que el veredicto que ejecuta el controller sea el correcto.
//

import Foundation
import Testing

@testable import Yala

@Suite("«Migrar a la nube» · la puerta de identidad")
struct StorageMigrationIdentityGateLogicTests {

    private typealias Logic = StorageMigrationIdentityGateLogic
    private typealias Discovery = CloudIdentityRoutingLogic.Discovery

    /// Por defecto, un teléfono que no empezó desde cero y la sesión que ya había al tocar: es la celda de siempre, y los
    /// casos anteriores al ticket `fresh-start-keeps-a-groups-session-that-migrate-promotes` la siguen midiendo tal cual.
    private func check(_ discovery: Discovery, associated: Bool?,
                       state: CloudIdentityRoutingLogic.DeviceSessionState = .privateSession,
                       claimedHere: Bool = false,
                       unansweredClaim: Bool = false,
                       freshStart: Bool = false,
                       openedHere: Bool = false) -> Logic.Check {
        Logic.check(answer: .discovered(discovery), deviceState: state, isAssociatedGroupsAccount: associated,
                    claimedForMigrationHere: claimedHere, hasUnansweredMigrationClaim: unansweredClaim,
                    sessionOpenedByThisAttempt: openedHere, deviceSealedForFreshStart: freshStart)
    }

    // MARK: - La fila de Ajustes, de punta a punta

    /// El bug del ticket: una cuenta con finanzas personales NO sigue al claim, se asocie lo que se asocie.
    @Test("cuenta completa → bloqueo, con cualquier asociación")
    func completa_bloquea() {
        for associated in [true, false, nil] as [Bool?] {
            #expect(check(.complete, associated: associated) == .blocked(.accountHasPersonalData),
                    "asociada=\(String(describing: associated))")
        }
    }

    /// CONTROL del de arriba: una cuenta nueva migra. Sin esto, una puerta que bloqueara todo pasaría el caso anterior.
    @Test("cuenta nueva sin otra asociada → sigue")
    func nueva_sigue() {
        #expect(check(.newAccount, associated: nil) == .proceed)
    }

    /// Decisión de Jürgen (2026-09-16): con OTRA cuenta asociada para grupos, una cuenta nueva tampoco recibe lo personal.
    /// Quedarían dos cuentas en la nube en el dispositivo, y la hoja de «una cuenta a la vez» se contradecía con lo que
    /// pasaba al tocar «Usar otra cuenta».
    @Test("cuenta nueva con OTRA asociada → bloqueo de «una cuenta a la vez»")
    func nuevaConOtraAsociada_bloquea() {
        #expect(check(.newAccount, associated: false) == .blocked(.anotherGroupsAccountAssociated))
    }

    @Test("solo grupos y ES la asociada → sigue (el claim la promueve)")
    func soloGruposAsociada_sigue() {
        #expect(check(.groupsOnly, associated: true) == .proceed)
    }

    /// Decisión de Jürgen (2026-09-16): sin ninguna asociada no hay «otra cuenta» de la que hablar, ni finanzas personales
    /// que fusionar. Bloquear aquí decía «ya usas otra cuenta para tus grupos» a quien no tiene ninguna.
    @Test("solo grupos y NINGUNA asociada → sigue")
    func soloGruposSinAsociada_sigue() {
        #expect(check(.groupsOnly, associated: nil) == .proceed)
    }

    @Test("solo grupos y OTRA asociada → bloqueo de «una cuenta a la vez»")
    func soloGruposOtraAsociada_bloquea() {
        #expect(check(.groupsOnly, associated: false) == .blocked(.anotherGroupsAccountAssociated))
    }

    /// Sin respuesta no se sabe si sería una fusión, así que tampoco se migra.
    @Test("no se pudo preguntar → no sigue")
    func sinRespuesta_noSigue() {
        for associated in [true, false, nil] as [Bool?] {
            for claimedHere in [true, false] {
                for freshStart in [true, false] {
                    for openedHere in [true, false] {
                        #expect(Logic.check(answer: .unavailable, deviceState: .privateSession,
                                            isAssociatedGroupsAccount: associated,
                                            claimedForMigrationHere: claimedHere,
                                            hasUnansweredMigrationClaim: claimedHere,
                                            sessionOpenedByThisAttempt: openedHere,
                                            deviceSealedForFreshStart: freshStart) == .couldNotCheck)
                    }
                }
            }
        }
    }

    /// Un gateway que no manda `kind` no puede colar una migración encima de una cuenta que sí tiene datos.
    @Test("`kind` ausente → bloqueo")
    func kindAusente_bloquea() {
        let discovery = CloudIdentityRoutingLogic.discovery(exists: true, kind: nil, gate: .settingsMigrateToCloud)
        #expect(check(discovery, associated: nil) == .blocked(.accountHasPersonalData))
    }

    /// La fila de Ajustes no lee el eje del dispositivo: el veredicto es el mismo en los cuatro estados.
    @Test("el estado del dispositivo no cambia el veredicto")
    func ejeNoDecide() {
        for discovery in Discovery.allCases {
            for associated in [true, false, nil] as [Bool?] {
                for claimedHere in [true, false] {
                    for freshStart in [true, false] {
                        for openedHere in [true, false] {
                            let esperado = check(discovery, associated: associated, state: .privateSession,
                                                 claimedHere: claimedHere, freshStart: freshStart, openedHere: openedHere)
                            for state in CloudIdentityRoutingLogic.DeviceSessionState.allCases {
                                #expect(check(discovery, associated: associated, state: state, claimedHere: claimedHere,
                                              freshStart: freshStart, openedHere: openedHere) == esperado, """
                                    \(discovery) · asociada=\(String(describing: associated)) · sello=\(claimedHere) · \
                                    de cero=\(freshStart) · sesión del intento=\(openedHere) · \(state)
                                    """)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - «Reintentar» tras un fallo (hallazgo de la review)

    /// El claim de un intento anterior dejó la cuenta `complete`, con este dispositivo de líder. «Reintentar» vuelve a
    /// «Migrar» y la comprobación la tomaba por una cuenta con datos ajenos: la migración no podía terminar nunca. Con el
    /// sello `.proceedMigration` de esa cuenta en este dispositivo, sigue y decide el claim.
    @Test("cuenta completa que ESTE dispositivo reclamó para migrar → sigue")
    func completaReclamadaAqui_sigue() {
        #expect(check(.complete, associated: nil, claimedHere: true) == .proceed)
        #expect(check(.complete, associated: true, claimedHere: true) == .proceed)
    }

    /// El sello no se salta la regla de «una cuenta a la vez», y no abre nada fuera de `complete`.
    @Test("el sello no abre otra asociada ni cambia las demás respuestas")
    func selloAcotado() {
        #expect(check(.complete, associated: false, claimedHere: true) == .blocked(.anotherGroupsAccountAssociated))
        #expect(check(.groupsOnly, associated: false, claimedHere: true) == .blocked(.anotherGroupsAccountAssociated))
        #expect(check(.newAccount, associated: false, claimedHere: true) == .blocked(.anotherGroupsAccountAssociated))
        #expect(check(.groupsOnly, associated: nil, claimedHere: true) == .proceed)
        #expect(check(.newAccount, associated: nil, claimedHere: true) == .proceed)
    }

    // MARK: - «Empezar desde cero» con la sesión de antes

    /// El bug del ticket `fresh-start-keeps-a-groups-session-that-migrate-promotes`: el teléfono empezó desde cero, la sesión
    /// viva la dejó la persona anterior y no hay ninguna asociada. Promoverla subía las finanzas de la persona nueva a esa
    /// cuenta, y crear una nueva con esa sesión las dejaba en una cuenta con la identidad de la anterior.
    @Test("empezó de cero + sesión de antes + ninguna asociada → bloqueo, en solo-grupos y en cuenta nueva")
    func empezoDeCero_sesionDeAntes_bloquea() {
        #expect(check(.groupsOnly, associated: nil, freshStart: true, openedHere: false)
                == .blocked(.sessionFromBeforeFreshStart))
        #expect(check(.newAccount, associated: nil, freshStart: true, openedHere: false)
                == .blocked(.sessionFromBeforeFreshStart))
        // El sello `.proceedMigration` solo abre una cuenta `complete`: con otra, no exime del bloqueo (hallazgo de la review).
        #expect(check(.groupsOnly, associated: nil, claimedHere: true, freshStart: true, openedHere: false)
                == .blocked(.sessionFromBeforeFreshStart))
        #expect(check(.newAccount, associated: nil, claimedHere: true, freshStart: true, openedHere: false)
                == .blocked(.sessionFromBeforeFreshStart))
    }

    /// CONTROL del término de la sesión: si la abrió este intento, la persona eligió la cuenta y sigue. Sin él, una puerta
    /// que bloqueara todo teléfono que empezó de cero pasaría el caso de arriba.
    @Test("empezó de cero + sesión abierta por el intento → sigue")
    func empezoDeCero_sesionDelIntento_sigue() {
        #expect(check(.groupsOnly, associated: nil, freshStart: true, openedHere: true) == .proceed)
        #expect(check(.newAccount, associated: nil, freshStart: true, openedHere: true) == .proceed)
    }

    /// CONTROL del término del sello: sin empezar de cero no cambia nada. Con sesión privada el arranque ya asocia la sesión
    /// viva, así que una sesión de antes con `nil` es la de un teléfono solo-grupos, y se sigue promoviendo.
    @Test("sin empezar de cero, una sesión de antes sin asociada sigue como hasta hoy")
    func sinEmpezarDeCero_sesionDeAntes_sigue() {
        #expect(check(.groupsOnly, associated: nil, freshStart: false, openedHere: false) == .proceed)
        #expect(check(.newAccount, associated: nil, freshStart: false, openedHere: false) == .proceed)
    }

    /// Criterio 2 del ticket: quien migra con SU cuenta de grupos asociada la sigue promoviendo, también en un teléfono que
    /// empezó de cero. Ahí solo hay asociación si la persona firmó en la hoja de Grupos: `GroupsAccountAssociation.associate`
    /// no apunta con el sello una sesión que ya estaba abierta (`GroupsAccountAssociationStoreTests`).
    @Test("empezó de cero + la sesión ES la asociada → sigue, la abriera o no el intento")
    func empezoDeCero_asociada_sigue() {
        for openedHere in [true, false] {
            #expect(check(.groupsOnly, associated: true, freshStart: true, openedHere: openedHere) == .proceed)
        }
    }

    /// La regla solo retira un `.proceed`: lo que ya se bloqueaba conserva su aviso.
    @Test("empezó de cero: otra asociada y cuenta completa conservan su aviso")
    func empezoDeCero_noCambiaLosOtrosAvisos() {
        for openedHere in [true, false] {
            for discovery in [Discovery.groupsOnly, .newAccount] {
                #expect(check(discovery, associated: false, freshStart: true, openedHere: openedHere)
                        == .blocked(.anotherGroupsAccountAssociated))
            }
            for associated in [true, false, nil] as [Bool?] {
                #expect(check(.complete, associated: associated, freshStart: true, openedHere: openedHere)
                        == .blocked(.accountHasPersonalData))
            }
        }
    }

    /// «Reintentar» tras un fallo sigue en un teléfono que empezó de cero. El sello `.proceedMigration` lo deja un intento de
    /// este teléfono, y en el reintento su sesión ya no es «de este intento»: bloquearlo cerraba la única salida de la
    /// migración. El residual (un sello de la persona anterior que sobrevive al relevo) está escrito en el docblock de `check`.
    @Test("empezó de cero: la cuenta que ESTE dispositivo reclamó sigue con «Reintentar»")
    func empezoDeCero_reintentar_sigue() {
        #expect(check(.complete, associated: nil, claimedHere: true, freshStart: true, openedHere: false) == .proceed)
        #expect(check(.complete, associated: false, claimedHere: true, freshStart: true, openedHere: false)
                == .blocked(.anotherGroupsAccountAssociated))
    }

    // MARK: - El claim de «Migrar» que se quedó sin respuesta (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`)

    /// El bug que abrió el techo del 22 %: un claim que creó la cuenta y perdió la respuesta la deja `complete` sin sello.
    /// Con la marca, el reintento llega al claim —que sigue decidiendo— en vez de pararse con un «ya tiene datos» falso.
    /// CONTROL: sin marca y sin sello, la misma cuenta se sigue bloqueando.
    @Test("cuenta completa con un claim de «Migrar» sin respuesta → sigue; sin la marca, bloqueo")
    func completaConClaimSinRespuesta_sigue() {
        #expect(check(.complete, associated: nil, unansweredClaim: true) == .proceed)
        #expect(check(.complete, associated: true, unansweredClaim: true) == .proceed)
        #expect(check(.complete, associated: nil) == .blocked(.accountHasPersonalData), "control del caso")
    }

    /// La marca abre lo mismo que el sello y nada más: ni otra asociada, ni fuera de `complete`.
    @Test("la marca no abre otra asociada ni cambia las demás respuestas")
    func marcaAcotada() {
        #expect(check(.complete, associated: false, unansweredClaim: true) == .blocked(.anotherGroupsAccountAssociated))
        #expect(check(.groupsOnly, associated: false, unansweredClaim: true) == .blocked(.anotherGroupsAccountAssociated))
        #expect(check(.groupsOnly, associated: nil, unansweredClaim: true, freshStart: true, openedHere: false)
                == .blocked(.sessionFromBeforeFreshStart))
    }

    /// **La diferencia con el sello, y es la decisión:** en un teléfono que empezó de cero, con una sesión que no abrió este
    /// intento y sin asociada, la marca NO cuenta. Esa sesión puede ser de la persona anterior, y promoverla con el claim
    /// del mismo líder subiría las finanzas de la nueva a su cuenta (lo cazaron dos lentes). El sello sí sigue, y ese es su
    /// residual escrito; la marca no lo amplía. CONTROL: con la sesión abierta por el intento, o asociada, sí cuenta.
    @Test("empezó de cero + sesión de antes sin asociada: la marca no abre una cuenta completa")
    func empezoDeCero_marcaNoAbre() {
        #expect(check(.complete, associated: nil, unansweredClaim: true, freshStart: true, openedHere: false)
                == .blocked(.accountHasPersonalData))
        #expect(check(.complete, associated: nil, unansweredClaim: true, freshStart: true, openedHere: true) == .proceed)
        #expect(check(.complete, associated: true, unansweredClaim: true, freshStart: true, openedHere: false) == .proceed)
        #expect(check(.complete, associated: nil, claimedHere: true, freshStart: true, openedHere: false) == .proceed,
                "el sello conserva su «Reintentar»")
    }

    // MARK: - La parada en el claim

    /// `claim_account` promueve toda solo-grupos sin lo personal reclamado, así que una `groupsOnly` que llega a
    /// `existing_stable` es la que volvió a iCloud. Las demás se completaron entre la comprobación y el claim.
    @Test("claim devuelto con existing_stable: solo-grupos → volvió a iCloud; lo demás → ya tiene finanzas personales")
    func avisoDelClaim() {
        #expect(Logic.blockForClaimRefusal(checkedDiscovery: .groupsOnly, claimState: .existingStable) == .accountReturnedToICloud)
        #expect(Logic.blockForClaimRefusal(checkedDiscovery: .newAccount, claimState: .existingStable) == .accountHasPersonalData)
        #expect(Logic.blockForClaimRefusal(checkedDiscovery: .complete, claimState: .existingStable) == .accountHasPersonalData)
        #expect(Logic.blockForClaimRefusal(checkedDiscovery: nil, claimState: .existingStable) == .accountHasPersonalData)
    }

    /// `claiming_in_progress` es otro dispositivo migrando esa cuenta (Jürgen, 2026-09-16: parar y avisar). Nunca «volvió a
    /// iCloud», tampoco si la comprobación la vio solo-grupos: otro dispositivo la acaba de promover.
    @Test("claim devuelto con claiming_in_progress: siempre ya tiene finanzas personales")
    func avisoDelClaimEnCurso() {
        for discovery in [.groupsOnly, .newAccount, .complete, nil] as [CloudIdentityRoutingLogic.Discovery?] {
            #expect(Logic.blockForClaimRefusal(checkedDiscovery: discovery, claimState: .claimingInProgress)
                    == .accountHasPersonalData, "comprobación \(String(describing: discovery))")
        }
    }

    // MARK: - El canario

    /// Los slugs viajan al dashboard: cambiarlos parte la serie. Se fijan literales y distintos.
    @Test("los slugs del canario son estables y distintos")
    func slugs() {
        #expect(Logic.Block.accountHasPersonalData.slug == "personal_data")
        #expect(Logic.Block.anotherGroupsAccountAssociated.slug == "other_groups_account")
        #expect(Logic.Block.accountReturnedToICloud.slug == "returned_to_icloud")
        #expect(Logic.Block.sessionFromBeforeFreshStart.slug == "fresh_start_session")
        #expect(Set(Logic.Block.allCases.map(\.slug)).count == Logic.Block.allCases.count)
    }

    // MARK: - Los textos

    private typealias Copy = L10n.Storage.MigrateBlock

    /// Cada motivo dice algo distinto, y ninguno se queda en la clave cruda.
    @Test("título y cuerpo resueltos y distintos por motivo")
    func textosPorMotivo() {
        let titles = Logic.Block.allCases.map { Copy.title(for: $0) }
        let bodies = Logic.Block.allCases.map { Copy.body(for: $0, offersAnotherAccount: true, associatedEmail: nil) }
        for text in titles + bodies {
            #expect(!text.isEmpty)
            #expect(!text.hasPrefix("storage.migrateBlock."), "clave sin traducir: \(text)")
        }
        #expect(Set(titles).count == titles.count)
        #expect(Set(bodies).count == bodies.count)
        #expect(!Copy.useAnotherAccount.hasPrefix("storage."))
        #expect(!L10n.Storage.Errors.identityCheck.hasPrefix("storage."))
    }

    /// Cada motivo, con SU título: sin emparejar, intercambiar dos títulos dejaba los textos distintos y el test en verde.
    @Test("cada motivo tiene su título")
    func tituloPorMotivo() {
        #expect(Copy.title(for: .accountHasPersonalData) == Copy.personalDataTitle)
        #expect(Copy.title(for: .anotherGroupsAccountAssociated) == Copy.otherGroupsTitle)
        #expect(Copy.title(for: .accountReturnedToICloud) == Copy.returnedTitle)
        #expect(Copy.body(for: .accountReturnedToICloud, offersAnotherAccount: false, associatedEmail: nil)
                == Copy.returnedBody)
        #expect(Copy.title(for: .sessionFromBeforeFreshStart) == Copy.freshStartSessionTitle)
    }

    /// El aviso de la sesión de antes tiene un solo cuerpo: no nombra el correo (la sección «Grupos» ya lo enseña) ni cambia
    /// con «Usar otra cuenta», que con una sesión de antes nunca sale.
    @Test("«puede ser de otra persona» tiene un solo cuerpo")
    func cuerpoDeLaSesionDeAntes() {
        for offers in [true, false] {
            for email in [nil, "", "ana@example.com"] as [String?] {
                #expect(Copy.body(for: .sessionFromBeforeFreshStart, offersAnotherAccount: offers, associatedEmail: email)
                        == Copy.freshStartSessionBody)
            }
        }
    }

    /// **El cuerpo promete dos gestos, y en los 16 idiomas nombra los de verdad**: la sección «Grupos», que con esa sesión
    /// viva ofrece desasociar en un teléfono con sesión privada, y el botón «Activar la nube», que sin sesión abre la elección
    /// de cuenta. Se compara con el título de la sección y el del botón en el mismo idioma, y **entre comillas**: en alemán,
    /// japonés y chino el nombre de la sección también sale suelto («Deine Gruppen», 「グループは」, 「你的群组」), así que un
    /// `contains` a secas pasaba con una traducción que no mandara a ninguna sección (lo cazó la review).
    @Test("en todos los idiomas, el cuerpo nombra entre comillas la sección «Grupos» y el botón «Activar la nube»")
    func cuerpoNombraLosGestosReales() throws {
        #expect(SupportedLocale.allCases.count == 16)
        func quoted(_ name: String, in text: String) -> Bool {
            let pattern = "[«“„‘「]\\s?" + NSRegularExpression.escapedPattern(for: name) + "\\s?[»”“’」]"
            return text.range(of: pattern, options: .regularExpression) != nil
        }
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            let body = try #require(strings["storage.migrateBlock.freshStartSessionBody"], "\(locale.code): falta el cuerpo")
            let section = try #require(strings["storage.groups.title"], "\(locale.code): falta el título de la sección")
            let button = try #require(strings["storage.migrate.button"], "\(locale.code): falta el botón")
            #expect(quoted(section, in: body), "\(locale.code): el cuerpo no nombra entre comillas «\(section)»")
            #expect(quoted(button, in: body), "\(locale.code): el cuerpo no nombra entre comillas «\(button)»")
            #expect(!(strings["storage.migrateBlock.freshStartSessionTitle"] ?? "").isEmpty, "\(locale.code): falta el título")
        }
    }

    /// La nota de Apple sale junto a «Usar otra cuenta» y solo si la rechazada era de Apple (Jürgen, 2026-09-16).
    @Test("la nota de Apple: solo con «Usar otra cuenta» y una cuenta de Apple")
    func notaDeApple() {
        func block(_ offers: Bool, _ provider: CloudSignInProvider?) -> MigrationIdentityBlock {
            MigrationIdentityBlock(reason: .accountHasPersonalData, offersAnotherAccount: offers, associatedEmail: nil,
                                   rejectedProvider: provider)
        }
        #expect(block(true, .apple).showsAppleSameAccountNote)
        #expect(!block(true, .google).showsAppleSameAccountNote)
        #expect(!block(true, nil).showsAppleSameAccountNote)
        #expect(!block(false, .apple).showsAppleSameAccountNote, "sin el botón, la nota no tiene a qué referirse")
        #expect(!Copy.appleSameAccountNote.hasPrefix("storage."))
    }

    /// Dos avisos seguidos por el mismo motivo son dos avisos: la hoja se presenta por `id`.
    @Test("cada aviso es nuevo aunque repita motivo")
    func avisoNuevoCadaVez() {
        let a = MigrationIdentityBlock(reason: .accountHasPersonalData, offersAnotherAccount: true, associatedEmail: nil,
                                       rejectedProvider: nil)
        let b = MigrationIdentityBlock(reason: .accountHasPersonalData, offersAnotherAccount: true, associatedEmail: nil,
                                       rejectedProvider: nil)
        #expect(a.id != b.id)
    }

    /// «Usa otra cuenta» solo se dice cuando la hoja tiene ese botón: con la sesión de sus grupos, cambiar de cuenta exige
    /// desasociar primero, y el texto no puede mandar a un gesto que la pantalla no ofrece.
    @Test("«ya tiene finanzas personales» cambia de cuerpo con y sin «Usar otra cuenta»")
    func cuerpoSegunElBoton() {
        let conBoton = Copy.body(for: .accountHasPersonalData, offersAnotherAccount: true, associatedEmail: nil)
        let sinBoton = Copy.body(for: .accountHasPersonalData, offersAnotherAccount: false, associatedEmail: nil)
        #expect(conBoton == Copy.personalDataBody)
        #expect(sinBoton == Copy.personalDataBodyNoSwitch)
        #expect(conBoton != sinBoton)
    }

    @Test("«otra cuenta de grupos» nombra el correo cuando lo hay")
    func cuerpoConCorreo() {
        let conCorreo = Copy.body(for: .anotherGroupsAccountAssociated, offersAnotherAccount: true,
                                  associatedEmail: "ana@example.com")
        #expect(conCorreo.contains("ana@example.com"))
        #expect(Copy.body(for: .anotherGroupsAccountAssociated, offersAnotherAccount: true, associatedEmail: nil)
                == Copy.otherGroupsBody)
        #expect(Copy.body(for: .anotherGroupsAccountAssociated, offersAnotherAccount: true, associatedEmail: "")
                == Copy.otherGroupsBody, "un correo vacío no se interpola")
    }
}
