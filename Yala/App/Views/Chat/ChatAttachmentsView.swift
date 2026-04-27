//
//  ChatAttachmentsView.swift
//  Yala
//
//  Renders [ChatAttachment] dentro del bubble del assistant: cards apiladas
//  para drafts, chips horizontales para ambiguous.
//

import SwiftUI

struct ChatAttachmentsView: View {

    let messageID: UUID
    let attachments: [ChatAttachment]
    @Bindable var viewModel: ChatAssistantViewModel

    @Environment(SessionState.self) private var sessionState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(attachments.enumerated()), id: \.offset) { _, attachment in
                attachmentView(for: attachment)
            }
            if hasSavedDrafts {
                viewRecordsButton
            }
        }
    }

    /// `true` si al menos un draft del bubble está `.saved` (transacción persistida).
    private var hasSavedDrafts: Bool {
        for attachment in attachments {
            if case .drafts(let drafts) = attachment, drafts.contains(where: { $0.status == .saved }) {
                return true
            }
        }
        return false
    }

    private var viewRecordsButton: some View {
        Button {
            dismiss()  // cierra ChatSheet (agnóstico a los 3 puntos de entrada)
            sessionState.navigateToRecordsStandalone()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.Chat.Draft.viewRecordsButton)
                    .font(DS.Typography.labelSmall)
                Image(systemName: "arrow.right")
                    .font(DS.Typography.labelTiny)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(.thCard)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Chat.Draft.viewRecordsButton)
    }

    @ViewBuilder
    private func attachmentView(for attachment: ChatAttachment) -> some View {
        switch attachment {
        case .drafts(let drafts):
            VStack(spacing: DS.Spacing.sm) {
                ForEach(drafts) { draft in
                    ChatTransactionDraftCard(
                        draft: draft,
                        messageID: messageID,
                        onSave: { draftID in
                            Task { await viewModel.saveDraft(messageID: messageID, draftID: draftID) }
                        },
                        onEdit: { draftID in
                            viewModel.editDraft(messageID: messageID, draftID: draftID)
                        },
                        onDiscard: { draftID in
                            viewModel.discardDraft(messageID: messageID, draftID: draftID)
                        },
                        onAmountChange: { newAmount in
                            viewModel.updateDraft(
                                messageID: messageID,
                                draftID: draft.id,
                                amount: newAmount
                            )
                        },
                        onAccountChange: { newAccountID in
                            viewModel.updateDraft(
                                messageID: messageID,
                                draftID: draft.id,
                                accountID: .some(newAccountID)
                            )
                        },
                        onSubcategoryChange: { newSubID in
                            viewModel.updateDraft(
                                messageID: messageID,
                                draftID: draft.id,
                                subcategoryID: .some(newSubID)
                            )
                        },
                        onDateChange: { newDate in
                            viewModel.updateDraft(
                                messageID: messageID,
                                draftID: draft.id,
                                date: newDate
                            )
                        },
                        onTagsChange: { newTagIDs in
                            viewModel.updateDraft(
                                messageID: messageID,
                                draftID: draft.id,
                                tagIDs: newTagIDs
                            )
                        },
                        onNoteChange: { newNote in
                            viewModel.updateDraft(
                                messageID: messageID,
                                draftID: draft.id,
                                note: newNote
                            )
                        }
                    )
                }
            }
        case .ambiguous(_, let choices):
            HStack(spacing: DS.Spacing.sm) {
                ForEach(choices) { chip in
                    Button {
                        Task {
                            await viewModel.dismissAmbiguous(
                                triggerText: chip.triggerText,
                                forceIntent: chip.forceIntent
                            )
                        }
                    } label: {
                        Text(chip.label)
                            .font(DS.Typography.labelSmall)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(.thCard)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
