//
//  SetupStepRow.swift
//  Yala
//
//  Individual step row in the setup checklist card.
//

import SwiftUI

struct SetupStepRow: View {

    // MARK: - Properties

    let step: SetupStep
    let isCurrent: Bool

    // MARK: - Indicator

    // A11Y-DT: SF Symbol icon sizing — fixed size for checklist indicator alignment
    @ViewBuilder
    private var indicatorImage: some View {
        if step.isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(DS.Semantic.successForeground)
        } else if step.isLocked {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.thSecondaryText)
        } else if isCurrent {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.thAccent)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(.thSecondaryText)
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Completion indicator
            indicatorImage

            // Step icon
            Image(systemName: step.icon)
                .font(.system(size: 14)) // A11Y-DT: SF Symbol icon sizing for step icon
                .foregroundStyle((step.isCompleted || step.isLocked) ? ThemeColor.thSecondaryText : ThemeColor.thPrimaryText)
                .frame(width: 20)

            // Step title
            Text(step.id.localizedTitle)
                .font(isCurrent ? DS.Typography.label : DS.Typography.caption)
                .foregroundStyle((step.isCompleted || step.isLocked) ? ThemeColor.thSecondaryText : ThemeColor.thPrimaryText)

            Spacer()

            if isCurrent {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)) // A11Y-DT: SF Symbol icon sizing for chevron
                    .foregroundStyle(.thAccent)
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(step.id.localizedTitle)
        .accessibilityHint(step.isCompleted ? L10n.SetupChecklist.stepCompleted : step.isLocked ? L10n.SetupChecklist.stepLocked : L10n.SetupChecklist.stepTapToStart)
    }
}

// MARK: - SetupStepID L10n

extension SetupStepID {
    var localizedTitle: String {
        switch self {
        case .exploreSettings: L10n.SetupChecklist.Step.exploreSettings
        case .firstExpense: L10n.SetupChecklist.Step.firstExpense
        case .firstBudget: L10n.SetupChecklist.Step.firstBudget
        case .scheduledPayment: L10n.SetupChecklist.Step.scheduledPayment
        case .tryVoiceInput: L10n.SetupChecklist.Step.tryVoiceInput
        case .tryImageInput: L10n.SetupChecklist.Step.tryImageInput
        case .discoverFeatures: L10n.SetupChecklist.Step.discoverFeatures
        }
    }
}

// MARK: - L10n Extension

extension L10n {
    enum SetupChecklist {
        static var title: String {
            NSLocalizedString("setup.title", comment: "Setup checklist title")
        }
        static var subtitle: String {
            NSLocalizedString("setup.subtitle", comment: "Setup checklist subtitle")
        }
        static func progress(_ completed: Int, _ total: Int) -> String {
            String(format: NSLocalizedString("setup.progress", comment: "Setup progress"), completed, total)
        }
        static var collapse: String {
            NSLocalizedString("setup.collapse", comment: "Collapse checklist")
        }
        static var continueSetup: String {
            NSLocalizedString("setup.continue", comment: "Continue setup")
        }
        static var completeTitle: String {
            NSLocalizedString("setup.complete.title", comment: "Setup complete title")
        }
        static var completeSubtitle: String {
            NSLocalizedString("setup.complete.subtitle", comment: "Setup complete subtitle")
        }
        static var stepCompleted: String {
            NSLocalizedString("setup.step.completed", comment: "Accessibility: step completed")
        }
        static var stepTapToStart: String {
            NSLocalizedString("setup.step.tapToStart", comment: "Accessibility: tap to start step")
        }
        static var stepLocked: String {
            NSLocalizedString("setup.step.locked", comment: "Accessibility: step is locked")
        }
        static func nextStep(_ stepTitle: String) -> String {
            String(format: NSLocalizedString("setup.nextStep", comment: "Accessibility: next step to complete"), stepTitle)
        }

        // Practice cleanup
        static func practiceTitle(_ itemName: String) -> String {
            String(format: NSLocalizedString("setup.practice.title", comment: "Practice cleanup title"), itemName)
        }
        static var practiceMessage: String {
            NSLocalizedString("setup.practice.message", comment: "Practice cleanup message")
        }
        static var practiceKeep: String {
            NSLocalizedString("setup.practice.keep", comment: "Keep created item")
        }
        static var practiceDelete: String {
            NSLocalizedString("setup.practice.delete", comment: "Delete practice item")
        }

        enum PracticeType {
            static var expense: String {
                NSLocalizedString("setup.practice.type.expense", comment: "Expense type")
            }
            static var budget: String {
                NSLocalizedString("setup.practice.type.budget", comment: "Budget type")
            }
            static var scheduled: String {
                NSLocalizedString("setup.practice.type.scheduled", comment: "Scheduled type")
            }
            static var voiceTrial: String {
                NSLocalizedString("setup.practice.type.voiceTrial", comment: "Voice trial type")
            }
            static var imageTrial: String {
                NSLocalizedString("setup.practice.type.imageTrial", comment: "Image trial type")
            }
        }

        // Step titles
        enum Step {
            static var exploreSettings: String {
                NSLocalizedString("setup.step1.title", comment: "Step 1 title")
            }
            static var firstExpense: String {
                NSLocalizedString("setup.step2.title", comment: "Step 2 title")
            }
            static var firstBudget: String {
                NSLocalizedString("setup.step3.title", comment: "Step 3 title")
            }
            static var scheduledPayment: String {
                NSLocalizedString("setup.step4.title", comment: "Step 4 title")
            }
            static var tryVoiceInput: String {
                NSLocalizedString("setup.step6.title", comment: "Step 6 title")
            }
            static var tryImageInput: String {
                NSLocalizedString("setup.step7.title", comment: "Step 7 title")
            }
            static var discoverFeatures: String {
                NSLocalizedString("setup.step5.title", comment: "Step 5 title")
            }
        }

        // Skip step
        static var skipStep: String {
            NSLocalizedString("setup.skipStep", comment: "Skip setup step")
        }

        // Image trial
        enum ImageTrial {
            static var pickExample: String {
                NSLocalizedString("setup.imageTrial.pickExample", comment: "Pick example image")
            }
            static var orPickOwn: String {
                NSLocalizedString("setup.imageTrial.orPickOwn", comment: "Or pick your own")
            }
            static var exampleReceipt: String {
                NSLocalizedString("setup.imageTrial.exampleReceipt", comment: "Receipt example")
            }
            static var exampleBankAlert: String {
                NSLocalizedString("setup.imageTrial.exampleBank", comment: "Bank alert example")
            }
            static var exampleTransactionList: String {
                NSLocalizedString("setup.imageTrial.exampleList", comment: "Transaction list example")
            }
            static var useThisImage: String {
                NSLocalizedString("setup.imageTrial.useThisImage", comment: "Use this example image")
            }
        }

        // Demo (vista previa interactiva)
        enum Demo {
            static var bannerLabel: String {
                NSLocalizedString("setup.demo.bannerLabel", comment: "Vista previa")
            }
            static var cta: String {
                NSLocalizedString("setup.demo.cta", comment: "Toca para empezar")
            }
            static var ctaA11yHint: String {
                NSLocalizedString("setup.demo.ctaA11yHint", comment: "Abre la pantalla real para crear")
            }
            static var proTrialBadge: String {
                NSLocalizedString("setup.demo.proTrialBadge", comment: "Pro · Gratis durante setup")
            }
            static var proBadge: String {
                NSLocalizedString("setup.demo.proBadge", comment: "Pro")
            }
            static var settingsTitle: String {
                NSLocalizedString("setup.demo.settings.title", comment: "Explora tus ajustes")
            }
            static var settingsCta: String {
                NSLocalizedString("setup.demo.settings.cta", comment: "Abrir Ajustes")
            }
            static var settingsCard1Title: String {
                NSLocalizedString("setup.demo.settings.card1Title", comment: "Cuentas y categorías")
            }
            static var settingsCard1Caption: String {
                NSLocalizedString("setup.demo.settings.card1Caption", comment: "Organiza dónde y en qué")
            }
            static var settingsCard2Title: String {
                NSLocalizedString("setup.demo.settings.card2Title", comment: "Temas y personalización")
            }
            static var settingsCard2Caption: String {
                NSLocalizedString("setup.demo.settings.card2Caption", comment: "9 temas para tu estilo")
            }
            static var settingsCard3Title: String {
                NSLocalizedString("setup.demo.settings.card3Title", comment: "Notificaciones")
            }
            static var settingsCard3Caption: String {
                NSLocalizedString("setup.demo.settings.card3Caption", comment: "Tú decides cuándo")
            }
            static var settingsCard4Title: String {
                NSLocalizedString("setup.demo.settings.card4Title", comment: "Biometría e iCloud")
            }
            static var settingsCard4Caption: String {
                NSLocalizedString("setup.demo.settings.card4Caption", comment: "Tus datos, seguros")
            }
            static var settingsCard5Title: String {
                NSLocalizedString("setup.demo.settings.card5Title", comment: "Privacidad IA")
            }
            static var settingsCard5Caption: String {
                NSLocalizedString("setup.demo.settings.card5Caption", comment: "Tú controlas qué procesa")
            }
            static var budgetNameExample: String {
                NSLocalizedString("setup.demo.budget.nameExample", comment: "Comida")
            }
            static var budgetAlertCaption: String {
                NSLocalizedString("setup.demo.budget.alertCaption", comment: "Te avisamos al 80%")
            }
            static var scheduledNameExample: String {
                NSLocalizedString("setup.demo.scheduled.nameExample", comment: "Netflix")
            }
            static var scheduledNotifCaption: String {
                NSLocalizedString("setup.demo.scheduled.notifCaption", comment: "Te avisamos 3 días antes")
            }
        }
    }
}
