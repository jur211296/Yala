//
//  InboxView.swift
//  Neto
//
//  Bandeja de entrada para borradores de transacciones.
//  Fase 8: Registro Inteligente
//

import SwiftData
import SwiftUI

// MARK: - Filter Type

enum InboxFilter: String, CaseIterable {
    case pending
    case archived

    var displayName: String {
        switch self {
        case .pending:
            return L10n.Inbox.pending
        case .archived:
            return L10n.Inbox.archived
        }
    }

    var icon: String {
        switch self {
        case .pending:
            return "tray.full"
        case .archived:
            return "archivebox"
        }
    }
}

// MARK: - InboxView

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preferredCurrency") private var preferredCurrency: String = "PEN"

    @State private var selectedFilter: InboxFilter = .pending
    @State private var selectedDraft: InboxDraft?

    // Query all drafts
    @Query(sort: \InboxDraft.createdAt, order: .reverse)
    private var allDrafts: [InboxDraft]

    private var filteredDrafts: [InboxDraft] {
        switch selectedFilter {
        case .pending:
            return allDrafts.filter { $0.status == .pending }
        case .archived:
            return allDrafts.filter { $0.status == .approved || $0.status == .rejected }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        // Filter chips
                        filterChips
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.top, DS.Spacing.sm)

                        // Content
                        if filteredDrafts.isEmpty {
                            emptyState
                                .padding(.top, DS.Spacing.xxxxl)
                        } else {
                            draftsList
                                .padding(.horizontal, DS.Spacing.lg)
                        }
                    }
                    .padding(.bottom, DS.Spacing.safeBottom)
                }
            }
            .navigationTitle(L10n.Inbox.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.done) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedDraft) { draft in
                InboxDraftDetailSheet(draft: draft)
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(InboxFilter.allCases, id: \.self) { filter in
                filterChip(for: filter)
            }
            Spacer()
        }
    }

    private func filterChip(for filter: InboxFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = countForFilter(filter)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.displayName)
                    .font(.subheadline.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.electricIndigo : Color.clear)
            )
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func countForFilter(_ filter: InboxFilter) -> Int {
        switch filter {
        case .pending:
            return allDrafts.filter { $0.status == .pending }.count
        case .archived:
            return allDrafts.filter { $0.status == .approved || $0.status == .rejected }.count
        }
    }

    // MARK: - Drafts List

    private var draftsList: some View {
        LazyVStack(spacing: DS.Spacing.sm) {
            ForEach(filteredDrafts, id: \.persistentModelID) { draft in
                InboxDraftRowView(
                    draft: draft,
                    currencyCode: draft.account?.currencyCode ?? preferredCurrency,
                    onTap: {
                        selectedDraft = draft
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteDraft(draft)
                    } label: {
                        Label(L10n.Inbox.delete, systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        switch selectedFilter {
        case .pending:
            NetoEmptyState(
                icon: "tray",
                title: L10n.Inbox.noPending,
                message: L10n.Inbox.noPendingDescription
            )
        case .archived:
            NetoEmptyState(
                icon: "archivebox",
                title: L10n.Inbox.noArchived,
                message: L10n.Inbox.noArchivedDescription
            )
        }
    }

    // MARK: - Actions

    private func deleteDraft(_ draft: InboxDraft) {
        withAnimation {
            draft.status = .rejected
            draft.updatedAt = Date()
            do {
                try modelContext.save()
            } catch {
                print("Error deleting draft: \(error)")
            }
        }
    }
}

// MARK: - Draft Detail Sheet (Placeholder)

struct InboxDraftDetailSheet: View {
    let draft: InboxDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxl) {
                // Source icon
                ZStack {
                    Circle()
                        .fill(Color.electricIndigo.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: draft.sourceIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
                }

                // Info
                VStack(spacing: DS.Spacing.md) {
                    Text(draft.note.isEmpty ? L10n.Common.uncategorized : draft.note)
                        .font(DS.Typography.title2)
                        .multilineTextAlignment(.center)

                    if let amount = draft.amount {
                        Text(NetoFormatter.currency(value: amount, currencyCode: draft.account?.currencyCode ?? "PEN"))
                            .font(DS.Typography.amountLarge)
                            .foregroundStyle(amount >= 0 ? Color.electricIndigo : Color.hotPink)
                    }

                    Text(draft.effectiveDate, style: .date)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Placeholder message
                Text("Edición completa disponible en Subfase 8.2")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, DS.Spacing.xl)

                Spacer()
            }
            .padding(DS.Spacing.xxl)
            .navigationTitle(L10n.Inbox.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.done) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InboxView()
        .modelContainer(for: InboxDraft.self, inMemory: true)
}
