//
//  SecondarySessionRetirementTests.swift
//  YalaTests
//
//  La ÚNICA pieza del barrido de la sesión de visita que no es un borrado: la retirada de lo que esa
//  sesión pudo dejar en disco. Lo que hay que fijar aquí no es «borra cosas» —eso lo dice el tipo— sino
//  las tres propiedades de las que depende que no haga daño:
//
//   1. **Kill-safe**: la marca de «ya corrió» se escribe AL FINAL, así que un kill a mitad repite el
//      trabajo entero en el arranque siguiente. Escribirla antes convertiría un kill en un residuo
//      permanente.
//   2. **El ORDEN del cajón**: el dominio de preferencias de la visita se llama con un dato que la
//      propia retirada borra, así que destruirlo tiene que ocurrir ANTES. Al revés queda huérfano para
//      siempre, con datos de otra persona dentro.
//   3. **Jamás un dominio «por defecto»**: un descriptor ilegible no compone nombre y no se toca nada.
//      Resolver «lo que devuelva» y borrarlo arrasaría el `UserDefaults` del dispositivo entero.
//
//  Ticket `shell-derives-from-two-session-axes` (paso 12, PR-B) · ADR 2026-09-09 «Sesiones — dos ejes».
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Retirada de la sesión de visita")
struct SecondarySessionRetirementTests {

    private func makeDefaults(_ sufijo: String) -> UserDefaults {
        let nombre = "test.retirement.\(sufijo).\(UUID().uuidString)"
        let d = UserDefaults(suiteName: nombre)!
        d.removePersistentDomain(forName: nombre)
        return d
    }

    // MARK: - Lo que borra

    @Test func borraLosTresStores_lasKeysYElCajonDelDescriptor() {
        let defaults = makeDefaults("completa")
        defaults.set("sub-de-la-visita", forKey: SecondarySessionRetirement.legacyDefaultsKeys[0])
        defaults.set(true, forKey: "cloudSync.secondaryWipeArmed")
        defaults.set(true, forKey: "onboardingMode")

        var borrados: [String] = []
        var destruidos: [String] = []
        let corrio = SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: ["YalaModel-Secondary", "YalaSyncMeta-Secondary", "YalaGroups-Secondary"],
            deleteStore: { borrados.append($0); return true },
            destroySuite: { destruidos.append($0) })

        #expect(corrio)
        #expect(borrados == ["YalaModel-Secondary", "YalaSyncMeta-Secondary", "YalaGroups-Secondary"])
        #expect(destruidos == ["yala.session.sub-de-la-visita"])
        for key in SecondarySessionRetirement.legacyDefaultsKeys
            + SecondarySessionRetirement.legacySessionModeKeys {
            #expect(defaults.object(forKey: key) == nil, "quedó viva: \(key)")
        }
        #expect(defaults.bool(forKey: SecondarySessionRetirement.doneKey))
    }

    /// El cajón se destruye con el descriptor TODAVÍA puesto. Si alguien moviera el borrado de keys por
    /// encima, el nombre dejaría de poder componerse y el cajón quedaría huérfano para siempre — con el
    /// nombre y la divisa de otra persona dentro del teléfono del dueño.
    @Test func elCajonSeDestruyeANTESDeBorrarElDescriptor() {
        let defaults = makeDefaults("orden")
        defaults.set("abc123", forKey: SecondarySessionRetirement.legacyDefaultsKeys[0])

        var descriptorVivoAlDestruir: Bool?
        SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: [],
            deleteStore: { _ in true },
            destroySuite: { _ in
                descriptorVivoAlDestruir =
                    defaults.string(forKey: SecondarySessionRetirement.legacyDefaultsKeys[0]) != nil
            })

        #expect(descriptorVivoAlDestruir == true, """
            El cajón se destruyó DESPUÉS de borrar el descriptor: a partir de ahí no hay con qué
            componer su nombre.
            """)
    }

    @Test func losCajonesHuerfanosTambienSeDestruyen() {
        let defaults = makeDefaults("huerfanos")
        var destruidos: [String] = []
        SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: [],
            deleteStore: { _ in true },
            orphanSuiteNames: { ["yala.session.uno", "yala.session.dos"] },
            destroySuite: { destruidos.append($0) })

        #expect(destruidos == ["yala.session.uno", "yala.session.dos"], """
            Sin descriptor no hay nombre que componer, así que este es el ÚNICO camino que alcanza a un
            cajón que perdió al suyo en una versión anterior.
            """)
    }

    // MARK: - Lo que NO hace

    @Test func unDescriptorIlegibleNoDestruyeNingunDominio() {
        let defaults = makeDefaults("ilegible")
        // Ni una letra, ni un número, ni `-`, ni `_`: el saneado lo deja vacío.
        defaults.set("···", forKey: SecondarySessionRetirement.legacyDefaultsKeys[0])

        var destruidos: [String] = []
        SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: [],
            deleteStore: { _ in true },
            destroySuite: { destruidos.append($0) })

        #expect(destruidos.isEmpty, """
            Sin nombre utilizable NO se resuelve ningún dominio: hacerlo borraría el `UserDefaults` del
            dispositivo entero.
            """)
    }

    @Test func sinDescriptor_borraArchivosYKeysIgual() {
        let defaults = makeDefaults("sin-descriptor")
        var borrados: [String] = []
        var destruidos: [String] = []
        let corrio = SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: ["YalaModel-Secondary"],
            deleteStore: { borrados.append($0); return true },
            destroySuite: { destruidos.append($0) })

        #expect(corrio)
        #expect(borrados == ["YalaModel-Secondary"], """
            Los archivos se borran aunque el descriptor ya no esté: es justo el estado de un teléfono
            donde una versión anterior limpió la key y dejó los bytes.
            """)
        #expect(destruidos.isEmpty)
    }

    // MARK: - Idempotencia y kill-safety

    @Test func laSegundaPasadaEsUnNoOp() {
        let defaults = makeDefaults("idempotente")
        var pasadas = 0
        for _ in 0..<3 {
            SecondarySessionRetirement.purgeIfNeeded(
                defaults: defaults,
                storeNames: ["YalaModel-Secondary"],
                deleteStore: { _ in pasadas += 1; return true })
        }
        #expect(pasadas == 1, "La marca de «ya corrió» tiene que cortar las pasadas siguientes.")
    }

    /// **La aserción que carga el peso de la kill-safety.** Con la marca escrita al principio, un kill a
    /// mitad dejaría el trabajo hecho a medias y el arranque siguiente no lo repetiría: archivos vivos
    /// para siempre y nadie que vuelva a mirarlos.
    @Test func laMarcaSeEscribeAlFINAL() {
        let defaults = makeDefaults("kill-safe")
        var marcaVistaDurante: Bool?
        SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: ["YalaModel-Secondary"],
            deleteStore: { _ in
                marcaVistaDurante = defaults.bool(forKey: SecondarySessionRetirement.doneKey)
                return true
            })

        #expect(marcaVistaDurante == false, """
            La marca ya estaba puesta mientras el borrado corría: un kill en ese punto dejaría el
            residuo para siempre.
            """)
        #expect(defaults.bool(forKey: SecondarySessionRetirement.doneKey))
    }

    // MARK: - Failure-safety (≠ kill-safety)

    /// **La marca NO se escribe si algún archivo se resistió.** Es la otra mitad de la kill-safety y
    /// costó un hallazgo de review: la primera versión tiraba el resultado del borrado y marcaba «ya
    /// está» pasara lo que pasara, así que un fallo de I/O dejaba el corpus de otra persona en el
    /// teléfono **para siempre** — el arranque siguiente ya no volvía a mirar.
    @Test func siElBorradoFALLA_laMarcaNoSeEscribeYSeReintenta() {
        let defaults = makeDefaults("fallo")
        var intentos = 0

        let primera = SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: ["YalaModel-Secondary", "YalaSyncMeta-Secondary"],
            deleteStore: { nombre in intentos += 1; return nombre != "YalaSyncMeta-Secondary" })

        #expect(primera == false)
        #expect(defaults.bool(forKey: SecondarySessionRetirement.doneKey) == false, """
            la marca quedó puesta sobre un disco que todavía guarda el store de otra persona: nadie va a
            volver a mirarlo.
            """)

        // El arranque siguiente lo reintenta ENTERO, no solo el que falló.
        let segunda = SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: ["YalaModel-Secondary", "YalaSyncMeta-Secondary"],
            deleteStore: { _ in true })

        #expect(segunda == true)
        #expect(intentos == 2, "la primera pasada tiene que intentar los DOS, no abortar en el primero")
        #expect(defaults.bool(forKey: SecondarySessionRetirement.doneKey))
    }

    // MARK: - Las superficies COMPARTIDAS

    /// El snapshot del widget, las colas del App Group y las notificaciones no viven en el store, así que
    /// el borrado de archivos no las alcanza — y el sello que las marcaba se retira en este mismo PR. Sin
    /// esto, el widget del dueño sigue pintando los saldos de la otra persona.
    @Test func conVisitaEnElTelefono_seLimpianLasSuperficiesCompartidas() {
        let defaults = makeDefaults("con-visita")
        defaults.set("sub-de-la-visita", forKey: SecondarySessionRetirement.legacyDefaultsKeys[0])

        var purgadas = 0
        SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults, storeNames: [], deleteStore: { _ in true },
            destroySuite: { _ in }, purgeSharedSurfaces: { purgadas += 1 })

        #expect(purgadas == 1)
    }

    /// **Y la mitad que carga el peso: en un teléfono que NUNCA tuvo visita no se toca nada.** Purgar a
    /// ciegas le borraría al 100 % del parque su cola de Apple Pay pendiente y su snapshot de widget — un
    /// daño nuevo, y mucho mayor que el residuo que esto viene a limpiar.
    @Test func sinVisita_noSeTocanLasSuperficiesCompartidas() {
        let defaults = makeDefaults("sin-visita")

        var purgadas = 0
        SecondarySessionRetirement.purgeIfNeeded(
            defaults: defaults,
            storeNames: ["YalaModel-Secondary"],
            deleteStore: { _ in true },
            purgeSharedSurfaces: { purgadas += 1 })

        #expect(purgadas == 0, """
            se purgaron las superficies compartidas de alguien que nunca tuvo una visita: eso le borra su
            cola pendiente y su widget por un residuo que no existe.
            """)
    }

    // MARK: - La premisa del borrado de archivos

    /// `deleteLegacyStoreFiles` pasa el schema PERSONAL como portador para los tres stores, y eso solo
    /// es correcto si la URL de una `ModelConfiguration` **no depende del schema**. Es una afirmación
    /// verificable y barata, así que se verifica en vez de confiar en ella: si algún día dependiera, la
    /// retirada borraría rutas que no existen y los archivos se quedarían en disco sin que nada avise.
    @Test func laURLNoDependeDelSchema() {
        let conPersonal = ModelConfiguration(
            "YalaModel-Secondary", schema: SwiftDataConfiguration.personalSchema, cloudKitDatabase: .none)
        let conGrupos = ModelConfiguration(
            "YalaModel-Secondary", schema: SwiftDataConfiguration.groupsSchema, cloudKitDatabase: .none)

        #expect(conPersonal.url == conGrupos.url)
    }
}
