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
    @Environment(\.yalaTheme) private var theme

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

    /// «Guardar los N» al pie de las tarjetas (UX 2.2 · L14-9, opción D): solo con dos o más registros pendientes y
    /// completos. Con uno, su propio «Guardar» basta; los incompletos siguen pidiendo lo que falta en su tarjeta.
    @ViewBuilder
    private var saveAllButton: some View {
        let ready = viewModel.draftsReadyToSave(messageID: messageID)
        if ready.count >= 2 {
            Button {
                Task { await viewModel.saveAllReadyDrafts(messageID: messageID) }
            } label: {
                Text(L10n.UXL14D.saveAll(ready.count))
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(theme.accent))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chat_draft_save_all")
        }
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
                saveAllButton
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
