//
//  PanelDefaultsTests.swift
//  YalaTests
//
//  Pines de la fuente única de predeterminados del Panel y de su resolución en
//  LECTURA — la pieza que evita que «todavía no hay preferencias» se renderice
//  como «enséñalo todo» mientras la siembra no ha corrido.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct PanelDefaultsTests {

    private static func makeSuite() -> UserDefaults {
        let suiteName = "PanelDefaultsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: AppPreferences.Keys.panelPrefsMigratedV2)
        return defaults
    }

    /// Deja las preferencias en el estado exacto de «instalada pero aún sin sembrar»:
    /// listas vacías y centinela apagado. Es el estado que vive el usuario durante la
    /// espera del sync en un arranque con iCloud.
    private static func makeUnseeded() -> AppPreferences {
        let prefs = AppPreferences(defaults: makeSuite())
        prefs.panelTendenciasOrder = []
        prefs.panelTendenciasHidden = []
        prefs.panelDistribucionOrder = []
        prefs.panelDistribucionHidden = []
        prefs.panelPlanificacionOrder = []
        prefs.panelPlanificacionHidden = []
        prefs.panelSectionsHidden = []
        prefs.panelPrefsMigratedV2 = false
        return prefs
    }

    // MARK: - Invariantes de la tabla

    /// `hidden` tiene que ser un subconjunto de `order` y respetar su mismo orden.
    /// El seed persiste estas listas y el `didSet` las compara con `!=`: un orden
    /// inestable produciría escrituras y empujes a iCloud KV que no cambian nada.
    @Test func sectionDefaults_hiddenEsSubconjuntoOrdenadoDeOrder() {
        for kind in PanelSectionKind.allCases {
            guard let defaults = PanelDefaults.section(kind) else { continue }

            #expect(Set(defaults.order).count == defaults.order.count,
                    "\(kind.rawValue): hay widgets repetidos en `order`")

            let esperado = defaults.order.filter { defaults.hidden.contains($0) }
            #expect(defaults.hidden == esperado,
                    "\(kind.rawValue): `hidden` no sigue el orden de `order`, o tiene algo que no está en él")
        }
    }

    /// Cada sección con almacén por widget declara EXACTAMENTE los widgets que el
    /// catálogo le asigna. Si alguien añade un `WidgetType` a una sección y no lo mete
    /// en la tabla, cae aquí — y no en silencio, que es como se pierde un widget.
    @Test func sectionDefaults_cubreTodosLosWidgetsDeSuSeccion() {
        for kind in PanelSectionKind.allCases {
            guard let defaults = PanelDefaults.section(kind) else { continue }
            #expect(Set(defaults.order) == Set(WidgetType.defaultWidgets(in: kind)),
                    "\(kind.rawValue): la tabla y el catálogo no coinciden")
        }
    }

    /// Ningún tamaño predeterminado puede caer fuera de los soportados por su widget.
    /// El código anterior sí producía uno: los fallbacks devolvían `.medium` también
    /// para `trend`, cuyos tamaños son `[.small, .large]`, así que el selector recibía
    /// un valor imposible y no marcaba ninguna opción.
    @Test func size_siempreDentroDeSupportedSizes() {
        for type in WidgetType.allCases {
            let size = PanelDefaults.size(for: type)
            #expect(type.supportedSizes.contains(size),
                    "\(type.rawValue): \(size.rawValue) no está en supportedSizes")
        }
    }

    /// El anterior comprueba una postcondición que `size(for:)` ya garantiza por
    /// construcción, así que por sí solo no puede fallar. Este comprueba que el saneo
    /// EXISTE: `trend` no soporta `.medium`, y era justo el valor que devolvían los dos
    /// fallbacks anteriores.
    @Test func size_saneaUnTamanoImposible() {
        #expect(WidgetType.trend.supportedSizes.contains(.medium) == false,
                "si trend pasara a soportar .medium, este test deja de medir el saneo")
        #expect(PanelDefaults.size(for: .trend) != .medium)
    }

    @Test func size_cumpleElEncargo() {
        #expect(PanelDefaults.size(for: .trend) == .large)
        #expect(PanelDefaults.size(for: .budgets) == .small)
        #expect(PanelDefaults.size(for: .scheduledPayments) == .small)
    }

    /// Los dos widgets de Planificación tienen que nacer cumpliendo la invariante del
    /// pair-sync («ambos pequeños o ninguno»), o el primer cambio de tamaño movería al
    /// otro solo, nada más abrir la app.
    @Test func size_planificacionNaceCumpliendoElPairSync() {
        let budgets = PanelDefaults.size(for: .budgets)
        let scheduled = PanelDefaults.size(for: .scheduledPayments)
        #expect((budgets == .small) == (scheduled == .small))
    }

    // MARK: - defaultConfigs deriva de la tabla

    @Test func defaultConfigs_cubreTodosLosWidgetTypes() {
        let configs = WidgetConfig.defaultConfigs()
        #expect(Set(configs.map(\.type)) == Set(WidgetType.allCases))
        #expect(configs.count == WidgetType.allCases.count, "hay tipos duplicados")
    }

    @Test func defaultConfigs_usaLosTamanosDeLaTabla() {
        for config in WidgetConfig.defaultConfigs() {
            #expect(config.size == PanelDefaults.size(for: config.type))
        }
    }

    /// El `isVisible` de `defaultConfigs()` solo se lee en la rama de bootstrap de
    /// `activeWidgets(in:)`, en los frames previos a la inyección de preferencias.
    /// Aun así debe coincidir con el curado: si no, ese primer frame enseña un Panel
    /// distinto del que aparece medio segundo después.
    @Test func defaultConfigs_visibilidadCoincideConElCurado() {
        let visibles = WidgetConfig.defaultConfigs().filter(\.isVisible).map(\.type)
        #expect(visibles == [.trend, .scheduledPayments, .budgets, .latestRecords])
    }

    // MARK: - Resolución en lectura (el arreglo del parpadeo)

    /// Sin sembrar, la lectura devuelve el curado. Antes devolvía listas vacías, y
    /// `buildOrderedRawWidgets` interpretaba eso como «anexa el catálogo entero».
    @Test func lecturaSinSembrar_devuelveElCurado() {
        let prefs = Self.makeUnseeded()

        #expect(prefs.resolvedSectionsHidden == ["health", "distribucion", "tools"])
        #expect(prefs.order(for: .tendencias) == [
            "tendencia_saldo", "gasto_por_dia", "flujo_efectivo",
        ])
        #expect(prefs.hidden(for: .tendencias) == ["gasto_por_dia", "flujo_efectivo"])
        #expect(prefs.hidden(for: .planificacion) == [])
    }

    /// Y el Panel, sin sembrar, ya resuelve los cuatro widgets del encargo: este es el
    /// pin del parpadeo. Si alguien quita la resolución en lectura, aquí saldrían los
    /// trece.
    @Test func panelSinSembrar_yaMuestraSoloLosCuatro() {
        let prefs = Self.makeUnseeded()
        let vm = PanelViewModel()
        vm.setAppPreferences(prefs)

        #expect(vm.activeWidgets(in: .tendencias).map(\.type) == [.trend])
        #expect(vm.activeWidgets(in: .planificacion).map(\.type) == [.scheduledPayments, .budgets])
        #expect(vm.isWidgetVisible(.cashFlow) == false)
        #expect(vm.isWidgetVisible(.exchangeRate) == false)
        #expect(vm.isWidgetVisible(.categoriesPie) == false)
        #expect(vm.isWidgetVisible(.trend) == true)
    }

    /// El discriminador es el CENTINELA, nunca «la lista está vacía». Un usuario que
    /// ya pasó por la siembra y decide no ocultar nada tiene derecho a verlo todo: si
    /// se resolviera por vacío, se le impondría el curado una y otra vez.
    @Test func lecturaTrasSembrar_respetaAlUsuarioAunqueEsteVacio() {
        let prefs = AppPreferences(defaults: Self.makeSuite())
        prefs.panelPrefsMigratedV2 = true
        prefs.panelSectionsHidden = []
        prefs.panelTendenciasHidden = []
        prefs.panelTendenciasOrder = []

        #expect(prefs.resolvedSectionsHidden == [])
        #expect(prefs.hidden(for: .tendencias) == [])

        let vm = PanelViewModel()
        vm.setAppPreferences(prefs)
        // Sin orden guardado, el auto-sanado anexa el catálogo de la sección: es el
        // comportamiento correcto para quien ya está sembrado.
        #expect(vm.activeWidgets(in: .tendencias).count == 3)
    }

    /// La primera edición del usuario ANTES de que la siembra corra tiene que quedarse
    /// puesta. Sin materializar los predeterminados, se escribía su cambio pero la
    /// lectura seguía devolviendo el curado: el interruptor volvía solo a su sitio y el
    /// widget que acababa de encender no aparecía.
    @Test func primeraEdicionSinSembrar_seQuedaPuesta() {
        let prefs = Self.makeUnseeded()
        let vm = PanelViewModel()
        vm.setAppPreferences(prefs)

        // Estado de partida: Flujo de efectivo viene apagado de fábrica.
        #expect(vm.isWidgetVisible(.cashFlow) == false)

        // El usuario lo enciende antes de que la siembra haya corrido.
        vm.setWidgetHidden(.cashFlow, hidden: false)
        vm.flushPendingSectionWrites()

        #expect(prefs.panelPrefsMigratedV2 == true, "la primera edición debe fijar los predeterminados")
        #expect(vm.isWidgetVisible(.cashFlow) == true, "el cambio del usuario se perdía")
        // Y lo que no tocó sigue como estaba.
        #expect(vm.isWidgetVisible(.weekdayBar) == false)
    }

    /// Lo mismo para las secciones: encender una oculta de fábrica antes de la siembra.
    @Test func primeraEdicionDeSeccionSinSembrar_seQuedaPuesta() {
        let prefs = Self.makeUnseeded()

        prefs.materializePanelDefaultsIfNeeded()
        prefs.panelSectionsHidden = PanelSectionKind.allCases
            .map(\.rawValue)
            .filter { Set(prefs.resolvedSectionsHidden).subtracting(["distribucion"]).contains($0) }

        #expect(prefs.resolvedSectionsHidden == ["health", "tools"])
        #expect(prefs.panelPrefsMigratedV2 == true)
    }

    /// Todo escritor de preferencias del Panel tiene que materializar antes. Si alguno
    /// se olvida, `hasAnyPanelPreference` se vuelve true por su escritura y la
    /// resolución en lectura se apaga con las demás listas aún vacías: el Panel
    /// volvería a «enséñalo todo» justo por haber tocado otra cosa.
    @Test func todoEscritorMaterializaAntesDeEscribir() {
        // Reordenar secciones.
        let a = Self.makeUnseeded()
        a.movePanelSection(from: IndexSet(integer: 0), to: 2)
        #expect(a.panelPrefsMigratedV2 == true)
        #expect(a.resolvedSectionsHidden == ["health", "distribucion", "tools"])

        // Restablecer el orden de secciones.
        let b = Self.makeUnseeded()
        b.resetPanelSectionsOrder()
        #expect(b.panelPrefsMigratedV2 == true)
        #expect(b.resolvedSectionsHidden == ["health", "distribucion", "tools"])

        // Cambiar un tamaño (escribe en el almacén legacy, no en estas listas).
        let c = Self.makeUnseeded()
        let vm = PanelViewModel()
        vm.setAppPreferences(c)
        vm.setWidgetSize(.trend, size: .small)
        #expect(c.panelPrefsMigratedV2 == true,
                "sin esto el blob legacy desvía la migración a la rama de actualización")
        #expect(c.resolvedSectionsHidden == ["health", "distribucion", "tools"])
    }

    /// Las secciones sin almacén por widget no tienen tabla y sus setters son no-op:
    /// se gobiernan solo con `panelSectionsHidden`.
    @Test func seccionesSinAlmacenPorWidget_noTienenTabla() {
        for kind in [PanelSectionKind.accounts, .health, .latestRecords, .tools] {
            #expect(PanelDefaults.section(kind) == nil, "\(kind.rawValue) no debería tener tabla")
        }
    }
}
