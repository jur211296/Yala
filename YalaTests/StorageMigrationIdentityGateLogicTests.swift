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
                       openedHere: Bool = false,
                       migrationInProgress: Bool = false,
                       beacon: Bool = false) -> Logic.Check {
        Logic.check(answer: .discovered(discovery), deviceState: state, isAssociatedGroupsAccount: associated,
                    claimedForMigrationHere: claimedHere, hasUnansweredMigrationClaim: unansweredClaim,
                    sessionOpenedByThisAttempt: openedHere, deviceSealedForFreshStart: freshStart,
                    accountMigrationInProgress: migrationInProgress, beaconNamesThisAccount: beacon)
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
                                            deviceSealedForFreshStart: freshStart,
                                            accountMigrationInProgress: true,
                                            beaconNamesThisAccount: true) == .couldNotCheck)
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
        // Con y sin faro: `existing_stable` no es una ida en curso, así que el faro no cambia nada aquí.
        for beacon in [false, true] {
            #expect(Logic.blockForClaimRefusal(checkedDiscovery: .groupsOnly, claimState: .existingStable,
                                               beaconNamesThisAccount: beacon) == .accountReturnedToICloud)
            #expect(Logic.blockForClaimRefusal(checkedDiscovery: .newAccount, claimState: .existingStable,
                                               beaconNamesThisAccount: beacon) == .accountHasPersonalData)
            #expect(Logic.blockForClaimRefusal(checkedDiscovery: .complete, claimState: .existingStable,
                                               beaconNamesThisAccount: beacon) == .accountHasPersonalData)
            #expect(Logic.blockForClaimRefusal(checkedDiscovery: nil, claimState: .existingStable,
                                               beaconNamesThisAccount: beacon) == .accountHasPersonalData)
        }
    }

    /// `claiming_in_progress` es otro dispositivo migrando esa cuenta (Jürgen, 2026-09-16: parar y avisar). Nunca «volvió a
    /// iCloud», tampoco si la comprobación la vio solo-grupos: otro dispositivo la acaba de promover.
    @Test("claim devuelto con claiming_in_progress sin faro: ya tiene finanzas personales")
    func avisoDelClaimEnCurso() {
        for discovery in [.groupsOnly, .newAccount, .complete, nil] as [CloudIdentityRoutingLogic.Discovery?] {
            #expect(Logic.blockForClaimRefusal(checkedDiscovery: discovery, claimState: .claimingInProgress,
                                               beaconNamesThisAccount: false)
                    == .accountHasPersonalData, "comprobación \(String(describing: discovery))")
        }
    }

    /// Ticket `settings-migrate-blocks-a-second-device-before-its-marker`, la segunda capa: si la comprobación pasó antes de
    /// que el primer iPhone reclamara la cuenta, es el claim el que contesta `claiming_in_progress`. Con el faro de esta
    /// cuenta, es otro dispositivo de esta misma persona, y el aviso lo dice —venga de donde venga la comprobación—.
    @Test("claim devuelto con claiming_in_progress y el faro de la cuenta: otro de tus dispositivos")
    func avisoDelClaimEnCursoConFaro() {
        for discovery in [.groupsOnly, .newAccount, .complete, nil] as [CloudIdentityRoutingLogic.Discovery?] {
            #expect(Logic.blockForClaimRefusal(checkedDiscovery: discovery, claimState: .claimingInProgress,
                                               beaconNamesThisAccount: true)
                    == .migrationInProgressOnAnotherDevice, "comprobación \(String(describing: discovery))")
        }
    }

    // MARK: - El segundo iPhone del mismo iCloud (ticket `settings-migrate-blocks-a-second-device-before-its-marker`)

    /// El bug del ticket: con la ida del primer iPhone en curso, el segundo leía «Esa cuenta ya tiene finanzas personales».
    /// Con la ida en curso y el faro de esta cuenta, el motivo es otro —y sigue siendo un BLOQUEO—, se asocie lo que se asocie
    /// y venga de donde venga la sesión.
    @Test("cuenta completa + ida en curso + faro de la cuenta → otro de tus dispositivos")
    func idaEnCursoConFaro_motivoNuevo() {
        for associated in [true, false, nil] as [Bool?] {
            for freshStart in [false, true] {
                for openedHere in [false, true] {
                    #expect(check(.complete, associated: associated, freshStart: freshStart, openedHere: openedHere,
                                  migrationInProgress: true, beacon: true)
                            == .blocked(.migrationInProgressOnAnotherDevice),
                            "asociada=\(String(describing: associated)) sellado=\(freshStart) abierta=\(openedHere)")
                }
            }
        }
    }

    /// **La mitad que no se puede perder**: sin ida en curso, una cuenta completa es de datos que no son de este teléfono y el
    /// aviso es el de siempre, con faro o sin él.
    @Test("cuenta completa sin ida en curso → ya tiene finanzas personales, con faro o sin él")
    func sinIdaEnCurso_motivoDeSiempre() {
        for beacon in [false, true] {
            for associated in [true, false, nil] as [Bool?] {
                #expect(check(.complete, associated: associated, migrationInProgress: false, beacon: beacon)
                        == .blocked(.accountHasPersonalData),
                        "faro=\(beacon) asociada=\(String(describing: associated))")
            }
        }
    }

    /// Sin el faro de esta cuenta, «otro de tus dispositivos» podría ser falso: la cuenta en curso puede ser de otra persona
    /// que firmó con su cuenta en este teléfono.
    @Test("cuenta completa + ida en curso SIN el faro de la cuenta → ya tiene finanzas personales")
    func idaEnCursoSinFaro_motivoDeSiempre() {
        #expect(check(.complete, associated: nil, migrationInProgress: true, beacon: false)
                == .blocked(.accountHasPersonalData))
    }

    /// Los dos datos solo cambian el MOTIVO de una parada que ya existía: no abren nada que estuviera cerrado ni cierran nada
    /// que estuviera abierto. «Reintentar» del propio líder sigue pasando, y una cuenta nueva o solo-grupos sigue igual.
    @Test("la ida en curso y el faro no cambian ningún veredicto que no fuera «ya tiene finanzas personales»")
    func idaEnCurso_noTocaLosDemasVeredictos() {
        for discovery in [.newAccount, .groupsOnly, .complete] as [Discovery] {
            for associated in [true, false, nil] as [Bool?] {
                for claimedHere in [false, true] {
                    for freshStart in [false, true] {
                        let before = check(discovery, associated: associated, claimedHere: claimedHere,
                                           freshStart: freshStart)
                        let after = check(discovery, associated: associated, claimedHere: claimedHere,
                                          freshStart: freshStart, migrationInProgress: true, beacon: true)
                        if before == .blocked(.accountHasPersonalData) {
                            #expect(after == .blocked(.migrationInProgressOnAnotherDevice))
                        } else {
                            #expect(after == before, """
                                \(discovery) asociada=\(String(describing: associated)) sellado=\(claimedHere) \
                                desdeCero=\(freshStart)
                                """)
                        }
                    }
                }
            }
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
        #expect(Logic.Block.migrationInProgressOnAnotherDevice.slug == "other_device_migrating")
        #expect(Set(Logic.Block.allCases.map(\.slug)).count == Logic.Block.allCases.count)
    }

    // MARK: - Lo que la tarjeta recuerda (ticket `migrate-card-keeps-promising-an-account-the-check-refused`)

    private func session(_ sub: String?, epoch: Int, live: Bool = true) -> Logic.LiveSession {
        Logic.LiveSession(hasSession: live, sub: sub, sessionEpoch: epoch)
    }

    /// El bug del ticket: tras «Entendido» la tarjeta seguía prometiendo la cuenta rechazada. Con la misma sesión viva, el
    /// rechazo se recuerda y la tarjeta lo enseña, con su motivo.
    @Test("la misma sesión viva recuerda el rechazo, con su motivo",
          arguments: StorageMigrationIdentityGateLogic.Block.allCases)
    func mismaSesionRecuerda(reason: StorageMigrationIdentityGateLogic.Block) {
        let remembered = Logic.refusalToRemember(reason: reason, session: session("sub-a", epoch: 3))
        #expect(remembered == Logic.RefusedSession(reason: reason, sub: "sub-a", sessionEpoch: 3))
        #expect(Logic.cardRefusal(remembered: remembered, session: session("sub-a", epoch: 3)) == reason)
    }

    /// La sesión que abrió el intento se cierra antes del aviso: sin sesión viva no hay cuenta que la tarjeta prometa, y
    /// recordar algo ahí lo ataría a «ninguna sesión».
    @Test("sin sesión viva al avisar, no se recuerda nada")
    func sinSesionNoRecuerda() {
        #expect(Logic.refusalToRemember(reason: .accountHasPersonalData, session: session(nil, epoch: 4, live: false)) == nil)
    }

    /// Otra cuenta, u otra sesión de la misma cuenta, olvidan: cerrar y volver a entrar puede cambiar la respuesta.
    @Test("otra cuenta u otra sesión olvidan el rechazo")
    func otraSesionOlvida() {
        let remembered = Logic.RefusedSession(reason: .accountHasPersonalData, sub: "sub-a", sessionEpoch: 3)
        #expect(Logic.cardRefusal(remembered: remembered, session: session("sub-b", epoch: 3)) == nil,
                "otra cuenta con la misma época")
        #expect(Logic.cardRefusal(remembered: remembered, session: session("sub-a", epoch: 5)) == nil,
                "la misma cuenta en otra sesión")
        #expect(Logic.cardRefusal(remembered: remembered, session: session(nil, epoch: 3)) == nil,
                "sin `sub` legible no es la misma cuenta")
        #expect(Logic.cardRefusal(remembered: remembered, session: session("sub-a", epoch: 3, live: false)) == nil,
                "sin sesión viva la tarjeta no promete nada que apagar")
        #expect(Logic.cardRefusal(remembered: nil, session: session("sub-a", epoch: 3)) == nil)
    }

    /// La nota de la tarjeta: una por motivo, resuelta, y ninguna repite el «No cambiamos nada» de la hoja.
    @Test("la nota de la tarjeta, resuelta y distinta por motivo")
    func notaDeLaTarjeta() {
        let notes = Logic.Block.allCases.map { L10n.Storage.Migrate.refusedNote(for: $0) }
        for note in notes {
            #expect(!note.isEmpty)
            #expect(!note.hasPrefix("storage."), "clave sin traducir: \(note)")
        }
        #expect(Set(notes).count == notes.count, "dos motivos con la misma nota")
        #expect(!notes.contains(L10n.Storage.Migrate.accountReuseNoteGeneric))
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
        #expect(Copy.title(for: .migrationInProgressOnAnotherDevice) == Copy.otherDeviceTitle)
    }

    /// «Otro de tus dispositivos» tiene un solo cuerpo: no ofrece otra cuenta en el texto (el botón, si sale, ya lo dice) y
    /// no nombra el correo de grupos.
    @Test("«otro de tus dispositivos» tiene un solo cuerpo, y la tarjeta su nota")
    func cuerpoDeOtroDispositivo() {
        for offers in [true, false] {
            for email in [nil, "", "ana@example.com"] as [String?] {
                #expect(Copy.body(for: .migrationInProgressOnAnotherDevice, offersAnotherAccount: offers,
                                  associatedEmail: email) == Copy.otherDeviceBody)
            }
        }
        #expect(L10n.Storage.Migrate.refusedNote(for: .migrationInProgressOnAnotherDevice)
                != L10n.Storage.Migrate.refusedNote(for: .accountHasPersonalData))
    }

    /// El texto es la decisión de Jürgen (2026-10-08): el título lo dice tal cual, y ni el título ni el cuerpo ni la nota
    /// repiten «ya tiene finanzas personales», que es el texto falso que el ticket retira.
    @Test("en español, el aviso dice lo que decidió Jürgen y no repite el texto falso")
    func textoDeJurgen() throws {
        let strings = StringsFileParser.parseStrings(forLocale: "es-419")
        let title = try #require(strings["storage.migrateBlock.otherDeviceTitle"])
        let body = try #require(strings["storage.migrateBlock.otherDeviceBody"])
        let note = try #require(strings["storage.migrate.refusedOtherDevice"])
        #expect(title == "Otro de tus dispositivos está llevando tus datos a la nube")
        for text in [title, body, note] {
            #expect(!text.contains("finanzas personales"), "repite el texto falso: \(text)")
        }
        #expect(body.contains("reinténtala allí"))
        #expect(note.contains("reinténtala en ese dispositivo"))
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
