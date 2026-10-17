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

    /// «Duplicar» al pie (L8-4). `nil`: la pantalla que lo abre no lo ofrece. Solo sale si el registro se puede
    /// duplicar (`RecordContextActionLogic`, lo mismo que el menú de la fila).
    var onDuplicate: (() -> Void)? = nil

    /// «Eliminar» al pie (L8-4), ya confirmado: el detalle pregunta antes con la misma alerta que el menú y el editor
    /// (L8-7). `nil`: no se ofrece.
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.tagCatalog) private var tagCatalog
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.usesLargeSheets) private var usesLargeSheets

    @State private var transferPartnerAccount: Account?
    @State private var isConfirmingDelete = false
    /// Gasto de grupo (L8-5): su nombre y de dónde sale cada número. Se leen una vez al abrir.
    @State private var groupName: String?
    @State private var groupBreakdown: GroupExpenseBreakdownLogic.Breakdown?

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
                groupDeleteHint
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
            .frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Duplicar y Eliminar a la vista, al pie y fuera del scroll: se ven sin descubrir la pulsación larga ni entrar
        // al editor, y Eliminar queda lejos de Editar (auditoría UX 2.2, L8-4, variante 1).
        .safeAreaInset(edge: .bottom, spacing: DS.Spacing.none) {
            footerActions
        }
        .alert(deleteTitle, isPresented: $isConfirmingDelete) {
            Button(L10n.Action.cancel, role: .cancel) {}
            Button(L10n.Action.delete, role: .destructive) { onDelete?() }
        } message: {
            Text(deleteMessage)
        }
        .task(id: transaction.persistentModelID) { resolveGroup() }
    }

    // MARK: - Pie: Duplicar y Eliminar (L8-4)

    private var rowActions: RecordContextActionLogic.Actions {
        RecordContextActionLogic.actions(.init(record: transaction))
    }

    private var isGroupRecord: Bool {
        transaction.splitExpenseID != nil || transaction.splitSettlementID != nil
    }

    @ViewBuilder
    private var footerActions: some View {
        let offersDuplicate = onDuplicate != nil && rowActions.canDuplicate
        let offersDelete = onDelete != nil && rowActions.canDelete
        if offersDuplicate || offersDelete {
            HStack(spacing: DS.Spacing.md) {
                if offersDuplicate {
                    Button {
                        onDuplicate?()
                    } label: {
                        Label(L10n.Action.duplicate, systemImage: "doc.on.doc")
                            .font(DS.Typography.label)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(Color.secondary.opacity(0.18), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("transaction_detail_duplicate")
                }
                if offersDelete {
                    Button {
                        DS.Haptic.warning()
                        isConfirmingDelete = true
                    } label: {
                        Label(L10n.Action.delete, systemImage: "trash")
                            .font(DS.Typography.label)
                            .foregroundStyle(DS.Semantic.errorForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Semantic.errorBackgroundSubtle, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("transaction_detail_delete")
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity)
            // Fijo al pie y con su cristal: sin él, las filas que suben por detrás se leían entre los dos botones.
            .background(.ultraThinMaterial)
        }
    }

    /// Lo que viene de un grupo se borra desde el grupo: se dice dónde en vez de no ofrecer nada (L8-6). Va en el
    /// contenido, bajo la tarjeta: fijo al pie se montaba sobre la última fila (medido en el simulador el 17-oct).
    @ViewBuilder
    private var groupDeleteHint: some View {
        if isGroupRecord, onDelete != nil, !rowActions.canDelete {
            Text(L10n.UXL8.deleteFromGroupHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("transaction_detail_group_delete_hint")
        }
    }

    /// «¿Eliminar «Uber · S/ 26»?»: dice qué se borra (L8-7).
    private var deleteTitle: String {
        RecordDeleteConfirmationText.title(for: transaction, preferences: appPreferences)
    }

    private var deleteMessage: String {
        RecordDeleteConfirmationText.message(for: transaction)
    }

    // MARK: - Gasto de grupo (L8-5)

    /// El nombre del grupo y las patas del mismo gasto. Una vez por registro abierto; si algo no hidrató todavía (una
    /// pata sin cuenta), no se inventa nada y queda la fila «Grupos» de siempre.
    private func resolveGroup() {
        guard isGroupRecord else { return }
        if let zone = transaction.splitGroupZoneID {
            do {
                groupName = try modelContext.fetch(
                    FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone })
                ).first.map(\.name).flatMap { $0.isEmpty ? nil : $0 }
            } catch {
                #if DEBUG
                print("TransactionDetailSheet: Error fetching group name: \(error)")
                #endif
            }
        }
        guard let expenseID = transaction.splitExpenseID else { return }
        do {
            // Un saldo inicial de grupo (deuda de apertura importada) no es la parte de ningún gasto: sin desglose, como
            // en Estadísticas, que tampoco lo cuenta como gasto (revisión adversarial del lote 8).
            if let expenseUUID = UUID(uuidString: expenseID),
               try modelContext.fetch(
                   FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == expenseUUID && $0.isOpeningBalance })
               ).first != nil {
                return
            }
            let legs = try modelContext.fetch(
                FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == expenseID })
            )
            guard !legs.contains(where: { $0.account == nil }) else { return }
            groupBreakdown = GroupExpenseBreakdownLogic.breakdown(legs: legs.map {
                .init(amount: $0.amount, isSystemAccount: $0.account?.isSystemAccount ?? false)
            })
        } catch {
            #if DEBUG
            print("TransactionDetailSheet: Error fetching group legs: \(error)")
            #endif
        }
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
        // La nota entera: cortada a una línea no se leía lo que la persona escribió (L8-4).
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
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

            // La necesidad, en los gastos (en la fila va en la píldora; aquí faltaba). L8-4.
            if transaction.subcategory != nil, showsNeed {
                detailRow(
                    icon: "circle.lefthalf.filled",
                    label: L10n.Category.need,
                    value: transaction.effectiveNeed.displayName
                )
            }

            if !resolvedTags.isEmpty {
                tagsRow
            }

            if transaction.currencyCode != transaction.preferredCurrencyCode {
                conversionRow
            }

            if let breakdown = groupBreakdown {
                groupBreakdownRows(breakdown)
            } else if let splitTotal = transaction.splitTotalAmount {
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

            if isGroupRecord {
                // El grupo por su nombre; sin él (aún no llegó), la fila «Grupos» de siempre.
                if let groupName {
                    detailRow(icon: "person.2.fill", label: L10n.UXL8.group, value: groupName)
                        .accessibilityIdentifier("transaction_detail_group")
                } else {
                    infoRow(icon: "person.2.fill", text: L10n.Groups.title)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }

    private var showsNeed: Bool {
        RecordRowPresentationLogic.showsNeedPill(
            isBalanceAdjustment: transaction.balanceAdjustmentType != nil,
            isIncome: TransactionClassificationLogic.isIncome(transaction),
            subcategoryIsSystem: transaction.subcategory?.isAnySystem ?? false
        )
    }

    /// «Pagaste», «Tu parte» y «Te deben»: de dónde sale el importe de un gasto de grupo (L8-5).
    @ViewBuilder
    private func groupBreakdownRows(_ breakdown: GroupExpenseBreakdownLogic.Breakdown) -> some View {
        if let paid = breakdown.youPaid {
            detailRow(icon: "creditcard", label: L10n.UXL8.youPaid, value: money(paid))
                .accessibilityIdentifier("transaction_detail_you_paid")
        }
        detailRow(icon: "person.fill", label: L10n.UXL8.yourShare, value: money(breakdown.yourShare))
            .accessibilityIdentifier("transaction_detail_your_share")
        if let owed = breakdown.owedToYou {
            detailRow(icon: "arrow.down.left", label: L10n.UXL8.owedToYou, value: money(owed))
                .accessibilityIdentifier("transaction_detail_owed_to_you")
        }
    }

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: transaction.currencyCode, forceFullPrecision: true)
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
    /// (sin recalcular — formato del exchangeRateChip del form). Si la conversión no se escribió
    /// (0 con nativo ≠ 0), se reconvierte con la tasa de ese día o, sin ella, la fila lo dice con
    /// texto: nunca pinta 0 como importe (`TransactionDetailSheetLogic.conversionDisplay`).
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
                switch TransactionDetailSheetLogic.conversionDisplay(for: transaction, converter: currencyConverter) {
                case .amount(let value, let rate):
                    Text(
                        "≈ \(appPreferences.currency(value, currencyCode: transaction.preferredCurrencyCode, forceFullPrecision: true))"
                    )
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)

                    Text(L10n.Transaction.exchangeRateShort(ExchangeRateDisplayFormatter.string(rate)))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                case .missingRateForDay:
                    Text(L10n.Transaction.exchangeRateMissingForDay)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
