//
//  TransactionDetailSheet.swift
//  Yala
//
//  Sheet de detalle read-only de una transacción (Records). Abre en detent
//  medium (quick look estilo Wallet); el botón Editar o el drag a large hacen
//  swap in-place a NewTransactionView dentro del mismo sheet — sin encadenar
//  dismiss+present. En iPad el sheet vive fijo en large y solo el botón entra
//  a la edición. Decisiones de detents/swap en TransactionDetailSheetLogic.
//

import SwiftData
import SwiftUI

struct TransactionDetailSheet: View {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = AppLocale.current
        return f
    }()

    /// Badge del hero: más grande que el de las rows (DS.ListRow.iconSize)
    /// pero contenido para que el detalle quepa en detent medium.
    private static let heroBadgeSize: CGFloat = 64
    private static let rowIconWidth: CGFloat = 20
    private static let accountDotSize: CGFloat = 8

    let transaction: TransactionItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.tagCatalog) private var tagCatalog
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mode: TransactionDetailSheetLogic.Mode = .detail
    @State private var selectedDetent: PresentationDetent =
        TransactionDetailSheetLogic.initialDetent(usesLargeSheets: DS.Adaptive.usesLargeSheets)
        .presentationDetent
    @State private var transferPartnerAccount: Account?

    var body: some View {
        Group {
            if mode == .edit {
                // Sin wrapper: NewTransactionView trae NavigationStack + fondo
                // .subtle propios; su X hace dismiss() y cierra este sheet.
                NewTransactionView(transactionToEdit: transaction)
                    .transition(.opacity)
            } else {
                detailContent
                    .transition(.opacity)
            }
        }
        .presentationDetents(availableDetents, selection: $selectedDetent)
        .presentationDragIndicator(
            mode == .detail && !DS.Adaptive.usesLargeSheets ? .visible : .automatic
        )
        .onChange(of: selectedDetent) { _, newValue in
            guard
                TransactionDetailSheetLogic.shouldSwitchToEdit(
                    newDetent: TransactionDetailSheetLogic.Detent(newValue),
                    mode: mode,
                    usesLargeSheets: DS.Adaptive.usesLargeSheets
                )
            else { return }
            dsWithAnimation(reduceMotion) { mode = .edit }
        }
    }

    private var availableDetents: Set<PresentationDetent> {
        Set(
            TransactionDetailSheetLogic.availableDetents(
                mode: mode, usesLargeSheets: DS.Adaptive.usesLargeSheets
            ).map(\.presentationDetent)
        )
    }

    private func switchToEdit() {
        dsWithAnimation(reduceMotion) {
            selectedDetent = .large
            mode = .edit
        }
    }

    // MARK: - Detail content

    private var detailContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    heroHeader
                    detailsCard
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("transaction_detail_close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.edit) {
                        switchToEdit()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .accessibilityIdentifier("transaction_detail_edit")
                }
            }
            .yalaScreenBackground(DS.Adaptive.usesLargeSheets ? .subtle : .transparent)
        }
        .accessibilityIdentifier("transaction_detail_sheet")
        .task { resolveTransferPartner() }
    }

    // MARK: - Classification

    private var isTransfer: Bool {
        transaction.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer
    }

    private var transactionType: TransactionType {
        switch TransactionDetailSheetLogic.kind(
            isTransfer: isTransfer,
            categoryIsIncome: transaction.category?.isIncome,
            amount: transaction.amount
        ) {
        case .expense: return .expense
        case .income: return .income
        case .transfer: return .transfer
        }
    }

    private var resolvedTags: [Tag] {
        TagDisplayResolver.tags(for: transaction, catalog: tagCatalog)
    }

    private func resolveTransferPartner() {
        guard isTransfer else { return }
        let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: modelContext)
        transferPartnerAccount = partner?.account
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            heroBadge
                .padding(.bottom, DS.Spacing.xs)

            AmountText(
                value: transaction.amount,
                currencyCode: transaction.currencyCode,
                font: DS.Typography.heroAmount,
                secondaryFont: DS.Typography.heroAmountSecondary,
                tint: .color(transactionType.color),
                forceFullPrecision: true
            )

            if let note = transaction.note, !note.isEmpty {
                Text(note)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Text(Self.dateFormatter.string(from: transaction.date))
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var heroBadge: some View {
        // Réplica del subcategoryIcon de RecordRowView a escala hero.
        let colorHex = transaction.category?.colorHex ?? AppConstants.defaultColorHex
        let iconName =
            transaction.subcategory?.iconName
            ?? transaction.category?.iconName
            ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(isTransfer ? Color(.secondaryLabel) : Color(hex: colorHex))
                .frame(width: Self.heroBadgeSize, height: Self.heroBadgeSize)

            Image(systemName: isTransfer ? "arrow.left.arrow.right" : iconName)
                .font(DS.Typography.title2)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Details card

    private var detailsCard: some View {
        VStack(spacing: DS.Spacing.none) {
            typeRow

            if isTransfer {
                transferAccountsRows
            } else if let account = transaction.account {
                accountRow(
                    icon: "creditcard",
                    iconTint: .secondary,
                    label: L10n.Transaction.account,
                    account: account
                )
            }

            if !isTransfer, transaction.subcategory != nil || transaction.category != nil {
                categoryRow
            }

            if !resolvedTags.isEmpty {
                tagsRow
            }

            if transaction.currencyCode != transaction.preferredCurrencyCode {
                conversionRow
            }

            if let splitTotal = transaction.splitTotalAmount {
                detailRow(
                    icon: "percent",
                    label: L10n.Split.totalAmount,
                    value: appPreferences.currency(
                        splitTotal,
                        currencyCode: transaction.currencyCode,
                        forceFullPrecision: true
                    )
                )
            }

            if transaction.scheduledPaymentID != nil {
                infoRow(
                    icon: "arrow.trianglehead.2.clockwise.rotate.90",
                    text: L10n.Planning.scheduledPayments
                )
            }

            if transaction.splitExpenseID != nil || transaction.splitSettlementID != nil {
                infoRow(icon: "person.2.fill", text: L10n.Groups.title)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }

    // MARK: - Rows (patrón TransactionSuccessView)

    private var typeRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: transactionType.iconName)
                .font(DS.Typography.subheadline)
                .foregroundStyle(transactionType.color)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Transaction.type)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(transactionType.displayName)
                .font(DS.Typography.label)
                .foregroundStyle(transactionType.color)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    /// Fila informativa sin value (badge de origen: pago programado, grupo).
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private func accountRow(
        icon: String, iconTint: Color, label: String, account: Account
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(iconTint)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color(hex: account.colorHex))
                    .frame(width: Self.accountDotSize, height: Self.accountDotSize)
                Text(account.name)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    /// Origen → destino del par de transferencia. Si el partner es ambiguo o
    /// huérfano (lookup nil) solo se muestra el lado propio — nunca se inventa.
    private var transferAccountsRows: some View {
        let ownIsOrigin = TransactionDetailSheetLogic.transferOwnAccountIsOrigin(
            amount: transaction.amount)
        let origin = ownIsOrigin ? transaction.account : transferPartnerAccount
        let destination = ownIsOrigin ? transferPartnerAccount : transaction.account

        return VStack(spacing: DS.Spacing.none) {
            if let origin {
                accountRow(
                    icon: "arrow.up.circle",
                    iconTint: Color.hotPink,
                    label: L10n.Transaction.origin,
                    account: origin
                )
            }
            if let destination {
                accountRow(
                    icon: "arrow.down.circle",
                    iconTint: theme.accent,
                    label: L10n.Transaction.destination,
                    account: destination
                )
            }
        }
    }

    private var categoryRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "tag")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Transaction.category)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                if let subcatName = transaction.subcategory?.name {
                    Text(subcatName)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                }
                if let catName = transaction.category?.name {
                    Text(catName)
                        .font(
                            transaction.subcategory == nil
                                ? DS.Typography.label : DS.Typography.caption
                        )
                        .foregroundStyle(
                            transaction.subcategory == nil ? .primary : .secondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var tagsRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "number")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Transaction.tags)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Chips réplica de RecordRowView.tagsRow (límite 3 + "+N").
            HStack(spacing: DS.Spacing.xs) {
                ForEach(Array(resolvedTags.prefix(3)), id: \.persistentModelID) { tag in
                    Text(tag.name)
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(Color.contrastingText(for: Color(hex: tag.colorHex)))
                        .padding(.horizontal, DS.Chip.paddingV)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(Color(hex: tag.colorHex))
                        )
                }

                if resolvedTags.count > 3 {
                    Text("+\(resolvedTags.count - 3)")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    /// Monto convertido a la moneda preferida con la tasa snapshot persistida
    /// (sin recalcular — formato del exchangeRateChip del form).
    private var conversionRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Transaction.exchangeRate)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(
                    "≈ \(appPreferences.currency(transaction.amountInPreferredCurrency, currencyCode: transaction.preferredCurrencyCode, forceFullPrecision: true))"
                )
                .font(DS.Typography.label)
                .foregroundStyle(.primary)

                Text("TC: \(String(format: "%.4f", transaction.exchangeRate))")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }
}

// MARK: - Detent mapping

extension TransactionDetailSheetLogic.Detent {
    fileprivate var presentationDetent: PresentationDetent {
        switch self {
        case .medium: return .medium
        case .large: return .large
        }
    }

    fileprivate init(_ detent: PresentationDetent) {
        self = detent == .large ? .large : .medium
    }
}
