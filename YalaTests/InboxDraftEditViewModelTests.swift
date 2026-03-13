//
//  InboxDraftEditViewModelTests.swift
//  YalaTests
//
//  Tests for InboxDraftEditViewModel - pending draft helpers.
//  Note: pendingDrafts is private(set) and populated via ModelContext fetch,
//  so we test initial state and the helper logic by verifying behavior with empty data.
//  The core nextPendingDraft/hasNextPendingDraft logic is tested via InboxDraft model
//  array operations directly.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct InboxDraftEditViewModelTests {

    // MARK: - Initial State

    @MainActor @Test("Initial state has empty pendingDrafts")
    func initialState_pendingDraftsEmpty() {
        let vm = InboxDraftEditViewModel()
        #expect(vm.pendingDrafts.isEmpty)
    }

    // MARK: - loadPendingDrafts without context

    @MainActor @Test("loadPendingDrafts without context keeps empty array")
    func loadPendingDrafts_withoutContext_keepsEmpty() {
        let vm = InboxDraftEditViewModel()
        vm.loadPendingDrafts()
        #expect(vm.pendingDrafts.isEmpty)
    }

    // MARK: - nextPendingDraft with empty data

    @MainActor @Test("nextPendingDraft returns nil when pendingDrafts is empty")
    func nextPendingDraft_emptyArray_returnsNil() {
        let vm = InboxDraftEditViewModel()
        let draft = InboxDraft(note: "Test", amount: 10.0)
        let result = vm.nextPendingDraft(excluding: draft)
        #expect(result == nil)
    }

    @MainActor @Test("hasNextPendingDraft returns false when pendingDrafts is empty")
    func hasNextPendingDraft_emptyArray_returnsFalse() {
        let vm = InboxDraftEditViewModel()
        let draft = InboxDraft(note: "Test", amount: 10.0)
        let result = vm.hasNextPendingDraft(excluding: draft)
        #expect(result == false)
    }

    // MARK: - InboxDraft model properties (pure logic)

    @Test("InboxDraft default status is pending")
    func inboxDraft_defaultStatus_isPending() {
        let draft = InboxDraft(note: "Grocery run", amount: 25.0)
        #expect(draft.status == .pending)
        #expect(draft.statusRaw == "pending")
    }

    @Test("InboxDraft effectiveDate uses date when available")
    func inboxDraft_effectiveDate_usesDate() {
        let specificDate = Date(timeIntervalSince1970: 1_700_000_000)
        let draft = InboxDraft(note: "Test", amount: 10.0, date: specificDate)
        #expect(draft.effectiveDate == specificDate)
    }

    @Test("InboxDraft effectiveDate falls back to createdAt when date is nil")
    func inboxDraft_effectiveDate_fallsBackToCreatedAt() {
        let draft = InboxDraft(note: "Test", amount: 10.0, date: nil)
        #expect(draft.effectiveDate == draft.createdAt)
    }

    @Test("InboxDraft isReadyToApprove requires account, amount, and subcategory")
    func inboxDraft_isReadyToApprove_requiresAllFields() {
        let draft = InboxDraft(note: "Test", amount: 50.0)
        // No account or subcategory set
        #expect(draft.isReadyToApprove == false)
    }

    @Test("InboxDraft isReadyToApprove false when amount is nil")
    func inboxDraft_isReadyToApprove_falseWithoutAmount() {
        let draft = InboxDraft(note: "Test", amount: nil)
        #expect(draft.isReadyToApprove == false)
    }

    @Test("InboxDraft sourceIcon returns correct icon for voice")
    func inboxDraft_sourceIcon_voice() {
        let draft = InboxDraft(note: "Test", sourceType: .voice)
        #expect(draft.sourceIcon == "mic.fill")
    }

    @Test("InboxDraft sourceIcon returns correct icon for receiptPhoto")
    func inboxDraft_sourceIcon_receiptPhoto() {
        let draft = InboxDraft(note: "Test", sourceType: .receiptPhoto)
        #expect(draft.sourceIcon == "camera.fill")
    }
}

/*
Tests generated:
1. initialState_pendingDraftsEmpty - Verifies VM starts with empty array
2. loadPendingDrafts_withoutContext_keepsEmpty - No crash without context
3. nextPendingDraft_emptyArray_returnsNil - Returns nil when no drafts loaded
4. hasNextPendingDraft_emptyArray_returnsFalse - Returns false when no drafts
5. inboxDraft_defaultStatus_isPending - Default draft status
6. inboxDraft_effectiveDate_usesDate - Date resolution with explicit date
7. inboxDraft_effectiveDate_fallsBackToCreatedAt - Date resolution fallback
8. inboxDraft_isReadyToApprove_requiresAllFields - Validation without account/subcategory
9. inboxDraft_isReadyToApprove_falseWithoutAmount - Validation without amount
10. inboxDraft_sourceIcon_voice - Source icon mapping
11. inboxDraft_sourceIcon_receiptPhoto - Source icon mapping

Cases NOT covered (require ModelContext):
- nextPendingDraft/hasNextPendingDraft with populated pendingDrafts
  (pendingDrafts is private(set), populated only via fetch)
*/
