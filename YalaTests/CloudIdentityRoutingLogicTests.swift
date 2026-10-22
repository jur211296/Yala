//
//  CloudIdentityRoutingLogicTests.swift
//  YalaTests
//
//  Las **15 celdas** de la tabla del ADR 2026-09-09 §7 (bloque [I]) y los bordes donde «hay sesión
//  privada» cambia el destino. Es el alcance de tests que Jürgen fijó el 2026-09-09: «las 15 celdas de la
//  tabla + los bordes donde el eje decide (asociar, migrar a la nube, los dos bloqueos). No hace falta
//  escribir las 30 combinaciones ni afirmar las imposibles».
//
//  ## Por qué hay un recuento y no solo 15 `@Test`
//
//  Quince aserciones sueltas prueban que las celdas que ALGUIEN escribió están bien; no prueban que estén
//  todas. Si mañana `Gate` gana un caso, los quince siguen verdes y la celda nueva entra sin red —la
//  familia del «Executed 0 tests». `laTablaNoTieneCeldasSinAfirmar` cierra eso comparando el inventario
//  contra el producto cartesiano de los enums, así que un `case` nuevo ROMPE hasta que se le escriba su
//  celda.
//

import Testing

@testable import Yala

@Suite("Bloque [I] · la tabla de identidad en la nube")
struct CloudIdentityRoutingLogicTests {

    private typealias Logic = CloudIdentityRoutingLogic
    private typealias Gate = Logic.Gate
    private typealias Discovery = Logic.Discovery
    private typealias Destination = Logic.Destination
    private typealias DeviceSessionState = Logic.DeviceSessionState

    /// Una celda de la tabla, con los cuatro inputs y su destino esperado.
    private struct Celda {
        let gate: Gate
        let discovery: Discovery
        let deviceState: DeviceSessionState
        let isAssociated: Bool?
        let esperado: Destination
        let nombre: String

        func verificar() {
            let real = Logic.destination(
                gate: gate,
                discovery: discovery,
                deviceState: deviceState,
                isAssociatedGroupsAccount: isAssociated)
            #expect(real == esperado, """
                Celda «\(nombre)» rutea a \(real) y la tabla del ADR §7 dice \(esperado).
                Inputs: gate=\(gate) · discovery=\(discovery) · estado=\(deviceState) \
                · asociada=\(String(describing: isAssociated))
                """)
        }
    }

    /// **Las 15 celdas del ADR §7**, en el orden de su tabla. El eje se fija al valor que esa fila tiene
    /// por construcción: las dos del Welcome solo se alcanzan sin onboarding completado; la de Ajustes solo
    /// se ofrece con sesión privada viva.
    private static let quinceCeldas: [Celda] = [
        // ── Fila 1 · «Primera vez → nube» ──────────────────────────────────────────────────────────────
        Celda(gate: .welcomeFirstTimeCloud, discovery: .newAccount, deviceState: .fresh,
              isAssociated: nil, esperado: .createCompleteAccountThenPersonalOnboarding,
              nombre: "primera vez → nube · nueva"),
        Celda(gate: .welcomeFirstTimeCloud, discovery: .complete, deviceState: .fresh,
              isAssociated: nil, esperado: .adoptAsComplete,
              nombre: "primera vez → nube · completa (= «Ya tengo cuenta»)"),
        Celda(gate: .welcomeFirstTimeCloud, discovery: .groupsOnly, deviceState: .fresh,
              isAssociated: nil, esperado: .enterGroupsOnlyOfferingFullActivation,
              nombre: "primera vez → nube · solo grupos (ofrece Yala completo)"),

        // ── Fila 2 · «Ya tengo cuenta → Apple/Google» ──────────────────────────────────────────────────
        Celda(gate: .welcomeExistingAccount, discovery: .newAccount, deviceState: .fresh,
              isAssociated: nil, esperado: .offerSignUpNoAccountFound,
              nombre: "ya tengo cuenta · nueva (con botón al alta, no un callejón)"),
        Celda(gate: .welcomeExistingAccount, discovery: .complete, deviceState: .fresh,
              isAssociated: nil, esperado: .adoptAsComplete,
              nombre: "ya tengo cuenta · completa"),
        Celda(gate: .welcomeExistingAccount, discovery: .groupsOnly, deviceState: .fresh,
              isAssociated: nil, esperado: .enterGroupsOnly,
              nombre: "ya tengo cuenta · solo grupos (NO adopta)"),

        // ── Fila 3 · «Vengo por un grupo», sin sesión privada ──────────────────────────────────────────
        Celda(gate: .groups, discovery: .newAccount, deviceState: .fresh,
              isAssociated: nil, esperado: .continueGroupsSetup,
              nombre: "grupos sin privada · nueva"),
        Celda(gate: .groups, discovery: .complete, deviceState: .fresh,
              isAssociated: nil, esperado: .adoptAsCompleteAndOpenGroups,
              nombre: "grupos sin privada · completa (entra completa y abre Grupos)"),
        Celda(gate: .groups, discovery: .groupsOnly, deviceState: .fresh,
              isAssociated: nil, esperado: .continueGroupsSetup,
              nombre: "grupos sin privada · solo grupos"),

        // ── Fila 4 · «Privada + asociar grupos» ────────────────────────────────────────────────────────
        Celda(gate: .groups, discovery: .newAccount, deviceState: .privateSession,
              isAssociated: nil, esperado: .associateGroupsAccount,
              nombre: "privada + asociar · nueva"),
        Celda(gate: .groups, discovery: .complete, deviceState: .privateSession,
              isAssociated: nil, esperado: .blockedAccountIsComplete,
              nombre: "privada + asociar · completa (BLOQUEO)"),
        Celda(gate: .groups, discovery: .groupsOnly, deviceState: .privateSession,
              isAssociated: nil, esperado: .associateGroupsAccount,
              nombre: "privada + asociar · solo grupos"),

        // ── Fila 5 · «Privada → Ajustes: migrar a la nube» ─────────────────────────────────────────────
        Celda(gate: .settingsMigrateToCloud, discovery: .newAccount, deviceState: .privateSession,
              isAssociated: nil, esperado: .cutoverPrivateToCloud,
              nombre: "migrar a la nube · nueva (cutover)"),
        Celda(gate: .settingsMigrateToCloud, discovery: .complete, deviceState: .privateSession,
              isAssociated: nil, esperado: .blockedAccountIsComplete,
              nombre: "migrar a la nube · completa (BLOQUEO: sería una fusión)"),
        Celda(gate: .settingsMigrateToCloud, discovery: .groupsOnly, deviceState: .privateSession,
              isAssociated: true, esperado: .promoteAssociatedAccountThenCutover,
              nombre: "migrar a la nube · solo grupos que ES mi asociada (promover)"),
    ]

    @Test("las 15 celdas de la tabla del ADR §7 rutean donde dice el ADR")
    func lasQuinceCeldas() {
        for celda in Self.quinceCeldas { celda.verificar() }
        #expect(Self.quinceCeldas.count == 15,
                "el inventario dejó de tener 15 celdas: tiene \(Self.quinceCeldas.count)")
    }

    /// **El testigo aritmético.** Sin esto, quince `#expect` correctos conviven con una celda nueva sin
    /// cubrir: `Gate` gana un caso, el producto pasa de 15 a 18, y nadie se enteraría.
    ///
    /// Se calcula sobre los enums REALES (`allCases`) y no sobre un 15 escrito a mano: las cinco filas
    /// del ADR son cuatro puertas MÁS la de Grupos, que cuenta doble porque el estado del dispositivo la
    /// parte en dos.
    ///
    /// **`DeviceSessionState` queda FUERA del producto a propósito**, y esa es la parte que hay que
    /// entender: sus cuatro casos × cuatro puertas × tres resultados serían 48 celdas, y 33 son estados que
    /// esa puerta no alcanza — Jürgen lo acotó el 2026-09-09 («no hace falta afirmar las imposibles»). Lo
    /// que impide que un `case` nuevo del eje entre sin red es `elEjeCompletoTieneSuBorde`.
    @Test("MUTACIÓN: la tabla no tiene celdas sin afirmar")
    func laTablaNoTieneCeldasSinAfirmar() {
        let puertas = Gate.allCases.count
        let resultados = Discovery.allCases.count
        // +1 puerta: `.groups` aporta DOS filas lógicas (móvil limpio y sesión privada).
        let celdasEsperadas = (puertas + 1) * resultados
        #expect(Self.quinceCeldas.count == celdasEsperadas, """
            El producto de la tabla es \(celdasEsperadas) celdas (\(puertas) puertas + la de Grupos que \
            cuenta doble, × \(resultados) resultados) y el inventario afirma \(Self.quinceCeldas.count). \
            Si añadiste una puerta o un resultado, escríbele su celda antes de seguir.
            """)

        // Y que cada combinación (puerta × resultado × eje-que-aplica) aparezca UNA vez: un inventario con
        // el número correcto pero una celda duplicada y otra ausente pasaría el recuento de arriba.
        let claves = Self.quinceCeldas.map { "\($0.gate)|\($0.discovery)|\($0.deviceState)" }
        #expect(Set(claves).count == claves.count,
                "el inventario repite una combinación: \(claves.sorted())")
    }

    // MARK: - El segundo eje: dónde decide, y dónde no

    /// El borde que Jürgen pidió cubrir. La misma acción de la persona —crear un grupo, abrir una
    /// invitación— rutea distinto según si este móvil ya tiene una sesión privada.
    @Test("BORDE · la puerta de Grupos cambia de destino entre móvil limpio y sesión privada")
    func ejeDecideEnLaPuertaDeGrupos() {
        for discovery in Discovery.allCases {
            let sinPrivada = Logic.destination(
                gate: .groups, discovery: discovery,
                deviceState: .fresh, isAssociatedGroupsAccount: nil)
            let conPrivada = Logic.destination(
                gate: .groups, discovery: discovery,
                deviceState: .privateSession, isAssociatedGroupsAccount: nil)
            #expect(sinPrivada != conPrivada, """
                Con `\(discovery)` la puerta de Grupos rutea igual con y sin sesión privada (\(sinPrivada)). \
                El eje dejó de decidir, y con él se va el bloqueo que impide que una cuenta completa se \
                asocie a la Yala privada de otra persona.
                """)
        }
    }

    /// La otra mitad, y es la que evita que el eje se cuele donde no le toca: en las tres puertas
    /// restantes el destino **no** depende de él, porque su valor está fijado por construcción.
    @Test("BORDE · el eje NO decide en las puertas que no lo usan")
    func ejeNoDecideEnLasPuertasQueNoLoUsan() {
        for gate in Gate.allCases where gate != .groups {
            for discovery in Discovery.allCases {
                let conPrivada = Logic.destination(
                    gate: gate, discovery: discovery,
                    deviceState: .privateSession, isAssociatedGroupsAccount: true)
                let sinPrivada = Logic.destination(
                    gate: gate, discovery: discovery,
                    deviceState: .fresh, isAssociatedGroupsAccount: true)
                #expect(conPrivada == sinPrivada, """
                    `\(gate)` con `\(discovery)` cambió de destino según el eje (\(sinPrivada) → \
                    \(conPrivada)). Esa puerta no lo usa: si de verdad debe usarlo, esto es una fila nueva \
                    de la tabla y necesita su celda.
                    """)
            }
        }
    }

    // MARK: - Los dos bloqueos, y la sub-variante de «mi asociada»

    @Test("BORDE · migrar con una cuenta solo-grupos que NO es la asociada: una cuenta a la vez")
    func migrarConOtraCuentaDeGrupos() {
        #expect(Logic.destination(
            gate: .settingsMigrateToCloud, discovery: .groupsOnly,
            deviceState: .privateSession, isAssociatedGroupsAccount: false)
            == .blockedAnotherGroupsAccountAssociated)
    }

    /// **Una cuenta nueva tampoco, si hay OTRA asociada** (decisión de Jürgen, 2026-09-16): lo personal quedaría en la
    /// nueva y los grupos en la asociada. Sin asociada (`nil`, celda de las 15) recibe el cutover, que es el control.
    @Test("BORDE · migrar con una cuenta NUEVA teniendo otra asociada: una cuenta a la vez")
    func migrarConCuentaNuevaYOtraAsociada() {
        #expect(Logic.destination(
            gate: .settingsMigrateToCloud, discovery: .newAccount,
            deviceState: .privateSession, isAssociatedGroupsAccount: false)
            == .blockedAnotherGroupsAccountAssociated)
        #expect(Logic.destination(
            gate: .settingsMigrateToCloud, discovery: .newAccount,
            deviceState: .privateSession, isAssociatedGroupsAccount: true)
            == .cutoverPrivateToCloud, "la asociada nunca es una cuenta nueva, pero `true` no puede bloquear")
    }

    /// **`nil` en Ajustes es «no hay ninguna asociada», y ahí se promueve** (decisión de Jürgen, 2026-09-16).
    /// Hasta ese día esta celda bloqueaba, con la premisa de que «ningún call-site puede probar cuál es la
    /// asociada»; el paso 10 la persiste (`GroupsAccountAssociation.isAssociated(sub:)`, que devuelve `nil` sin
    /// registro). Bloquear aquí le decía «ya usas otra cuenta para tus grupos» a quien no tiene ninguna, y no
    /// protegía nada: la cuenta no tiene finanzas personales, y una cuenta nueva pasa la puerta igual.
    @Test("BORDE · migrar con una cuenta solo-grupos y NINGUNA asociada: se promueve")
    func migrarSinNingunaAsociadaPromueve() {
        #expect(Logic.destination(
            gate: .settingsMigrateToCloud, discovery: .groupsOnly,
            deviceState: .privateSession, isAssociatedGroupsAccount: nil)
            == .promoteAssociatedAccountThenCutover)
    }

    /// Los dos bloqueos dicen cosas distintas —«esa cuenta ya tiene Yala completo» frente a «una cuenta a
    /// la vez»— y la tabla tiene que producir **los dos**.
    ///
    /// La aserción va contra la TABLA y no contra el enum a propósito: `.blockedAccountIsComplete !=
    /// .blockedAnotherGroupsAccountAssociated` es cierto por construcción —colapsar los dos casos no
    /// compila— así que sería una aserción que no puede fallar. Lo que sí puede fallar, y es el riesgo
    /// real, es que alguien simplifique la tabla mandando las dos celdas al mismo bloqueo.
    @Test("MUTACIÓN: la tabla produce los DOS bloqueos, no uno solo")
    func laTablaProduceLosDosBloqueos() {
        let bloqueoPorCompleta = Logic.destination(
            gate: .groups, discovery: .complete,
            deviceState: .privateSession, isAssociatedGroupsAccount: nil)
        let bloqueoPorOtraCuenta = Logic.destination(
            gate: .settingsMigrateToCloud, discovery: .groupsOnly,
            deviceState: .privateSession, isAssociatedGroupsAccount: false)

        #expect(bloqueoPorCompleta == .blockedAccountIsComplete)
        #expect(bloqueoPorOtraCuenta == .blockedAnotherGroupsAccountAssociated)
        #expect(bloqueoPorCompleta != bloqueoPorOtraCuenta, """
            Las dos celdas de bloqueo rutean al mismo destino, así que una de las dos le va a contar al \
            usuario algo que no es: «ya tiene Yala completo» a quien solo tiene otra cuenta de grupos \
            asociada, o al revés.
            """)
    }

    // MARK: - Cuando el servidor no dice el tipo

    /// Hoy es el caso NORMAL: medido el 2026-09-10, ni staging ni producción sirven `kind` todavía. La
    /// regla es «lo que esa puerta hace hoy», no `groupsOnly` para todas — aplicarlo en el Welcome haría
    /// que quien tiene una cuenta completa dejara de adoptar y entrara a una app vacía.
    @Test("`kind` ausente ⇒ el comportamiento de HOY de cada puerta")
    func kindAusenteDegradaAlComportamientoDeHoy() {
        #expect(Logic.discovery(forExistingAccountWithUnknownKind: .welcomeExistingAccount) == .complete,
                "la re-entrada dejaría de adoptar: regresión en producción, no en un caso hipotético")
        #expect(Logic.discovery(forExistingAccountWithUnknownKind: .welcomeFirstTimeCloud) == .complete)
        #expect(Logic.discovery(forExistingAccountWithUnknownKind: .groups) == .groupsOnly,
                "la puerta de Grupos hoy no toca nada de lo personal, y sin el dato debe seguir así")
        #expect(Logic.discovery(forExistingAccountWithUnknownKind: .settingsMigrateToCloud) == .complete,
                "sin saber el tipo, migrar debe BLOQUEAR: jamás fusionar dos datasets personales")
    }

    /// **Control positivo del fallback**: sin esto, «`kind` ausente rutea como completa» se cumpliría
    /// igual si la función ignorara el `kind` SIEMPRE y devolviera `complete` a todo.
    @Test("CONTROL POSITIVO: con `kind` presente manda el `kind`, no el fallback de la puerta")
    func elKindPresenteMandaSobreElFallback() {
        #expect(Logic.discovery(exists: true, kind: .groupsOnly, gate: .welcomeExistingAccount)
            == .groupsOnly,
            "el fallback de esta puerta es `complete`: si gana él, el dato del servidor no sirve de nada")
        #expect(Logic.discovery(exists: true, kind: .complete, gate: .groups) == .complete,
            "el fallback de Grupos es `groupsOnly`: si gana él, la cuenta completa nunca adoptaría")
    }

    @Test("`exists == false` es «nueva», y ningún `kind` colado lo cambia")
    func existsFalseEsNueva() {
        for gate in Gate.allCases {
            #expect(Logic.discovery(exists: false, kind: nil, gate: gate) == .newAccount)
            // Un `kind` en una respuesta `exists:false` es una incoherencia del wire: gana `exists`.
            #expect(Logic.discovery(exists: false, kind: .complete, gate: gate) == .newAccount)
            #expect(Logic.discovery(exists: false, kind: .groupsOnly, gate: gate) == .newAccount)
        }
    }

    @Test("`exists == true` con `kind` ausente pasa por el fallback de la puerta")
    func existsTrueSinKindUsaElFallback() {
        for gate in Gate.allCases {
            #expect(Logic.discovery(exists: true, kind: nil, gate: gate)
                == Logic.discovery(forExistingAccountWithUnknownKind: gate))
        }
    }

    // MARK: - El eje, derivado de los estados reales del móvil

    /// Una fila por estado de la matriz de escenarios. El que carga el peso es **F**: en solo-grupos el
    /// `storageMode` sigue siendo `.icloud` porque la mini-app de Grupos jamás lo toca, así que sin mirar
    /// el eje de sesión privada esa persona pasaría por «tiene sesión privada» y la puerta de Grupos le
    /// bloquearía su propia cuenta.
    @Test("el eje de sesión privada, estado por estado de la matriz")
    func ejeDerivadoDeLosEstadosDelMovil() {
        // A/B · instalación fresca, o Welcome visible con store montado.
        #expect(Logic.deviceState(
            hasCompletedOnboarding: false, storageMode: .icloud, hasPrivateSession: true) == .fresh)
        // C/D · sesión privada, con o sin cuenta de grupos asociada.
        #expect(Logic.deviceState(
            hasCompletedOnboarding: true, storageMode: .icloud, hasPrivateSession: true) == .privateSession)
        // E · nube completa: la casilla «privada + nube completa» no existe (ADR §2).
        #expect(Logic.deviceState(
            hasCompletedOnboarding: true, storageMode: .cloud, hasPrivateSession: true) == .cloudComplete)
        // F · solo grupos. El `storageMode` MIENTE aquí, y es el caso que este término existe para cazar.
        #expect(Logic.deviceState(
            hasCompletedOnboarding: true, storageMode: .icloud, hasPrivateSession: false)
            == .cloudGroupsOnly,
            """
            Una persona en solo-grupos quedó clasificada como otra cosa. Si sale `privateSession`, volver a \
            firmar en la puerta de Grupos —lo que pasa si su sesión caduca a mitad de un join— le \
            bloquearía su propia cuenta si alguna vez la promovió a completa en otro dispositivo.
            """)
        // «Activé Yala completo desde solo-grupos» y lo personal se quedó en iCloud: sí hay privada.
        #expect(Logic.deviceState(
            hasCompletedOnboarding: true, storageMode: .icloud, hasPrivateSession: true)
            == .privateSession)
    }

    // MARK: - Qué destinos puede producir cada puerta

    /// **La red que sostiene una rama agrupada de `WelcomeCloudSignInView`.** Su `switch` sobre el destino
    /// nombra tres casos y manda el resto al camino de hoy, con el comentario «inalcanzables por esta
    /// puerta». Este test es lo que convierte esa frase en una afirmación medida: si la tabla empieza a
    /// producir un cuarto destino por el Welcome, aquí sale rojo antes de que allí se trague en silencio.
    ///
    /// El Welcome llega a la tabla siempre con `exists == true` —la rama `.accountMissing` se resuelve
    /// antes, con el faro— así que solo se comprueban `complete` y `groupsOnly`.
    @Test("MUTACIÓN: del Welcome con cuenta existente solo salen tres destinos")
    func soloTresDestinosSalenDelWelcome() {
        let permitidos: Set<String> = [
            "\(Destination.adoptAsComplete)",
            "\(Destination.enterGroupsOnly)",
            "\(Destination.enterGroupsOnlyOfferingFullActivation)",
        ]
        for gate in [Gate.welcomeFirstTimeCloud, .welcomeExistingAccount] {
            for discovery in [Discovery.complete, .groupsOnly] {
                let destino = Logic.destination(
                    gate: gate, discovery: discovery,
                    deviceState: .fresh, isAssociatedGroupsAccount: nil)
                #expect(permitidos.contains("\(destino)"), """
                    `\(gate)` con `\(discovery)` produce \(destino), que no está entre los tres que el \
                    `switch` de `WelcomeCloudSignInView.runSignInFlow` nombra. Allí caería en la rama \
                    agrupada y seguiría al adopt sin que nadie se enterase: dale su rama antes de seguir.
                    """)
            }
        }
    }


    /// La otra mitad: la puerta de Grupos **no** puede producir un adopt silencioso cuando hay sesión
    /// privada. Ese es el bloqueo entero del ADR, y en una línea.
    @Test("MUTACIÓN: con sesión privada, la puerta de Grupos nunca adopta")
    func conSesionPrivadaGruposNuncaAdopta() {
        for discovery in Discovery.allCases {
            let destino = Logic.destination(
                gate: .groups, discovery: discovery,
                deviceState: .privateSession, isAssociatedGroupsAccount: nil)
            #expect(destino != .adoptAsComplete && destino != .adoptAsCompleteAndOpenGroups, """
                Con `\(discovery)` y una sesión privada viva, la puerta de Grupos rutea a \(destino). \
                Adoptar ahí montaría la cuenta en la nube de una persona encima del Yala privado de otra.
                """)
        }
    }

    // MARK: - Los tres resultados son EXCLUYENTES

    /// El ADR §7 dice «uno de tres resultados **excluyentes**». Un cuarto caso en `Discovery` —«existe pero
    /// no sé de qué tipo»— convertiría la tabla de 15 celdas en una de 20 y obligaría a cada puerta a
    /// repetir su propio fallback, que es exactamente el bug que este bloque cierra.
    @Test("MUTACIÓN: `Discovery` tiene los tres resultados del ADR y ni uno más")
    func discoveryTieneTresCasos() {
        #expect(Discovery.allCases.count == 3, """
            `Discovery` tiene \(Discovery.allCases.count) casos. Si «el servidor calló» entró aquí como un \
            cuarto caso, sácalo: esa pregunta la contesta `discovery(forExistingAccountWithUnknownKind:)` \
            antes de llegar a la tabla.
            """)
    }

    /// **El otro medio testigo: que ningún estado del eje se quede sin borde.** El producto de arriba no
    /// mira `DeviceSessionState`, así que un `case` nuevo ahí no movería ningún número. Este test lo cubre
    /// desde el otro lado: recorre los cuatro estados por la puerta de Grupos —la única donde el eje
    /// decide— y exige que cada uno produzca un destino del conjunto permitido.
    @Test("MUTACIÓN: los cuatro estados del eje tienen su borde en la puerta de Grupos")
    func elEjeCompletoTieneSuBorde() {
        #expect(DeviceSessionState.allCases.count == 4, """
            `DeviceSessionState` tiene \(DeviceSessionState.allCases.count) casos. El eje creció y este \
            fichero no lo sabe: escríbele su borde en la puerta de Grupos antes de seguir.
            """)
        let permitidos: Set<String> = [
            "\(Destination.continueGroupsSetup)",
            "\(Destination.associateGroupsAccount)",
            "\(Destination.adoptAsCompleteAndOpenGroups)",
            "\(Destination.blockedAccountIsComplete)",
        ]
        for estado in DeviceSessionState.allCases {
            for discovery in Discovery.allCases {
                let destino = Logic.destination(
                    gate: .groups, discovery: discovery,
                    deviceState: estado, isAssociatedGroupsAccount: nil)
                #expect(permitidos.contains("\(destino)"),
                        "grupos · \(estado) × \(discovery) → \(destino), fuera del conjunto permitido")
            }
        }
    }

    // MARK: - Los dos estados de nube: el bug que el `Bool` escondía

    /// **El dispositivo ya está en la nube completa (E) y su sesión caducó.** La persona vuelve a firmar
    /// desde el tab Grupos, con su PROPIA cuenta, porque quería ver un grupo.
    ///
    /// Con el eje booleano esto daba `adoptAsCompleteAndOpenGroups` —«no hay sesión privada» era cierto por
    /// el motivo equivocado— y le montaba a pantalla completa la migración de su cuenta, **re-adoptando un
    /// dispositivo ya adoptado**. Peor si su claim local no estaba (reinstalación): el guard cross-cuenta
    /// le habría dicho «estos datos no son tuyos» al dueño de los datos.
    @Test("BORDE · ya en la nube completa: firmar desde Grupos NO re-adopta")
    func yaEnLaNubeCompletaNoReAdopta() {
        for discovery in Discovery.allCases {
            #expect(Logic.destination(
                gate: .groups, discovery: discovery,
                deviceState: .cloudComplete, isAssociatedGroupsAccount: nil)
                == .continueGroupsSetup, """
                Con `\(discovery)` y el dispositivo ya en la nube completa, la puerta de Grupos hace algo \
                distinto de seguir a su grupo. Este dispositivo ya tiene su sesión de nube resuelta: [I] no \
                tiene nada que rutear aquí.
                """)
        }
    }

    /// **El dispositivo está en solo-grupos (F).** No hay datos personales, pero tampoco los pidió: activar
    /// Yala completo es una elección explícita (ADR §8), no algo que pase por firmar para ver un grupo. Y
    /// el `storageMode` MIENTE en este estado —sigue `.icloud`, porque la mini-app de Grupos jamás lo
    /// toca— que es lo que hacía que el eje booleano lo confundiera con una sesión privada.
    @Test("BORDE · en solo-grupos: firmar desde Grupos no activa Yala completo")
    func enSoloGruposNoActivaYalaCompleto() {
        for discovery in Discovery.allCases {
            #expect(Logic.destination(
                gate: .groups, discovery: discovery,
                deviceState: .cloudGroupsOnly, isAssociatedGroupsAccount: nil)
                == .continueGroupsSetup)
        }
    }
}
