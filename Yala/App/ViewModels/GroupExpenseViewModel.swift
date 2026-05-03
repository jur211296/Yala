//
//  GroupExpenseViewModel.swift
//  Yala
//
//  Form state, validation, and save logic for group expense create/edit.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GroupExpenseViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    let group: SplitGroup
    let members: [SplitMember]
    let memberNameLookup: [String: String]

    // MARK: - Mode

    private(set) var editingExpense: SplitExpense?
    var isEditMode: Bool { editingExpense != nil }

    // MARK: - Form State

    var amountString: String = ""
    var expenseDescription: String = ""
    var note: String = ""
    var date: Date = .now
    var paidByMemberID: String = ""
    var currencyCode: String = ""
    var subcategoryName: String?
    var selectedSubcategory: Subcategory? {
        didSet { subcategoryName = selectedSubcategory?.name }
    }
    var splitType: SplitType = .equal

    // Per-participant state
    var selectedMemberIDs: Set<String> = []
    var exactAmounts: [String: String] = [:]
    var percentages: [String: String] = [:]
    var sharesCounts: [String: String] = [:]
    private var selectableMemberIDs: Set<String> = []

    // MARK: - UI State

    var isSaving: Bool = false
    var saveError: String?

    // MARK: - Computed

    var amount: Double {
        AmountInputHelper.parseDecimal(amountString)
    }

    var selectedMembers: [SplitMember] {
        members.filter { selectedMemberIDs.contains($0.id.uuidString) && selectableMemberIDs.contains($0.id.uuidString) }
    }

    var calculatedShares: [(memberID: String, amount: Double)]? {
        let participants = buildParticipants()
        guard !participants.isEmpty, amount > 0 else { return nil }
        return GroupSplitCalculator.calculate(
            total: amount,
            splitType: splitType,
            participants: participants
        )
    }

    var sharesTotal: Double {
        calculatedShares?.reduce(0.0) { $0 + $1.amount } ?? 0
    }

    var remainingToAllocate: Double {
        amount - sharesTotal
    }

    var isSharesBalanced: Bool {
        guard calculatedShares != nil else { return splitType == .equal && !selectedMemberIDs.isEmpty }
        return abs(remainingToAllocate) < 0.02
    }

    var isAmountValid: Bool { amount > 0 }
    var isDescriptionValid: Bool { !expenseDescription.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasSelectedMembers: Bool { !selectedMemberIDs.isEmpty }
    var isPaidByValid: Bool { !paidByMemberID.isEmpty }

    var canSave: Bool {
        isAmountValid && isDescriptionValid && hasSelectedMembers && isPaidByValid && isSharesBalanced
    }

    // MARK: - Init

    init(group: SplitGroup, members: [SplitMember], memberNameLookup: [String: String]) {
        self.group = group
        self.members = members
        self.memberNameLookup = memberNameLookup

        // Defaults
        self.currencyCode = group.currencyCode
        self.splitType = SplitType(rawValue: group.defaultSplitType) ?? .equal
        self.selectableMemberIDs = Set(members.filter(\.isActive).map { $0.id.uuidString })
        self.paidByMemberID = members.first(where: { $0.isCurrentUser && $0.isActive })?.id.uuidString ?? ""
        self.selectedMemberIDs = selectableMemberIDs
    }

    func setContext(_ ctx: ModelContext) {
        self.modelContext = ctx
    }

    // MARK: - Actions

    func save() -> Bool {
        guard canSave else { return false }
        guard let shares = calculatedShares else { return false }

        isSaving = true
        saveError = nil

        do {
            if let existing = editingExpense {
                try GroupExpenseService.shared.updateExpense(
                    existing,
                    in: group,
                    amount: amount,
                    currencyCode: currencyCode,
                    description: expenseDescription.trimmingCharacters(in: .whitespaces),
                    note: note.isEmpty ? nil : note,
                    date: date,
                    paidByMemberID: paidByMemberID,
                    splitType: splitType.rawValue,
                    subcategoryName: subcategoryName,
                    shares: shares
                )
            } else {
                try GroupExpenseService.shared.createExpense(
                    in: group,
                    amount: amount,
                    currencyCode: currencyCode,
                    description: expenseDescription.trimmingCharacters(in: .whitespaces),
                    note: note.isEmpty ? nil : note,
                    date: date,
                    paidByMemberID: paidByMemberID,
                    splitType: splitType.rawValue,
                    subcategoryName: subcategoryName,
                    shares: shares
                )
            }
            isSaving = false
            return true
        } catch {
            #if DEBUG
            print("GroupExpenseViewModel: Error saving: \(error)")
            #endif
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func prefill(from expense: SplitExpense, shares: [SplitShare]) {
        editingExpense = expense
        amountString = AmountInputHelper.formatWithGrouping(expense.amount)
        expenseDescription = expense.expenseDescription
        note = expense.note ?? ""
        date = expense.date
        paidByMemberID = expense.paidByMemberID
        currencyCode = expense.currencyCode
        subcategoryName = expense.subcategoryName
        resolveSubcategory()
        splitType = SplitType(rawValue: expense.splitType) ?? .equal

        selectedMemberIDs = Set(shares.map(\.memberID))
        selectableMemberIDs.formUnion(selectedMemberIDs)
        selectableMemberIDs.insert(expense.paidByMemberID)

        // Populate per-type fields from existing shares
        for share in shares {
            let id = share.memberID
            switch splitType {
            case .exact:
                exactAmounts[id] = AmountInputHelper.formatWithGrouping(share.amount)
            case .percentage:
                let pct = expense.amount > 0 ? (share.amount / expense.amount) * 100 : 0
                percentages[id] = String(format: "%.1f", pct)
            case .shares:
                // Shares are stored as amounts; derive share count from ratio
                sharesCounts[id] = "1"
            case .equal:
                break
            }
        }
    }

    // MARK: - Member Selection

    func selectAllMembers() {
        selectedMemberIDs = selectableMemberIDs
    }

    func deselectAllMembers() {
        selectedMemberIDs.removeAll()
    }

    func toggleMember(_ memberID: String) {
        guard selectableMemberIDs.contains(memberID) else { return }
        if selectedMemberIDs.contains(memberID) {
            selectedMemberIDs.remove(memberID)
        } else {
            selectedMemberIDs.insert(memberID)
        }
    }

    // MARK: - Private

    /// Resuelve subcategoryName (String) → Subcategory object via fetch
    private func resolveSubcategory() {
        guard let name = subcategoryName, let ctx = modelContext else { return }
        do {
            var descriptor = FetchDescriptor<Subcategory>(
                predicate: #Predicate { $0.name == name }
            )
            descriptor.fetchLimit = 1
            selectedSubcategory = try ctx.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("GroupExpenseViewModel: Error resolving subcategory '\(name)': \(error)")
            #endif
        }
    }

    private func buildParticipants() -> [GroupSplitCalculator.Participant] {
        let selected = members.filter { selectedMemberIDs.contains($0.id.uuidString) && selectableMemberIDs.contains($0.id.uuidString) }
        return selected.map { member in
            let id = member.id.uuidString
            let value: Double = switch splitType {
            case .equal:
                1.0
            case .exact:
                AmountInputHelper.parseDecimal(exactAmounts[id] ?? "0")
            case .percentage:
                Double(percentages[id] ?? "0") ?? 0
            case .shares:
                Double(sharesCounts[id] ?? "1") ?? 1
            }
            return GroupSplitCalculator.Participant(memberID: id, value: value)
        }
    }
}
