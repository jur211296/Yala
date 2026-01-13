//
//  AccountFormView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Formulario "Configurar cuenta"

struct AccountFormView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: AccountFormViewModel

    // Keeping these to pass to init if needed, though they are inside VM now.
    // The VM is the source of truth.

    init(existingNames: [String], accountToEdit: Account? = nil) {
        _viewModel = State(
            initialValue: AccountFormViewModel(
                accountToEdit: accountToEdit,
                existingNames: existingNames
            ))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        generalSection
                        currencySection
                        balanceSection
                        adjustmentSection
                        actionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(L10n.Account.configure)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton(action: { saveAccount() }, isDisabled: !viewModel.canSave)
                }
            }
            .sheet(isPresented: $viewModel.isPresentingColorPicker) {
                NavigationStack {
                    VStack(spacing: 24) {
                        ColorPicker(
                            L10n.Common.selectColor,
                            selection: $viewModel.customColor,
                            supportsOpacity: false
                        )
                        .padding()

                        Button(L10n.Common.useThisColor) {
                            viewModel.updateColorFromCustom()
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                    .padding()
                    .navigationTitle(L10n.Common.newColor)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }

        .tint(Color.electricIndigo)
        .alert(
            L10n.Account.deleteError,
            isPresented: $viewModel.isShowingDeleteError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(viewModel.deleteErrorMessage)
            }
        )
    }

    // MARK: Secciones de la vista

    private var generalSection: some View {
        SectionBox(title: L10n.Common.general) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField(L10n.Account.accountName, text: $viewModel.name)
                        .textContentType(.name)
                }
                .padding()

                SubsectionDivider()

                NavigationLink {
                    AccountTypeSelectorView(selectedType: $viewModel.selectedType)
                } label: {
                    HStack {
                        Text(L10n.Account.type)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(viewModel.selectedType.localizedName)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                SubsectionDivider()

                HStack(spacing: 12) {
                    Image(systemName: "number")
                        .foregroundStyle(.secondary)
                    TextField(L10n.Account.accountNumber, text: $viewModel.accountNumber)
                        .keyboardType(.numbersAndPunctuation)
                }
                .padding()
            }
        }
    }

    private var currencySection: some View {
        SectionBox(title: "Moneda") {
            NavigationLink {
                CurrencySelectorView(selectedCurrency: $viewModel.selectedCurrency)
                    .swipeBack()
            } label: {
                HStack(spacing: 12) {
                    Text(currencyInfo(for: viewModel.selectedCurrency).flag)
                        .font(.title3)

                    Text(L10n.Account.currency)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(currencyInfo(for: viewModel.selectedCurrency).name.capitalized)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
            .buttonStyle(.plain)
        }
    }

    private var balanceSection: some View {
        SectionBox(title: "Saldo actual") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(L10n.Account.sign)
                        .font(.subheadline)
                    Spacer()
                    Picker("Signo", selection: $viewModel.isPositive) {
                        Text("Positivo").tag(true)
                        Text("Negativo").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                SubsectionDivider()

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(currencyInfo(for: viewModel.selectedCurrency).code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $viewModel.balanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 28, weight: .bold))
                    }
                }
                .padding()
            }
        }
    }

    private var adjustmentSection: some View {
        SectionBox(title: "Ajuste") {
            VStack(spacing: 0) {
                NavigationLink {
                    AdjustmentModeSelectorView(
                        selectedAdjustmentMode: $viewModel.selectedAdjustmentMode)
                } label: {
                    HStack {
                        Text(L10n.Account.adjustment)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(viewModel.selectedAdjustmentMode.rawValue)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                SubsectionDivider()

                Text(viewModel.selectedAdjustmentMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var colorSection: some View {
        SectionBox(title: "Color") {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(colorForHex(hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.white,
                                            lineWidth: viewModel.selectedColorHex == hex ? 3 : 1)
                                )
                                .shadow(radius: viewModel.selectedColorHex == hex ? 4 : 0)
                                .onTapGesture {
                                    viewModel.selectedColorHex = hex
                                }
                        }

                        Button {
                            viewModel.isPresentingColorPicker = true
                        } label: {
                            Circle()
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Seleccionado: \(viewModel.selectedColorHex)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    private var actionsSection: some View {
        SectionBox(title: "Acciones") {
            VStack(spacing: 0) {
                Toggle(isOn: $viewModel.excludeFromStatistics) {
                    Text(L10n.Account.excludeFromStats)
                }
                .tint(Color.electricIndigo)
                .padding()

                SubsectionDivider()

                Toggle(isOn: $viewModel.isArchived) {
                    Text(L10n.Account.archive)
                }
                .tint(Color.electricIndigo)
                .padding()

                if viewModel.isEditing {
                    SubsectionDivider()

                    Button(role: .destructive) {
                        handleDeleteTapped()
                    } label: {
                        HStack {
                            Spacer()
                            Text(L10n.Account.delete)
                            Spacer()
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: Guardado

    private func saveAccount() {
        if viewModel.saveAccount(context: modelContext) {
            dismiss()
        }
    }

    // MARK: - Eliminación de cuenta

    private func handleDeleteTapped() {
        if viewModel.deleteAccount(context: modelContext) {
            dismiss()
        }
    }
}
