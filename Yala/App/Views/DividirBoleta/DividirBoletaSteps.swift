//
//  DividirBoletaSteps.swift
//  Yala
//
//  Los pasos de «Dividir una boleta» antes del resultado: elegir la foto, ¿entre quiénes?, el total a mano cuando la IA
//  no puede, y la revisión del reparto. La revisión repite la de Grupos (`GroupReceiptSplitReview`) con las personas de la
//  boleta en vez de miembros guardados: aquella recibe `SplitMember` y no se toca, para que el reparto dentro de un grupo
//  siga igual.
//

import SwiftUI

// MARK: - Elegir la foto

struct DividirBoletaSourceStep: View {
    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onFile: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text(L10n.DividirBoleta.sourceSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                tiles
                Text(L10n.DividirBoleta.entryHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("dividir_boleta_source")
    }

    /// Las fichas de la foto personal; con texto de accesibilidad, una debajo de otra.
    private var tiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        let hasCamera = ImageCameraPicker.isAvailable
        return layout {
            if hasCamera {
                tile(L10n.Image.Entry.camera, icon: "camera", isPrimary: true, id: "dividir_boleta_source_camera", action: onCamera)
            }
            tile(L10n.Image.Entry.photos, icon: "photo.on.rectangle", isPrimary: !hasCamera,
                 id: "dividir_boleta_source_photos", action: onPhotos)
            tile(L10n.Image.Entry.file, icon: "doc", isPrimary: false, id: "dividir_boleta_source_file", action: onFile)
        }
    }

    private func tile(_ title: String, icon: String, isPrimary: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(isPrimary ? theme.onAccent : theme.accentText)
                    .frame(width: 48, height: 48) // A11Y-DT: disco del icono de la fuente
                    .background(Circle().fill(isPrimary ? theme.onAccent.opacity(0.18) : theme.accent.opacity(0.15)))
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(isPrimary ? theme.onAccent : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(isPrimary ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thCard))
            )
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

// MARK: - Iniciales

/// Un círculo con las iniciales de la persona, del color que le toca por su orden en la boleta (el mismo de la imagen).
struct DividirBoletaAvatar: View {
    let person: DividirBoletaPerson
    let index: Int
    var meLabel: String = L10n.DividirBoleta.whoMe
    @ScaledMetric(relativeTo: .caption) private var side: CGFloat = 26

    var body: some View {
        Text(DividirBoletaImageBuilder.initials(person.isMe ? meLabel : person.name))
            .font(DS.Typography.badgeLabel)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: side, height: side)
            .background(Circle().fill(Color(hex: DividirBoletaPalette.avatar(at: index))))
            .accessibilityHidden(true)
    }
}

// MARK: - ¿Entre quiénes?

struct DividirBoletaWhoStep: View {
    @Bindable var model: DividirBoletaModel
    /// «Repartir»: la hoja mira el permiso de datos de IA y lee (o pasa a la revisión si ya leyó).
    let onSplit: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences
    @State private var newName = ""
    @State private var showsDuplicate = false
    @FocusState private var nameFocused: Bool
    @FocusState private var phraseFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                photoStrip
                peopleSection
                modeSection
                if model.mode == .byLines && model.readPhase != .read {
                    phraseSection
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .dsAnimation(DS.Animation.appear, value: model.mode, reduceMotion: reduceMotion)
        // El id del paso va en el scroll, antes de la barra: colgado del conjunto pisaba el de «Repartir».
        .accessibilityIdentifier("dividir_boleta_who")
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            YalaPrimaryButton(
                L10n.DividirBoleta.whoSplit,
                icon: "divide",
                isDisabled: !model.canSplitPeople,
                disabledHint: L10n.DividirBoleta.whoNeedsPeople,
                keepsDisabledToneInBar: true
            ) {
                nameFocused = false
                phraseFocused = false
                commitTypedName()
                onSplit()
            }
            .accessibilityIdentifier("dividir_boleta_split")
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.sm)
        }
    }

    // MARK: Foto

    private var photoStrip: some View {
        HStack(spacing: DS.Spacing.md) {
            if let photo = model.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 62) // A11Y-DT: miniatura de la foto
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(model.merchant ?? L10n.DividirBoleta.whoPhoto)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                Text(photoDetail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Spacing.sm)
            if model.readPhase == .read {
                Text(L10n.DividirBoleta.whoPhotoRead)
                    .font(DS.Typography.badgeLabel)
                    .foregroundStyle(theme.accentText)
            } else {
                Button(L10n.DividirBoleta.whoOtherPhoto) { model.chooseAnotherPhoto() }
                    .font(DS.Typography.badgeLabel)
                    .foregroundStyle(theme.accentText)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("dividir_boleta_other_photo")
            }
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(.thCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dividir_boleta_photo_strip")
    }

    private var photoDetail: String {
        guard model.readPhase == .read else { return L10n.DividirBoleta.whoPhotoPending }
        let total = Double(ReceiptSplitLogic.totalCents(model.lines)) / 100
        return L10n.DividirBoleta.whoPhotoReadDetail(
            appPreferences.currency(total, currencyCode: model.effectiveCurrency, forceFullPrecision: true))
    }

    // MARK: Personas

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionTitle(L10n.DividirBoleta.whoPeopleSection)
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(Array(model.people.enumerated()), id: \.element.id) { index, person in
                    personChip(person, index: index)
                }
            }
            HStack(spacing: DS.Spacing.sm) {
                TextField(L10n.DividirBoleta.whoNamePlaceholder, text: $newName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($nameFocused)
                    .onSubmit {
                        commitTypedName()
                        nameFocused = true
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(minHeight: 44)
                    .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .accessibilityIdentifier("dividir_boleta_name_field")
                Button {
                    commitTypedName()
                } label: {
                    Image(systemName: "plus")
                        .font(DS.Typography.headline)
                        .foregroundStyle(theme.onAccent)
                        .frame(width: 44, height: 44) // A11Y-DT: área de toque mínima
                        .background(Circle().fill(theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(L10n.DividirBoleta.whoAdd)
                .accessibilityIdentifier("dividir_boleta_add_person")
            }
            Text(showsDuplicate ? L10n.DividirBoleta.whoDuplicateName : L10n.DividirBoleta.whoPeopleFooter)
                .font(DS.Typography.caption)
                .foregroundStyle(showsDuplicate ? DS.Semantic.warningForeground : Color.secondary)
                .accessibilityIdentifier("dividir_boleta_people_footer")
        }
    }

    private func personChip(_ person: DividirBoletaPerson, index: Int) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            DividirBoletaAvatar(person: person, index: index)
            Text(person.isMe ? L10n.DividirBoleta.whoMe : person.name)
                .font(DS.Typography.subheadline)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            if !person.isMe {
                Button {
                    model.removePerson(person.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28) // A11Y-DT: área de toque de la X
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.DividirBoleta.whoRemove(person.name))
                .accessibilityIdentifier("dividir_boleta_remove_\(person.name)")
            }
        }
        .padding(.leading, DS.Spacing.xxs)
        .padding(.trailing, person.isMe ? DS.Spacing.md : DS.Spacing.xxs)
        .frame(minHeight: 36)
        .background(Capsule().fill(.thCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dividir_boleta_person_\(person.isMe ? "me" : person.name)")
    }

    private func commitTypedName() {
        let typed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return }
        if model.addPerson(named: typed) {
            newName = ""
            showsDuplicate = false
        } else {
            showsDuplicate = true
        }
    }

    // MARK: Modo y frase

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionTitle(L10n.DividirBoleta.whoModeSection)
            DividirBoletaModePicker(mode: $model.mode)
        }
    }

    private var phraseSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionTitle(L10n.DividirBoleta.whoPhraseSection)
            TextField(L10n.DividirBoleta.whoPhrasePlaceholder, text: $model.phrase, axis: .vertical)
                .lineLimit(1...4)
                .focused($phraseFocused)
                .padding(DS.Spacing.md)
                .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .accessibilityIdentifier("dividir_boleta_phrase")
            Text(L10n.DividirBoleta.whoPhraseFooter)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.label)
            .foregroundStyle(.thPrimaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

/// «Por igual» · «Por líneas».
struct DividirBoletaModePicker: View {
    @Binding var mode: DividirBoletaMode

    var body: some View {
        Picker(L10n.DividirBoleta.whoModeSection, selection: $mode) {
            Text(L10n.DividirBoleta.modeEqual).tag(DividirBoletaMode.equal)
            Text(L10n.DividirBoleta.modeByLines).tag(DividirBoletaMode.byLines)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(L10n.DividirBoleta.whoModeSection)
        .accessibilityIdentifier("dividir_boleta_mode")
    }
}

// MARK: - Leyendo y fallo

struct DividirBoletaReadingStep: View {
    let photo: UIImage?
    let onCancel: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xs) {
                Text(L10n.Image.Entry.readingOne)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.GruposCaptura.readingStep)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            if let photo {
                GroupCaptureReadingPhoto(image: photo, accent: theme.accent, reduceMotion: reduceMotion)
                    .padding(.top, DS.Spacing.xs)
            }
            Spacer(minLength: DS.Spacing.lg)
            Button(L10n.Action.cancel, action: onCancel)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: 48) // A11Y-DT: tap target de los botones de la hoja
                .accessibilityLabel(L10n.Image.Entry.cancelReading)
                .accessibilityIdentifier("dividir_boleta_cancel_reading")
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dividir_boleta_reading")
    }
}

// MARK: - Total a mano

struct DividirBoletaManualTotalStep: View {
    let currencyCode: String
    let onUse: (Double) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var amount: Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalized), value >= 0.01 else { return nil }
        return value
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(L10n.DividirBoleta.manualTitle)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.thPrimaryText)
                HStack(spacing: DS.Spacing.sm) {
                    Text(currencyCode)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.secondary)
                    TextField(
                        L10n.DividirBoleta.manualTitle,
                        text: $text,
                        prompt: Text(verbatim: "0.00").foregroundStyle(.tertiary)
                    )
                    .font(DS.Typography.title)
                    .amountKeyboard()
                    .focused($focused)
                    .accessibilityIdentifier("dividir_boleta_manual_amount")
                }
                .padding(DS.Spacing.md)
                .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                Text(L10n.DividirBoleta.manualFooter)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)
        }
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            YalaPrimaryButton(L10n.DividirBoleta.whoSplit, icon: "divide", isDisabled: amount == nil, keepsDisabledToneInBar: true) {
                guard let amount else { return }
                focused = false
                onUse(amount)
            }
            .accessibilityIdentifier("dividir_boleta_manual_split")
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.sm)
        }
        .onAppear { focused = true }
    }
}

// MARK: - Revisión

struct DividirBoletaReviewStep: View {
    @Bindable var model: DividirBoletaModel
    let onContinue: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private var items: [ReceiptSplitLine] { model.lines.filter { !$0.kind.isExtra } }
    private var extras: [ReceiptSplitLine] { model.lines.filter(\.kind.isExtra) }
    private var people: [DividirBoletaPerson] { model.people }

    var body: some View {
        List {
            Section {
                DividirBoletaModePicker(mode: $model.mode)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            if !model.unmatchedNames.isEmpty && model.mode == .byLines {
                Section {
                    Label(
                        L10n.ReceiptSplit.unmatchedNames(model.unmatchedNames.formatted(.list(type: .and))),
                        systemImage: "person.fill.questionmark"
                    )
                    .font(DS.Typography.subheadline)
                    .accessibilityIdentifier("dividir_boleta_unmatched")
                }
            }

            Section {
                ForEach(items) { line in itemRow(line) }
                    .onDelete { offsets in model.delete(Set(offsets.map { items[$0].id })) }
            } header: {
                Text(L10n.DividirBoleta.reviewLinesSection)
            } footer: {
                Text(model.mode == .byLines
                     ? L10n.DividirBoleta.reviewLinesFooterByLines
                     : L10n.DividirBoleta.reviewLinesFooterEqual)
            }

            Section {
                ForEach(extras) { line in extraRow(line) }
                    .onDelete { offsets in model.delete(Set(offsets.map { extras[$0].id })) }
                surchargeMenu
            } header: {
                Text(L10n.ReceiptSplit.extrasSection)
            } footer: {
                Text(L10n.ReceiptSplit.extrasFooter)
            }

            Section {
                ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                    HStack(spacing: DS.Spacing.sm) {
                        DividirBoletaAvatar(person: person, index: index)
                        Text(person.isMe ? L10n.DividirBoleta.whoMe : person.name)
                        Spacer()
                        Text(money(model.shareCents[person.id] ?? 0))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("dividir_boleta_share_\(person.isMe ? "me" : person.name)")
                }
                HStack {
                    Text(L10n.ReceiptSplit.total)
                        .font(DS.Typography.headline)
                    Spacer()
                    Text(money(ReceiptSplitLogic.totalCents(DividirBoletaLogic.effectiveLines(model.lines, mode: model.mode))))
                        .font(DS.Typography.headline)
                        .monospacedDigit()
                        .accessibilityIdentifier("dividir_boleta_total")
                }
            } header: {
                Text(L10n.ReceiptSplit.perPersonSection)
            } footer: {
                if let mismatch = totalMismatch {
                    Text(mismatch)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("dividir_boleta_review")
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            VStack(spacing: DS.Spacing.xs) {
                if let reason = blockedReason {
                    Text(reason)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                YalaPrimaryButton(
                    L10n.DividirBoleta.reviewContinue,
                    isDisabled: !model.canContinueFromReview,
                    keepsDisabledToneInBar: true,
                    action: onContinue
                )
                .accessibilityIdentifier("dividir_boleta_review_continue")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.sm)
        }
    }

    private var blockedReason: String? {
        let shares = model.shareCents
        if shares.isEmpty { return L10n.ReceiptSplit.nothingToSplit }
        if shares.values.contains(where: { $0 < 0 }) { return L10n.ReceiptSplit.negativeShare }
        return nil
    }

    private var totalMismatch: String? {
        guard let printed = model.printedTotal else { return nil }
        let read = ReceiptSplitLogic.readTotal(model.lines)
        guard abs(read - printed) >= 0.01 else { return nil }
        return L10n.ReceiptSplit.printedTotalMismatch(
            printed: appPreferences.currency(printed, currencyCode: model.effectiveCurrency, forceFullPrecision: true),
            lines: appPreferences.currency(read, currencyCode: model.effectiveCurrency, forceFullPrecision: true))
    }

    // MARK: Filas

    private func itemRow(_ line: ReceiptSplitLine) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.description)
                    .font(DS.Typography.body)
                Spacer(minLength: DS.Spacing.sm)
                Text(money(ReceiptSplitLogic.cents(line.amount)))
                    .monospacedDigit()
            }
            if model.mode == .byLines {
                Menu {
                    Button {
                        model.setEveryone(for: line.id)
                    } label: {
                        if line.assignees.isEmpty {
                            Label(L10n.ReceiptSplit.everyone, systemImage: "checkmark")
                        } else {
                            Text(L10n.ReceiptSplit.everyone)
                        }
                    }
                    Section(L10n.ReceiptSplit.whoHadIt) {
                        ForEach(people) { person in
                            Button { model.toggle(person.id, in: line.id) } label: {
                                if line.assignees.contains(person.id) {
                                    Label(displayName(person), systemImage: "checkmark")
                                } else {
                                    Text(displayName(person))
                                }
                            }
                        }
                    }
                } label: {
                    chip(line.assignees.isEmpty ? L10n.ReceiptSplit.everyone : names(line.assignees), flagged: line.needsReview)
                }
                .accessibilityIdentifier("dividir_boleta_people_\(line.description)")
            } else {
                chip(L10n.ReceiptSplit.everyone, muted: true, showsChevron: false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dividir_boleta_line_\(line.description)")
    }

    private func extraRow(_ line: ReceiptSplitLine) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(line.description)
                        .font(DS.Typography.body)
                    Text(L10n.ReceiptSplit.kindLabel(line.kind))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text((line.kind == .discount ? "−" : "") + money(ReceiptSplitLogic.cents(line.amount)))
                    .monospacedDigit()
                    .foregroundStyle(line.isIncluded ? .primary : .secondary)
            }
            Menu {
                shareButton(.excluded, title: L10n.ReceiptSplit.shareExcluded, line: line)
                shareButton(.proportional, title: L10n.ReceiptSplit.shareProportional, line: line)
                shareButton(.equal, title: L10n.ReceiptSplit.shareEqual, line: line)
                Section(L10n.ReceiptSplit.sharePeople) {
                    ForEach(people) { person in
                        Button { model.toggleExtraPerson(person.id, in: line.id) } label: {
                            if line.extraShare == .people, line.assignees.contains(person.id) {
                                Label(displayName(person), systemImage: "checkmark")
                            } else {
                                Text(displayName(person))
                            }
                        }
                    }
                }
            } label: {
                chip(extraChipText(line), muted: !line.isIncluded)
            }
            .accessibilityIdentifier("dividir_boleta_extra_\(line.description)")
        }
    }

    private func shareButton(_ share: ReceiptExtraShare, title: String, line: ReceiptSplitLine) -> some View {
        Button {
            model.setExtraShare(share, for: line.id)
        } label: {
            if line.extraShare == share {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var surchargeMenu: some View {
        Menu {
            surchargeOption(.tip, percent: 10)
            surchargeOption(.tip, percent: 15)
            surchargeOption(.service, percent: 10)
        } label: {
            Label(L10n.ReceiptSplit.addSurcharge, systemImage: "plus.circle")
        }
        .accessibilityIdentifier("dividir_boleta_add_surcharge")
    }

    private func surchargeOption(_ kind: ReceiptLineKind, percent: Int) -> some View {
        Menu(L10n.ReceiptSplit.surchargeTitle(kind: kind, percent: percent)) {
            Button(L10n.ReceiptSplit.shareProportional) { model.addSurcharge(kind, percent: percent, share: .proportional) }
            Button(L10n.ReceiptSplit.shareEqual) { model.addSurcharge(kind, percent: percent, share: .equal) }
        }
    }

    private func chip(_ text: String, muted: Bool = false, flagged: Bool = false, showsChevron: Bool = true) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: flagged ? "person.fill.questionmark" : "person.2")
            Text(text)
                .lineLimit(2)
            if showsChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .font(DS.Typography.caption)
            }
        }
        .font(DS.Typography.caption)
        .foregroundStyle(muted ? Color.secondary : theme.accentText)
        .padding(.vertical, DS.Spacing.xxs)
        .contentShape(Rectangle())
    }

    private func extraChipText(_ line: ReceiptSplitLine) -> String {
        switch line.extraShare {
        case .excluded: L10n.ReceiptSplit.shareExcluded
        case .proportional: L10n.ReceiptSplit.shareProportional
        case .equal: L10n.ReceiptSplit.shareEqual
        case .people: line.assignees.isEmpty ? L10n.ReceiptSplit.shareExcluded : names(line.assignees)
        }
    }

    private func displayName(_ person: DividirBoletaPerson) -> String {
        person.isMe ? L10n.DividirBoleta.whoMe : person.name
    }

    private func names(_ ids: Set<String>) -> String {
        people.filter { ids.contains($0.id) }.map(displayName).formatted(.list(type: .and))
    }

    private func money(_ cents: Int) -> String {
        appPreferences.currency(Double(cents) / 100, currencyCode: model.effectiveCurrency, forceFullPrecision: true)
    }
}
