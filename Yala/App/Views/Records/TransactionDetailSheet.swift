//
//  TransactionDetailSheet.swift
//  Yala
//
//  Sheet de detalle read-only de una transacción (Records). Detent fijo:
//  medium en iPhone (quick look estilo Wallet), large en iPad. Sin dragger ni
//  drag-to-edit; la edición se alcanza con el botón Editar, que cierra este
//  sheet y deja que el padre presente NewTransactionView en su `onDismiss`
//  (reemplazo de sheet nativo: este baja, el editor sube desde abajo). El padre
//  difiere la limpieza de `editingTransaction` vía pendingEditAfterDetail (VM).
//  Clasificación visual de la TX en TransactionDetailSheetLogic.
//
//  Diseño neutro: sobre el fondo transparent del detent medium los tintes
//  finos (pink/indigo) se pierden — monto, íconos y valores van en primary/
//  secondary; el color solo vive en fills sólidos (badge de categoría, dot de
//  cuenta, chips de tags). Hero compacto en línea para que la card de filas
//  quepa sin corte en medium.
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

    private static let rowIconWidth: CGFloat = 20

    let transaction: TransactionItem

    /// Dónde vive el detalle: hoja (iPhone, ventana estrecha), columna de detalle de Registros en una ventana
    /// ancha, o panel de Estadísticas › Registros en una ventana ancha. En columna no hay X —la columna no se
    /// cierra— ni detents, y Editar abre el editor directo.
    ///
    /// `pane`: como la columna, pero sin pila propia ni barra que tomar prestada. El chip Registros vive dentro de la
    /// pila de Estadísticas: meter ahí `.toolbar` o el título inline cambiaría la barra de Estadísticas (su título
    /// grande pasaría a inline y Editar se sumaría a sus botones). Así que lleva su propia cabecera, con X —cuando no
    /// caben lista y detalle, el panel tapa la lista y la X es la vuelta— y Editar.
    enum Presentation { case sheet, column, pane }
    var presentation: Presentation = .sheet

    /// Botón Editar. El padre marca pendingEditAfterDetail y cierra este sheet;
    /// al cerrarse presenta NewTransactionView (reemplazo de sheet nativo).
    let onEdit: () -> Void

    /// Cerrar el panel (`pane`): el padre vacía lo abierto. En hoja cierra `dismiss()` y en columna no hay X.
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.tagCatalog) private var tagCatalog
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesLargeSheets) private var usesLargeSheets

    @State private var transferPartnerAccount: Account?

    /// Detent fijo: medium en ventana compacta / large en ventana ancha. Sin `selection` — ya no hay
    /// drag-to-edit que dispare cambios de modo.
    private var detent: PresentationDetent {
        TransactionDetailSheetLogic.initialDetent(usesLargeSheets: usesLargeSheets)
            .presentationDetent
    }

    var body: some View {
        switch presentation {
        case .sheet:
            detailContent
                .presentationDetents([detent])
                .presentationDragIndicator(.hidden)
        case .column:
            columnContent
        case .pane:
            paneContent
        }
    }

    // MARK: - Detail content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                compactHero
                detailsCard
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
            .frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var editButton: some View {
        Button(L10n.Action.edit) {
            onEdit()
        }
        .fontWeight(.semibold)
        .foregroundStyle(Color.primary)
        .accessibilityIdentifier("transaction_detail_edit")
    }

    /// Columna de detalle de Registros: ya está dentro de la pila de su columna, así que no abre otra.
    private var columnContent: some View {
        scrollContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    editButton
                }
            }
            .yalaScreenBackground(.panel)
            .accessibilityIdentifier("transaction_detail_column")
            .task(id: transaction.persistentModelID) { resolveTransferPartner() }
    }

    /// Panel de Estadísticas › Registros: cabecera propia en vez de la barra de la pantalla (ver `Presentation`).
    private var paneContent: some View {
        VStack(spacing: DS.Spacing.none) {
            HStack {
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(L10n.Action.close)
                .accessibilityIdentifier("transaction_detail_close")

                Spacer()

                editButton
                    .buttonStyle(.glass)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)

            scrollContent
        }
        .yalaScreenBackground(.panel)
        // `.contain` ANTES del id: un id suelto en el contenedor pisa los de sus botones (X y Editar).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("transaction_detail_pane")
        .task(id: transaction.persistentModelID) { resolveTransferPartner() }
    }

    private var detailContent: some View {
        NavigationStack {
            scrollContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("transaction_detail_close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    editButton
                }
            }
            .yalaScreenBackground(.partialSheet)
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

    // MARK: - Hero compacto (badge + monto en línea, nota · fecha debajo)

    private var compactHero: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                heroBadge

                AmountText(
                    value: transaction.amount,
                    currencyCode: transaction.currencyCode,
                    font: DS.Typography.largeTitle,
                    secondaryFont: DS.Typography.body,
                    tint: .primary,
                    forceFullPrecision: true
                )
            }

            noteAndDateLine
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// "Nota · fecha" en una sola línea; sin nota queda solo la fecha.
    private var noteAndDateLine: some View {
        let dateText = Self.dateFormatter.string(from: transaction.date)
        let note = transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let notePart = Text(note).foregroundStyle(.primary)
        let separatorPart = Text(" · ").foregroundStyle(.secondary)
        let datePart = Text(dateText).foregroundStyle(.secondary)

        return Group {
            if note.isEmpty {
                datePart
            } else {
                Text("\(notePart)\(separatorPart)\(datePart)")
            }
        }
        .font(DS.Typography.subheadline)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private var heroBadge: some View {
        // Réplica del subcategoryIcon de RecordRowView (fill sólido: legible
        // sobre el fondo transparent, a diferencia de un ícono tintado).
        let colorHex = transaction.category?.colorHex ?? AppConstants.defaultColorHex
        let iconName =
            transaction.subcategory?.iconName
            ?? transaction.category?.iconName
            ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(isTransfer ? Color(.secondaryLabel) : Color(hex: colorHex))
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

            Image(systemName: isTransfer ? "arrow.left.arrow.right" : iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Details card (filas neutras, patrón TransactionSuccessView)

    private var detailsCard: some View {
        VStack(spacing: DS.Spacing.none) {
            typeRow

            if isTransfer {
                transferAccountsRows
            } else if let account = transaction.account {
                accountRow(
                    icon: "creditcard",
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

    // MARK: - Rows (neutras: íconos/labels secondary, values primary)

    private var typeRow: some View {
        AdaptiveRowStack(spacing: DS.Spacing.md) {
            Image(systemName: transactionType.iconName)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Transaction.type)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        } trailing: {
            Text(transactionType.displayName)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        AdaptiveRowStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        } trailing: {
            Text(value)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
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

    private func accountRow(icon: String, label: String, account: Account) -> some View {
        AdaptiveRowStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        } trailing: {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color(hex: account.colorHex))
                    .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
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
                    label: L10n.Transaction.origin,
                    account: origin
                )
            }
            if let destination {
                accountRow(
                    icon: "arrow.down.circle",
                    label: L10n.Transaction.destination,
                    account: destination
                )
            }
        }
    }

    private var categoryRow: some View {
        AdaptiveRowStack(spacing: DS.Spacing.md) {
            Image(systemName: "tag")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Transaction.category)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        } trailing: {
            VStack(alignment: .trailingUnlessStacked(dynamicTypeSize), spacing: DS.Spacing.xxs) {
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
        AdaptiveRowStack(spacing: DS.Spacing.md) {
            Image(systemName: "number")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Transaction.tags)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        } trailing: {
            // Chips réplica de RecordRowView.tagsRow (límite 3 + "+N") — fill
            // de color propio del tag (contenido del usuario, sólido y legible).
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
        AdaptiveRowStack(spacing: DS.Spacing.md) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Transaction.exchangeRate)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        } trailing: {
            VStack(alignment: .trailingUnlessStacked(dynamicTypeSize), spacing: DS.Spacing.xxs) {
                Text(
                    "≈ \(appPreferences.currency(transaction.amountInPreferredCurrency, currencyCode: transaction.preferredCurrencyCode, forceFullPrecision: true))"
                )
                .font(DS.Typography.label)
                .foregroundStyle(.primary)

                Text(L10n.Transaction.exchangeRateShort(ExchangeRateDisplayFormatter.string(transaction.exchangeRate)))
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
}
