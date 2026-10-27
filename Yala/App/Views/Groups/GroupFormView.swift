//
//  GroupFormView.swift
//  Yala
//
//  Sheet para crear o editar un grupo compartido.
//
//  UX 2.2 · L12-9 (decisión B de Jürgen, 2026-10-18): crear es escribir un nombre y guardar. El nombre lleva ejemplo y
//  las tres opciones, que traen un valor que sirve a casi todos, van plegadas en «Más opciones» con palabras de persona.
//
//  UX 2.2 · L12-12 (decisión B): en la rama «Crear mi primer grupo» de la bienvenida este formulario pide además el
//  nombre de la persona («Tu nombre en el grupo», obligatorio) y sustituye a la pantalla «¿Cómo te llamas?», cuyo botón
//  decía «Crear mi grupo» y abría otro formulario. Al crear escribe el alta (`GroupsOrganizerOnboarding.completeSetup`,
//  su ÚNICO llamador de producción) y crea el grupo en el mismo gesto.
//

import SwiftUI
import SwiftData

struct GroupFormView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    // MARK: - Input

    let group: SplitGroup?
    /// Solo al CREAR: el grupo recién nacido, antes de cerrar la hoja. Quien la presentó lo usa para proponer invitar
    /// en cuanto la hoja se cierre (auditoría UX 2.2 · L12-10).
    var onCreated: ((SplitGroup) -> Void)? = nil
    /// L12-12 · rama «Crear mi primer grupo»: el formulario pide también el nombre de la persona y escribe el alta.
    var isFirstGroupSetup: Bool = false
    /// L12-12 · el alta quedó escrita (aunque crear el grupo falle después): quien presentó el formulario ya no puede
    /// devolver a la persona al Welcome.
    var onSetupCompleted: (() -> Void)? = nil

    // MARK: - Form State

    @State private var name: String = ""
    @State private var iconName: String = "person.2.fill"
    @State private var colorHex: String = "#8B5CF6"
    @State private var simplifyDebts: Bool = false
    @State private var showDebtsInSingleCurrency: Bool = false
    @State private var selectedCurrency: CurrencyCode = .pen
    @State private var defaultSplitType: SplitType = .equal
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var isSaving: Bool = false
    /// L12-12 · el nombre de la persona (solo en la rama del primer grupo).
    @State private var displayName: String = ""
    /// L12-12 · el alta ya se escribió en esta presentación: un reintento tras un fallo al crear no la repite.
    @State private var setupWritten = false
    /// L12-9 · «Más opciones» plegadas por defecto.
    @State private var showsMoreOptions = false
    /// Card ycke (C2) · la pregunta del nombre al cerrar el primer grupo sin haberlo escrito.
    @State private var showCloseNamePrompt = false
    @State private var closeNameDraft = ""

    // MARK: - Sheet State

    @State private var showIconPicker = false
    @State private var showCurrencyPicker = false

    @FocusState private var isNameFocused: Bool

    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Icon preview
                    iconPreview

                    // L12-12 · primero quién eres, después el grupo.
                    if isFirstGroupSetup {
                        displayNameSection
                    }

                    // Name
                    nameSection

                    // Options (L12-9: plegadas)
                    moreOptionsSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .navigationTitle(group == nil ? L10n.Groups.newGroup : L10n.Groups.editGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.cancel) {
                        close()
                    }
                    .accessibilityIdentifier("group_form_close")
                    // Cerrar a mitad del guardado separaba el grupo creado de lo que venía después (la hoja de
                    // invitar o el gasto de L13-8): se espera a que termine.
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(
                        action: { Task { await saveAsync() } },
                        isDisabled: isSaving || !canSave
                    )
                    .accessibilityIdentifier("group_form_save")
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconColorPickerSheet(
                    selectedIconName: $iconName,
                    selectedColorHex: $colorHex
                )
            }
            .sheet(isPresented: $showCurrencyPicker) {
                NavigationStack {
                    CurrencySelectorView(selectedCurrency: $selectedCurrency)
                }
            }
            .onAppear {
                populateFromGroup()
            }
            .alert(L10n.Common.error, isPresented: $showSaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(saveErrorMessage)
            }
            // Card ycke (C2) · cerrar el primer grupo sin tu nombre: se pregunta en una línea en vez de echar al Welcome.
            // Los textos de los botones van literales (regla del `actions` de un `.alert` en `swiftui-ds.md`).
            .alert(L10n.Welcome.Groups.closeNameTitle, isPresented: $showCloseNamePrompt) {
                TextField(L10n.Groups.Invite.namePlaceholder, text: $closeNameDraft)
                    .textContentType(.givenName)
                    .accessibilityIdentifier("group_form_close_name_input")
                Button(L10n.Action.cancel, role: .cancel) {}
                Button(L10n.Action.continueAction) { enterGroupsWithoutCreating(named: closeNameDraft) }
                    .disabled(closeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("group_form_close_name_continue")
            } message: {
                Text(L10n.Welcome.Groups.closeNameBody)
            }
        }
    }

    // MARK: - Icon Preview

    private var iconPreview: some View {
        Button {
            showIconPicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 80, height: 80)

                Image(systemName: iconName)
                    .font(.system(size: 32, weight: .medium)) // A11Y-DT: decorative icon preview, fixed size
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(hex: colorHex).opacity(0.4), radius: DS.Shadow.medium.radius, x: DS.Shadow.medium.x, y: DS.Shadow.medium.y)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(.thCard)
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(Color(hex: colorHex))
                    )
                    .overlay(
                        Circle()
                            .stroke(.thBackground, lineWidth: 2)
                    )
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.md)
        .accessibilityLabel(L10n.Groups.Form.icon)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        SectionBox(title: L10n.Groups.Form.name) {
            TextField(L10n.GroupsCreate.namePlaceholder, text: $name)
                .font(DS.Typography.body)
                .focused($isNameFocused)
                .accessibilityIdentifier("group_form_name_input")
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
        }
    }

    // MARK: - Your Name (L12-12)

    private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionBox(title: L10n.GroupsCreate.yourName) {
                TextField(L10n.Groups.Invite.namePlaceholder, text: $displayName)
                    .font(DS.Typography.body)
                    .textContentType(.givenName)
                    .accessibilityIdentifier("group_form_your_name_input")
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
            }
            Text(L10n.Welcome.Groups.nameBody)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.xs)
        }
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        // L12-12: sin nombre no se sigue (antes se dejaba y los demás te veían como «Usuario»).
        if isFirstGroupSetup && displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    // MARK: - More Options (L12-9)

    private var moreOptionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                withAnimation(.smooth(duration: 0.25)) { showsMoreOptions.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Text(L10n.Common.moreOptions)
                        .font(DS.Typography.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(DS.Typography.captionSmall.weight(.semibold))
                        .rotationEffect(.degrees(showsMoreOptions ? 180 : 0))
                        .accessibilityHidden(true)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(showsMoreOptions ? .isSelected : [])
            .accessibilityIdentifier("group_form_more_options")

            if showsMoreOptions {
                optionsSection
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        // El título del bloque es el botón «Más opciones» de encima: la tarjeta va sola.
        VStack(spacing: DS.Spacing.none) {
            VStack(spacing: DS.Spacing.none) {
                // Simplify Debts
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(L10n.GroupsCreate.simplify, isOn: $simplifyDebts)
                        .font(DS.Typography.body)

                    Text(L10n.GroupsCreate.simplifyHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)

                // Ver las deudas en una sola moneda — mismas claves que Ajustes del grupo (avq3): crear y ajustar
                // nombran igual la misma opción, y al compartir clave no pueden volver a divergir.
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(L10n.UXL19.singleCurrency, isOn: $showDebtsInSingleCurrency)
                        .font(DS.Typography.body)
                        .accessibilityIdentifier("group_form_single_currency_toggle")

                    Text(L10n.Groups.Form.showDebtsInSingleCurrencyHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)

                    if showDebtsInSingleCurrency {
                        Button {
                            showCurrencyPicker = true
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                let info = currencyInfo(for: selectedCurrency)
                                Text(info.flag)
                                    .font(DS.Typography.body)

                                Text(info.code)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(info.name.capitalized)
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, DS.Spacing.sm)
                            // El `contentShape` va DENTRO del label, NO en el `Button`: el label es un
                            // `HStack` con `Spacer()` y sin fondo relleno, así que ahí el hueco central
                            // no es tocable y solo responden los glifos de los extremos. Ver la regla del
                            // DS en `.claude/rules/swiftui-ds.md`.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("group_form_currency_row")
                    }
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)

                // Default split type
                HStack {
                    Text(L10n.UXL19.splitType)
                        .font(DS.Typography.body)

                    Spacer()

                    Picker("", selection: $defaultSplitType) {
                        ForEach(SplitType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)
            }
        }
        .solidCard()
    }

    // MARK: - Actions

    private func saveAsync() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard canSave else { return }

        // En la rama del primer grupo, la divisa es la que acaba de escribir el alta (la de la región), leída de su
        // misma fuente: el espejo observable de `AppPreferences` se pone al día por notificación y puede ir un paso por
        // detrás justo después del alta.
        let preferredCurrency = isFirstGroupSetup
            ? CurrencyDefaults.detectCurrencyFromRegion()
            : appPreferences.defaultCurrencyCode
        let currencyCode = showDebtsInSingleCurrency ? selectedCurrency.rawValue : preferredCurrency.rawValue

        do {
            if let group {
                // Update
                try GroupService.shared.updateGroup(
                    group,
                    name: trimmedName,
                    iconName: iconName,
                    colorHex: colorHex,
                    currencyCode: currencyCode,
                    simplifyDebts: simplifyDebts,
                    showDebtsInSingleCurrency: showDebtsInSingleCurrency,
                    defaultSplitType: defaultSplitType.rawValue,
                    membersCanInvite: false
                )
            } else {
                // Create — C4: el ÚNICO canal de creación es el backend. El gate canal/consent/sign-in ya
                // corrió en el call-site que abrió el form (GroupsContainerView.requestCreateGroup, que
                // además re-mide el flag con `refreshIfDue(force: true)`); las ramas no-`.backend` de aquí
                // son belt defensivo (no deberían alcanzarse) — las needs* ceden el anchor con dismiss()
                // PRIMERO, y `.channelOff` NO cede: se queda y dice el porqué, porque tras el dismiss no
                // queda nadie que pueda contárselo al usuario.
                switch GroupCreateRoutingLogic.route(
                    flagOn: CloudSyncFlags.groupsBackendEnabled,
                    hasSession: CloudAuthService.shared.hasSession,
                    consentAccepted: GroupsConsentState.isAccepted
                ) {
                case .channelOff:
                    // Cero escrituras: antes de C4 esta rama era `.cloudKit` y acuñaba un `SplitGroup`
                    // local con `isBackendGroup == false` — no invitable y sin vía de migración.
                    DS.Haptic.warning()
                    saveErrorMessage = L10n.Welcome.Groups.channelOffBody
                    showSaveError = true
                    return
                case .backend:
                    // L12-12 · el alta va ANTES de crear, como iba antes de abrir el formulario: es la que fija la
                    // divisa de la región (la del grupo cuando no se elige otra) y retira las preferencias del dueño
                    // del Apple ID. Solo con el canal encendido (`.channelOff` no escribe nada, C4) y una vez por
                    // presentación: si crear falla, el reintento ya no la repite.
                    writeFirstGroupSetupIfNeeded(displayName: displayName)
                    // `displayName` no-vacío (patrón defaultName R1: `join`/`create_group` hacen btrim=''
                    // → yala_bad_input permanente si vacío).
                    let profile = UserDefaults.standard.string(forKey: "userName") ?? ""
                    let typedName = self.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayName = isFirstGroupSetup && !typedName.isEmpty
                        ? typedName
                        : (profile.isEmpty ? L10n.Profile.defaultName : profile)
                    let created = try await GroupBackendMembershipService(
                        client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
                        .createGroup(
                            name: trimmedName,
                            iconName: iconName,
                            colorHex: colorHex,
                            currencyCode: currencyCode,
                            displayName: displayName,
                            defaultSplitType: defaultSplitType.rawValue,
                            simplifyDebts: simplifyDebts,
                            showDebtsInSingleCurrency: showDebtsInSingleCurrency,
                            membersCanInvite: false,
                            context: modelContext
                        )
                    // Paridad de side-effects: el servicio backend NO los emite (a diferencia de
                    // GroupService.createGroup) — replicarlos aquí para no regresionar la UX.
                    SessionState.shared.incrementDataVersion()
                    NudgeService.shared.recordGroupJoinIfNeeded()
                    // Antes de cerrar la hoja: su `onDismiss` tiene que encontrar el grupo ya apuntado.
                    onCreated?(created)
                case .needsConsent:
                    dismiss()
                    RouterEntryGate.shared.submit(.presentGroupsConsent(pendingJoin: ""))
                    return
                case .needsSignIn:
                    dismiss()
                    RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: ""))
                    return
                }
            }
            DS.Haptic.success()
            dismiss()
        } catch {
            #if DEBUG
            print("GroupFormView: Error saving group: \(error)")
            #endif
            DS.Haptic.warning()
            // `GroupsRPCError` no es `LocalizedError`: sin clasificar salía «Error de Yala.GroupsRPCError 2».
            saveErrorMessage = GroupActionErrorLogic.message(for: error)
            showSaveError = true
        }
    }

    /// El alta del primer grupo, una vez por presentación. Es su ÚNICO sitio en el formulario (lo cuentan los source-scan
    /// de `GroupsGateLogicTests`): crear y cerrar (card ycke) pasan por aquí.
    private func writeFirstGroupSetupIfNeeded(displayName: String) {
        if isFirstGroupSetup && !setupWritten {
            GroupsOrganizerOnboarding.completeSetup(displayName: displayName, context: modelContext)
            setupWritten = true
            onSetupCompleted?()
        }
    }

    /// Card ycke (C2 del estudio del Welcome solo-grupos) · la «X». En la rama del primer grupo, cerrar ya no devuelve al
    /// Welcome: quien aún no sabe cómo llamar al grupo, o espera que un amigo lo invite, entra en Grupos sin crearlo. Con su
    /// nombre escrito se completa el alta y la pestaña aterriza en su estado vacío (el `onDismiss` de `ContentView` lo hace
    /// al ver el alta escrita); sin nombre, se pregunta en una línea, porque el alta lo necesita (L12-12).
    ///
    /// Se queda como antes —cerrar devuelve al elector— fuera de esa rama, con el alta ya escrita (crear falló después) y
    /// sin el canal de grupos: el alta solo se escribe con el canal encendido (C4), igual que al crear.
    private func close() {
        guard isFirstGroupSetup, !setupWritten,
              GroupCreateRoutingLogic.route(
                flagOn: CloudSyncFlags.groupsBackendEnabled,
                hasSession: CloudAuthService.shared.hasSession,
                consentAccepted: GroupsConsentState.isAccepted
              ) == .backend
        else {
            dismiss()
            return
        }
        let typed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else {
            closeNameDraft = ""
            showCloseNamePrompt = true
            return
        }
        enterGroupsWithoutCreating(named: typed)
    }

    /// Card ycke · completa el alta con ese nombre, sin crear grupo, y cierra: el `onDismiss` del cover aterriza en Grupos.
    private func enterGroupsWithoutCreating(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        writeFirstGroupSetupIfNeeded(displayName: trimmed)
        dismiss()
    }

    private func populateFromGroup() {
        if let group {
            name = group.name
            iconName = group.iconName
            colorHex = group.colorHex
            simplifyDebts = group.simplifyDebts
            showDebtsInSingleCurrency = group.showDebtsInSingleCurrency
            selectedCurrency = CurrencyCode(rawValue: group.currencyCode) ?? .pen
            defaultSplitType = SplitType(rawValue: group.defaultSplitType) ?? .equal
        } else if isFirstGroupSetup {
            // El alta escribirá la divisa de la región al guardar; la de antes del alta puede ser la del dueño del
            // Apple ID (la aplica el arranque neutro), así que el selector arranca ya en la que va a valer.
            selectedCurrency = CurrencyDefaults.detectCurrencyFromRegion()
        } else {
            selectedCurrency = appPreferences.defaultCurrencyCode
        }
    }
}
