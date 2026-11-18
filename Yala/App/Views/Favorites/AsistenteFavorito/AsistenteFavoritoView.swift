//
//  AsistenteFavoritoView.swift
//  Yala
//
//  «Nuevo favorito» por pasos (encargo del 17-nov): una pregunta por pantalla con lo sugerido ya elegido, «Usar
//  formulario» arriba y, al final, el resumen con «Crear favorito». Sobre el contenedor compartido
//  `AsistenteCreacionView` (molde: `AsistentePagoPlanificadoView`). Se guarda por el camino del formulario
//  (`FavoriteEditorViewModel.saveFavorite`). Lo que no pregunta (etiquetas, nota, naturaleza) queda vacío, como en el
//  formulario recién abierto.
//

import SwiftData
import SwiftUI

struct AsistenteFavoritoView: View {
    typealias Logica = AsistenteFavoritoLogica
    private typealias A = L10n.AsistenteFavorito

    @Bindable var estado: AsistenteFavoritoEstado
    /// Se creó el favorito, o se descartó: quien presenta cierra la hoja.
    let alCerrar: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(SessionState.self) private var sessionState
    @Environment(AppPreferences.self) private var appPreferences

    // Datos de la persona (se vuelven a leer si el contenido se rehace: no son respuestas).
    @State private var cuentas: [Account] = []
    @State private var recientes: [Subcategory] = []
    @State private var didLoad = false
    @State private var muestraOtra = false
    /// La subcategoría elegida en «Otra categoría» (la hoja escribe aquí).
    @State private var otra: Subcategory?
    @State private var otraAlAbrir: PersistentIdentifier?
    @State private var creando = false
    @State private var fallo = false
    @State private var editorViewModel = FavoriteEditorViewModel()
    @FocusState private var nombreEnfocado: Bool
    @FocusState private var montoEnfocado: Bool

    private var paso: Logica.Paso { estado.navegador.actual }
    private var pasos: [Logica.Paso] { estado.pasos }
    private var tituloCrear: String {
        dynamicTypeSize.isAccessibilitySize ? A.crearCorto : A.crear
    }

    var body: some View {
        AsistenteCreacionView(
            titulo: A.titulo,
            pregunta: pregunta,
            detalle: detalle,
            indice: estado.navegador.indice(en: pasos),
            total: pasos.count,
            identidad: paso.rawValue,
            tituloPrincipal: paso == .resumen ? tituloCrear : L10n.Action.next,
            puedeSeguir: estado.puedeSeguir && !creando,
            puedeRetroceder: estado.navegador.puedeRetroceder,
            tieneRespuestas: estado.navegador.tieneRespuestas,
            tituloDescartar: A.descartarTitulo,
            ocupado: creando,
            alSeguir: seguir,
            alRetroceder: { estado.navegador.retroceder(en: pasos) },
            alUsarFormulario: { estado.usarFormulario() },
            alCerrar: alCerrar
        ) {
            respuesta
        }
        .onAppear(perform: cargar)
        .onChange(of: paso) { _, nuevo in alEntrar(en: nuevo) }
        .onChange(of: estado.tipo) { _, _ in cargarRecientes() }
        .modifier(AsistenteFavoritoPresentaciones(
            muestraOtra: $muestraOtra, otra: $otra, tipo: estado.tipo, alCerrarOtra: aplicarOtra,
            fallo: $fallo
        ))
    }

    // MARK: - Pregunta

    private var pregunta: String {
        switch paso {
        case .tipo: return A.tipoPregunta
        case .categoria: return A.categoriaPregunta
        case .nombre: return A.nombrePregunta
        case .monto: return A.montoPregunta(estado.tipo)
        case .cuenta: return A.cuentaPregunta(estado.tipo)
        case .destino: return A.destinoPregunta
        case .resumen: return A.resumenPregunta
        }
    }

    private var detalle: String? {
        switch paso {
        case .tipo: return A.tipoDetalle
        case .categoria: return A.categoriaDetalle
        case .nombre: return A.nombreDetalle
        case .monto: return A.montoDetalle
        case .cuenta: return A.cuentaDetalle
        case .destino: return A.destinoDetalle
        case .resumen: return A.resumenDetalle
        }
    }

    // MARK: - Respuesta

    @ViewBuilder
    private var respuesta: some View {
        switch paso {
        case .tipo: tipo
        case .categoria: categoria
        case .nombre: nombre
        case .monto: monto
        case .cuenta: cuentaOrigen
        case .destino: cuentaDestino
        case .resumen: resumen
        }
    }

    private var tipo: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(estado.tiposDisponibles, id: \.self) { opcion in
                AsistenteOpcion(titulo: FavoriteEditorTypeLogic.title(for: opcion), detalle: A.tipoPista(opcion),
                                icono: icono(de: opcion), elegida: estado.tipo == opcion,
                                id: "asistente_favorito_tipo_\(opcion.rawValue)") {
                    estado.elegirTipo(opcion)
                }
            }
        }
    }

    private func icono(de tipo: TransactionType) -> String {
        switch tipo {
        case .income: return "arrow.down.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        default: return "arrow.up.circle.fill"
        }
    }

    private var categoria: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(opcionesDeCategoria, id: \.persistentModelID) { subcategoria in
                AsistenteOpcion(titulo: subcategoria.name, detalle: subcategoria.category?.name,
                                icono: subcategoria.iconName ?? "tag.fill",
                                elegida: estado.subcategoriaID == subcategoria.persistentModelID,
                                id: "asistente_favorito_categoria_\(subcategoria.name)") {
                    elegirCategoria(subcategoria)
                }
            }
            AsistenteOpcion(titulo: A.sinCategoria, detalle: A.sinCategoriaPista, icono: "tag.slash",
                            elegida: estado.subcategoriaID == nil, id: "asistente_favorito_sin_categoria") {
                elegirCategoria(nil)
            }
            Button(A.otraCategoria, action: abrirOtra)
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(theme.accentText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("asistente_favorito_otra_categoria")
        }
    }

    /// Las cuatro más recientes del tipo y, si se eligió otra, esa arriba.
    private var opcionesDeCategoria: [Subcategory] {
        var lista = Array(recientes.prefix(4))
        if let elegida = subcategoriaElegida, !lista.contains(where: { $0.persistentModelID == elegida.persistentModelID }) {
            lista.insert(elegida, at: 0)
        }
        return lista
    }

    private var nombre: some View {
        AsistenteTarjeta {
            TextField("", text: $estado.nombre, prompt: Text(L10n.Favorites.namePlaceholder).foregroundStyle(.tertiary))
                .font(DS.Typography.title3)
                .focused($nombreEnfocado)
                .submitLabel(.next)
                .onSubmit { if estado.puedeSeguir { seguir() } }
                .onChange(of: estado.nombre) { _, _ in
                    if nombreEnfocado { estado.nombreEditado = true }
                }
                .padding(DS.Spacing.lg)
                .accessibilityLabel(A.nombrePregunta)
                .accessibilityIdentifier("asistente_favorito_nombre")
        }
    }

    private var monto: some View {
        AsistenteTarjeta {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                Text(simboloMoneda)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("", text: $estado.montoTexto, prompt: Text(verbatim: "0").foregroundStyle(.tertiary))
                    .font(DS.Typography.largeTitle.weight(.bold))
                    .amountKeyboard()
                    .focused($montoEnfocado)
                    .onChange(of: estado.montoTexto) { _, nuevo in filtrarMonto(nuevo) }
                    .accessibilityLabel(A.montoPregunta(estado.tipo))
                    .accessibilityIdentifier("asistente_favorito_monto")
            }
            .padding(DS.Spacing.lg)
        }
    }

    private var cuentaOrigen: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(cuentas, id: \.persistentModelID) { cuenta in
                opcionCuenta(cuenta, elegida: estado.origenID == cuenta.persistentModelID,
                             id: "asistente_favorito_cuenta_\(cuenta.name)") {
                    estado.origenID = cuenta.persistentModelID
                }
            }
            AsistenteOpcion(titulo: A.sinCuenta, detalle: A.sinCuentaPista, icono: "creditcard.trianglebadge.exclamationmark",
                            elegida: estado.origenID == nil, id: "asistente_favorito_sin_cuenta") {
                estado.origenID = nil
            }
        }
    }

    private var cuentaDestino: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(cuentas.filter { $0.persistentModelID != estado.origenID }, id: \.persistentModelID) { cuenta in
                opcionCuenta(cuenta, elegida: estado.destinoID == cuenta.persistentModelID,
                             id: "asistente_favorito_destino_\(cuenta.name)") {
                    estado.destinoID = cuenta.persistentModelID
                }
            }
            AsistenteOpcion(titulo: A.sinCuenta, detalle: A.sinCuentaPista, icono: "creditcard.trianglebadge.exclamationmark",
                            elegida: estado.destinoID == nil, id: "asistente_favorito_sin_destino") {
                estado.destinoID = nil
            }
        }
    }

    private func opcionCuenta(_ cuenta: Account, elegida: Bool, id: String, accion: @escaping () -> Void) -> some View {
        AsistenteOpcion(titulo: cuenta.name, detalle: cuenta.currencyCode, icono: cuenta.iconName,
                        elegida: elegida, id: id, accion: accion)
    }

    // MARK: - Resumen

    private var resumen: some View {
        AsistenteTarjeta {
            if estado.pasos.contains(.tipo) {
                fila(.tipo, A.resumenTipo, FavoriteEditorTypeLogic.title(for: estado.tipo))
                Divider().padding(.leading, DS.Spacing.lg)
            }
            if estado.tipo != .transfer {
                fila(.categoria, A.resumenCategoria, subcategoriaElegida?.name ?? A.sinCategoria)
                Divider().padding(.leading, DS.Spacing.lg)
            }
            fila(.nombre, A.resumenNombre, Logica.nombreLimpio(estado.nombre))
            Divider().padding(.leading, DS.Spacing.lg)
            fila(.monto, A.resumenMonto, Logica.monto(estado.montoTexto).map(dinero) ?? A.resumenMontoVacio)
            Divider().padding(.leading, DS.Spacing.lg)
            if estado.tipo == .transfer {
                fila(.cuenta, A.resumenOrigen, cuenta(estado.origenID)?.name ?? A.sinCuenta)
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.destino, A.resumenDestino, cuenta(estado.destinoID)?.name ?? A.sinCuenta)
            } else {
                fila(.cuenta, A.resumenCuenta, cuenta(estado.origenID)?.name ?? A.sinCuenta)
            }
        }
    }

    private func fila(_ destino: Logica.Paso, _ etiqueta: String, _ valor: String) -> some View {
        AsistenteResumenFila(etiqueta: etiqueta, valor: valor, id: "asistente_favorito_resumen_\(destino.rawValue)") {
            estado.navegador.cambiar(destino, desde: .resumen)
        }
    }

    // MARK: - Datos

    private func cuenta(_ id: PersistentIdentifier?) -> Account? {
        guard let id else { return nil }
        return cuentas.first { $0.persistentModelID == id }
    }

    private var subcategoriaElegida: Subcategory? {
        guard let id = estado.subcategoriaID else { return nil }
        if let otra, otra.persistentModelID == id { return otra }
        return recientes.first { $0.persistentModelID == id }
    }

    /// La moneda de la cuenta elegida (o la de la app), como el formulario.
    private var moneda: String {
        cuenta(estado.origenID)?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
    }

    private var simboloMoneda: String {
        appPreferences.currencyIdentifier(for: moneda)
    }

    private func dinero(_ valor: Double) -> String {
        appPreferences.currency(valor, currencyCode: moneda, forceFullPrecision: true)
    }

    // MARK: - Avance

    private func cargar() {
        editorViewModel.setContext(modelContext)
        guard !didLoad else { return }
        didLoad = true
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(modelContext, deletionService: EntityDeletionService.shared)
        cuentas = viewModel.activeAccounts
        estado.prepararSiHaceFalta(
            tiposDisponibles: FavoriteEditorTypeLogic.availableTypes(isExpensesOnlyMode: sessionState.isExpensesOnlyMode),
            cuentaSugerida: { viewModel.lastUsedAccount()?.persistentModelID }
        )
        cargarRecientes()
    }

    /// Las recientes del tipo, como la hoja de categorías («Recientes»). Una transferencia no lleva categoría.
    private func cargarRecientes() {
        guard estado.tipo != .transfer else {
            recientes = []
            return
        }
        let viewModel = SubcategorySelectorViewModel()
        viewModel.setContext(modelContext, transactionType: estado.tipo)
        recientes = viewModel.recentSubcategories
    }

    private func elegirCategoria(_ subcategoria: Subcategory?) {
        estado.subcategoriaID = subcategoria?.persistentModelID
        if let subcategoria, subcategoria.persistentModelID != otra?.persistentModelID { otra = nil }
    }

    private func abrirOtra() {
        otraAlAbrir = otra?.persistentModelID
        muestraOtra = true
    }

    /// Al cerrarse la hoja de «Otra categoría»: la elegida queda marcada. Cerrarla sin elegir otra no toca nada.
    private func aplicarOtra() {
        guard let elegida = otra, elegida.persistentModelID != otraAlAbrir else { return }
        estado.subcategoriaID = elegida.persistentModelID
    }

    /// El nombre propuesto sigue a la categoría hasta que la persona escribe el suyo; el destino, al origen.
    private func alEntrar(en paso: Logica.Paso) {
        nombreEnfocado = false
        montoEnfocado = false
        switch paso {
        case .nombre:
            if !estado.nombreEditado || Logica.nombreLimpio(estado.nombre).isEmpty {
                estado.nombre = Logica.nombrePropuesto(tipo: estado.tipo, categoria: subcategoriaElegida?.name,
                                                       transferencia: FavoriteEditorTypeLogic.title(for: .transfer))
                estado.nombreEditado = false
            }
        case .destino:
            sugerirDestino()
        case .resumen:
            // Pasar a transferencia desde el resumen vuelve aquí sin preguntar el destino (el navegador compartido salta
            // a lo ya contestado): llega el sugerido, con su fila para cambiarlo.
            if estado.tipo == .transfer, !estado.navegador.respondidos.contains(.destino) { sugerirDestino() }
        default:
            break
        }
    }

    private func sugerirDestino() {
        estado.destinoID = Logica.destinoSugerido(actual: estado.destinoID, origen: estado.origenID,
                                                  cuentas: cuentas.map(\.persistentModelID))
    }

    private func filtrarMonto(_ texto: String) {
        let filtrado = AmountInputHelper.filterAmountInput(texto)
        if filtrado != texto { estado.montoTexto = filtrado }
    }

    private func seguir() {
        guard estado.puedeSeguir else { return }
        if paso == .resumen {
            crear()
        } else {
            estado.navegador.avanzar(en: pasos)
        }
    }

    /// Guarda por el camino del formulario. El monto va como lo guardaría el formulario: con separadores normalizados.
    private func crear() {
        guard !creando else { return }
        creando = true
        let subcategoria = estado.tipo == .transfer ? nil : subcategoriaElegida
        let guardado = editorViewModel.saveFavorite(
            existing: nil,
            name: estado.nombre,
            transactionType: estado.tipo,
            amountString: Logica.monto(estado.montoTexto).map { AmountInputHelper.formatWithGrouping($0) } ?? "",
            note: "",
            account: cuenta(estado.origenID),
            subcategory: subcategoria,
            tags: [],
            needOverride: subcategoria?.need,
            destinationAccount: estado.tipo == .transfer ? cuenta(estado.destinoID) : nil
        )
        creando = false
        guard guardado else {
            // El ViewModel ya vibró el error: aquí solo se enseña el aviso.
            fallo = editorViewModel.showSaveError
            editorViewModel.dismissSaveError()
            return
        }
        DS.Haptic.success()
        alCerrar()
    }
}

/// La hoja de «Otra categoría» y el error al guardar. En su propio modificador para no alargar el `body`
/// (`swiftui-ds.md`, el compilador del CI).
private struct AsistenteFavoritoPresentaciones: ViewModifier {
    @Binding var muestraOtra: Bool
    @Binding var otra: Subcategory?
    let tipo: TransactionType
    let alCerrarOtra: () -> Void
    @Binding var fallo: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $muestraOtra, onDismiss: alCerrarOtra) {
                SubcategorySelectorSheet(selectedSubcategory: $otra, transactionType: tipo)
            }
            .alert(L10n.Common.error, isPresented: $fallo) {
                Button(L10n.Common.understood, role: .cancel) {}
            } message: {
                Text(L10n.Common.saveError)
            }
    }
}
