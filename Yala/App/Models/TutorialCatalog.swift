//
//  TutorialCatalog.swift
//  Yala
//
//  Created by Yala.
//

import SwiftUI

// MARK: - Tutorial Category

enum TutorialCategory: String, CaseIterable, Identifiable {
    case gettingStarted
    case dailyUse
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gettingStarted: return L10n.Tutorials.categoryGettingStarted
        case .dailyUse: return L10n.Tutorials.categoryDailyUse
        case .advanced: return L10n.Tutorials.categoryAdvanced
        }
    }

    var tutorials: [Tutorial] {
        Tutorial.allCases.filter { $0.category == self }
    }
}

// MARK: - Tutorial

enum Tutorial: String, CaseIterable, Identifiable, Hashable {
    case createAccount
    case createCategories
    case createTags
    case createRecord
    case importData
    case createBudgets
    case createScheduledPayments
    case createFavorites
    case editPanel
    case panelFiltering
    case inboxApproval
    case applePay

    var id: String { rawValue }

    var category: TutorialCategory {
        switch self {
        case .createAccount, .createCategories, .createTags:
            return .gettingStarted
        case .createRecord, .importData, .createBudgets, .createScheduledPayments, .createFavorites:
            return .dailyUse
        case .editPanel, .panelFiltering, .inboxApproval, .applePay:
            return .advanced
        }
    }

    var title: String {
        switch self {
        case .createAccount: return L10n.Tutorials.createAccountTitle
        case .createCategories: return L10n.Tutorials.createCategoriesTitle
        case .createTags: return L10n.Tutorials.createTagsTitle
        case .createRecord: return L10n.Tutorials.createRecordTitle
        case .importData: return L10n.Tutorials.importDataTitle
        case .createBudgets: return L10n.Tutorials.createBudgetsTitle
        case .createScheduledPayments: return L10n.Tutorials.createScheduledPaymentsTitle
        case .createFavorites: return L10n.Tutorials.createFavoritesTitle
        case .editPanel: return L10n.Tutorials.editPanelTitle
        case .panelFiltering: return L10n.Tutorials.panelFilteringTitle
        case .inboxApproval: return L10n.Tutorials.inboxApprovalTitle
        case .applePay: return L10n.Tutorials.applePayTitle
        }
    }

    var icon: String {
        switch self {
        case .createAccount: return "banknote.fill"
        case .createCategories: return "folder.fill"
        case .createTags: return "tag.fill"
        case .createRecord: return "plus.circle.fill"
        case .importData: return "square.and.arrow.down.fill"
        case .createBudgets: return "chart.pie.fill"
        case .createScheduledPayments: return "calendar.badge.clock"
        case .createFavorites: return "star.fill"
        case .editPanel: return "rectangle.grid.2x2.fill"
        case .panelFiltering: return "line.3.horizontal.decrease"
        case .inboxApproval: return "tray.full.fill"
        case .applePay: return "apple.logo"
        }
    }

    var color: Color {
        switch self {
        case .createAccount: return .green
        case .createCategories: return .electricIndigo
        case .createTags: return .orange
        case .createRecord: return .hotPink
        case .importData: return .teal
        case .createBudgets: return .purple
        case .createScheduledPayments: return .blue
        case .createFavorites: return .yellow
        case .editPanel: return .electricIndigo
        case .panelFiltering: return .orange
        case .inboxApproval: return .teal
        case .applePay: return .black
        }
    }

    // MARK: - Intro

    var introTitle: String {
        switch self {
        case .createAccount: return L10n.Tutorials.createAccountIntroTitle
        case .createCategories: return L10n.Tutorials.createCategoriesIntroTitle
        case .createTags: return L10n.Tutorials.createTagsIntroTitle
        case .createRecord: return L10n.Tutorials.createRecordIntroTitle
        case .importData: return L10n.Tutorials.importDataIntroTitle
        case .createBudgets: return L10n.Tutorials.createBudgetsIntroTitle
        case .createScheduledPayments: return L10n.Tutorials.createScheduledPaymentsIntroTitle
        case .createFavorites: return L10n.Tutorials.createFavoritesIntroTitle
        case .editPanel: return L10n.Tutorials.editPanelIntroTitle
        case .panelFiltering: return L10n.Tutorials.panelFilteringIntroTitle
        case .inboxApproval: return L10n.Tutorials.inboxApprovalIntroTitle
        case .applePay: return L10n.Tutorials.applePayIntroTitle
        }
    }

    var introDescription: String {
        switch self {
        case .createAccount: return L10n.Tutorials.createAccountIntroDesc
        case .createCategories: return L10n.Tutorials.createCategoriesIntroDesc
        case .createTags: return L10n.Tutorials.createTagsIntroDesc
        case .createRecord: return L10n.Tutorials.createRecordIntroDesc
        case .importData: return L10n.Tutorials.importDataIntroDesc
        case .createBudgets: return L10n.Tutorials.createBudgetsIntroDesc
        case .createScheduledPayments: return L10n.Tutorials.createScheduledPaymentsIntroDesc
        case .createFavorites: return L10n.Tutorials.createFavoritesIntroDesc
        case .editPanel: return L10n.Tutorials.editPanelIntroDesc
        case .panelFiltering: return L10n.Tutorials.panelFilteringIntroDesc
        case .inboxApproval: return L10n.Tutorials.inboxApprovalIntroDesc
        case .applePay: return L10n.Tutorials.applePayIntroDesc
        }
    }

    // MARK: - Completion

    var completionTitle: String {
        switch self {
        case .createAccount: return L10n.Tutorials.createAccountCompletionTitle
        case .createCategories: return L10n.Tutorials.createCategoriesCompletionTitle
        case .createTags: return L10n.Tutorials.createTagsCompletionTitle
        case .createRecord: return L10n.Tutorials.createRecordCompletionTitle
        case .importData: return L10n.Tutorials.importDataCompletionTitle
        case .createBudgets: return L10n.Tutorials.createBudgetsCompletionTitle
        case .createScheduledPayments: return L10n.Tutorials.createScheduledPaymentsCompletionTitle
        case .createFavorites: return L10n.Tutorials.createFavoritesCompletionTitle
        case .editPanel: return L10n.Tutorials.editPanelCompletionTitle
        case .panelFiltering: return L10n.Tutorials.panelFilteringCompletionTitle
        case .inboxApproval: return L10n.Tutorials.inboxApprovalCompletionTitle
        case .applePay: return L10n.Tutorials.applePayCompletionTitle
        }
    }

    var completionDescription: String {
        switch self {
        case .createAccount: return L10n.Tutorials.createAccountCompletionDesc
        case .createCategories: return L10n.Tutorials.createCategoriesCompletionDesc
        case .createTags: return L10n.Tutorials.createTagsCompletionDesc
        case .createRecord: return L10n.Tutorials.createRecordCompletionDesc
        case .importData: return L10n.Tutorials.importDataCompletionDesc
        case .createBudgets: return L10n.Tutorials.createBudgetsCompletionDesc
        case .createScheduledPayments: return L10n.Tutorials.createScheduledPaymentsCompletionDesc
        case .createFavorites: return L10n.Tutorials.createFavoritesCompletionDesc
        case .editPanel: return L10n.Tutorials.editPanelCompletionDesc
        case .panelFiltering: return L10n.Tutorials.panelFilteringCompletionDesc
        case .inboxApproval: return L10n.Tutorials.inboxApprovalCompletionDesc
        case .applePay: return L10n.Tutorials.applePayCompletionDesc
        }
    }

    /// Next tutorial in the same category, if available
    var nextTutorial: Tutorial? {
        let siblings = category.tutorials
        guard let idx = siblings.firstIndex(of: self), idx + 1 < siblings.count else { return nil }
        return siblings[idx + 1]
    }

    // MARK: - Steps (aligned to real video counts)

    var steps: [TutorialStep] {
        switch self {
        case .createAccount:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.createAccountStep0Title,
                L10n.Tutorials.createAccountStep1Title,
                L10n.Tutorials.createAccountStep2Title,
            ])
        case .createCategories:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.createCategoriesStep0Title,
                L10n.Tutorials.createCategoriesStep1Title,
                L10n.Tutorials.createCategoriesStep2Title,
                L10n.Tutorials.createCategoriesStep3Title,
            ])
        case .createTags:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.createTagsStep0Title,
                L10n.Tutorials.createTagsStep1Title,
            ])
        case .createRecord:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.createRecordStep0Title,
                L10n.Tutorials.createRecordStep1Title,
                L10n.Tutorials.createRecordStep2Title,
                L10n.Tutorials.createRecordStep3Title,
            ])
        case .importData:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.importDataStep0Title,
                L10n.Tutorials.importDataStep1Title,
            ])
        case .createBudgets:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.createBudgetsStep0Title,
                L10n.Tutorials.createBudgetsStep1Title,
                L10n.Tutorials.createBudgetsStep2Title,
                L10n.Tutorials.createBudgetsStep3Title,
            ])
        case .createScheduledPayments:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.createScheduledPaymentsStep0Title,
                L10n.Tutorials.createScheduledPaymentsStep1Title,
                L10n.Tutorials.createScheduledPaymentsStep2Title,
                L10n.Tutorials.createScheduledPaymentsStep3Title,
                L10n.Tutorials.createScheduledPaymentsStep4Title,
            ])
        case .createFavorites:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.createFavoritesStep0Title,
                L10n.Tutorials.createFavoritesStep1Title,
            ])
        case .editPanel:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.editPanelStep0Title,
                L10n.Tutorials.editPanelStep1Title,
                L10n.Tutorials.editPanelStep2Title,
            ])
        case .panelFiltering:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.panelFilteringStep0Title,
                L10n.Tutorials.panelFilteringStep1Title,
                L10n.Tutorials.panelFilteringStep2Title,
                L10n.Tutorials.panelFilteringStep3Title,
                L10n.Tutorials.panelFilteringStep4Title,
            ])
        case .inboxApproval:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.inboxApprovalStep0Title,
                L10n.Tutorials.inboxApprovalStep1Title,
                L10n.Tutorials.inboxApprovalStep2Title,
                L10n.Tutorials.inboxApprovalStep3Title,
            ])
        case .applePay:
            return TutorialStep.make(tutorial: self, titles: [
                L10n.Tutorials.applePayStep0Title,
                L10n.Tutorials.applePayStep1Title,
                L10n.Tutorials.applePayStep2Title,
                L10n.Tutorials.applePayStep3Title,
            ])
        }
    }
}

// MARK: - Tutorial Step

struct TutorialStep: Identifiable {
    let id: Int
    let title: String
    let description: String?
    let videoURL: URL?
    let screenshotName: String?

    static func make(tutorial: Tutorial, titles: [String]) -> [TutorialStep] {
        titles.enumerated().map { index, title in
            let baseName = "tutorial-\(tutorial.rawValue)-step\(index)"
            let videoURL = Bundle.main.url(forResource: baseName, withExtension: "mp4")
            let hasScreenshot = videoURL == nil && UIImage(named: baseName) != nil
            return TutorialStep(
                id: index,
                title: title,
                description: nil,
                videoURL: videoURL,
                screenshotName: hasScreenshot ? baseName : nil
            )
        }
    }
}
