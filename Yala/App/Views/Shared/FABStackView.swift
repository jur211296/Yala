//
//  FABStackView.swift
//  Yala
//
//  Shared FAB component: AI FAB (sparkles) + Transaction FAB (plus) with expandable menu.
//  Used by PanelView, DetailContainerView, and RecordsStandaloneView.
//

import SwiftUI

struct FABStackView: View {

    // MARK: - Configuration

    let canUseVoiceInput: Bool
    let isVoiceLocked: Bool
    let isImageLocked: Bool
    let isChatLocked: Bool
    let chatConsentAccepted: Bool
    let chatFABVisible: Bool

    // MARK: - Callbacks

    let onVoiceTap: () -> Void
    let onImageTap: () -> Void
    let onManualTap: () -> Void
    let onUpgradeVoice: () -> Void
    let onUpgradeImage: () -> Void
    let onChatTap: () -> Void
    let onUpgradeChat: () -> Void
    let onChatConsentNeeded: () -> Void

    // MARK: - Internal State

    @State private var showFABMenu = false
    @AppStorage(AppPreferences.Keys.aiDataConsentAccepted) private var aiDataConsentAccepted: Bool = false
    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice

    // MARK: - Environment

    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState

    // MARK: - Animation Constants

    private static let fabSpring: Animation = .spring(
        response: DS.Animation.springResponse,
        dampingFraction: DS.Animation.springDamping
    )

    private static let fabScaleTransition: AnyTransition = .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)

    private func toggleMenu() {
        dsWithAnimation(reduceMotion, Self.fabSpring) { showFABMenu.toggle() }
    }

    private func dismissMenu() {
        dsWithAnimation(reduceMotion, Self.fabSpring) { showFABMenu = false }
    }

    // MARK: - Body

    var body: some View {
        let fabBackground = canUseVoiceInput ? theme.accent : DS.Semantic.disabledForeground.opacity(0.5)

        if canUseVoiceInput {
            VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                if showFABMenu {
                    menuButtons
                }

                if chatFABVisible && !showFABMenu {
                    aiFAB.transition(Self.fabScaleTransition)
                }

                transactionFAB(background: fabBackground)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
            .onChange(of: sessionState.selectedMainTab) { _, _ in
                guard showFABMenu else { return }
                dismissMenu()
            }
            .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { input in
                switch input {
                case .voice: onVoiceTap()
                case .image: onImageTap()
                }
            }
        } else {
            disabledFAB(background: fabBackground)
        }
    }

    // MARK: - AI FAB

    private var aiFAB: some View {
        Button {
            DS.Haptic.selection()
            if isChatLocked {
                onUpgradeChat()
            } else if !chatConsentAccepted {
                onChatConsentNeeded()
            } else {
                onChatTap()
            }
        } label: {
            ZStack {
                Image(systemName: "sparkles")
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(isChatLocked ? DS.Semantic.disabledForeground : .white)

                if isChatLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8)) // A11Y-DT: decorative lock badge on FAB
                        .foregroundStyle(DS.Semantic.disabledForeground)
                        .offset(x: 14, y: 14)
                }
            }
            .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
            .background {
                if isChatLocked {
                    DS.Semantic.neutralBackground
                } else {
                    LinearGradient(
                        colors: DS.Gradients.proBadge,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(Circle())
            .shadow(color: (isChatLocked ? Color.gray : Color.orange).opacity(0.3), radius: DS.Shadow.medium.radius, x: 0, y: DS.Shadow.medium.y)
        }
        .buttonStyle(.plain)
        .coachMarkAnchor("proChatFab")
        .accessibilityLabel(L10n.Chat.title)
    }

    // MARK: - Transaction FAB

    private func transactionFAB(background: Color) -> some View {
        Button {
            DS.Haptic.medium()
            toggleMenu()
        } label: {
            Image(systemName: showFABMenu ? "xmark" : "plus")
                .font(DS.Typography.title)
                .foregroundStyle(Color.contrastingText(for: theme.accent))
                .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                .background(showFABMenu ? DS.Semantic.disabledForeground : background)
                .clipShape(Circle())
                .rotationEffect(.degrees(showFABMenu ? 90 : 0))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive())
        .dsFloatingShadow()
        .accessibilityLabel(showFABMenu ? L10n.Accessibility.closeMenu : L10n.Accessibility.newRecord)
        .accessibilityIdentifier("fab_new_transaction")
        .coachMarkAnchor("fab")
    }

    // MARK: - Menu Buttons

    private var menuButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            fabMenuButton(icon: "waveform", text: L10n.Panel.fabVoice, color: .hotPink, isLocked: isVoiceLocked) {
                dismissMenu()
                if isVoiceLocked {
                    onUpgradeVoice()
                } else if !aiDataConsentAccepted {
                    pendingAIInput = .voice
                    showAIConsentAlert = true
                } else {
                    onVoiceTap()
                }
            }

            fabMenuButton(icon: "photo", text: L10n.Panel.fabImage, color: .teal, isLocked: isImageLocked) {
                dismissMenu()
                if isImageLocked {
                    onUpgradeImage()
                } else if !aiDataConsentAccepted {
                    pendingAIInput = .image
                    showAIConsentAlert = true
                } else {
                    onImageTap()
                }
            }

            fabMenuButton(icon: "square.and.pencil", text: L10n.Panel.fabManual, color: .electricIndigo) {
                dismissMenu()
                onManualTap()
            }
        }
        .transition(Self.fabScaleTransition)
    }

    // MARK: - Disabled FAB

    private func disabledFAB(background: Color) -> some View {
        Button {} label: {
            Image(systemName: "plus")
                .font(DS.Typography.title)
                .foregroundStyle(Color.contrastingText(for: theme.accent))
                .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                .background(background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive())
        .dsFloatingShadow()
        .coachMarkAnchor("fab")
        .padding(.trailing, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xxl)
        .disabled(true)
        .accessibilityLabel(L10n.Accessibility.newRecord)
        .accessibilityHint(L10n.Accessibility.createAccountFirst)
    }

    // MARK: - FAB Menu Button

    private func fabMenuButton(
        icon: String,
        text: String,
        color: Color,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.headline)
                    .frame(width: DS.Button.fabMenuIconSize)
                    .accessibilityHidden(true)

                Text(text)
                    .font(DS.Typography.headline)

                Spacer(minLength: 0)

                if isLocked {
                    ProBadge(size: .small)
                }
            }
            .foregroundStyle(.white)
            .frame(width: DS.Button.fabMenuWidth)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(isLocked ? DS.Semantic.disabledForeground : color)
            .clipShape(Capsule())
            .shadow(color: (isLocked ? DS.Semantic.disabledForeground : color).opacity(0.3), radius: DS.Shadow.medium.radius, x: 0, y: DS.Shadow.medium.y)
        }
        .buttonStyle(.plain)
        .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, phase in
            content.scaleEffect(phase ? 1.03 : 1.0)
        } animation: { _ in
            .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        }
    }
}
