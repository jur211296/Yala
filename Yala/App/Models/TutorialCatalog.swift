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

    var steps: [TutorialStep] {
        switch self {
        case .createAccount:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.createAccountStep0Title, L10n.Tutorials.createAccountStep0Desc),
                (L10n.Tutorials.createAccountStep1Title, L10n.Tutorials.createAccountStep1Desc),
                (L10n.Tutorials.createAccountStep2Title, L10n.Tutorials.createAccountStep2Desc),
            ])
        case .createCategories:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.createCategoriesStep0Title, L10n.Tutorials.createCategoriesStep0Desc),
                (L10n.Tutorials.createCategoriesStep1Title, L10n.Tutorials.createCategoriesStep1Desc),
                (L10n.Tutorials.createCategoriesStep2Title, L10n.Tutorials.createCategoriesStep2Desc),
            ])
        case .createTags:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.createTagsStep0Title, L10n.Tutorials.createTagsStep0Desc),
                (L10n.Tutorials.createTagsStep1Title, L10n.Tutorials.createTagsStep1Desc),
                (L10n.Tutorials.createTagsStep2Title, L10n.Tutorials.createTagsStep2Desc),
            ])
        case .createRecord:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.createRecordStep0Title, L10n.Tutorials.createRecordStep0Desc),
                (L10n.Tutorials.createRecordStep1Title, L10n.Tutorials.createRecordStep1Desc),
                (L10n.Tutorials.createRecordStep2Title, L10n.Tutorials.createRecordStep2Desc),
            ])
        case .importData:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.importDataStep0Title, L10n.Tutorials.importDataStep0Desc),
                (L10n.Tutorials.importDataStep1Title, L10n.Tutorials.importDataStep1Desc),
                (L10n.Tutorials.importDataStep2Title, L10n.Tutorials.importDataStep2Desc),
            ])
        case .createBudgets:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.createBudgetsStep0Title, L10n.Tutorials.createBudgetsStep0Desc),
                (L10n.Tutorials.createBudgetsStep1Title, L10n.Tutorials.createBudgetsStep1Desc),
                (L10n.Tutorials.createBudgetsStep2Title, L10n.Tutorials.createBudgetsStep2Desc),
            ])
        case .createScheduledPayments:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.createScheduledPaymentsStep0Title, L10n.Tutorials.createScheduledPaymentsStep0Desc),
                (L10n.Tutorials.createScheduledPaymentsStep1Title, L10n.Tutorials.createScheduledPaymentsStep1Desc),
                (L10n.Tutorials.createScheduledPaymentsStep2Title, L10n.Tutorials.createScheduledPaymentsStep2Desc),
            ])
        case .createFavorites:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.createFavoritesStep0Title, L10n.Tutorials.createFavoritesStep0Desc),
                (L10n.Tutorials.createFavoritesStep1Title, L10n.Tutorials.createFavoritesStep1Desc),
                (L10n.Tutorials.createFavoritesStep2Title, L10n.Tutorials.createFavoritesStep2Desc),
            ])
        case .editPanel:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.editPanelStep0Title, L10n.Tutorials.editPanelStep0Desc),
                (L10n.Tutorials.editPanelStep1Title, L10n.Tutorials.editPanelStep1Desc),
                (L10n.Tutorials.editPanelStep2Title, L10n.Tutorials.editPanelStep2Desc),
            ])
        case .panelFiltering:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.panelFilteringStep0Title, L10n.Tutorials.panelFilteringStep0Desc),
                (L10n.Tutorials.panelFilteringStep1Title, L10n.Tutorials.panelFilteringStep1Desc),
                (L10n.Tutorials.panelFilteringStep2Title, L10n.Tutorials.panelFilteringStep2Desc),
            ])
        case .inboxApproval:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.inboxApprovalStep0Title, L10n.Tutorials.inboxApprovalStep0Desc),
                (L10n.Tutorials.inboxApprovalStep1Title, L10n.Tutorials.inboxApprovalStep1Desc),
                (L10n.Tutorials.inboxApprovalStep2Title, L10n.Tutorials.inboxApprovalStep2Desc),
            ])
        case .applePay:
            return TutorialStep.make(tutorial: self, items: [
                (L10n.Tutorials.applePayStep0Title, L10n.Tutorials.applePayStep0Desc),
                (L10n.Tutorials.applePayStep1Title, L10n.Tutorials.applePayStep1Desc),
                (L10n.Tutorials.applePayStep2Title, L10n.Tutorials.applePayStep2Desc),
            ])
        }
    }
}

// MARK: - Tutorial Step

struct TutorialStep: Identifiable {
    let id: Int
    let title: String
    let description: String
    let videoURL: URL?
    let screenshotName: String?

    static func make(tutorial: Tutorial, items: [(String, String)]) -> [TutorialStep] {
        items.enumerated().map { index, item in
            let baseName = "tutorial-\(tutorial.rawValue)-step\(index)"
            let videoURL = Bundle.main.url(forResource: baseName, withExtension: "mp4")
            let hasScreenshot = videoURL == nil && UIImage(named: baseName) != nil
            return TutorialStep(
                id: index,
                title: item.0,
                description: item.1,
                videoURL: videoURL,
                screenshotName: hasScreenshot ? baseName : nil
            )
        }
    }
}
