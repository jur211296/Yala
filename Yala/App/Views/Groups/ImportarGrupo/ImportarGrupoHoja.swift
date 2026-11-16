//
//  ImportarGrupoHoja.swift
//  Yala
//
//  La hoja que lee el export: cómo sacarlo de la otra app y «Elegir archivo» (Archivos); después la vista previa —origen,
//  personas, gastos, pagos, fechas y el saldo de cada persona— con «¿Quién eres tú en este grupo?»; o el error, que dice
//  qué pasó y deja elegir otro archivo. «Usar estos saldos» devuelve lo elegido a Crear grupo; no crea nada.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportarGrupoHoja: View {
    let onUse: (ImportarGrupoSeleccion) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    enum Phase: Equatable {
        case intro
        case preview(ImportedGroupSnapshot)
        case failed(String)
    }

    @State private var phase: Phase = .intro
    @State private var showsImporter = false
    /// Quién es la persona en el export. `notMeTag`: no está en el grupo. `nil`: aún no eligió.
    @State private var me: String?
    @State private var showsMissingMe = false

    static let notMeTag = "\u{1}not-me"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    switch phase {
                    case .intro:
                        introContent
                    case .preview(let snapshot):
                        previewContent(snapshot)
                    case .failed(let message):
                        failedContent(message)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .readableColumn()
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.ImportarGrupo.previewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.cancel) { dismiss() }
                        .accessibilityIdentifier("group_import_close")
                }
            }
            .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
                bottomButton
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.sm)
            }
            .fileImporter(
                isPresented: $showsImporter,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                read(result)
            }
        }
    }

    // MARK: - Fases

    private var introContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Image(systemName: "person.3.sequence.fill")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.thAccentText)
                .accessibilityHidden(true)
            Text(L10n.ImportarGrupo.entryTitle)
                .font(DS.Typography.title2)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.ImportarGrupo.entrySubtitle)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.ImportarGrupo.previewHowToExport)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .solidCard()
        }
    }

    private func failedContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L10n.ImportarGrupo.errorTitle)
                .font(DS.Typography.title2)
            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("group_import_error_message")
            Text(L10n.ImportarGrupo.previewHowToExport)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func previewContent(_ snapshot: ImportedGroupSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            SectionBox(title: L10n.ImportarGrupo.previewSource(L10n.ImportarGrupo.sourceName(snapshot.source))) {
                factRow(L10n.ImportarGrupo.previewPeople, "\(snapshot.people.count)")
                Divider()
                factRow(L10n.ImportarGrupo.previewExpenses, "\(snapshot.expenseCount)")
                if snapshot.paymentCount > 0 {
                    Divider()
                    factRow(L10n.ImportarGrupo.previewPayments, "\(snapshot.paymentCount)")
                }
                if let range = dateRange(snapshot) {
                    Divider()
                    factRow(L10n.ImportarGrupo.previewDates, range)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                SectionBox(title: L10n.ImportarGrupo.previewBalancesTitle) {
                    ForEach(Array(snapshot.people.enumerated()), id: \.offset) { index, person in
                        if index > 0 { Divider() }
                        ImportarGrupoPersonaFila(person: person, balances: snapshot.balances(of: person))
                    }
                }
                if snapshot.currencies.count > 1 {
                    Text(L10n.ImportarGrupo.previewCurrenciesNote)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.xs)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                SectionBox(title: L10n.ImportarGrupo.previewWhoAreYou) {
                    ForEach(snapshot.people, id: \.self) { person in
                        meRow(title: person, tag: person)
                        Divider()
                    }
                    meRow(title: L10n.ImportarGrupo.previewNotMe, tag: Self.notMeTag)
                }
                .overlay {
                    if showsMissingMe {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(Color.groupOweAmount, lineWidth: 1.5)
                            .padding(.top, DS.Spacing.xl)
                            .allowsHitTesting(false)
                    }
                }
                Text(showsMissingMe ? L10n.ImportarGrupo.previewPickYourself : L10n.ImportarGrupo.previewWhoAreYouFooter)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(showsMissingMe ? Color.groupOweAmount : .secondary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("group_import_me_footer")
            }
        }
    }

    private func factRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(DS.Typography.body)
            Spacer(minLength: DS.Spacing.sm)
            Text(value)
                .font(DS.Typography.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        .accessibilityElement(children: .combine)
    }

    private func meRow(title: String, tag: String) -> some View {
        Button {
            me = tag
            showsMissingMe = false
            DS.Haptic.selection()
        } label: {
            HStack {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: DS.Spacing.sm)
                if me == tag {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.thAccentText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(me == tag ? .isSelected : [])
        .accessibilityIdentifier("group_import_me_\(tag == Self.notMeTag ? "none" : tag)")
    }

    // MARK: - Botón de abajo

    @ViewBuilder
    private var bottomButton: some View {
        switch phase {
        case .intro:
            YalaPrimaryButton(L10n.ImportarGrupo.previewChooseFile, icon: "folder") { chooseFile() }
                .accessibilityIdentifier("group_import_choose_file")
        case .failed:
            YalaPrimaryButton(L10n.ImportarGrupo.errorTryAnother, icon: "folder") { chooseFile() }
                .accessibilityIdentifier("group_import_choose_file")
        case .preview(let snapshot):
            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.ImportarGrupo.previewUse, keepsDisabledToneInBar: true) {
                    use(snapshot)
                }
                .accessibilityIdentifier("group_import_use")
                Button(L10n.ImportarGrupo.errorTryAnother) { chooseFile() }
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.thAccentText)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("group_import_choose_another")
            }
        }
    }

    // MARK: - Acciones

    /// Abre Archivos. En XCUITest con `-uitest-import-csv`, lee ese archivo directamente (`ImportarGrupoUITestSeams`).
    private func chooseFile() {
        if let path = ImportarGrupoUITestSeams.csvPath {
            read(.success([URL(fileURLWithPath: path)]))
            return
        }
        showsImporter = true
    }

    private func use(_ snapshot: ImportedGroupSnapshot) {
        guard let me else {
            showsMissingMe = true
            DS.Haptic.error()
            return
        }
        DS.Haptic.success()
        onUse(ImportarGrupoSeleccion(snapshot: snapshot, me: me == Self.notMeTag ? nil : me))
        dismiss()
    }

    private func read(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            #if DEBUG
            print("ImportarGrupoHoja: Error: \(error)")
            #endif
            phase = .failed(L10n.ImportarGrupo.errorUnreadableFile)
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let text = try ImportedGroupSnapshotBuilder.text(from: data)
                let snapshot = try ImportedGroupSnapshotBuilder.snapshot(fromCSV: text, fileName: url.lastPathComponent)
                me = nil
                showsMissingMe = false
                phase = .preview(snapshot)
            } catch {
                #if DEBUG
                print("ImportarGrupoHoja: Error: \(error)")
                #endif
                phase = .failed(ImportarGrupoErrorCopy.message(for: error))
            }
        }
    }

    private func dateRange(_ snapshot: ImportedGroupSnapshot) -> String? {
        guard let first = snapshot.firstDate, let last = snapshot.lastDate else { return nil }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLocale.current)
        let from = first.formatted(style)
        let to = last.formatted(style)
        return from == to ? from : "\(from) – \(to)"
    }
}

/// Una persona del export y su saldo en cada moneda: «Le deben» / «Debe» con el monto, o «Al día».
struct ImportarGrupoPersonaFila: View {
    let person: String
    let balances: [(currency: String, cents: Int)]

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(person)
                .font(DS.Typography.body)
            Spacer(minLength: DS.Spacing.sm)
            if balances.isEmpty {
                Text(L10n.ImportarGrupo.previewSettled)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    ForEach(balances, id: \.currency) { item in
                        HStack(spacing: DS.Spacing.xs) {
                            Text(item.cents > 0 ? L10n.ImportarGrupo.previewOwed : L10n.ImportarGrupo.previewOwes)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                            AmountText(value: Double(abs(item.cents)) / 100, currencyCode: item.currency,
                                       font: DS.Typography.body.weight(.semibold))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group_import_person_\(person)")
    }
}

/// El texto de cada error de lectura.
enum ImportarGrupoErrorCopy {
    static func message(for error: Error) -> String {
        guard let error = error as? ImportedGroupError else { return L10n.ImportarGrupo.errorUnreadableFile }
        switch error {
        case .unrecognizedFormat: return L10n.ImportarGrupo.errorUnrecognized
        case .noEntries: return L10n.ImportarGrupo.errorNoEntries
        case .unknownCurrency(let code): return L10n.ImportarGrupo.errorUnknownCurrency(code.isEmpty ? "?" : code)
        case .unreadableAmount(let row): return L10n.ImportarGrupo.errorUnreadableAmount(row)
        case .rowDoesNotAddUp(let row): return L10n.ImportarGrupo.errorRowDoesNotAddUp(row)
        case .balancesDoNotAddUp(let code): return L10n.ImportarGrupo.errorBalancesDoNotAddUp(code)
        case .unreadableFile: return L10n.ImportarGrupo.errorUnreadableFile
        }
    }
}
