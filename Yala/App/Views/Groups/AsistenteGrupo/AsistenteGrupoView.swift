//
//  AsistenteGrupoView.swift
//  Yala
//
//  «Nuevo grupo» por pasos (encargo del 17-nov): una pregunta por pantalla con el valor de un grupo nuevo ya elegido,
//  «Usar formulario» arriba y, al final, el resumen con «Crear grupo». Monta `AsistenteCreacionView` (molde:
//  `AsistentePresupuestoView`). Pregunta lo mismo que el formulario (nombre, icono y las tres «Más opciones»), y crea por
//  el mismo canal que él (`GroupBackendMembershipService.createGroup`) con las mismas comprobaciones.
//

import SwiftData
import SwiftUI

struct AsistenteGrupoView: View {
    typealias Logica = AsistenteGrupoLogica
    private typealias T = L10n.AsistenteGrupo

    @Bindable var estado: AsistenteGrupoEstado
    /// El grupo acaba de nacer, ANTES de cerrar la hoja: quien la presentó lo apunta para la hoja de invitar.
    let alCrear: (SplitGroup) -> Void
    /// Se creó el grupo, se descartó o hay que ceder la hoja: quien presenta la cierra.
    let alCerrar: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppPreferences.self) private var appPreferences

    @State private var creando = false
    @State private var muestraError = false
    @State private var mensajeError = ""
    @State private var muestraIconos = false
    @State private var muestraMonedas = false
    @FocusState private var nombreEnfocado: Bool

    private var paso: Logica.Paso { estado.navegador.actual }
    private var tituloCrear: String { dynamicTypeSize.isAccessibilitySize ? T.crearCorto : T.crear }

    var body: some View {
        AsistenteCreacionView(
            titulo: T.titulo,
            pregunta: pregunta,
            detalle: detalle,
            indice: estado.navegador.indice(en: estado.pasos),
            total: estado.pasos.count,
            identidad: paso.rawValue,
            tituloPrincipal: paso == .resumen ? tituloCrear : L10n.Action.next,
            puedeSeguir: estado.puedeSeguir && !creando,
            puedeRetroceder: estado.navegador.puedeRetroceder,
            tieneRespuestas: estado.tieneAlgo,
            tituloDescartar: T.descartarTitulo,
            ocupado: creando,
            alSeguir: seguir,
            alRetroceder: { estado.navegador.retroceder(en: estado.pasos) },
            alUsarFormulario: estado.usarFormulario,
            alCerrar: alCerrar
        ) {
            respuesta
        }
        .modifier(AsistenteGrupoPresentaciones(
            estado: estado, muestraIconos: $muestraIconos, muestraMonedas: $muestraMonedas, muestraError: $muestraError,
            mensajeError: mensajeError))
        .onChange(of: paso) { _, _ in nombreEnfocado = false }
    }

    // MARK: - Pregunta

    private var pregunta: String {
        switch paso {
        case .nombre: return T.nombrePregunta
        case .icono: return T.iconoPregunta
        case .reparto: return T.repartoPregunta
        case .deudas: return T.deudasPregunta
        case .moneda: return T.monedaPregunta
        case .resumen: return T.resumenPregunta
        }
    }

    private var detalle: String? {
        switch paso {
        case .nombre: return T.nombreDetalle
        case .icono: return T.iconoDetalle
        case .reparto: return T.repartoDetalle
        case .deudas: return T.deudasDetalle
        case .moneda: return T.monedaDetalle
        case .resumen: return T.resumenDetalle
        }
    }

    // MARK: - Respuesta

    @ViewBuilder
    private var respuesta: some View {
        switch paso {
        case .nombre: nombre
        case .icono: iconos
        case .reparto: reparto
        case .deudas: deudas
        case .moneda: moneda
        case .resumen: resumen
        }
    }

    private var nombre: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            AsistenteTarjeta {
                TextField("", text: $estado.respuestas.nombre,
                          prompt: Text(L10n.GroupsCreate.namePlaceholder).foregroundStyle(.tertiary))
                    .font(DS.Typography.title3)
                    .focused($nombreEnfocado)
                    .submitLabel(.next)
                    .onSubmit { if estado.puedeSeguir { seguir() } }
                    .padding(DS.Spacing.lg)
                    .accessibilityLabel(T.nombrePregunta)
                    .accessibilityIdentifier("asistente_grupo_nombre")
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(T.ideas)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: DS.Spacing.sm) {
                    ForEach(Logica.Idea.allCases, id: \.self) { idea in
                        AsistenteGrupoIdeaChip(
                            titulo: T.idea(idea), icono: idea.icono,
                            elegida: Logica.nombreLimpio(estado.respuestas.nombre) == T.idea(idea),
                            id: "asistente_grupo_idea_\(idea.rawValue)"
                        ) {
                            estado.elegir(idea, nombre: T.idea(idea))
                            nombreEnfocado = false
                        }
                    }
                }
            }
            ImportarGrupoEntrada(selection: $estado.importacion) { estado.importar($0) }
        }
    }

    private var iconos: some View {
        VStack(spacing: DS.Spacing.lg) {
            AsistenteGrupoIconoGrande(icono: estado.respuestas.icono, color: estado.respuestas.color)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md),
                                     count: dynamicTypeSize.isAccessibilitySize ? 3 : 4),
                      spacing: DS.Spacing.md) {
                ForEach(Array(Logica.iconos.enumerated()), id: \.element) { indice, icono in
                    AsistenteGrupoIconoBoton(
                        icono: icono, numero: indice + 1,
                        elegido: estado.respuestas.icono == icono.nombre && estado.respuestas.color == icono.color
                    ) {
                        estado.elegir(icono: icono.nombre, color: icono.color)
                    }
                }
            }
            Button(T.masIconos) { muestraIconos = true }
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.thAccentText)
                .accessibilityIdentifier("asistente_grupo_mas_iconos")
        }
    }

    private var reparto: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(SplitType.allCases) { tipo in
                AsistenteOpcion(titulo: tipo.displayName, detalle: T.repartoPista(tipo),
                                elegida: estado.respuestas.reparto == tipo,
                                id: "asistente_grupo_reparto_\(tipo.rawValue)") {
                    estado.respuestas.reparto = tipo
                }
            }
        }
    }

    private var deudas: some View {
        VStack(spacing: DS.Spacing.sm) {
            AsistenteOpcion(titulo: T.deudasSi, detalle: T.deudasSiPista, icono: "arrow.triangle.merge",
                            elegida: estado.respuestas.menosPagos, id: "asistente_grupo_deudas_si") {
                estado.respuestas.menosPagos = true
            }
            AsistenteOpcion(titulo: T.deudasNo, detalle: T.deudasNoPista, icono: "arrow.left.arrow.right",
                            elegida: !estado.respuestas.menosPagos, id: "asistente_grupo_deudas_no") {
                estado.respuestas.menosPagos = false
            }
        }
    }

    private var moneda: some View {
        VStack(spacing: DS.Spacing.sm) {
            AsistenteOpcion(titulo: T.monedaCada, detalle: T.monedaCadaPista, icono: "dollarsign.arrow.circlepath",
                            elegida: !estado.respuestas.unaSolaMoneda, id: "asistente_grupo_moneda_cada") {
                estado.respuestas.unaSolaMoneda = false
            }
            AsistenteOpcion(titulo: T.monedaUna, detalle: T.monedaUnaPista, icono: "equal.circle.fill",
                            elegida: estado.respuestas.unaSolaMoneda, id: "asistente_grupo_moneda_una") {
                estado.respuestas.unaSolaMoneda = true
            }
            if estado.respuestas.unaSolaMoneda {
                AsistenteTarjeta {
                    AsistenteResumenFila(etiqueta: T.monedaElegir, valor: textoMoneda,
                                         id: "asistente_grupo_moneda_elegir") { muestraMonedas = true }
                }
            }
        }
    }

    // MARK: - Resumen

    private var resumen: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Button {
                DS.Haptic.selection()
                estado.navegador.cambiar(.icono, desde: .resumen)
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    AsistenteGrupoIconoGrande(icono: estado.respuestas.icono, color: estado.respuestas.color,
                                              tamano: 56)
                    Text(Logica.nombreLimpio(estado.respuestas.nombre))
                        .font(DS.Typography.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DS.Spacing.sm)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(T.resumenIconoPista)
            .accessibilityIdentifier("asistente_grupo_resumen_icono")
            AsistenteTarjeta {
                fila(.nombre, T.resumenNombre, Logica.nombreLimpio(estado.respuestas.nombre))
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.reparto, T.resumenReparto, estado.respuestas.reparto.displayName)
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.deudas, T.resumenDeudas, estado.respuestas.menosPagos ? T.deudasSi : T.deudasNo)
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.moneda, T.resumenMoneda, estado.respuestas.unaSolaMoneda ? textoMoneda : T.monedaCada)
            }
        }
    }

    private func fila(_ destino: Logica.Paso, _ etiqueta: String, _ valor: String) -> some View {
        AsistenteResumenFila(etiqueta: etiqueta, valor: valor, id: "asistente_grupo_resumen_\(destino.rawValue)") {
            estado.navegador.cambiar(destino, desde: .resumen)
        }
    }

    private var textoMoneda: String {
        let info = currencyInfo(for: estado.respuestas.moneda)
        return "\(info.flag) \(info.code) · \(info.name.capitalized)"
    }

    // MARK: - Avance

    private func seguir() {
        guard estado.puedeSeguir else { return }
        if paso == .resumen {
            Task { await crear() }
        } else {
            estado.navegador.avanzar(en: estado.pasos)
        }
    }

    /// Crea por el canal del formulario (`GroupFormView.saveAsync`, rama `.backend`) y con sus mismos efectos: sube
    /// `dataVersion`, apunta el grupo para los recordatorios, aplica lo traído de Splitwise o Tricount y avisa a quien
    /// abrió la hoja ANTES de cerrarla (su `onDismiss` abre la hoja de invitar). La puerta de canal, sesión y
    /// consentimiento ya corrió al abrir (`GroupsContainerView.requestCreateGroup`); aquí es el cinturón, como en el
    /// formulario.
    private func crear() async {
        guard !creando else { return }
        creando = true
        defer { creando = false }
        let r = estado.respuestas
        switch GroupCreateRoutingLogic.route(
            flagOn: CloudSyncFlags.groupsBackendEnabled,
            hasSession: CloudAuthService.shared.hasSession,
            consentAccepted: GroupsConsentState.isAccepted
        ) {
        case .channelOff:
            DS.Haptic.error()
            mensajeError = L10n.Welcome.Groups.channelOffBody
            muestraError = true
        case .needsConsent:
            alCerrar()
            RouterEntryGate.shared.submit(.presentGroupsConsent(pendingJoin: ""))
        case .needsSignIn:
            alCerrar()
            RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: ""))
        case .backend:
            let perfil = UserDefaults.standard.string(forKey: "userName") ?? ""
            let monedaGrupo = r.unaSolaMoneda ? r.moneda : appPreferences.defaultCurrencyCode
            do {
                let creado = try await GroupBackendMembershipService(
                    client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
                    .createGroup(
                        name: Logica.nombreLimpio(r.nombre),
                        iconName: r.icono,
                        colorHex: r.color,
                        currencyCode: monedaGrupo.rawValue,
                        displayName: perfil.isEmpty ? L10n.Profile.defaultName : perfil,
                        defaultSplitType: r.reparto.rawValue,
                        simplifyDebts: r.menosPagos,
                        showDebtsInSingleCurrency: r.unaSolaMoneda,
                        membersCanInvite: false,
                        context: modelContext
                    )
                SessionState.shared.incrementDataVersion()
                NudgeService.shared.recordGroupJoinIfNeeded()
                estado.importacion?.start(in: creado)
                alCrear(creado)
                DS.Haptic.success()
                alCerrar()
            } catch {
                #if DEBUG
                print("AsistenteGrupoView: Error creating group: \(error)")
                #endif
                DS.Haptic.error()
                mensajeError = GroupActionErrorLogic.message(for: error)
                muestraError = true
            }
        }
    }
}

// MARK: - Presentaciones

/// Las hojas de «Más iconos y colores» y de la moneda, y el aviso de error al crear: fuera del `body` del asistente para
/// no alargar su cadena (el compilador del CI, `swiftui-ds.md`).
private struct AsistenteGrupoPresentaciones: ViewModifier {
    @Bindable var estado: AsistenteGrupoEstado
    @Binding var muestraIconos: Bool
    @Binding var muestraMonedas: Bool
    @Binding var muestraError: Bool
    let mensajeError: String

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $muestraIconos) {
                IconColorPickerSheet(selectedIconName: $estado.respuestas.icono,
                                     selectedColorHex: $estado.respuestas.color)
                    .onDisappear { estado.iconoElegidoAMano = true }
            }
            .sheet(isPresented: $muestraMonedas) {
                NavigationStack { CurrencySelectorView(selectedCurrency: $estado.respuestas.moneda) }
            }
            .alert(L10n.Common.error, isPresented: $muestraError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(mensajeError)
            }
    }
}

// MARK: - Piezas

/// Una idea de nombre: cápsula con su icono. Elegida, rellena del acento.
private struct AsistenteGrupoIdeaChip: View {
    let titulo: String
    let icono: String
    let elegida: Bool
    let id: String
    let accion: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button {
            DS.Haptic.selection()
            accion()
        } label: {
            Label(titulo, systemImage: icono)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(elegida ? theme.onAccent : .primary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(elegida ? theme.accent : theme.card))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(id)
    }
}

/// El icono del grupo como se verá en la lista: círculo del color con el símbolo en blanco.
private struct AsistenteGrupoIconoGrande: View {
    let icono: String
    let color: String
    var tamano: CGFloat = 80

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: color))
            Image(systemName: icono)
                .font(.system(size: tamano * 0.4, weight: .medium)) // A11Y-DT: icono decorativo de tamaño fijo, como el formulario
                .foregroundStyle(.white)
        }
        .frame(width: tamano, height: tamano)
        .accessibilityHidden(true)
    }
}

/// Un icono de la rejilla: elegido, con aro del acento y marca.
private struct AsistenteGrupoIconoBoton: View {
    let icono: AsistenteGrupoLogica.Icono
    let numero: Int
    let elegido: Bool
    let accion: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button {
            DS.Haptic.selection()
            accion()
        } label: {
            AsistenteGrupoIconoGrande(icono: icono.nombre, color: icono.color, tamano: 52)
                .padding(DS.Spacing.xs)
                .overlay(Circle().strokeBorder(elegido ? theme.accent : Color.clear, lineWidth: 3))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.AsistenteGrupo.iconoOpcion(numero))
        .accessibilityAddTraits(elegido ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("asistente_grupo_icono_\(numero)")
    }
}
