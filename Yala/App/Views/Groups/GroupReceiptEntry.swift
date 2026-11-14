//
//  GroupReceiptEntry.swift
//  Yala
//
//  Voz y Foto de Grupos: repartir un recibo con IA desde el inicio de Grupos y desde el detalle de un grupo
//  (Jürgen, 2026-11-14: «asemejar la experiencia de personal; los botones de imagen y voz en el inicio de Grupos, no
//  dentro del nuevo registro»). Ticket `group-receipt-split-home-buttons`.
//
//  - `GroupQuickActionsRow`: «Nuevo gasto», Voz, Foto y Yala IA en una fila, como la del Panel.
//  - `groupReceiptSplitFlow`: el camino entero. Con varios grupos, «¿En qué grupo?» primero; después la hoja del recibo
//    (Voz la abre escuchando; Yala IA, para escribir el gasto); y con «Usar este reparto», `onReady` con el grupo y el reparto para abrir Nuevo gasto
//    relleno. Cada hoja se pide en el `onDismiss` de la anterior: dos presentaciones seguidas del mismo ancla sin
//    esperar a que la primera se cierre se pierden (`swiftui-ds.md`).
//

import SwiftUI

// MARK: - Botones

/// Cómo se le cuenta el recibo a la IA: foto, nota de voz o escrito (el botón «Yala IA», Jürgen 2026-11-14).
enum GroupReceiptEntryKind: Equatable {
    case photo, voice, text
}

/// La fila de acciones de Grupos, como la de personal: «Nuevo gasto», Voz, Foto y Yala IA (Jürgen, 2026-11-14). En el
/// inicio de Grupos y bajo el saldo de un grupo; «Nuevo grupo» vive en la barra de arriba. Sin candado: en Grupos la IA
/// es gratis con un cupo diario (5 recibos Free, 50 Pro), lo cuenta el gateway.
struct GroupQuickActionsRow: View {
    /// `groups` en el inicio de Grupos, `group_detail` dentro de un grupo.
    let identifierPrefix: String
    let onNewExpense: () -> Void
    let onReceipt: (GroupReceiptEntryKind) -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var iconHeight: CGFloat = 18

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Con texto de accesibilidad, «Nuevo gasto» en su línea y las otras debajo (molde de la fila del Panel).
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                newExpensePill
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.Spacing.sm) { aiPills }
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) { aiPills }
                }
            }
        } else {
            // Una sola fila. Si en algún idioma no cabe, se desplaza como la de personal, nunca se corta un título.
            ViewThatFits(in: .horizontal) {
                row
                ScrollView(.horizontal, showsIndicators: false) { row }
            }
        }
    }

    private var row: some View {
        HStack(spacing: DS.Spacing.sm) {
            newExpensePill
            aiPills
        }
    }

    private var newExpensePill: some View {
        TopPrimaryActionPill(
            title: L10n.Groups.Expense.newExpense,
            systemImage: "square.and.pencil",
            accessibilityIdentifier: "\(identifierPrefix)_action_new_expense",
            action: onNewExpense
        )
        .fixedSize()
    }

    @ViewBuilder
    private var aiPills: some View {
        captionPill(caption: L10n.Panel.voiceShort, icon: "waveform", kind: .voice, id: "voice")
        captionPill(caption: L10n.Panel.photoShort, icon: "photo", kind: .photo, id: "photo")
        aiPill
    }

    /// Voz y Foto: icono y su palabra debajo, como en el Panel.
    private func captionPill(caption: String, icon: String, kind: GroupReceiptEntryKind, id: String) -> some View {
        Button {
            DS.Haptic.selection()
            onReceipt(kind)
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(DS.Typography.label)
                    .frame(height: iconHeight)
                Text(caption)
                    .font(DS.Typography.labelTiny)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xxs)
            .frame(minHeight: 44)
            .background(Capsule().fill(theme.card))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadow(color: DS.Shadow.small.color, radius: DS.Shadow.small.radius, x: DS.Shadow.small.x, y: DS.Shadow.small.y)
        .accessibilityLabel(caption)
        .accessibilityHint(L10n.ReceiptSplit.entryHint)
        .accessibilityIdentifier("\(identifierPrefix)_receipt_\(id)")
    }

    /// «Yala IA» con el dorado de la de personal y sin candado: aquí escribe el gasto para repartirlo.
    private var aiPill: some View {
        Button {
            DS.Haptic.selection()
            onReceipt(.text)
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(DS.Typography.label)
                Text(L10n.Chat.assistantName)
                    .font(DS.Typography.label)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(Color.proGoldOnCard)
            .padding(.horizontal, DS.Spacing.md)
            .frame(minHeight: 44)
            .background {
                Capsule()
                    .fill(theme.card)
                    .overlay { Capsule().strokeBorder(Color.proGoldOnCard, lineWidth: 1.5) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadow(color: DS.Shadow.small.color, radius: DS.Shadow.small.radius, x: DS.Shadow.small.x, y: DS.Shadow.small.y)
        .accessibilityLabel(L10n.Chat.assistantName)
        .accessibilityHint(L10n.ReceiptSplit.textHint)
        .accessibilityIdentifier("\(identifierPrefix)_receipt_ai")
    }
}

// MARK: - Camino

/// Lo que se pidió al tocar Voz o Foto: con un grupo ya decidido, la hoja del recibo; con varios, el selector.
struct GroupReceiptRequest: Identifiable {
    let id = UUID()
    let groups: [SplitGroup]
    /// El grupo marcado en el selector (el del último gasto). Con un solo grupo, ese.
    let preselected: SplitGroup
    let source: GroupReceiptEntryKind

    var needsPicker: Bool { groups.count > 1 }
}

private struct GroupReceiptSheet: Identifiable {
    let id = UUID()
    let group: SplitGroup
    let source: GroupReceiptEntryKind
}

private struct GroupReceiptSplitFlow: ViewModifier {
    @Binding var request: GroupReceiptRequest?
    let activeMembers: (SplitGroup) -> [SplitMember]
    let memberCount: (SplitGroup) -> Int
    let onReady: (SplitGroup, GroupExpensePrefillTemplate) -> Void

    @State private var picking: GroupReceiptRequest?
    @State private var chosen: GroupReceiptSheet?
    @State private var sheet: GroupReceiptSheet?
    @State private var used: (group: SplitGroup, template: GroupExpensePrefillTemplate)?

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id) { _, _ in start() }
            .sheet(item: $picking, onDismiss: openChosen) { request in picker(for: request) }
            .sheet(item: $sheet, onDismiss: finish) { sheet in receiptSheet(sheet) }
    }

    private func start() {
        guard let request else { return }
        self.request = nil
        if request.needsPicker {
            picking = request
        } else {
            sheet = GroupReceiptSheet(group: request.preselected, source: request.source)
        }
    }

    private func picker(for request: GroupReceiptRequest) -> some View {
        GroupPickerSheet(
            groups: request.groups,
            selectedGroupID: request.preselected.id,
            memberCount: memberCount,
            opensAtMediumHeight: true
        ) { group in
            chosen = GroupReceiptSheet(group: group, source: request.source)
            picking = nil
        }
    }

    private func openChosen() {
        guard let chosen else { return }
        self.chosen = nil
        sheet = chosen
    }

    private func receiptSheet(_ sheet: GroupReceiptSheet) -> some View {
        let members = activeMembers(sheet.group)
        return GroupReceiptSplitView(
            members: members,
            currentMemberID: GroupExpenseService.resolveCurrentUserMember(from: members)?.id.uuidString,
            currencyCode: sheet.group.currencyCode,
            onUse: { used = (sheet.group, $0) },
            startsWith: sheet.source
        )
        .yalaSheetDetents([.large])
    }

    private func finish() {
        guard let used else { return }
        self.used = nil
        onReady(used.group, used.template)
    }
}

extension View {
    /// Voz y Foto de Grupos: pon `request` y el camino hace el resto; `onReady` llega con la hoja ya cerrada.
    func groupReceiptSplitFlow(
        request: Binding<GroupReceiptRequest?>,
        activeMembers: @escaping (SplitGroup) -> [SplitMember],
        memberCount: @escaping (SplitGroup) -> Int,
        onReady: @escaping (SplitGroup, GroupExpensePrefillTemplate) -> Void
    ) -> some View {
        modifier(GroupReceiptSplitFlow(
            request: request,
            activeMembers: activeMembers,
            memberCount: memberCount,
            onReady: onReady
        ))
    }
}
