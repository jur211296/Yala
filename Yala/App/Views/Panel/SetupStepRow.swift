//
//  SetupStepRow.swift
//  Yala
//
//  Una fila de la lista «Primeros pasos» que abre «Ver los 7 pasos» (Y23-05): el número del paso (o ✓ si está hecho),
//  su nombre y una línea de qué es. No se toca: la lista enseña dónde va la persona; el paso se empieza en el mazo.
//

import SwiftUI

struct SetupStepRow: View {

    let step: SetupStep
    let position: Int
    let isCurrent: Bool

    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 30

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            badge

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(step.id.localizedTitle)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(step.isCompleted || step.isSkipped ? .thSecondaryText : .thPrimaryText)
                Text(step.id.localizedSubtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            step.isCompleted ? L10n.SetupChecklist.stepCompleted
                : step.isSkipped ? L10n.SetupChecklist.Deck.skippedValue
                : isCurrent ? L10n.SetupChecklist.Deck.currentValue
                : ""
        )
    }

    @ViewBuilder
    private var badge: some View {
        ZStack {
            Circle()
                .fill(step.isCompleted || isCurrent ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.thSecondaryText.opacity(DS.Opacity.subtle)))
            if step.isCompleted {
                Image(systemName: "checkmark")
                    .font(DS.Typography.labelSmall.bold())
                    .foregroundStyle(theme.onAccent)
            } else {
                Text(verbatim: "\(position)")
                    .font(DS.Typography.labelSmall.bold())
                    .foregroundStyle(isCurrent ? AnyShapeStyle(theme.onAccent) : AnyShapeStyle(.thSecondaryText))
            }
        }
        .frame(width: badgeSize, height: badgeSize)
        .accessibilityHidden(true)
    }
}

// MARK: - SetupStepID L10n

extension SetupStepID {
    var localizedTitle: String {
        switch self {
        case .firstAccount: L10n.SetupChecklist.Step.firstAccount
        case .firstExpense: L10n.SetupChecklist.Step.learnToRecord
        case .firstBudget: L10n.SetupChecklist.Step.firstBudgetDeck
        case .scheduledPayment: L10n.SetupChecklist.Step.fixedPayments
        case .groups: L10n.SetupChecklist.Step.groups
        case .whereMoneyGoes: L10n.SetupChecklist.Step.whereMoneyGoes
        case .homeScreen: L10n.SetupChecklist.Step.homeScreen
        case .tryVoiceInput: L10n.SetupChecklist.Step.tryVoiceInput
        case .tryImageInput: L10n.SetupChecklist.Step.tryImageInput
        }
    }

    /// La línea de qué es cada paso en la lista de los 7 (prototipo oficial v35).
    var localizedSubtitle: String {
        switch self {
        case .firstAccount: L10n.SetupChecklist.Step.firstAccountDetail
        case .firstExpense: L10n.SetupChecklist.Step.learnToRecordDetail
        case .firstBudget: L10n.SetupChecklist.Step.firstBudgetDetail
        case .scheduledPayment: L10n.SetupChecklist.Step.fixedPaymentsDetail
        case .groups: L10n.SetupChecklist.Step.groupsDetail
        case .whereMoneyGoes: L10n.SetupChecklist.Step.whereMoneyGoesDetail
        case .homeScreen: L10n.SetupChecklist.Step.homeScreenDetail
        case .tryVoiceInput, .tryImageInput: ""
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
        static var stepSkipped: String {
            NSLocalizedString("setup.step.skipped", comment: "Accessibility: step was skipped with Not now")
        }
        /// «Probar» en un paso saltado (UX 2.2 · L5-2).
        static var tryAgain: String {
            NSLocalizedString("setup.step.tryAgain", comment: "Try a skipped setup step")
        }
        /// Final de la lista con algún paso saltado (UX 2.2 · L5-2).
        static var basicsTitle: String {
            NSLocalizedString("setup.complete.basics.title", comment: "Setup finished with skipped steps")
        }
        static var basicsSubtitle: String {
            NSLocalizedString("setup.complete.basics.subtitle", comment: "Setup finished with skipped steps, subtitle")
        }
        /// Tarjeta «Primeros pasos» (UX 2.2 · L5-4).
        static var nextStepLabel: String {
            NSLocalizedString("setup.nextStepLabel", comment: "Label above the current setup step")
        }
        static var start: String {
            NSLocalizedString("setup.start", comment: "Start the current setup step")
        }
        static func showAllSteps(_ count: Int) -> String {
            String(format: NSLocalizedString("setup.showAllSteps", comment: "Show all N setup steps"), count)
        }
        static var hideAllSteps: String {
            NSLocalizedString("setup.hideAllSteps", comment: "Hide the setup steps list")
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
        // Step titles. Los siete del mazo (Y23-05) y las prácticas de voz y foto de dentro del paso 2.
        enum Step {
            static var firstAccount: String {
                NSLocalizedString("setup.deck.step.account", comment: "Getting started step 1: create your first account")
            }
            static var firstAccountDetail: String {
                NSLocalizedString("setup.deck.step.account.detail", comment: "Getting started step 1, one-line description")
            }
            static var learnToRecord: String {
                NSLocalizedString("setup.deck.step.record", comment: "Getting started step 2: learn to record")
            }
            static var learnToRecordDetail: String {
                NSLocalizedString("setup.deck.step.record.detail", comment: "Getting started step 2, one-line description")
            }
            static var firstBudgetDeck: String {
                NSLocalizedString("setup.deck.step.budget", comment: "Getting started step 3: create your first budget")
            }
            static var firstBudgetDetail: String {
                NSLocalizedString("setup.deck.step.budget.detail", comment: "Getting started step 3, one-line description")
            }
            static var fixedPayments: String {
                NSLocalizedString("setup.deck.step.payments", comment: "Getting started step 4: note your fixed payments")
            }
            static var fixedPaymentsDetail: String {
                NSLocalizedString("setup.deck.step.payments.detail", comment: "Getting started step 4, one-line description")
            }
            static var groups: String {
                NSLocalizedString("setup.deck.step.groups", comment: "Getting started step 5: split expenses with your group")
            }
            static var groupsDetail: String {
                NSLocalizedString("setup.deck.step.groups.detail", comment: "Getting started step 5, one-line description")
            }
            static var whereMoneyGoes: String {
                NSLocalizedString("setup.deck.step.money", comment: "Getting started step 6: see where your money goes")
            }
            static var whereMoneyGoesDetail: String {
                NSLocalizedString("setup.deck.step.money.detail", comment: "Getting started step 6, one-line description")
            }
            static var homeScreen: String {
                NSLocalizedString("setup.deck.step.home", comment: "Getting started step 7: Yala on your Home Screen")
            }
            static var homeScreenDetail: String {
                NSLocalizedString("setup.deck.step.home.detail", comment: "Getting started step 7, one-line description")
            }
            static var tryVoiceInput: String {
                NSLocalizedString("setup.step6.title", comment: "Step 6 title")
            }
            static var tryImageInput: String {
                NSLocalizedString("setup.step7.title", comment: "Step 7 title")
            }
        }

        /// El mazo de «Primeros pasos» (Y23-05).
        enum Deck {
            /// «Primeros pasos · 2 de 7».
            static func counter(_ position: Int, _ total: Int) -> String {
                String(format: NSLocalizedString("setup.deck.counter", comment: "Getting started deck: 'Getting started · 2 of 7'"), position, total)
            }
            /// «Después: …», el primero que asoma detrás.
            static func after(_ title: String) -> String {
                String(format: NSLocalizedString("setup.deck.after", comment: "Getting started deck: next step peeking behind, 'Next: …'"), title)
            }
            /// «Luego: …», el segundo que asoma detrás.
            static func then(_ title: String) -> String {
                String(format: NSLocalizedString("setup.deck.then", comment: "Getting started deck: step after next peeking behind, 'Then: …'"), title)
            }
            /// «Seguir donde iba»: cierra la lista de los 7.
            static var resume: String {
                NSLocalizedString("setup.deck.resume", comment: "Getting started list: close and go back to where I was")
            }
            /// «Solo gastos», en la llegada: la única acción.
            static var firstExpense: String {
                NSLocalizedString("setup.deck.firstExpense", comment: "Expenses-only arrival: note your first expense")
            }
            /// Debajo de «Anotar el primer gasto»: a qué cuenta van.
            static func firstExpenseNote(_ accountName: String) -> String {
                String(format: NSLocalizedString("setup.deck.firstExpense.note", comment: "Expenses-only arrival: your expenses go to «%@», which Yala creates on its own"), accountName)
            }
            /// VoiceOver: el paso que toca en la lista.
            static var currentValue: String {
                NSLocalizedString("setup.deck.currentValue", comment: "Accessibility: this is the current step")
            }
            /// VoiceOver: un paso omitido en la lista.
            static var skippedValue: String {
                NSLocalizedString("setup.deck.skippedValue", comment: "Accessibility: this step was skipped")
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
    }
}
