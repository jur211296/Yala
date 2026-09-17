//
//  GroupsAccountAssociation.swift
//  Yala
//
//  Paso 10 del rediseño de sesiones · **dónde vive «esta sesión privada tiene asociada ESTA cuenta de la
//  nube para grupos»**. La tabla que decide qué se hace con ese dato está en `GroupsAssociationLogic`;
//  aquí solo se escribe, se lee y se borra.
//
//  ## Dos almacenes, y ninguno de los dos sobra
//
//  · **iCloud-KV del Apple ID**, por `OwnerKeyValueStore` y con el molde exacto de `CloudBeacon`. Es lo
//    que hace que la asociación **viaje con la sesión privada**: el segundo móvil del mismo Apple ID, y
//    este mismo tras «Restaurar desde iCloud», saben que existe una cuenta de grupos aunque la SESIÓN no
//    haya viajado (el JWT vive en el llavero de un solo dispositivo). Es la fila «D · N (segundo móvil)»
//    de la matriz, que era un HUECO justamente porque la asociación se persistía solo local.
//  · **`UserDefaults`**, como espejo. El iCloud-KV puede tardar o no estar (sin iCloud, sin red, primer
//    arranque), y la fila de Ajustes y el empty state de Grupos leen en caliente. Escribir los dos y
//    leer el que conteste es el mismo patrón que ya usa el idioma.
//
//  **Se lee la UNIÓN, no la intersección**, y el orden es local → iCloud: lo local es lo que este
//  dispositivo decidió, y un iCloud-KV que todavía no ha sincronizado no debe borrar una asociación que
//  se acaba de escribir aquí.
//
//  ## PII: aquí sí, y es una decisión de Jürgen
//
//  `CloudBeacon` guarda el `sub` HASHEADO y lo dice en su cabecera. Esto guarda el correo **en claro**,
//  por decisión de Jürgen del 2026-09-09: «se guarda la identidad completa, no un hash — la fila tiene
//  que ser inequívoca cuando el usuario tiene varias cuentas». El destino es el iCloud-KV **del propio
//  Apple ID del usuario**, o sea su propia cuenta de iCloud; no sale de ahí, no va a ningún servidor de
//  Yala y no se muestra a nadie más. Lo que NO se guarda, porque no hace falta para nada: nombre, foto,
//  tokens.
//
//  ## Por qué el namespace de UserDefaults es `groups.*`
//
//  Misma razón que `GroupsSessionHistoryMarker`: `cloudSync.*` está EXCLUIDO del wipe a propósito
//  (`DataWipeService.removeUserPreferenceKeys`, «infra del propio sign-out/wipe»), así que una asociación
//  guardada ahí sobreviviría al «empiezo de cero» en silencio y le diría al humano SIGUIENTE que tiene
//  una cuenta de grupos esperando. En `groups.*` se la lleva `removeGroupsDomainPreferenceKeys`, que es
//  donde se decide esa frontera.
//

import Foundation

// MARK: - El registro

/// Lo que se guarda de la cuenta asociada. `Codable` porque el espejo local va como un solo blob JSON
/// (molde `GroupsPendingBridgeIntent`): una sola key que aparece y desaparece entera, sin estados a
/// medias entre campo y campo.
nonisolated struct GroupsAssociationRecord: Codable, Equatable, Sendable {
    /// `sub` de la cuenta (`CloudAuthService.currentUserID`). **Es el criterio de «la MISMA cuenta»** al
    /// re-asociar, y el único campo que no puede faltar.
    let sub: String
    /// `"apple"` / `"google"` — el string del wire, el mismo que guarda el faro.
    let provider: String?
    /// Correo tal cual, cuando el proveedor lo entregó. Ver la nota de PII en la cabecera.
    let email: String?
    /// `complete` / `groups_only` en el instante de asociar. Es una FOTO y puede envejecer: la verdad
    /// viva la sirve `AccountKindService`, que pregunta al backend. Se guarda porque la fila del segundo
    /// móvil tiene que decir algo antes de que haya sesión con la que preguntar.
    let kind: AccountKind?
    let associatedAt: Date
}

// MARK: - La puerta

/// Escribe y lee la asociación. **Un solo sitio**, por la misma razón que `OwnerKeyValueStore` existe:
/// «acordarse en N sitios» ya falló dos veces en este repo.
@MainActor
final class GroupsAccountAssociation {

    /// Claves del iCloud-KV. WIRE-STABLE: un rename las deja ilegibles para el otro dispositivo, que
    /// puede estar en una versión anterior de la app.
    enum Keys {
        static let associated = "yala.groups.associated"
        static let sub = "yala.groups.associatedSub"
        static let provider = "yala.groups.associatedProvider"
        static let email = "yala.groups.associatedEmail"
        static let kind = "yala.groups.associatedKind"
        static let associatedAt = "yala.groups.associatedAt"
        /// **El tombstone del desasociar.** Sin él, «desasociado» es solo la AUSENCIA de las otras keys, y
        /// el segundo armador de cualquier otro dispositivo del Apple ID con sesión viva las repone en su
        /// siguiente arranque: la desasociación se deshacía sola, sin que nadie tocara nada.
        static let detachedAt = "yala.groups.detachedAt"

        static let all = [associated, sub, provider, email, kind, associatedAt, detachedAt]
    }

    /// Espejo local. Namespace `groups.*` — ver la cabecera.
    static let localKey = "groups.associatedAccount"

    static let shared = GroupsAccountAssociation(iKV: OwnerKeyValueStore.shared)

    private let iKV: BeaconKeyValueStore
    private let defaults: UserDefaults

    /// `iKV` va SIN valor por defecto a propósito: un `= OwnerKeyValueStore.shared` se evalúa en el
    /// contexto del LLAMADOR, que puede ser `nonisolated`, y eso deja un warning de aislamiento en cada
    /// construcción. Producción usa `shared`; los tests inyectan su doble.
    init(iKV: BeaconKeyValueStore, defaults: UserDefaults = .standard) {
        self.iKV = iKV
        self.defaults = defaults
    }

    // MARK: Lectura

    /// La asociación vigente, o `nil`. Local primero — ver «se lee la UNIÓN» en la cabecera.
    func read() -> GroupsAssociationRecord? {
        if let local = readLocal() { return local }
        return readICloud()
    }

    var hasAssociation: Bool { read() != nil }

    /// ¿Hay un desasociar explícito registrado en el iCloud-KV del Apple ID? Es lo que impide que otro
    /// dispositivo con sesión viva reponga la asociación que esta persona acaba de soltar.
    var isDetached: Bool { iKV.double(forKey: Keys.detachedAt) > 0 }

    /// El `sub` asociado, para `CloudIdentityRoutingLogic.isAssociatedGroupsAccount` y para decidir el
    /// re-enlace de las filas dormidas.
    var associatedSub: String? { read()?.sub }

    /// ¿Es ESTA cuenta la asociada? `nil` cuando no hay asociación registrada, `false` cuando hay otra. No son lo mismo
    /// y la tabla de [I] no los trata igual: en la puerta de «Migrar a la nube» `false` bloquea («una cuenta a la vez») y
    /// `nil` deja seguir, porque sin ninguna asociada no hay otra cuenta de la que hablar (Jürgen, 2026-09-16; hasta ese
    /// día `nil` bloqueaba la promoción). Devolver `false` sin registro bloquearía a quien no tiene ninguna.
    ///
    /// **Con el dominio sellado, `nil` también sale con la sesión de la persona anterior**: aquí no se lee el iCloud-KV y
    /// nadie apunta una sesión que ya estaba abierta (ver `associate`). Por eso la puerta de «Migrar a la nube» no lee solo
    /// este valor: con el sello y una sesión que no abrió el intento, `nil` no deja seguir
    /// (`StorageMigrationIdentityGateLogic.check`). Y `true` con el sello sale solo de un sign-in hecho en este teléfono.
    func isAssociated(sub: String?) -> Bool? {
        guard let stored = associatedSub else { return nil }
        guard let sub, !sub.isEmpty else { return false }
        return stored == sub
    }

    private func readLocal() -> GroupsAssociationRecord? {
        guard let data = defaults.data(forKey: Self.localKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(GroupsAssociationRecord.self, from: data)
        } catch {
            // Payload ilegible (formato viejo, escritura truncada). Se descarta el espejo y se cae al
            // iCloud-KV, que es la copia autoritativa para el dispositivo que no la escribió.
            #if DEBUG
            print("GroupsAccountAssociation: espejo local ilegible, se descarta: \(error)")
            #endif
            defaults.removeObject(forKey: Self.localKey)
            return nil
        }
    }

    private func readICloud() -> GroupsAssociationRecord? {
        // **Con el dominio de Grupos sellado, el iCloud-KV no se lee.** Ese sello lo escribe el «empiezo
        // de cero» del Welcome y significa «este teléfono pasó a otro humano»: la asociación que haya en
        // el iCloud-KV es del ANTERIOR, y leerla le enseñaría al nuevo su CORREO en la fila de Ajustes.
        //
        // Se cierra AQUÍ y no borrando las keys en el handover, que era lo obvio y es peor: el iCloud-KV
        // pertenece al Apple ID, así que ese borrado viaja y le quitaría al dueño la asociación en su
        // iPad. La invariante «al iKV va UNA sola key desde el handover» está pinneada en
        // `HandoverGroupsDomainTests`, y este guard la respeta. El espejo local sí se barre allí.
        //
        // El sello no se levanta nunca en ese dispositivo (`GroupsDomainAdoptionLogic` lo combina con la
        // adopción en vez de borrarlo), así que el humano nuevo jamás lee esta copia: la suya la escribe
        // él al asociar, y el espejo local tiene prioridad de lectura.
        guard !defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart) else { return nil }
        guard iKV.bool(forKey: Keys.associated) else { return nil }
        // El `sub` es lo único sin lo que el registro no sirve: sin él no se puede decidir «misma cuenta»
        // ni servir `isAssociatedGroupsAccount`. Un registro a medias se trata como ausente.
        guard let sub = iKV.string(forKey: Keys.sub), !sub.isEmpty else { return nil }
        let at = iKV.double(forKey: Keys.associatedAt)
        return GroupsAssociationRecord(
            sub: sub,
            provider: iKV.string(forKey: Keys.provider),
            email: iKV.string(forKey: Keys.email),
            kind: iKV.string(forKey: Keys.kind).flatMap(AccountKind.init(rawValue:)),
            associatedAt: at > 0 ? Date(timeIntervalSince1970: at) : .distantPast)
    }

    // MARK: Escritura

    /// Registra la asociación. Idempotente: re-escribir la MISMA cuenta no mueve `associatedAt`, para que
    /// el dato signifique «desde cuándo está asociada» y no «cuándo se abrió la app por última vez».
    ///
    /// Un `sub` vacío **no escribe nada** y lo dice: sin él, el registro no puede contestar ninguna de las
    /// tres preguntas para las que existe.
    ///
    /// **Con el dominio sellado, solo se apunta una sesión abierta por el propio sign-in** (ticket
    /// `fresh-start-keeps-a-groups-session-that-migrate-promotes`). Desde el 2026-09-17 «Empezar desde cero» RETIRA la sesión
    /// en la nube (`CloudSessionRetirement`), pero el retiro es asíncrono y una reinstalación no deja sello, así que una sesión
    /// que ya estaba abierta todavía puede ser de la persona anterior. Apuntarla le daba a la puerta de «Migrar a la nube» un
    /// `true` que promovía esa cuenta con las finanzas de la persona nueva. Pasaba por el cinturón de `GroupsSignInView`: una
    /// unión por invitación que vuelve pidiendo sesión con la sesión aún guardada re-presenta la hoja, y la hoja reusa la sesión
    /// viva sin enseñar botones. Hoy llega ahí con un 401 del gateway; hasta el 2026-09-17 también llegaba con el token que no
    /// se renovaba sin red (`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`). Es la misma
    /// regla que ya cumplía `GroupsAssociationRegistrar`, puesta en el escritor para que no dependa de cada llamador.
    ///
    /// - Parameter sessionOpenedByThisSignIn: la sesión la abrió el gesto que asocia, así que la persona eligió la cuenta.
    ///   `false` con una sesión que ya estaba abierta: el cinturón de la hoja de Grupos y el registrador del arranque.
    @discardableResult
    func associate(
        sub: String?,
        provider: String?,
        email: String?,
        kind: AccountKind?,
        sessionOpenedByThisSignIn: Bool,
        now: Date = .now
    ) -> Bool {
        guard let sub, !sub.isEmpty else {
            #if DEBUG
            print("GroupsAccountAssociation: asociar sin `sub` — no se escribe nada")
            #endif
            return false
        }
        guard sessionOpenedByThisSignIn
                || !defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart) else {
            #if DEBUG
            print("GroupsAccountAssociation: dominio sellado y sesión que ya estaba abierta — no se asocia")
            #endif
            return false
        }
        let previo = read()
        let record = GroupsAssociationRecord(
            sub: sub,
            provider: provider,
            email: email,
            kind: kind,
            associatedAt: previo?.sub == sub ? previo?.associatedAt ?? now : now)
        writeLocal(record)
        // **Con el dominio sellado, al iCloud-KV no se escribe.** Ese sello significa «este teléfono pasó
        // a otro humano», y el iCloud-KV sigue siendo el del Apple ID del ANTERIOR: escribir ahí metería
        // el correo del nuevo en la cuenta de iCloud del viejo, que es la misma fuga que el guard de
        // lectura evita en la otra dirección. Con el sello puesto la asociación vive solo en local, que
        // es exactamente el alcance que le corresponde a un teléfono prestado.
        if !defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart) {
            writeICloud(record)
        }
        return true
    }

    /// Borra la asociación de los dos almacenes. Simétrico a `associate`.
    /// Borra la asociación de los dos almacenes y **deja el tombstone**. Simétrico a `associate`, que lo
    /// retira.
    ///
    /// El tombstone es la mitad que faltaba: el iCloud-KV es del Apple ID, así que la ausencia de las
    /// keys no distingue «nunca hubo» de «se soltó», y el registrador de OTRO dispositivo con sesión viva
    /// la reponía en su siguiente arranque — la desasociación se deshacía sola. Con él, quien reponga
    /// tiene que ser un gesto de asociar, no un arranque.
    ///
    /// **Con el dominio sellado, solo se borra el espejo local.** Es el gesto al que manda el aviso de «Migrar a la nube»
    /// cuando la sesión puede ser de la persona anterior (ticket `fresh-start-keeps-a-groups-session-that-migrate-promotes`),
    /// y en ese teléfono el iCloud-KV sigue siendo el del Apple ID de antes: borrar sus keys y dejar el tombstone le quitaría
    /// la asociación en sus otros dispositivos y apagaría allí el registrador. Es la simetría de `associate` y `readICloud`,
    /// que con el sello tampoco tocan el iCloud-KV.
    func clear(now: Date = .now) {
        defaults.removeObject(forKey: Self.localKey)
        guard !defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart) else { return }
        for key in Keys.all where key != Keys.detachedAt { iKV.removeObject(forKey: key) }
        iKV.setDouble(now.timeIntervalSince1970, forKey: Keys.detachedAt)
        iKV.synchronize()
    }

    private func writeLocal(_ record: GroupsAssociationRecord) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            defaults.set(try encoder.encode(record), forKey: Self.localKey)
        } catch {
            #if DEBUG
            print("GroupsAccountAssociation: no se pudo escribir el espejo local: \(error)")
            #endif
        }
    }

    private func writeICloud(_ record: GroupsAssociationRecord) {
        // El tombstone se retira aquí y solo aquí: asociar es el único gesto que deshace un desasociar.
        iKV.removeObject(forKey: Keys.detachedAt)
        iKV.setBool(true, forKey: Keys.associated)
        iKV.setString(record.sub, forKey: Keys.sub)
        // Los opcionales se RETIRAN cuando no hay valor en vez de dejarse como estaban: si no, una cuenta
        // nueva sin correo heredaría el correo de la anterior y la fila mentiría.
        write(record.provider, to: Keys.provider)
        write(record.email, to: Keys.email)
        write(record.kind?.rawValue, to: Keys.kind)
        iKV.setDouble(record.associatedAt.timeIntervalSince1970, forKey: Keys.associatedAt)
        iKV.synchronize()
    }

    private func write(_ value: String?, to key: String) {
        if let value, !value.isEmpty {
            iKV.setString(value, forKey: key)
        } else {
            iKV.removeObject(forKey: key)
        }
    }
}

// MARK: - El registrador

/// Pone la asociación al día desde la sesión viva. Existe por lo mismo que el SEGUNDO armador de
/// `GroupsSessionHistoryMarker`: el parque que ya tiene sesión de grupos **no va a pasar por ningún
/// sign-in nuevo**, así que sin esto su fila diría «no tienes cuenta de grupos» mientras la tiene.
///
/// No es un cinturón defensivo: son dos caminos que cubren poblaciones distintas.
///  1. El sign-in de Grupos, para quien asocia a partir de ahora.
///  2. El arranque con sesión viva, para quien ya la tenía.
@MainActor
enum GroupsAssociationRegistrar {

    /// Escribe la asociación si hay sesión de grupos viva **y** este dispositivo tiene sesión privada.
    ///
    /// El eje privada/nube se toma de `CloudIdentityRoutingLogic.deviceState`, que es la MISMA derivación
    /// que usa la tabla de [I]: en `.cloudComplete` grupos ES la cuenta personal y no hay nada que
    /// asociar (ADR §4), y en `.cloudGroupsOnly` / `.fresh` no hay sesión privada a la que ligarla.
    /// La identidad de la sesión viva, como DATO. `CloudAuthService` es una clase final con singleton y
    /// sin protocolo, así que pasarlo entero dejaría este registrador sin forma de probarse: los tests
    /// acabarían inyectando el singleton real y afirmando sobre lo que el simulador tuviera puesto. Lo que
    /// el registrador necesita son cuatro campos.
    struct LiveIdentity: Equatable {
        let hasSession: Bool
        let sub: String?
        let provider: String?
        let email: String?

        @MainActor
        static func live(_ auth: CloudAuthService) -> LiveIdentity {
            LiveIdentity(
                hasSession: auth.hasSession,
                sub: auth.currentUserID,
                provider: auth.storedProvider(),
                email: auth.capturedEmail())
        }
    }

    static func syncFromLiveSessionIfNeeded(
        deviceState: CloudIdentityRoutingLogic.DeviceSessionState,
        identity: LiveIdentity,
        kind: AccountKind? = nil,
        store: GroupsAccountAssociation,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) {
        guard deviceState == .privateSession, identity.hasSession else { return }
        // **Con el dominio sellado para un usuario nuevo, no se registra nada.** El JWT vive en su propio
        // llavero y sobrevive al relevo por sí solo; desde el 2026-09-17 el «empiezo de cero» lo RETIRA
        // (`CloudSessionRetirement`, armado en `DataWipeService.wipeLocalGroupsDomain`), pero ese retiro es
        // un `Task` y este arranque puede adelantarlo. Sin este guard, el primer arranque del humano
        // SIGUIENTE volvería a escribir la asociación del ANTERIOR, deshaciendo en silencio el barrido del
        // handover. Es el mismo sello que cierra el bridge por la misma razón.
        guard !defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart) else { return }
        // **Un desasociar explícito no se deshace en un arranque.** El tombstone viaja por el iCloud-KV
        // del Apple ID, así que este guard vale también para el OTRO dispositivo, que es justo donde
        // estaba el agujero: el que no desasoció seguía con su sesión viva y reponía las keys.
        guard !store.isDetached else { return }
        guard let sub = identity.sub, !sub.isEmpty else { return }
        // Re-escribir la misma cuenta es barato e idempotente, y además REFRESCA correo y `kind`: el
        // correo puede haberse capturado después del primer registro, y el `kind` cambia con una
        // promoción. Lo que no se toca es `associatedAt` (ver `associate`).
        store.associate(
            sub: sub,
            provider: identity.provider,
            email: identity.email,
            kind: kind,
            sessionOpenedByThisSignIn: false,
            now: now)
    }
}
