//
//  PanelSheetTriggers.swift
//  Yala
//
//  onChange observers that trigger sheet presentations, extracted from PanelView.
//

import SwiftUI

struct PanelSheetTriggers: ViewModifier {
    let sessionState: SessionState
    @Binding var sheets: PanelSheetState

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.shouldShowInbox) { _, shouldShow in
                if shouldShow {
                    sheets.showInbox = true
                    sessionState.shouldShowInbox = false
                }
            }
            .onChange(of: sessionState.shouldShowSharedImage) { _, shouldShow in
                if shouldShow {
                    sheets.showImageSelection = true
                    sessionState.shouldShowSharedImage = false
                }
            }
            .onChange(of: sessionState.shouldShowVoiceEntry) { _, shouldShow in
                if shouldShow {
                    sheets.showVoiceRecording = true
                    sessionState.shouldShowVoiceEntry = false
                }
            }
            .onChange(of: sessionState.shouldShowImageEntry) { _, shouldShow in
                if shouldShow {
                    sheets.showImageSelection = true
                    sessionState.shouldShowImageEntry = false
                }
            }
            .onChange(of: sessionState.shouldShowNewTransaction) { _, shouldShow in
                if shouldShow {
                    sheets.showNewTransaction = true
                    sessionState.shouldShowNewTransaction = false
                }
            }
            .onChange(of: sessionState.shouldShowUpgradeForVoice) { _, shouldShow in
                if shouldShow {
                    sheets.showUpgradeForVoice = true
                    sessionState.shouldShowUpgradeForVoice = false
                }
            }
            .onChange(of: sessionState.shouldShowUpgradeForImage) { _, shouldShow in
                if shouldShow {
                    sheets.showUpgradeForImage = true
                    sessionState.shouldShowUpgradeForImage = false
                }
            }
    }
}
