//
//  AsistentePagoCompartidoPasos.swift
//  Yala
//
//  Los tres pasos que el asistente de «Nuevo pago planificado» ganó el 21-nov: «¿Es un gasto compartido?» (solo con
//  algún grupo activo), «¿Cómo lo dividen?» (moneda y división, con el mismo selector que el formulario) y «¿Algo
//  más?» (cuenta, descripción, etiquetas, fecha de fin y activo, con todo ya puesto). Lo elegido vive en
//  `AsistentePagoPlanificadoEstado` (quien presenta la hoja), no aquí: el contenido de una hoja puede rehacerse.
//

import SwiftData
import SwiftUI

// MARK: - La división con el selector del formulario

/// El paso entre lo elegido (`AsistentePagoPlanificadoReparto`) y el ViewModel transitorio que alimenta
/// `GroupSplitSelectorView`, el mismo que usa el formulario (`ScheduledPaymentEditorView.buildTransientVM`). Nunca se le
/// llama `save()`: crearía un gasto de grupo.
@MainActor
enum AsistenteRepartoPuente {

    static func miembros(de grupo: SplitGroup, in context: ModelContext) -> [SplitMember] {
        do {
            return try GroupService.shared.fetchMembers(for: grupo, context: context)
        } catch {
            #if DEBUG
            print("AsistenteRepartoPuente: Error fetching members: \(error)")
            #endif
            return []
        }
    }

    /// Solo los grupos en los que sigues activo: en uno del que saliste el pago no genera su borrador
    /// (`ScheduledPaymentDraftService.groupGateDecision`) y la división no te incluye.
    static func soyMiembroActivo(de grupo: SplitGroup, in context: ModelContext) -> Bool {
        do {
            return try GroupExpenseService.resolveCurrentUserMember(inZone: grupo.cloudKitZoneID, context: context)?
                .isActive ?? false
        } catch {
            #if DEBUG
            print("AsistenteRepartoPuente: Error resolving current member: \(error)")
            #endif
            return false
        }
    }

    /// El ViewModel con lo elegido (o, sin división todavía, con la del grupo: todos los activos, su modo por defecto).
    static func viewModel(
        _ reparto: AsistentePagoPlanificadoReparto, grupo: SplitGroup, miembros: [SplitMember],
        monto: Double?, in context: ModelContext
    ) -> GroupExpenseViewModel {
        let lookup = Dictionary(miembros.map { ($0.id.uuidString, $0.resolvedDisplayName) },
                                uniquingKeysWith: { first, _ in first })
        let vm = GroupExpenseViewModel(group: grupo, members: miembros, memberNameLookup: lookup)
        vm.setContext(context)
        vm.currencyCode = reparto.moneda.isEmpty ? grupo.currencyCode : reparto.moneda
        vm.amountString = monto.map { AmountInputHelper.formatWithGrouping($0) } ?? ""
        guard !reparto.participantes.isEmpty else { return vm }
        vm.splitType = reparto.tipo
        vm.selectedMemberIDs = Set(reparto.participantes.map(\.uuidString))
        var porcentajes: [(id: String, percentage: Double)] = []
        for (uuid, valor) in reparto.valores {
            let id = uuid.uuidString
            switch reparto.tipo {
            case .exact: vm.exactAmounts[id] = AmountInputHelper.formatWithGrouping(valor)
            case .percentage: porcentajes.append((id: id, percentage: valor))
            case .shares: vm.sharesCounts[id] = String(Int(valor.rounded()))
            case .equal: break
            }
        }
        if !porcentajes.isEmpty { vm.loadPercentages(porcentajes) }
        return vm
    }

    /// Lo elegido en el selector, con la parte propia del monto de ahora. Quien no recibió valor no participa.
    static func extraer(_ vm: GroupExpenseViewModel, zona: String) -> AsistentePagoPlanificadoReparto {
        vm.purgeEmptyParticipants()
        var reparto = AsistentePagoPlanificadoReparto(grupoZona: zona, moneda: vm.currencyCode, tipo: vm.splitType)
        reparto.participantes = vm.selectedMemberIDs.compactMap { UUID(uuidString: $0) }.sorted { $0.uuidString < $1.uuidString }
        for id in vm.selectedMemberIDs {
            guard let uuid = UUID(uuidString: id) else { continue }
            switch vm.splitType {
            case .equal: break
            case .exact: reparto.valores[uuid] = AmountInputHelper.parseDecimal(vm.exactAmounts[id] ?? "")
            case .percentage: reparto.valores[uuid] = AmountInputHelper.parseDecimal(vm.percentages[id] ?? "")
            case .shares: reparto.valores[uuid] = AmountInputHelper.parseDecimal(vm.sharesCounts[id] ?? "")
            }
        }
        if let mio = vm.currentUserMemberID { reparto.miParte = vm.effectiveAmountsByID[mio] ?? 0 }
        reparto.listo = !reparto.participantes.isEmpty && vm.isSharesBalanced && vm.currentUserMemberID != nil
        return reparto
    }

    /// Con el monto de ahora: volver atrás y cambiar el monto mueve la parte propia.
    static func recalcular(
        _ reparto: AsistentePagoPlanificadoReparto, grupos: [SplitGroup], monto: Double?, in context: ModelContext
    ) -> AsistentePagoPlanificadoReparto {
        guard let zona = reparto.grupoZona, let grupo = grupos.first(where: { $0.cloudKitZoneID == zona }) else {
            return reparto
        }
        let vm = viewModel(reparto, grupo: grupo, miembros: miembros(de: grupo, in: context), monto: monto, in: context)
        return extraer(vm, zona: zona)
    }
}

// MARK: - ¿Es un gasto compartido?

struct AsistentePasoCompartido: View {
    private typealias A = L10n.AsistentePagoPlanificado

    @Bindable var estado: AsistentePagoPlanificadoEstado
    let grupos: [SplitGroup]
    let miembrosActivos: (SplitGroup) -> Int

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            AsistenteOpcion(titulo: A.soloMio, detalle: A.soloMioPista, icono: "person.fill",
                            elegida: estado.reparto.grupoZona == nil, id: "asistente_pago_compartido_no") {
                estado.reparto = AsistentePagoPlanificadoReparto()
            }
            ForEach(grupos) { grupo in
                AsistenteOpcion(titulo: grupo.name, detalle: A.grupoPista(miembrosActivos(grupo), grupo.currencyCode),
                                icono: grupo.iconName,
                                elegida: estado.reparto.grupoZona == grupo.cloudKitZoneID,
                                id: "asistente_pago_compartido_grupo") {
                    elegir(grupo)
                }
            }
        }
    }

    /// Elegir un grupo deja ya su división por defecto (todos, en su modo): el camino común sigue sin tocar nada más.
    private func elegir(_ grupo: SplitGroup) {
        guard estado.reparto.grupoZona != grupo.cloudKitZoneID else { return }
        let base = AsistentePagoPlanificadoReparto(grupoZona: grupo.cloudKitZoneID, moneda: grupo.currencyCode)
        let vm = AsistenteRepartoPuente.viewModel(
            base, grupo: grupo, miembros: AsistenteRepartoPuente.miembros(de: grupo, in: modelContext),
            monto: estado.monto, in: modelContext)
        estado.reparto = AsistenteRepartoPuente.extraer(vm, zona: grupo.cloudKitZoneID)
    }
}

// MARK: - ¿Cómo lo dividen?

struct AsistentePasoReparto: View {
    private typealias A = L10n.AsistentePagoPlanificado

    @Bindable var estado: AsistentePagoPlanificadoEstado
    let grupos: [SplitGroup]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    @State private var vm: GroupExpenseViewModel?
    @State private var muestraDivision = false
    @State private var muestraMoneda = false
    @State private var moneda: CurrencyCode = .usd

    private var grupo: SplitGroup? {
        grupos.first { $0.cloudKitZoneID == estado.reparto.grupoZona }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AsistenteTarjeta {
                fila(icono: "coloncurrencysign.circle", titulo: A.repartoMoneda, valor: estado.reparto.moneda,
                     id: "asistente_pago_reparto_moneda") { muestraMoneda = true }
                Divider().padding(.leading, DS.Spacing.lg)
                fila(icono: "chart.pie.fill", titulo: A.repartoDivision, valor: resumen,
                     id: "asistente_pago_reparto_division") { abrirDivision() }
            }
            Button(A.repartoCambiar, action: abrirDivision)
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(theme.accentText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("asistente_pago_reparto_cambiar")
        }
        .onAppear { moneda = CurrencyCode(rawValue: estado.reparto.moneda) ?? .usd }
        .onChange(of: moneda) { _, nueva in cambiarMoneda(nueva) }
        .sheet(isPresented: $muestraDivision, onDismiss: tomarDivision) {
            if let vm { GroupSplitSelectorView(viewModel: vm) }
        }
        .sheet(isPresented: $muestraMoneda) {
            CurrencyPickerSheet(selectedCurrency: $moneda)
        }
    }

    /// «Entre 2 · Partes iguales · Tu parte S/ 60.00», o «Elegir» si la división no cuadra.
    private var resumen: String {
        guard estado.reparto.listo else { return NSLocalizedString("common.select", comment: "") }
        // Estimado: «≈», como la tarjeta del resumen, que pinta esta misma cifra.
        let parte = appPreferences.currency(estado.reparto.miParte, currencyCode: estado.reparto.moneda,
                                            isEstimate: estado.draft.isVariableAmount)
        return L10n.Scheduled.GroupExpense.splitSummary(estado.reparto.participantes.count,
                                                        estado.reparto.tipo.shortName, parte)
    }

    private func fila(icono: String, titulo: String, valor: String, id: String,
                      accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icono)
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(titulo)
                    .foregroundStyle(Color(.label))
                Spacer(minLength: DS.Spacing.sm)
                Text(valor)
                    .foregroundStyle(estado.reparto.listo || id.hasSuffix("moneda")
                                     ? Color(.secondaryLabel) : Color.hotPink)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func abrirDivision() {
        guard let grupo else { return }
        vm = AsistenteRepartoPuente.viewModel(
            estado.reparto, grupo: grupo, miembros: AsistenteRepartoPuente.miembros(de: grupo, in: modelContext),
            monto: estado.monto, in: modelContext)
        muestraDivision = true
    }

    private func tomarDivision() {
        guard let vm, let zona = estado.reparto.grupoZona else { return }
        estado.reparto = AsistenteRepartoPuente.extraer(vm, zona: zona)
    }

    /// Otra moneda: la división vuelve a la del grupo (los montos exactos de antes eran de la otra moneda), como en el
    /// formulario.
    private func cambiarMoneda(_ nueva: CurrencyCode) {
        guard nueva.rawValue != estado.reparto.moneda, let grupo, let zona = estado.reparto.grupoZona else { return }
        let base = AsistentePagoPlanificadoReparto(grupoZona: zona, moneda: nueva.rawValue)
        let vm = AsistenteRepartoPuente.viewModel(
            base, grupo: grupo, miembros: AsistenteRepartoPuente.miembros(de: grupo, in: modelContext),
            monto: estado.monto, in: modelContext)
        estado.reparto = AsistenteRepartoPuente.extraer(vm, zona: zona)
        if let elegida = estado.extras.accountID,
           (modelContext.model(for: elegida) as? Account)?.currencyCode != nueva.rawValue {
            estado.extras.accountID = nil
        }
    }
}

// MARK: - ¿Algo más?

struct AsistentePasoAlgoMas: View {
    private typealias A = L10n.AsistentePagoPlanificado
    private typealias T = L10n.PrimerosPasos23.Payment

    @Bindable var estado: AsistentePagoPlanificadoEstado
    let cuentas: [Account]
    let etiquetas: [Tag]
    /// La cuenta que se usa si no se elige otra.
    let cuentaPorDefecto: Account?

    // Copias locales de lo de `estado.extras` para los controles (sin `Binding(get:set:)`, `swiftui-ds.md`).
    @State private var cuentaID: PersistentIdentifier?
    @State private var termina = false
    @State private var fin = Calendar.current.startOfDay(for: .now)

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AsistenteTarjeta {
                cuentaFila
                Divider().padding(.leading, DS.Spacing.lg)
                TextField("", text: $estado.extras.note, prompt: Text(A.algoMasNota).yalaFieldPrompt())
                    .yalaFieldText()
                    .padding(DS.Spacing.lg)
                    .accessibilityLabel(A.algoMasNota)
                    .accessibilityIdentifier("asistente_pago_extra_nota")
                if estado.reparto.grupoZona == nil && !etiquetas.isEmpty {
                    Divider().padding(.leading, DS.Spacing.lg)
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(A.algoMasEtiquetas)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: DS.Spacing.sm) {
                            ForEach(etiquetas) { etiqueta in
                                TutorialChip(title: etiqueta.name,
                                             isOn: estado.extras.tagIDs.contains(etiqueta.persistentModelID),
                                             id: "asistente_pago_extra_etiqueta") {
                                    alternar(etiqueta)
                                }
                            }
                        }
                    }
                    .padding(DS.Spacing.lg)
                }
            }
            AsistenteTarjeta {
                if estado.draft.frequency.isRecurring {
                    Toggle(A.algoMasTermina, isOn: $termina)
                        .padding(DS.Spacing.lg)
                        .accessibilityIdentifier("asistente_pago_extra_termina")
                    if termina {
                        DatePicker(A.algoMasUltimoPago, selection: $fin,
                                   in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.md)
                            .accessibilityIdentifier("asistente_pago_extra_fin")
                    }
                    Divider().padding(.leading, DS.Spacing.lg)
                }
                Toggle(L10n.Scheduled.Editor.active, isOn: $estado.extras.isActive)
                    .padding(DS.Spacing.lg)
                    .accessibilityIdentifier("asistente_pago_extra_activo")
            }
        }
        .onAppear(perform: copiar)
        .onChange(of: cuentaID) { _, nueva in estado.extras.accountID = nueva }
        .onChange(of: termina) { _, encendido in estado.extras.endDate = encendido ? fin : nil }
        .onChange(of: fin) { _, nueva in if termina { estado.extras.endDate = nueva } }
    }

    /// Lo que ya estaba respondido (volver a este paso desde el resumen). Sin fin elegido, la fecha propuesta es dentro
    /// de un año.
    private func copiar() {
        cuentaID = cuentaElegida?.persistentModelID
        termina = estado.extras.endDate != nil
        let calendario = Calendar.current
        fin = estado.extras.endDate
            ?? calendario.date(byAdding: .year, value: 1, to: calendario.startOfDay(for: .now))
            ?? calendario.startOfDay(for: .now)
    }

    /// Las cuentas que se pueden elegir: en un pago compartido, las de su moneda.
    private var opciones: [Account] {
        guard estado.reparto.grupoZona != nil else { return cuentas }
        return cuentas.filter { $0.currencyCode == estado.reparto.moneda }
    }

    private var cuentaElegida: Account? {
        if let id = estado.extras.accountID, let elegida = opciones.first(where: { $0.persistentModelID == id }) {
            return elegida
        }
        return cuentaPorDefecto
    }

    private var cuentaFila: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(A.algoMasCuenta)
                .font(DS.Typography.body)
            Spacer(minLength: DS.Spacing.sm)
            Picker(A.algoMasCuenta, selection: $cuentaID) {
                ForEach(opciones) { cuenta in
                    Text(cuenta.name).tag(Optional(cuenta.persistentModelID))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .accessibilityLabel(A.algoMasCuenta)
            .accessibilityIdentifier("asistente_pago_extra_cuenta")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func alternar(_ etiqueta: Tag) {
        let id = etiqueta.persistentModelID
        if estado.extras.tagIDs.contains(id) { estado.extras.tagIDs.remove(id) } else { estado.extras.tagIDs.insert(id) }
    }
}
