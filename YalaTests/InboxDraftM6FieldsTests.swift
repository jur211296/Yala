//
//  InboxDraftM6FieldsTests.swift
//  YalaTests
//
//  M6: 3 nuevos campos opcionales en InboxDraft para hint contextual de drafts
//  creados por bridge ante modificaciones remotas (cambio moneda, sync remoto, etc.).
//

import Foundation
import Testing

@testable import Yala

struct InboxDraftM6FieldsTests {

    // MARK: - Defaults

    @Test func originReasonKey_defaultsToNil() {
        let draft = InboxDraft(note: "test")
        #expect(draft.originReasonKey == nil)
    }

    @Test func originActorName_defaultsToNil() {
        let draft = InboxDraft(note: "test")
        #expect(draft.originActorName == nil)
    }

    @Test func originGroupName_defaultsToNil() {
        let draft = InboxDraft(note: "test")
        #expect(draft.originGroupName == nil)
    }

    // MARK: - Init params populate fields

    @Test func init_populatesAllOriginFields() {
        let draft = InboxDraft(
            note: "Cena viernes",
            amount: -400,
            sourceType: .groupExpense,
            needsUserInput: ["account"],
            splitExpenseID: "expense-uuid",
            splitGroupZoneID: "zone-uuid",
            originReasonKey: "groups.bridge.draftReasonRemoteCreate",
            originActorName: "Maria",
            originGroupName: "Cena viernes"
        )
        #expect(draft.originReasonKey == "groups.bridge.draftReasonRemoteCreate")
        #expect(draft.originActorName == "Maria")
        #expect(draft.originGroupName == "Cena viernes")
    }

    @Test func init_originFieldsIndependentlyOptional() {
        // Reason key sin actor (caso currencyChanged impersonal).
        let draft = InboxDraft(
            note: "test",
            originReasonKey: "groups.bridge.draftReasonCurrencyChanged",
            originActorName: nil,
            originGroupName: "Viaje Cusco"
        )
        #expect(draft.originReasonKey == "groups.bridge.draftReasonCurrencyChanged")
        #expect(draft.originActorName == nil)
        #expect(draft.originGroupName == "Viaje Cusco")
    }
}
