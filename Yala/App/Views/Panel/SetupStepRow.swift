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
    /// Cualquier paso pendiente o saltado se puede tocar (UX 2.2 · L5-1): ya no hay candados.
    var onTap: (() -> Void)?

    // MARK: - Indicator

    // A11Y-DT: SF Symbol icon sizing — fixed size for checklist indicator alignment
    @ViewBuilder
    private var indicatorImage: some View {
        if step.isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(DS.Semantic.successForeground)
        } else if step.isSkipped {
            // Saltado con «Ahora no»: sin ✓, en gris (UX 2.2 · L5-2).
            Image(systemName: "minus.circle")
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

    private var isDimmed: Bool { step.isCompleted || step.isSkipped }

    // MARK: - Body

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                // Completion indicator
                indicatorImage

                // Step icon
                Image(systemName: step.icon)
                    .font(.system(size: 14)) // A11Y-DT: SF Symbol icon sizing for step icon
                    .foregroundStyle(isDimmed ? ThemeColor.thSecondaryText : ThemeColor.thPrimaryText)
                    .frame(width: 20)

                // Step title
                Text(step.id.localizedTitle)
                    .font(isCurrent ? DS.Typography.label : DS.Typography.caption)
                    .foregroundStyle(isDimmed ? ThemeColor.thSecondaryText : ThemeColor.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: DS.Spacing.xs)

                if step.isSkipped {
                    Text(L10n.SetupChecklist.tryAgain)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.thAccent)
                } else if !step.isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold)) // A11Y-DT: SF Symbol icon sizing for chevron
                        .foregroundStyle(isCurrent ? AnyShapeStyle(.thAccent) : AnyShapeStyle(.thSecondaryText))
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(step.isCompleted || onTap == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(step.id.localizedTitle)
        .accessibilityHint(
            step.isCompleted ? L10n.SetupChecklist.stepCompleted
                : step.isSkipped ? L10n.SetupChecklist.stepSkipped
                : L10n.SetupChecklist.stepTapToStart
        )
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
        case .discoverFeatures:
            L10n.SetupChecklist.Step.discoverFeatures(
                Self.discoverTitle(
                    isProUser: FeatureGateService.shared.isProUser,
                    trialEligible: StoreKitManager.shared.isIntroOfferEligible
                )
            )
        }
    }

    /// Cómo se llama el último paso (UX 2.2 · L5-3, opción A): por lo que abre. Antes decía «Descubre qué más puede
    /// hacer Yala» y abría una oferta con precios. Quien ya usó la prueba no la vuelve a tener (lote 17 · B4), así que
    /// a esa persona no se le promete «gratis».
    enum DiscoverTitle: Equatable {
        case freeTrial
        case knowPro
        case alreadyPro
    }

    static func discoverTitle(isProUser: Bool, trialEligible: Bool) -> DiscoverTitle {
        if isProUser { return .alreadyPro }
        return trialEligible ? .freeTrial : .knowPro
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
            static func discoverFeatures(_ title: SetupStepID.DiscoverTitle) -> String {
                switch title {
                case .freeTrial:
                    NSLocalizedString("setup.step5.title.trial", comment: "Last setup step: free Pro trial (30 days)")
                case .knowPro:
                    NSLocalizedString("setup.step5.title.knowPro", comment: "Last setup step: see Yala Pro (trial already used)")
                case .alreadyPro:
                    NSLocalizedString("setup.step5.title.alreadyPro", comment: "Last setup step for a Pro user")
                }
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
