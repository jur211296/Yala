//
//  GroupInviteNeutralGateLogic.swift
//  Yala
//
//  **La puerta del INVITADO, hermana de `GroupsOrganizerGateLogic` y deliberadamente distinta.**
//
//  El daño que cierra: acepto una invitación en un teléfono que ya espeja el iCloud de otra persona —lo
//  presté, lo compré de segunda mano, o entré por «privado» y no terminé—, empiezo a anotar gastos
//  compartidos y **el bridge de Grupos los escribe en el store personal, que está espejado**. Los gastos
//  del invitado acaban en el iCloud del dueño, sin un solo aviso, y se ven días después en otro
//  dispositivo suyo.
//
//  ## Por qué no es una llamada a `GroupsOrganizerGateLogic.decide`
//
//  Aquella vive DENTRO del Welcome, así que su contexto —«no hay sesión privada viva»— lo garantiza el
//  sitio donde está montada. Ésta corre desde `GroupBackendInviteEntryHandler.drive`, al que llaman el
//  universal link, la card «Tengo una invitación», los sheets de la cadena y **el reconciler en los
//  triggers `.boot` y `.foreground`** — o sea, en CUALQUIER estado del dispositivo. Reusar la del
//  organizador tal cual le borraría el corpus a quien tiene la sesión privada abierta, que es lo contrario
//  de lo que manda la matriz del ADR:
//
//      C · llega una invitación (link) → «misma regla que asociar: [I] → asociar → unirme»
//      (docs/sessions/2026-09-09-matriz-escenarios-sesiones.md)
//
//  De ahí el PRIMER término, que la del organizador no tiene ni necesita: la vuelta al neutro solo se
//  interpone donde el ADR la pide —los estados A/B/G, con el Welcome visible— y jamás sobre una sesión
//  privada viva. La fila que gobierna el caso cubierto es la B:
//
//      B · Vengo por un grupo (crear o invitación) → **sin bloqueo**: vuelta al neutro (borra local,
//      iCloud intacto, relanza) y sigue
//
//  ## Los dos últimos son los de la puerta del organizador, y por lo mismo
//
//  `hasExistingData` (hay corpus de alguien debajo) **o** `mountAttachesMirror` (aunque el store esté
//  VACÍO: con el espejo adjunto, lo que se escriba se exporta al iCloud del Apple ID de este teléfono).
//  El segundo es el que el detector de filas no puede ver, porque todavía no hay filas — y es
//  exactamente el caso del síntoma.
//

import Foundation

/// ¿Puede esta invitación seguir adelante, o hay que devolver el dispositivo al neutro antes?
nonisolated enum GroupInviteNeutralGateLogic {

    enum Decision: Equatable {
        /// El flujo del invitado sigue tal cual: sign-in → consent → hoja → join.
        case proceed
        /// Antes de entrar al grupo hay que devolver el dispositivo al neutro. **No es un bloqueo**: la
        /// rama sigue, con una pantalla en medio. Esta decisión no escribe ni borra nada por sí sola —
        /// quien borra es el cierre de sesión privado, y quien lo dispara es la persona en la pantalla.
        case returnsToNeutral
    }

    /// - Parameters:
    ///   - hasCompletedPersonalOnboarding: `AppPreferences.hasCompletedOnboarding`. **Es el término que
    ///     separa esta puerta de la del organizador**, y va PRIMERO porque es el que evita el daño más
    ///     caro: con la sesión privada viva, el que está delante es el dueño de esos datos y la invitación
    ///     va por asociación de cuenta (fila C de la matriz), nunca por un borrado.
    ///   - hasExistingData: el detector del guard cross-cuenta (`ContentView.checkHasExistingData`), que
    ///     cuenta también grupos y filas bridgeadas y **falla CERRADO** ante un error de fetch.
    ///   - mountAttachesMirror: `SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror`.
    ///     **Sin valor por defecto a propósito**, igual que en la puerta del organizador: un default sería
    ///     `false` y cualquier call-site nuevo heredaría en silencio justo el medio bug que este término
    ///     existe para cerrar.
    static func decide(hasCompletedPersonalOnboarding: Bool,
                       hasExistingData: Bool,
                       mountAttachesMirror: Bool) -> Decision {
        guard !hasCompletedPersonalOnboarding else { return .proceed }
        return (hasExistingData || mountAttachesMirror) ? .returnsToNeutral : .proceed
    }
}

// MARK: - La invitación, que tiene que sobrevivir al borrado

/// Dónde vive el join intent mientras el dispositivo vuelve al neutro y se relanza.
///
/// **Por qué hace falta un almacén propio y no vale `PendingJoinStore`.** Su key
/// (`yala.groups.pendingJoins`) **no** está en el barrido de `DataWipeService.removeUserPreferenceKeys`
/// —comprobado— pero muere igual por la otra mitad del reset:
///
///     resetForSignOutWipe() → resetAllUserPreferences() → AppRouter.resetAll() → PendingJoinStore.clearAll()
///
/// Y ese borrado **no es un defecto que corregir aquí**: existe para que un intent de la persona A jamás
/// sobreviva a la sesión de la persona B. Lo que hace este almacén es reponer, después del wipe, sólo la
/// invitación que la propia persona acaba de aceptar en la pantalla que le contó lo que iba a pasar. Sin
/// él, el invitado reabre la app **sin su invitación**: el camino muerto, movido un paso más adelante.
///
/// **Qué guarda, y qué NO.** El par `{groupID, token}` y nada más. Sin PII: ni el nombre tecleado, ni la
/// marca del grupo (`branded`, que sí es dato del usuario), ni el `legacyMemberKey` —que además es una
/// credencial de re-bind y no debe cruzar un wipe—. Lo que se repone es la INTENCIÓN de unirse, no el
/// estado de la sesión anterior; el resto lo vuelve a traer el flujo (la hoja del invitado captura el
/// nombre otra vez) o simplemente no hace falta.
///
/// **One-shot, y sin TTL propio.** Se consume en el arranque que lo lee; el TTL de verdad sigue siendo el
/// de `PendingJoinStore` (7 días), que arranca de cero al reponerse — lo correcto, porque la persona
/// acaba de reafirmar la intención. Molde literal de `WelcomePendingDestinationStore`.
@MainActor
enum GroupInviteResumeStore {

    /// Deliberadamente FUERA del prefijo `cloudSync.*` y del `yala.groups.*` de `PendingJoinStore`: el
    /// primero lo gestiona el orden kill-safe del boot-hook y el segundo es justo el que el reset barre.
    static let key = "groups.invite.resumeAfterNeutralReturn"

    /// `UserDefaults` inyectable para tests, igual que en `PendingJoinStore`.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    /// Cuánto vive el sobre. **El mismo TTL que `PendingJoinStore`, y no por simetría estética**: es la
    /// vida de la invitación que representa. Un sobre sin caducidad se convierte en el defecto que la
    /// review cazó — el borrado aborta, la key se queda huérfana, y meses después el cierre de sesión de
    /// OTRA persona la repone y le manda al admin de un grupo viejo una solicitud que nadie pidió.
    static let ttl: TimeInterval = 7 * 24 * 60 * 60

    /// Lo que cruza el borrado. `Codable` con claves cortas porque esto es un sobre, no un modelo.
    struct Entry: Codable, Equatable {
        let groupID: String
        let token: String
        /// Cuándo se escribió. No es PII y es lo único que permite que el sobre caduque solo.
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case groupID = "g"
            case token = "t"
            case createdAt = "c"
        }

        /// Back-compat: un sobre escrito por la versión anterior no traía fecha. Se trata como RECIÉN
        /// escrito en vez de como caducado — descartarlo destruiría la invitación de quien actualice la
        /// app justo entre el gesto y el relanzamiento.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            groupID = try c.decode(String.self, forKey: .groupID)
            token = try c.decode(String.self, forKey: .token)
            createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        }

        init(groupID: String, token: String, createdAt: Date = .now) {
            self.groupID = groupID
            self.token = token
            self.createdAt = createdAt
        }
    }

    /// Guarda la invitación que hay que reponer tras el borrado. **Lo llama la PANTALLA al recibir el
    /// gesto**, no el callback del arm: entre armar el borrado y que `ContentView` se entere hay una
    /// vuelta de SwiftUI, y en el camino del swap in-process la jerarquía se desmonta antes de esa vuelta.
    static func set(groupID: String, token: String, now: Date = .now) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(Entry(groupID: groupID, token: token, createdAt: now))
            defaults.set(data, forKey: key)
        } catch {
            #if DEBUG
            print("GroupInviteResumeStore: Error encoding entry: \(error)")
            #endif
        }
    }

    /// Lee SIN consumir. **Retira el sobre CADUCADO o ilegible en el mismo gesto**, que es lo que impide
    /// que un residuo se quede esperando a un wipe que no es el suyo.
    static func peek(now: Date = .now) -> Entry? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry: Entry
        do {
            entry = try decoder.decode(Entry.self, from: data)
        } catch {
            #if DEBUG
            print("GroupInviteResumeStore: Error decoding entry: \(error)")
            #endif
            defaults.removeObject(forKey: key)
            return nil
        }
        // El reloj puede ir hacia atrás (cambio de zona, ajuste manual): `abs` para que un sobre del
        // «futuro» caduque igual en vez de vivir para siempre.
        guard abs(now.timeIntervalSince(entry.createdAt)) < ttl else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return entry
    }

    /// Lee y RETIRA.
    static func consume(now: Date = .now) -> Entry? {
        let entry = peek(now: now)
        defaults.removeObject(forKey: key)
        return entry
    }

    /// Retira el sobre sin leerlo. Lo llaman las fronteras que barren las demás superficies de join —hoy
    /// el abort del boot-wipe—, por la misma razón que barren a sus hermanas: un intent que cruce una
    /// frontera de persona se ejecutaría bajo la cuenta equivocada.
    static func clear() {
        defaults.removeObject(forKey: key)
    }

    /// **La reposición, y su único sitio.** La llama el boot-hook del cierre de sesión
    /// (`SwiftDataConfiguration.performSignOutWipeIfArmed`) justo DESPUÉS de `resetPrefs()`, que es lo
    /// que acaba de vaciar `PendingJoinStore`. Antes sería un no-op silencioso.
    ///
    /// Upsert por la vía normal (`persistIntent`) y no un `save` a pelo: así el intent repuesto entra con
    /// el mismo keying, el mismo TTL y —lo que importa— con el tap ARMADO, que es la señal sin la cual
    /// `GroupJoinReconcileLogic.decideBackend` no autoriza el `join_group` de quien tiene un member
    /// residual. Sin eso, reponer la invitación la dejaba visible pero inerte.
    ///
    /// **NO consume, y eso es el orden kill-safe del hook.** Su docblock declara que una re-entrada tras un
    /// kill re-ejecuta el borrado entero, y ese borrado incluye `resetPrefs()`, que vuelve a vaciar
    /// `PendingJoinStore`. Con un `consume()` aquí, la segunda pasada destruía la invitación: el
    /// destructor se re-ejecutaba y el reparador ya no. La key la retira `clearAfterRestore()`, pegada al
    /// desarme, que es donde el hook pone todo lo one-shot.
    @discardableResult
    static func restoreIntoPendingJoins(now: Date = .now) -> Bool {
        guard let entry = peek(now: now) else { return false }
        GroupBackendInviteEntryHandler.persistIntent(groupID: entry.groupID, token: entry.token)
        return true
    }

    /// Retira el sobre ya repuesto. Va PEGADA al desarme del wipe, no a la reposición — ver el docblock de
    /// arriba. Idempotente: llamarla sin sobre no hace nada.
    static func clearAfterRestore() {
        defaults.removeObject(forKey: key)
    }
}
