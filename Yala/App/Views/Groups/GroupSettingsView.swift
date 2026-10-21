//
//  GroupSettingsView.swift
//  Yala
//
//  Hoja de ajustes del grupo — info, opciones, presupuesto, resumen, salir, archivar y eliminar.
//
//  Desde el lote 19 decidido de la auditoría UX 2.2 (Jürgen, 18 y 19-oct) es una lista agrupada como «Ajustes de
//  Grupos» (`YalaSettingsList`, lienzo «Una sola Yala»): un bloque por sección y la ayuda en el pie del bloque. Las
//  opciones se explican con un ejemplo (L19-7), el presupuesto se fija en su hoja (L19-6), archivar y eliminar van
//  en una tarjeta con dos pesos (L19-5) y el bloqueo de eliminar dice quién debe y cuánto (L19-10). Salir y eliminar
//  dicen qué pasa con el dinero (L19-11).
//

import SwiftUI
import SwiftData

struct GroupSettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState

    // MARK: - Input

    let group: SplitGroup
    @Bindable var viewModel: GroupDetailViewModel

    // MARK: - State

    @State private var editName: String = ""
    @State private var editIconName: String = ""
    @State private var editColorHex: String = ""
    @State private var showIconPicker: Bool = false
    @State private var simplifyDebts: Bool = false
    @State private var showDebtsInSingleCurrency: Bool = false
    @State private var selectedCurrency: CurrencyCode = .pen
    @State private var showCurrencyPicker: Bool = false
    @State private var defaultSplitType: SplitType = .equal

    /// Presupuesto del grupo (G14). La hoja (L19-6) devuelve lo tecleado como texto y lo parsea
    /// `AmountInputHelper.parseDecimal`, que respeta el separador decimal de la locale.
    @State private var showBudgetSheet: Bool = false
    @State private var showBudgetRemoveConfirm: Bool = false

    /// Resumen compartible («cierre del viaje»).
    @State private var showShareableSummary = false
    /// Cache de si hay algo que resumir — ver `recomputeShareableSummary()`.
    @State private var hasShareableSummary = false

    @State private var showArchiveConfirm = false

    /// Cache de «¿queda alguna deuda en el grupo?» para no hacer cuatro fetches por cada evaluación del body. Se
    /// recalcula en `.onAppear` y tras cada recálculo con freno del detalle (`viewModel.coalescedReloadRevision`).
    /// Desde L19-10 no cuenta el residuo de redondeo (`GroupRoundingResidueLogic`): solo las deudas de persona a persona.
    @State private var hasOutstandingDebt: Bool = false
    /// Las deudas que cuentan, del mismo cálculo: nombran a quién bloquea eliminar (L19-10).
    @State private var outstandingDebts: [Debt] = []

    // Leave group
    @State private var showLeaveGroupConfirm = false
    @State private var showLeaveWithDebtConfirm = false
    @State private var isLeavingGroup = false
    @State private var showLeaveError = false
    @State private var leaveErrorMessage: String = ""
    @State private var showActionError = false
    @State private var actionErrorMessage: String = ""

    // FU-02: soft-delete owner-only.
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeleting: Bool = false

    // Transferir y salir (owner con co-members en canal backend).
    /// Cache de `GroupService.ownerExitOffer`, recalculado en el MISMO sitio que `hasOutstandingDebt`
    /// (del que depende). `nil` hasta el primer `.onAppear` → el body cae al `fallbackOffer`, que es
    /// byte-a-byte lo que esta pantalla hacía antes de existir la transferencia.
    @State private var ownerExitOffer: GroupOwnerExitLogic.Offer?
    /// A quién iría el grupo. Se NOMBRA en la confirmación: el servidor elige heredero por su cuenta
    /// y el usuario tiene derecho a saber quién antes de confirmar algo irreversible para él.
    @State private var designatedHeirName: String?
    @State private var showTransferConfirm = false
    @State private var isTransferring = false
    /// El servidor ya dijo `no_eligible_owner` en esta sesión. Apaga la oferta hasta que llegue dato
    /// nuevo: los conteos locales no cambian con ese rechazo, así que sin esto la pantalla vuelve a
    /// ofrecer la transferencia y a nombrar al mismo heredero fantasma, en bucle.
    @State private var transferRefusedByServer = false

    // MARK: - Qué salida se ofrece

    /// El offer cacheado, o —antes del primer cálculo— exactamente lo que esta pantalla ofrecía
    /// hasta ahora. El fallback NO es defensivo por costumbre: `ownerExitOffer` necesita fetches de
    /// SwiftData y se calcula en `.onAppear`, así que hay un primer render sin él. Sin este camino,
    /// ese render escondería «Salir» y «Eliminar» a todo el mundo durante un frame.
    private var currentOffer: GroupOwnerExitLogic.Offer {
        ownerExitOffer ?? GroupOwnerExitLogic.Offer(
            showsLeave: !group.isOwner,
            showsTransferAndLeave: false,
            showsDelete: group.isOwner,
            deleteEnabled: !hasOutstandingDebt,
            deleteHint: hasOutstandingDebt ? .debtNoTransferAvailable : nil)
    }

    /// Lo que el bloqueo de «Eliminar» añade, según qué salida le quede al dueño (L19-5 y L19-10).
    ///
    /// Primero QUIÉN debe y CUÁNTO («Beto debe $ 30.00»), que es lo que faltaba; después la condición («Cuando las
    /// cuentas queden en cero podrás eliminarlo») y, si el dueño tiene otra salida, cuál: con heredero, «Transferir y
    /// salir»; sin heredero y sin archivar, «Archivar», que está en la misma tarjeta. El `switch` es exhaustivo a
    /// propósito: un caso nuevo en `DeleteHint` tiene que romper aquí, que es donde se decide qué lee el usuario.
    private func deleteBlockedText(_ hint: GroupOwnerExitLogic.DeleteHint) -> String {
        var parts: [String] = []
        // Quién debe y cuánto, con las MISMAS deudas que enseña Saldos (respetan «simplificar» y «moneda única»): con
        // las simplificadas de `outstandingDebts`, el texto decía «Ana debe S/ 50» y Saldos «Ana paga S/ 80 a Tú».
        // Si las del detalle aún no están cargadas, las simplificadas.
        let shownDebts = viewModel.debts.isEmpty ? outstandingDebts : viewModel.debts
        if let debtors = GroupDebtCopyLogic.debtorsSentence(
            debts: shownDebts,
            currentMemberID: viewModel.currentMemberID,
            name: { viewModel.memberName(for: $0) },
            money: { appPreferences.currency($0, currencyCode: $1) }
        ) {
            parts.append(debtors)
        }
        parts.append(L10n.UXL19.deleteBlockedTail)
        switch hint {
        case .debtTransferInstead:     parts.append(L10n.UXL19.deleteTransferInstead)
        case .debtArchiveInstead:      parts.append(L10n.UXL19.deleteArchiveInstead)
        case .debtNoTransferAvailable: break
        }
        return parts.joined(separator: " ")
    }

    /// Mensaje de la confirmación de «Transferir y salir»: quién hereda, y —si el usuario tiene saldo
    /// propio— el aviso de que sale con él.
    ///
    /// El aviso va como PÁRRAFO aparte y no como frase compuesta: son dos hechos independientes y
    /// concatenarlos dentro de una sola clave obligaría a cuatro variantes (con/sin nombre ×
    /// con/sin deuda) en dieciséis idiomas.
    ///
    /// Que exista es lo que iguala esta salida con las otras dos: «Salir del grupo» avisa con la cifra y
    /// «Archivar» con `archiveWithDebtWarning`. Ésta era la única que callaba, y encima es la que borra el
    /// histórico local del grupo al salir — el usuario perdía de vista quién le debía sin que nadie se lo
    /// hubiera dicho.
    private var transferConfirmMessage: String {
        // La llamada va explícita y no como referencia a función (`.map(L10n…transferAndLeaveConfirm)`):
        // pasarla como valor la saca del contexto `@MainActor` y el compilador avisa.
        let base: String
        if let name = designatedHeirName {
            base = L10n.Groups.Settings.transferAndLeaveConfirm(name)
        } else {
            base = L10n.Groups.Settings.transferAndLeaveConfirmUnknownHeir
        }
        guard hasOutstandingBalance else { return base }
        return base + "\n\n" + L10n.Groups.Settings.transferAndLeaveDebtWarning
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            YalaSettingsList {
                infoSection

                // Opciones — visibles para todos los miembros activos. Simplificar y el reparto los cambia
                // cualquiera; la moneda única, quien creó el grupo; el presupuesto, un administrador.
                if viewModel.canCurrentUserParticipate {
                    optionsSections
                }

                // Integración personal (F4): visible solo para members .isActive.
                if viewModel.canCurrentUserParticipate {
                    personalIntegrationSection
                }

                // Resumen compartible («cierre del viaje»). Va FUERA de la guarda de participación a propósito:
                // es de solo lectura y no enseña nada que quien abre esta pantalla no esté viendo ya en el
                // detalle, así que quien salió del grupo conserva la foto de cómo quedaron las cuentas.
                if hasShareableSummary {
                    shareableSummarySection
                }

                // Leave group (non-owner)
                if currentOffer.showsLeave {
                    leaveGroupSection
                }

                // Transferir y salir — la salida del DUEÑO. Va antes de «Archivar o eliminar» a propósito: es la
                // acción reversible para el grupo (sigue vivo, con sus saldos), y el bloqueo de eliminar apunta aquí.
                if currentOffer.showsTransferAndLeave {
                    transferAndLeaveSection
                }

                // L19-5: archivar y eliminar en una tarjeta, cada una con el peso de lo que hace.
                if viewModel.isCurrentUserAdmin || currentOffer.showsDelete {
                    exitsSection
                }
            }
            // `dismissKeyboardOnTap()` no va aquí: su `onTapGesture` sobre una `List` se come los toques de las filas.
            // El teclado del nombre baja al arrastrar y con «Listo».
            .scrollDismissesKeyboard(.interactively)
            .yalaScreenBackground(.subtle)
            .onDisappear { saveIdentity() }
            .onAppear {
                recomputeOwnerExit()
                recomputeShareableSummary()
            }
            // Llegó dato nuevo: el rechazo del servidor deja de ser la información más fresca que
            // tenemos. Se apunta AQUÍ, en el acto, y no tras el freno: si esperara 150 ms, un cambio
            // que llegó ANTES de la respuesta del servidor borraría el rechazo y «Transferir y salir»
            // volvería a salir. Lo caro no va aquí — ver el `onChange` siguiente.
            .onChange(of: sessionState.dataVersion) { _, _ in transferRefusedByServer = false }
            // El recálculo cuelga del freno del detalle, no de cada `dataVersion`: una ráfaga de
            // cambios remotos cuesta UN recálculo, uno cancelado no publica, y el resumen compartible
            // lee los datos del VM ya recargados (con `dataVersion` los leía 150 ms antes de la recarga).
            .onChange(of: viewModel.coalescedReloadRevision) { _, _ in recomputeAfterRemoteChange() }
            .navigationTitle(L10n.Groups.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                NavigationStack {
                    CurrencySelectorView(selectedCurrency: $selectedCurrency)
                }
            }
            // Cuelga del stack y no de `shareableSummarySection` a propósito: la sección desaparece
            // en cuanto el grupo se queda sin gastos, y si un sync la retirase con el resumen
            // abierto, UIKit tumbaría la presentación dejando el flag en `true` — el cover fantasma
            // de la regla de presentaciones. El stack, en cambio, siempre está.
            .sheet(isPresented: $showShareableSummary) {
                GroupShareableSummarySheet(group: group, viewModel: viewModel)
            }
            // L19-6: el presupuesto se fija en su hoja, no en una alerta. Cuelga del stack por lo mismo que el resumen.
            .sheet(isPresented: $showBudgetSheet) {
                GroupBudgetSheet(
                    group: group,
                    expenses: viewModel.expenses,
                    initialInput: budgetInputSeed(),
                    onSave: { saveBudgetLimitFromInput($0) }
                )
                .yalaSheetDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .modifier(LeavePresentations(
                showLeaveGroupConfirm: $showLeaveGroupConfirm,
                showLeaveWithDebtConfirm: $showLeaveWithDebtConfirm,
                leaveWithDebtMessage: leaveWithDebtMessage,
                onLeave: { Task { await leaveGroup() } },
                onSettleFirst: { settleFirstFromLeave() }
            ))
            .confirmationDialog(
                L10n.Groups.Settings.archive,
                isPresented: $showArchiveConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.archive, role: .destructive) {
                    performArchiveToggle(isArchiving: true)
                }
                Button(L10n.Common.cancel) {}
                    .accessibilityIdentifier("group_settings_archive_cancel")
            } message: {
                if hasOutstandingDebt {
                    Text(L10n.Groups.Settings.archiveWithDebtWarning)
                } else {
                    Text(L10n.Groups.Settings.archiveConfirm)
                }
            }
            .alert(L10n.Common.error, isPresented: $showLeaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(leaveErrorMessage)
            }
            .alert(L10n.Common.error, isPresented: $showActionError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(actionErrorMessage)
            }
            .confirmationDialog(
                L10n.Groups.Budget.removeConfirm,
                isPresented: $showBudgetRemoveConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Budget.remove, role: .destructive) { applyBudgetLimit(nil) }
                Button(L10n.Common.cancel) {}
                    .accessibilityIdentifier("group_budget_remove_cancel")
            }
            .confirmationDialog(
                L10n.Groups.Settings.deleteGroupConfirm,
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    Task { await performSoftDelete() }
                }
                Button(L10n.Common.cancel) {}
                    .accessibilityIdentifier("group_settings_delete_cancel")
            } message: {
                // L19-11: qué pasa con tu dinero. Lo que el puente apuntó en tus cuentas reales se queda
                // (`GroupTransactionBridge.freezeForSoftDelete` libera las transacciones de cuenta real).
                Text(L10n.UXL19.deleteBody)
            }
            .confirmationDialog(
                L10n.Groups.Settings.transferAndLeave,
                isPresented: $showTransferConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.transferAndLeave, role: .destructive) {
                    Task { await transferAndLeave() }
                }
                Button(L10n.Common.cancel) {}
                    .accessibilityIdentifier("group_settings_transfer_cancel")
            } message: {
                // El nombre del heredero es el punto del diálogo. Si por lo que sea no se pudo
                // resolver, se dice el hecho sin nombre en vez de callarlo: nombrar a quien no toca
                // sería peor que no nombrar.
                Text(transferConfirmMessage)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        YalaSettingsSection(L10n.Groups.Settings.info) {
            HStack(spacing: DS.Spacing.md) {
                if viewModel.isCurrentUserAdmin {
                    // Group icon — tappable to change (admin only)
                    Button {
                        showIconPicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: editColorHex))
                                .frame(width: 48, height: 48) // A11Y-DT: fixed icon size matching CategoryDetailView pattern

                            Image(systemName: editIconName)
                                .font(DS.Typography.title2)
                                .foregroundStyle(.white)

                            // A11Y-DT: decorative edit badge on group icon
                            Image(systemName: "pencil.circle.fill")
                                .font(DS.Typography.label)
                                .foregroundStyle(Color(hex: editColorHex))
                                .background(Circle().fill(.white).frame(width: 16, height: 16))
                                .offset(x: 16, y: 16)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Groups.Form.icon)

                    // Group name — editable inline (admin only). L19-7: el lápiz al lado dice que se puede tocar;
                    // antes era un campo sin borde que se leía como un título.
                    TextField(L10n.Groups.Form.namePlaceholder, text: $editName)
                        .font(DS.Typography.headline)
                        .submitLabel(.done)
                        .onSubmit { saveIdentity() }
                        .accessibilityIdentifier("group_settings_name_field")

                    Image(systemName: "pencil")
                        .font(DS.Typography.body)
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .accessibilityHidden(true)
                } else {
                    // Group icon — static (non-admin)
                    ZStack {
                        Circle()
                            .fill(Color(hex: editColorHex))
                            .frame(width: 48, height: 48) // A11Y-DT: fixed icon size matching CategoryDetailView pattern

                        Image(systemName: editIconName)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.white)
                    }

                    // Group name — read-only (non-admin)
                    Text(editName)
                        .font(DS.Typography.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DS.Spacing.xxs)
        }
        .onAppear {
            editName = group.name
            editIconName = group.iconName
            editColorHex = group.colorHex
        }
        .sheet(isPresented: $showIconPicker, onDismiss: {
            saveIdentity()
        }) {
            IconColorPickerSheet(
                selectedIconName: $editIconName,
                selectedColorHex: $editColorHex
            )
        }
    }

    // MARK: - Options (L19-7: cada opción con su ejemplo, en el pie de su bloque)

    @ViewBuilder
    private var optionsSections: some View {
        // Menos pagos entre ustedes — cualquier miembro activo.
        YalaSettingsSection(L10n.Groups.Settings.options) {
            YalaSettingsToggleRow(L10n.UXL19.simplify, isOn: $simplifyDebts)
                .accessibilityIdentifier("group_settings_simplify_toggle")
        } footer: {
            Text(L10n.UXL19.simplifyExample)
        }
        .onChange(of: simplifyDebts) { _, newValue in
            // Guard de igualdad: el `.onAppear` siembra el @State desde el group, lo que
            // dispararía un save+sync espurio en cada apertura sin este check.
            guard newValue != group.simplifyDebts else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                updateMemberOption { $0.simplifyDebts = newValue }
            }
        }

        // Ver las deudas en una sola moneda — solo quien creó el grupo (visible para todos, apagado si no).
        YalaSettingsSection {
            YalaSettingsToggleRow(L10n.UXL19.singleCurrency, isOn: $showDebtsInSingleCurrency, isDisabled: !group.isOwner)
            if showDebtsInSingleCurrency {
                Button {
                    showCurrencyPicker = true
                } label: {
                    let info = currencyInfo(for: selectedCurrency)
                    YalaSettingsRowLabel(title: L10n.Groups.Form.currency, value: "\(info.flag) \(info.code)")
                }
                .disabled(!group.isOwner)
            }
        } footer: {
            Text(group.isOwner
                 ? L10n.Groups.Form.showDebtsInSingleCurrencyHint
                 : L10n.Groups.Form.showDebtsInSingleCurrencyHint + " " + L10n.UXL19.ownerOnly)
        }
        .onChange(of: showDebtsInSingleCurrency) { _, newValue in
            guard newValue != group.showDebtsInSingleCurrency else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                updateGroupOption { group in
                    group.showDebtsInSingleCurrency = newValue
                    if !newValue {
                        group.currencyCode = appPreferences.defaultCurrencyCode.rawValue
                    }
                }
                if !newValue {
                    selectedCurrency = appPreferences.defaultCurrencyCode
                }
            }
        }
        .onChange(of: selectedCurrency) { _, newValue in
            guard newValue.rawValue != group.currencyCode else { return }
            updateGroupOption { $0.currencyCode = newValue.rawValue }
        }

        // Cómo se reparte un gasto nuevo — cualquier miembro activo.
        YalaSettingsSection {
            Picker(L10n.UXL19.splitType, selection: $defaultSplitType) {
                ForEach(SplitType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
        }
        .onChange(of: defaultSplitType) { _, newValue in
            guard newValue.rawValue != group.defaultSplitType else { return }
            updateMemberOption { $0.defaultSplitType = newValue.rawValue }
        }

        budgetSection
            .onAppear {
                simplifyDebts = group.simplifyDebts
                showDebtsInSingleCurrency = group.showDebtsInSingleCurrency
                selectedCurrency = CurrencyCode(rawValue: group.currencyCode) ?? .pen
                defaultSplitType = SplitType(rawValue: group.defaultSplitType) ?? .equal
            }
    }

    /// Presupuesto del grupo (G14) — ADMIN-only, y no por criterio de la app: la policy `split_groups_update` del
    /// backend exige `is_group_admin`, así que ofrecérselo a un miembro normal sería ofrecer un cambio que el server
    /// descarta y que se quedaría solo en su teléfono. Y el grupo CONGELADO se gatea igual que en el resto de Grupos:
    /// `setBudgetLimit` llama a `validateGroupIsWritable` ANTES que al guard de admin (`canEditBudget`).
    private var budgetSection: some View {
        YalaSettingsSection {
            Button {
                showBudgetSheet = true
            } label: {
                YalaSettingsRowLabel(title: L10n.Groups.Budget.title, value: budgetValueText)
            }
            .disabled(!canEditBudget)
            .accessibilityIdentifier("group_settings_budget_row")

            // «Quitar» tiene su fila y su confirmación: junto al de guardar invitaba a borrar sin querer.
            if group.budgetLimitAmount != nil && canEditBudget {
                Button(role: .destructive) {
                    showBudgetRemoveConfirm = true
                } label: {
                    Text(L10n.Groups.Budget.remove)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                }
                .accessibilityIdentifier("group_settings_budget_remove")
            }
        } footer: {
            Text(budgetFooterText)
        }
    }

    private var budgetValueText: String {
        guard let limit = group.budgetLimitAmount else { return L10n.Groups.Budget.none }
        return appPreferences.currency(limit, currencyCode: group.currencyCode)
    }

    private var budgetFooterText: String {
        let hint = L10n.Groups.Budget.hint(appPreferences.currencyDisplayFormat.label(for: group.currencyCode))
        return viewModel.isCurrentUserAdmin ? hint : hint + " " + L10n.Groups.Budget.adminOnly
    }

    // MARK: - Personal Integration (Bridge Override per-grupo, F4)

    @State private var showPerGroupDeactivationSheet: Bool = false
    @State private var showGroupsGlobalSettings: Bool = false

    private var personalIntegrationState: OverrideStateLogic.UIState {
        OverrideStateLogic.compute(
            global: appPreferences.bridgeGroupExpensesToPersonalAccounts,
            override: BridgeModeResolver.shared.override(forZoneID: group.cloudKitZoneID, context: modelContext),
            memberIsActive: viewModel.canCurrentUserParticipate
        )
    }

    /// Binding al estado visual del toggle. Lectura: deriva del state computed.
    /// Escritura: invoca el resolver para persistir override.
    private var personalIntegrationToggle: Binding<Bool> {
        Binding(
            get: {
                switch personalIntegrationState {
                case .enabledOnInheriting, .enabledOnLocal: return true
                case .enabledOffLocal, .disabledOff, .hiddenSection: return false
                }
            },
            set: { newValue in
                let global = appPreferences.bridgeGroupExpensesToPersonalAccounts
                guard global else { return }  // disabled cuando global OFF
                do {
                    // ON estando OFF → setOverride(nil) (volver a heredar).
                    // OFF estando ON → setOverride(false) (override OFF explícito).
                    let override: Bool? = newValue ? nil : false
                    try BridgeModeResolver.shared.setOverride(for: group, override: override, in: modelContext)
                    // Si user desactivó (newValue==false) Y hay TX bridgeadas para este
                    // grupo, presenta BridgeDeactivationSheet scoped (plan F4) para que
                    // el user decida freeze vs delete.
                    if !newValue && hasBridgedTransactionsForGroup() {
                        showPerGroupDeactivationSheet = true
                    }
                } catch {
                    #if DEBUG
                    print("personalIntegrationToggle: setOverride failed: \(error)")
                    #endif
                }
            }
        )
    }

    @ViewBuilder
    private var personalIntegrationSection: some View {
        let state = personalIntegrationState
        if state != .hiddenSection {
            YalaSettingsSection(L10n.UXL19.personalSection) {
                YalaSettingsToggleRow(
                    L10n.UXL19.personalToggle,
                    isOn: personalIntegrationToggle,
                    isDisabled: state == .disabledOff
                )
                // UX 2.2 · L13-14: el aviso manda a Ajustes de Grupos; ahora lleva el camino.
                if state == .disabledOff {
                    Button(L10n.Groups.Settings.openGroupsSettings) {
                        showGroupsGlobalSettings = true
                    }
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.accent)
                    .accessibilityIdentifier("group_settings_open_groups_settings")
                }
            } footer: {
                Text(personalIntegrationHint(for: state))
            }
            .sheet(isPresented: $showGroupsGlobalSettings) {
                GroupsGlobalSettingsView()
            }
            .sheet(isPresented: $showPerGroupDeactivationSheet) {
                BridgeDeactivationSheet(
                    scope: .perGroup(zoneID: group.cloudKitZoneID, groupName: group.name),
                    onConfirm: { /* cleanup hecho dentro del sheet */ },
                    onCancel: revertPerGroupOverride
                )
            }
        }
    }

    /// Revierte el override per-grupo cuando user cancela el sheet de deactivation
    /// (restauración del intent: si user cancela, no quiere desactivar).
    private func revertPerGroupOverride() {
        do {
            try BridgeModeResolver.shared.setOverride(for: group, override: nil, in: modelContext)
        } catch {
            #if DEBUG
            print("revertPerGroupOverride failed: \(error)")
            #endif
        }
    }

    /// Conteo de TX bridgeadas para este grupo (`splitGroupZoneID == cloudKitZoneID`).
    private func hasBridgedTransactionsForGroup() -> Bool {
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> {
                $0.splitGroupZoneID == zoneID &&
                ($0.splitExpenseID != nil || $0.splitSettlementID != nil)
            }
        )
        do {
            return try modelContext.fetchCount(descriptor) > 0
        } catch {
            #if DEBUG
            print("hasBridgedTransactionsForGroup: fetchCount failed: \(error)")
            #endif
            return false
        }
    }

    private func personalIntegrationHint(for state: OverrideStateLogic.UIState) -> String {
        switch state {
        case .hiddenSection: return ""
        case .disabledOff: return L10n.Groups.Settings.personalIntegrationHintBlockedByGlobal
        case .enabledOnInheriting, .enabledOnLocal: return L10n.UXL19.personalInherit
        case .enabledOffLocal: return L10n.Groups.Settings.personalIntegrationHintLocalOff
        }
    }

    // MARK: - Resumen compartible («cierre del viaje»)

    /// Si se ofrece el resumen compartible. Es un cache, recalculado en los MISMOS sitios que
    /// `hasOutstandingDebt` (`.onAppear` + `onChange(coalescedReloadRevision)`), para no armar el snapshot en
    /// cada evaluación del body.
    ///
    /// Lo decide el SNAPSHOT y no `!viewModel.expenses.isEmpty`, que era un proxy y no coincidía:
    /// esa lista incluye los saldos iniciales, que el resumen no cuenta como gasto. Un grupo
    /// importado de Splitwise cuyos únicos «gastos» son saldos iniciales ya liquidados pasaba el
    /// proxy y producía una tarjeta con la cabecera, la fecha y el pie, y nada en medio: la imagen
    /// en blanco que el propio gate decía querer evitar.
    private func recomputeShareableSummary() {
        // Un grupo migrado y congelado enseña una COPIA de cuando se movió, y la app lo dice en su
        // banner («puede que no esté al día»). El resumen no tiene dónde poner ese aviso y encima
        // fecha la imagen HOY, así que sería un documento con pinta de autoritativo sobre datos que
        // la propia app declara viejos. No se ofrece.
        //
        // Ojo: esto NO es `canCurrentUserParticipate`, que junta el congelado con «no eres miembro
        // activo». Quien salió del grupo sí conserva el resumen — es de solo lectura y no enseña
        // nada que no esté viendo en el detalle.
        guard !group.isMigratedFrozen else {
            hasShareableSummary = false
            return
        }

        hasShareableSummary = !GroupShareableSummaryLogic.build(
            group: group,
            members: viewModel.members,
            expenses: viewModel.expenses,
            shares: viewModel.shares,
            settlements: viewModel.settlements,
            unknownMemberName: L10n.Groups.ShareableSummary.unknownMember
        ).isEmpty
    }

    private var shareableSummarySection: some View {
        YalaSettingsSection(L10n.Groups.ShareableSummary.title) {
            Button {
                showShareableSummary = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.thAccent)
                    Text(L10n.Groups.ShareableSummary.action)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.labelSmall.weight(.medium))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("group_settings_share_summary_button")
        } footer: {
            Text(L10n.Groups.ShareableSummary.hint)
        }
    }

    // MARK: - Leave Group

    private var leaveGroupSection: some View {
        YalaSettingsSection {
            Button {
                openLeaveConfirmation()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Text(L10n.Groups.Settings.leaveGroup)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Spacer()
                    if isLeavingGroup {
                        ProgressView()
                    }
                }
                .contentShape(Rectangle())
            }
            .disabled(isLeavingGroup)
            .accessibilityIdentifier("group_settings_leave")
        }
    }

    /// L19-11: con deuda propia, el aviso con la cifra y «Saldar primero»; sin ella, la confirmación de siempre.
    private func openLeaveConfirmation() {
        if hasOutstandingBalance {
            showLeaveWithDebtConfirm = true
        } else {
            showLeaveGroupConfirm = true
        }
    }

    /// Las deudas en las que estoy, tal como las enseña el grupo (respeta «simplificar» y «moneda única»).
    private var myDebts: [Debt] {
        guard let me = viewModel.currentMemberID else { return [] }
        return GroupDebtCopyLogic.debts(involving: me, in: viewModel.debts)
    }

    /// «Debes S/ 270.00 a Ana. Si sales, dejas de ver este grupo y esa deuda; Ana la seguirá viendo.» (L19-11).
    private var leaveWithDebtMessage: String {
        guard let me = viewModel.currentMemberID, !myDebts.isEmpty else {
            return L10n.Groups.Settings.leaveGroupWithDebtWarning
        }
        let sentences = GroupDebtCopyLogic.relationSentences(
            about: me,
            debts: viewModel.debts,
            currentMemberID: me,
            name: { viewModel.memberName(for: $0) },
            money: { appPreferences.currency($0, currencyCode: $1) }
        )
        let counterparts = Set(myDebts.map { $0.fromMemberID == me ? $0.toMemberID : $0.fromMemberID })
        let tail: String
        if counterparts.count == 1, let other = counterparts.first {
            tail = L10n.UXL19.leaveDebtTailOne(viewModel.memberName(for: other))
        } else {
            tail = L10n.UXL19.leaveDebtTailMany
        }
        return (sentences + [tail]).joined(separator: " ")
    }

    /// «Saldar primero» al salir: con una sola deuda, «Saldar» con ella; con varias, Saldos.
    private func settleFirstFromLeave() {
        let debts = myDebts
        if debts.count == 1, let debt = debts.first {
            viewModel.requestAfterSheetDismiss(.settle(debt))
        } else {
            viewModel.requestAfterSheetDismiss(.showBalances)
        }
    }

    // MARK: - Transferir y salir (owner con heredero, canal backend)

    private var transferAndLeaveSection: some View {
        YalaSettingsSection {
            Button {
                // Refresca antes de abrir el diálogo — simétrico con «Eliminar» y `toggleArchive`. Aquí importa
                // doble: si el sync trajo la salida del último co-member, el heredero que íbamos a nombrar ya no existe.
                recomputeOwnerExit()
                guard currentOffer.showsTransferAndLeave else { return }
                showTransferConfirm = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Text(L10n.Groups.Settings.transferAndLeave)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Spacer()
                    if isTransferring {
                        ProgressView()
                    }
                }
                .contentShape(Rectangle())
            }
            .disabled(isTransferring || isDeleting)
            .accessibilityIdentifier("group_settings_transfer")
        } footer: {
            Text(L10n.Groups.Settings.transferAndLeaveHint)
        }
    }

    private func transferAndLeave() async {
        guard !isTransferring else { return }
        isTransferring = true
        defer { isTransferring = false }

        do {
            switch try await GroupService.shared.transferOwnershipThenLeave(group) {
            case .left:
                DS.Haptic.success()
                dismiss()
            case .needsDecision:
                // El servidor no encontró heredero (el último co-member elegible se fue entre que
                // pintamos el botón y el usuario confirmó). NO es un error del usuario ni del canal:
                // es un cambio de estado, y el copy lo dice tal cual. La pantalla se queda abierta y
                // se recalcula, así que el botón desaparece solo.
                DS.Haptic.warning()
                actionErrorMessage = L10n.Groups.Errors.transferNoHeir
                showActionError = true
                transferRefusedByServer = true
                recomputeOwnerExit()
            }
        } catch {
            DS.Haptic.warning()
            // Mismo contrato que `leaveGroup()`: nunca un número crudo ni una dev-string.
            actionErrorMessage = GroupLeaveErrorLogic.classify(
                error, attestUnavailable: GroupsAttestStreakStore.isTerminal()).localizedMessage
            showActionError = true
        }
    }

    // MARK: - L19-5 · Archivar o eliminar, cada uno con su peso

    private var exitsSection: some View {
        let showsArchive = viewModel.isCurrentUserAdmin
        let showsDelete = currentOffer.showsDelete
        return YalaSettingsSection(showsArchive && showsDelete ? L10n.UXL19.exitsSectionBoth : L10n.UXL19.exitsSectionArchive) {
            if showsArchive {
                archiveRow
            }
            if showsDelete {
                deleteRow
            }
        }
    }

    /// Archivar se deshace con un toque: va en el color de la app, no en rojo. Desarchivar, igual.
    private var archiveRow: some View {
        Button {
            toggleArchive()
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: group.isArchived ? "tray.and.arrow.up" : "archivebox")
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thAccent)
                    .frame(width: 28, alignment: .center) // A11Y-DT: columna de icono de la fila
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(group.isArchived ? L10n.Groups.Settings.unarchive : L10n.Groups.Settings.archive)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)
                    Text(group.isArchived ? L10n.UXL19.unarchiveBody : L10n.UXL19.archiveBody)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall.weight(.medium))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group_settings_archive")
    }

    /// Eliminar no se deshace: rojo. Bloqueado, rojo apagado, con quién debe y cuánto y «Ver los saldos» (L19-10).
    private var deleteRow: some View {
        let offer = currentOffer
        let blocked = !offer.deleteEnabled
        let red = DS.Semantic.errorForeground.opacity(blocked ? 0.5 : 1)
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Button {
                // Refresh cache antes de mostrar el dialog — simétrico con toggleArchive, evita falsos negativos si
                // el sync trajo deuda después del último onAppear/dataVersion change.
                recomputeOwnerExit()
                guard currentOffer.deleteEnabled else { return }
                showDeleteConfirm = true
            } label: {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Image(systemName: "trash")
                        .font(DS.Typography.title3)
                        .foregroundStyle(red)
                        .frame(width: 28, alignment: .center) // A11Y-DT: columna de icono de la fila
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(L10n.Groups.Settings.deleteGroup)
                            .font(DS.Typography.body)
                            .foregroundStyle(red)
                        Text(deleteRowBody(offer))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("group_settings_delete_body")
                    }
                    Spacer(minLength: 0)
                    if isDeleting {
                        ProgressView()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(blocked || isDeleting || isTransferring)
            .accessibilityIdentifier("group_settings_delete")

            if blocked {
                Button {
                    viewModel.requestAfterSheetDismiss(.showBalances)
                } label: {
                    // El área táctil va DENTRO del label: con el `frame` colgado del botón medía 13 pt de alto.
                    Text(L10n.UXL19.seeBalances)
                        .font(DS.Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(.thAccent)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 28 + DS.Spacing.md) // A11Y-DT: alineado con el texto de la fila
                .accessibilityIdentifier("group_settings_see_balances")
            }
        }
    }

    private func deleteRowBody(_ offer: GroupOwnerExitLogic.Offer) -> String {
        guard !offer.deleteEnabled, let hint = offer.deleteHint else { return L10n.UXL19.deleteRowBody }
        return L10n.UXL19.deleteRowBody + " " + deleteBlockedText(hint)
    }

    private func performSoftDelete() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            try GroupService.shared.softDelete(group)
            DS.Haptic.warning()
            dismiss()
        } catch {
            // El copy de `ownerCannotLeave` manda AQUÍ («…puedes eliminarlo»), así que este camino no
            // puede seguir pintando la dev-string en inglés de `GroupServiceError` («GroupService: Only
            // the group owner…»): sería mandar al usuario a un callejón con cartel técnico.
            actionErrorMessage = GroupLeaveErrorLogic.classify(
                error, attestUnavailable: GroupsAttestStreakStore.isTerminal()).localizedMessage
            showActionError = true
        }
    }

    // MARK: - Deuda

    /// 2.6 — una sola resolución de identidad, la canónica del write-side. La versión anterior probaba
    /// PRIMERO el `cachedRecordName` de iCloud y, si no casaba ningún member, devolvía nil SIN caer al
    /// fallback: en un grupo del canal backend eso da siempre nil (`cloudKitUserRecordID` está vacío por
    /// diseño, pero el recordName de iCloud SÍ existe) ⇒ el usuario aparecía sin deuda aunque debiera
    /// dinero, y esta propiedad es la que decide si se le deja archivar o salir del grupo.
    ///
    /// L19-10: el residuo de redondeo no cuenta (`GroupRoundingResidueLogic`).
    private var hasOutstandingBalance: Bool {
        guard let memberID = GroupExpenseService.selectCurrentUserMemberID(
            from: viewModel.members,
            cachedRecordName: GroupUserIdentityService.shared.cachedRecordName,
            currentUserID: CloudSyncFlags.groupsBackendEnabled ? CloudAuthService.shared.currentUserID : nil
        ) else { return false }
        return GroupRoundingResidueLogic.hasOutstanding(debts: viewModel.debts, memberID: memberID)
    }

    /// Alcance global: cualquier miembro con balance pendiente. Cubre cross-currency
    /// automáticamente porque `MemberBalance` tiene una entry por memberID×currencyCode.
    ///
    /// Bypass del cache `viewModel.balances` con fetches directos del context — defense
    /// in depth para casos donde `loadData` no haya corrido al momento del tap archive
    /// (race con sync, cold launch del settings, etc). Fallback graceful al cache del VM
    /// si los fetches throw. El resultado se cachea en `hasOutstandingDebt`
    /// (recalculado en `.onAppear` + `onChange(coalescedReloadRevision)` + pre-tap de archive/delete)
    /// para evitar fetches por cada re-evaluación del body de SwiftUI.
    private func recomputeOutstandingDebt() {
        let zoneID = group.cloudKitZoneID
        do {
            // Early exit: si el grupo no tiene expenses, no hay deuda posible — skip los
            // otros 3 fetches + `calculateBalances`. `fetchCount` es O(1) en SwiftData
            // (delega a SQL COUNT). Ahorra ~50ms en grupos vacíos/recién creados.
            let expensesCount = try modelContext.fetchCount(FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            guard expensesCount > 0 else {
                hasOutstandingDebt = false
                outstandingDebts = []
                return
            }

            let expenses = try modelContext.fetch(FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let shares = try modelContext.fetch(FetchDescriptor<SplitShare>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let settlements = try modelContext.fetch(FetchDescriptor<SplitSettlement>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let members = try modelContext.fetch(FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let balances = GroupBalanceService.calculateBalances(
                expenses: expenses,
                shares: shares,
                members: members,
                settlements: settlements
            )
            outstandingDebts = GroupRoundingResidueLogic.outstandingDebts(
                expenses: expenses, shares: shares, settlements: settlements)
            hasOutstandingDebt = GroupRoundingResidueLogic.hasOutstanding(debts: outstandingDebts, balances: balances)
        } catch {
            #if DEBUG
            print("GroupSettingsView: recomputeOutstandingDebt fetch error \(error), fallback to cache")
            #endif
            // Las deudas del detalle pueden venir convertidas («moneda única»); para decidir si hay deuda da igual.
            outstandingDebts = viewModel.debts
            hasOutstandingDebt = GroupRoundingResidueLogic.hasOutstanding(debts: viewModel.debts, balances: viewModel.balances)
        }
    }

    /// Lo que se recalcula cuando llegan cambios remotos, una vez por ráfaga. Los gestos de la propia
    /// persona (abrir, el pre-tap de archivar y eliminar, la respuesta de transferir o salir) siguen
    /// llamando a `recomputeOwnerExit()` directo: el diálogo que abren depende del valor de ESE momento.
    private func recomputeAfterRemoteChange() {
        recomputeOwnerExit()
        recomputeShareableSummary()
    }

    /// Recalcula la deuda del grupo Y, con ella, qué salida se le ofrece al dueño. Van juntos porque
    /// el offer DEPENDE de la deuda: calcularlos por separado dejaría un frame en el que el botón de
    /// eliminar y su texto discrepan sobre si hay saldos.
    private func recomputeOwnerExit() {
        recomputeOutstandingDebt()
        do {
            let result = try GroupService.shared.ownerExitOffer(
                group, groupHasOutstandingDebt: hasOutstandingDebt,
                serverRefusedTransfer: transferRefusedByServer)
            ownerExitOffer = result.offer
            designatedHeirName = result.heir?.displayName
        } catch {
            #if DEBUG
            print("GroupSettingsView: ownerExitOffer error \(error), fallback al offer previo")
            #endif
            // Se deja el offer ANTERIOR: ponerlo a `nil` haría desaparecer «Transferir y salir»
            // ante un fetch fallido, que es justo el callejón que este ticket viene a cerrar.
            //
            // Y lo que este camino NO puede hacer, dicho porque es el hueco de verdad: si el throw
            // ocurre en el PRIMER `.onAppear` no hay offer anterior, así que el body cae al fallback
            // —sin transferencia— y el dueño con deuda vuelve a ver las tres salidas cerradas. No se
            // puede hacer mejor sin los datos que el fetch no trajo: la alternativa sería ofrecer una
            // transferencia sin saber si hay heredero, y eso acaba en un `no_eligible_owner` tras
            // confirmar. El estado es recuperable —cualquier cambio remoto reintenta, tras el freno del
            // detalle— y degrada al comportamiento anterior al ticket, no a uno peor.
        }
    }

    private func leaveGroup() async {
        guard !isLeavingGroup else { return }
        isLeavingGroup = true
        defer { isLeavingGroup = false }

        do {
            try await GroupService.shared.leaveGroup(group)
            DS.Haptic.success()
            dismiss()
        } catch {
            DS.Haptic.warning()
            // Copy propio por caso: el `localizedDescription` de un `GroupsRPCError` es el número del
            // discriminante («…GroupsRPCError 10.»), y el de un `GroupServiceError` es una dev-string en
            // inglés. Ninguno de los dos es un mensaje para el usuario.
            let kind = GroupLeaveErrorLogic.classify(
                error, attestUnavailable: GroupsAttestStreakStore.isTerminal())
            // El servidor acaba de decir «eres el dueño», y `reconcileServerSideOwnership` ya corrigió
            // el flag y bumpeó `dataVersion` — así que la pantalla, detrás de este alert, se ha
            // repintado con las salidas del dueño. Hay que recalcular ANTES de elegir el copy: con la
            // transferencia disponible, el texto por defecto («…puedes eliminarlo») manda a un botón
            // que en ese momento está en gris y cuyo hint devuelve a «transfiérelo y sal». El usuario
            // daba vueltas entre dos mensajes que se remitían el uno al otro.
            recomputeOwnerExit()
            leaveErrorMessage = (kind == .ownedByCurrentUser && currentOffer.showsTransferAndLeave)
                ? L10n.Groups.Errors.ownerCannotLeaveCanTransfer
                : kind.localizedMessage
            showLeaveError = true
        }
    }

    // MARK: - Actions

    private func saveIdentity() {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let nameChanged = trimmedName != group.name
        let iconChanged = editIconName != group.iconName
        let colorChanged = editColorHex != group.colorHex
        guard nameChanged || iconChanged || colorChanged else { return }

        do {
            try GroupService.shared.updateGroup(
                group,
                name: trimmedName,
                iconName: editIconName,
                colorHex: editColorHex,
                currencyCode: group.currencyCode,
                simplifyDebts: group.simplifyDebts,
                showDebtsInSingleCurrency: group.showDebtsInSingleCurrency,
                defaultSplitType: group.defaultSplitType,
                membersCanInvite: group.membersCanInvite
            )
            viewModel.loadData()
        } catch {
            actionErrorMessage = GroupActionErrorLogic.message(for: error)
            showActionError = true
        }
    }

    private func toggleArchive() {
        let willArchive = !group.isArchived
        // Refresca el cache antes del check para evitar valor stale si el sync trajo
        // data después del último onAppear/dataVersion change. Tiene que ser `recomputeOwnerExit`
        // y no solo la deuda: desde que «Eliminar» lee `currentOffer` en vez del `@State` vivo,
        // refrescar únicamente `hasOutstandingDebt` deja el botón habilitado y sin texto de bloqueo
        // mientras el diálogo de archivar, en la misma pantalla, ya avisa de que hay deudas.
        if willArchive { recomputeOwnerExit() }
        if willArchive && hasOutstandingDebt {
            showArchiveConfirm = true
            return
        }
        performArchiveToggle(isArchiving: willArchive)
    }

    private func performArchiveToggle(isArchiving: Bool) {
        do {
            try GroupService.shared.setArchived(group, isArchived: isArchiving)
            DS.Haptic.success()
            viewModel.loadData()
            if group.isArchived {
                dismiss()
                announceArchived()
            }
        } catch {
            actionErrorMessage = GroupActionErrorLogic.message(for: error)
            showActionError = true
        }
    }

    /// L19-8 (decisión B de Jürgen): al archivar, «Lo moviste a Archivados · Deshacer», como en la Bandeja. Antes el
    /// grupo desaparecía de la lista sin decir dónde había ido. El aviso vive en su propia ventana
    /// (`DraftDiscardUndoNotice`): esta hoja y el detalle se cierran al archivar.
    private func announceArchived() {
        let archived = group
        DraftDiscardUndoNotice.show(
            message: L10n.UXL19.archivedNotice,
            systemImage: "archivebox",
            undoTitle: L10n.UXL19.undo,
            noticeIdentifier: "group_archived_notice",
            undoIdentifier: "group_archived_undo"
        ) {
            do {
                try GroupService.shared.setArchived(archived, isArchived: false)
                DS.Haptic.success()
            } catch {
                #if DEBUG
                print("GroupSettingsView: deshacer el archivado falló: \(error)")
                #endif
            }
        }
    }

    /// Quién puede tocar el presupuesto, con el MISMO criterio que el servicio.
    ///
    /// `setBudgetLimit` exige árbol escribible (`validateGroupIsWritable`) **y** admin, en ese orden. La
    /// UI tiene que pedir lo mismo o se rompe por uno de los dos lados: si pide menos, ofrece un botón
    /// que falla; si pide más, esconde una acción legítima.
    private var canEditBudget: Bool {
        viewModel.isCurrentUserAdmin && !group.isMigratedFrozen
    }

    /// Texto con el que se abre el campo del presupuesto.
    ///
    /// SIN separador de miles a propósito: lo que se teclee se vuelve a leer con
    /// `AmountInputHelper.parseDecimal`, y un "3.000,00" con puntos de millar es exactamente lo que hace
    /// ambiguo el parseo entre locales (en `es-ES` el punto es millar; en `en` es decimal). Se siembra el
    /// número pelado con el separador decimal de la locale, y sin decimales si el tope es entero.
    private func budgetInputSeed() -> String {
        guard let limit = group.budgetLimitAmount, limit.isFinite, limit > 0 else { return "" }
        if limit == limit.rounded() { return String(format: "%.0f", limit) }
        let separator = Locale.current.decimalSeparator ?? "."
        return String(format: "%.2f", limit).replacingOccurrences(of: ".", with: separator)
    }

    /// Guarda lo que se tecleó, y NO lo interpreta como "quitar" si no se entiende.
    ///
    /// `AmountInputHelper.parseDecimal` devuelve `0` para lo que no sabe leer —vacío, `"abc"`, un pegado
    /// desde otra app—, y con eso `setBudgetLimit` normalizaría a `nil`, es decir BORRARÍA el
    /// presupuesto de todo el grupo. El usuario que abre el editor para subir el tope, lo deja en blanco
    /// un momento y toca Guardar no está pidiendo eso; para quitarlo hay una fila propia con
    /// confirmación. Así que aquí lo ilegible se contesta con un aviso, no con un borrado.
    private func saveBudgetLimitFromInput(_ input: String) {
        let amount = AmountInputHelper.parseDecimal(input)
        guard amount.isFinite, amount > 0, amount < GroupService.maxBudgetLimitAmount else {
            actionErrorMessage = L10n.Groups.Budget.invalidAmount
            showActionError = true
            return
        }
        applyBudgetLimit(amount)
    }

    /// Fija (`amount`) o quita (`nil`) el presupuesto.
    private func applyBudgetLimit(_ amount: Double?) {
        do {
            try GroupService.shared.setBudgetLimit(group, amount: amount)
            viewModel.loadData()
        } catch {
            // Localizado, no `error.localizedDescription`: los dos errores que este camino puede lanzar
            // —`.adminRequired` e `.inactiveMember`— devuelven dev-strings en inglés («GroupService:
            // Only group admins can perform this action»).
            actionErrorMessage = GroupLeaveErrorLogic.classify(
                error, attestUnavailable: GroupsAttestStreakStore.isTerminal()).localizedMessage
            showActionError = true
        }
    }

    private func updateGroupOption(_ update: (SplitGroup) -> Void) {
        update(group)
        do {
            try GroupService.shared.updateGroup(
                group,
                name: group.name,
                iconName: group.iconName,
                colorHex: group.colorHex,
                currencyCode: group.currencyCode,
                simplifyDebts: group.simplifyDebts,
                showDebtsInSingleCurrency: group.showDebtsInSingleCurrency,
                defaultSplitType: group.defaultSplitType,
                membersCanInvite: group.membersCanInvite
            )
            viewModel.loadData()
        } catch {
            actionErrorMessage = GroupActionErrorLogic.message(for: error)
            showActionError = true
        }
    }

    /// Variante de `updateGroupOption` para las opciones que cualquier miembro activo puede
    /// cambiar (simplify/split). Usa `updateMemberEditableOptions` (guard de miembro activo, no
    /// admin) para no reintroducir el alert "solo admins" de B-19.
    private func updateMemberOption(_ update: (SplitGroup) -> Void) {
        update(group)
        do {
            try GroupService.shared.updateMemberEditableOptions(
                group,
                simplifyDebts: group.simplifyDebts,
                defaultSplitType: group.defaultSplitType
            )
            viewModel.loadData()
        } catch {
            actionErrorMessage = GroupActionErrorLogic.message(for: error)
            showActionError = true
        }
    }

}

// MARK: - Salir del grupo (L19-11)

/// Las dos confirmaciones de salir, en su propio modificador para no alargar la cadena del `body` (el compilador del
/// CI tipa peor que el de 27: `swiftui-ds.md`). Son DOS diálogos y no uno con un botón condicional: los botones de
/// una presentación no admiten contenido que dependa del estado (regla medida el 2026-09-06).
private struct LeavePresentations: ViewModifier {
    @Binding var showLeaveGroupConfirm: Bool
    @Binding var showLeaveWithDebtConfirm: Bool
    let leaveWithDebtMessage: String
    let onLeave: () -> Void
    let onSettleFirst: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.Groups.Settings.leaveGroup,
                isPresented: $showLeaveGroupConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.leaveGroup, role: .destructive) { onLeave() }
                Button(L10n.Common.cancel) {}
                    .accessibilityIdentifier("group_settings_leave_cancel")
            } message: {
                Text(L10n.Groups.Settings.leaveGroupConfirm)
            }
            .confirmationDialog(
                L10n.Groups.Settings.leaveGroup,
                isPresented: $showLeaveWithDebtConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.leaveGroup, role: .destructive) { onLeave() }
                    .accessibilityIdentifier("group_settings_leave_confirm")
                Button(L10n.UXL19.settleFirst) { onSettleFirst() }
                    .accessibilityIdentifier("group_settings_leave_settle_first")
                Button(L10n.Common.cancel) {}
                    .accessibilityIdentifier("group_settings_leave_with_debt_cancel")
            } message: {
                Text(leaveWithDebtMessage)
            }
    }
}
