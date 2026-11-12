//
//  L10n+UXAudit22Lote19Decididas.swift
//  Yala
//
//  Textos del lote 19 de la auditoría UX 2.2 tal como lo decidió Jürgen el 18-oct (Grupos III: administrar,
//  archivar, eliminar, salir y desasociar). Van en su propio fichero para no pisar `L10n.swift` con los otros lotes.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func l19(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum UXL19 {

        // MARK: - L19-3 · El rol, con una sola palabra

        static var roleAdmin: String { l19("groups.l19.role.admin") }
        static var makeAdmin: String { l19("groups.l19.member.makeAdmin") }
        static var removeAdmin: String { l19("groups.l19.member.removeAdmin") }
        static func makeAdminTitle(_ name: String) -> String { String(format: l19("groups.l19.member.makeAdminTitle"), name) }
        static func makeAdminBody(_ name: String) -> String { String(format: l19("groups.l19.member.makeAdminBody"), name) }
        static func removeAdminTitle(_ name: String) -> String {
            String(format: l19("groups.l19.member.removeAdminTitle"), name)
        }
        static func removeAdminBody(_ name: String) -> String {
            String(format: l19("groups.l19.member.removeAdminBody"), name)
        }

        // MARK: - L19-4 · Quitar a alguien

        static var removeMember: String { l19("groups.l19.member.remove") }
        static func removeTitle(_ name: String) -> String { String(format: l19("groups.l19.member.removeTitle"), name) }
        static func removeBody(_ name: String) -> String { String(format: l19("groups.l19.member.removeBody"), name) }
        static func removeDebtTail(_ name: String) -> String {
            String(format: l19("groups.l19.member.removeDebtTail"), name)
        }
        static var settleFirst: String { l19("groups.l19.settleFirst") }

        // MARK: - L19-3 · Los rechazos del cambio de rol, con su texto

        static var errorCreatorStaysAdmin: String { l19("groups.l19.error.creatorStaysAdmin") }
        static var errorLastAdmin: String { l19("groups.l19.error.lastAdmin") }
        static var errorMemberNeedsAccount: String { l19("groups.l19.error.memberNeedsAccount") }

        // MARK: - Frases de deuda (L19-4, L19-10, L19-11)

        static func owesYou(_ name: String, _ amount: String) -> String {
            String(format: l19("groups.l19.debt.owesYou"), name, amount)
        }
        static func youOwe(_ name: String, _ amount: String) -> String {
            String(format: l19("groups.l19.debt.youOwe"), name, amount)
        }
        static func owesOther(_ from: String, _ amount: String, _ to: String) -> String {
            String(format: l19("groups.l19.debt.owesOther"), from, amount, to)
        }
        static func memberOwes(_ name: String, _ amount: String) -> String {
            String(format: l19("groups.l19.debt.memberOwes"), name, amount)
        }
        static func youOweNet(_ amount: String) -> String { String(format: l19("groups.l19.debt.youOweNet"), amount) }

        // MARK: - L19-11 · Salir o eliminar

        static func leaveDebtTailOne(_ name: String) -> String {
            String(format: l19("groups.l19.leave.debtTailOne"), name)
        }
        static var leaveDebtTailMany: String { l19("groups.l19.leave.debtTailMany") }
        static var deleteBody: String { l19("groups.l19.delete.body") }

        // MARK: - L19-5 · Archivar o eliminar

        static var exitsSectionBoth: String { l19("groups.l19.exits.sectionBoth") }
        static var exitsSectionArchive: String { l19("groups.l19.exits.sectionArchive") }
        static var archiveBody: String { l19("groups.l19.archive.body") }
        static var unarchiveBody: String { l19("groups.l19.unarchive.body") }
        static var deleteRowBody: String { l19("groups.l19.delete.rowBody") }
        static var deleteBlockedTail: String { l19("groups.l19.delete.blockedTail") }
        static var deleteTransferInstead: String { l19("groups.l19.delete.transferInstead") }
        static var deleteArchiveInstead: String { l19("groups.l19.delete.archiveInstead") }
        static var seeBalances: String { l19("groups.l19.seeBalances") }

        // MARK: - L19-8 · Archivar avisa y se deshace

        static var archivedNotice: String { l19("groups.l19.archived.notice") }
        static var undo: String { l19("groups.l19.undo") }

        // MARK: - L19-9 · Un grupo archivado lo dice

        static var archivedBannerTitle: String { l19("groups.l19.archived.bannerTitle") }
        static var archivedBannerMemberHint: String { l19("groups.l19.archived.bannerMemberHint") }
        static var unarchive: String { l19("groups.l19.archived.unarchive") }
        static func archivedOwedLine(_ amounts: String) -> String {
            String(format: l19("groups.l19.archived.owedLine"), amounts)
        }
        static func archivedOweLine(_ amounts: String) -> String {
            String(format: l19("groups.l19.archived.oweLine"), amounts)
        }

        // MARK: - L19-6 · El presupuesto en su hoja

        static var budgetQuestion: String { l19("groups.l19.budget.question") }
        static func budgetSpentSoFar(_ amount: String) -> String {
            String(format: l19("groups.l19.budget.spentSoFar"), amount)
        }
        static var budgetNoSpendingYet: String { l19("groups.l19.budget.noSpendingYet") }
        static func budgetWouldExceed(_ amount: String) -> String {
            String(format: l19("groups.l19.budget.wouldExceed"), amount)
        }
        static func budgetWouldRemain(_ amount: String) -> String {
            String(format: l19("groups.l19.budget.wouldRemain"), amount)
        }
        static var budgetSeenByAll: String { l19("groups.l19.budget.seenByAll") }
        static var budgetAlerts: String { l19("groups.l19.budget.alerts") }

        // MARK: - L19-7 · Opciones con ejemplo

        static var simplify: String { l19("groups.l19.options.simplify") }
        static var simplifyExample: String { l19("groups.l19.options.simplifyExample") }
        static var singleCurrency: String { l19("groups.l19.options.singleCurrency") }
        static var ownerOnly: String { l19("groups.l19.options.ownerOnly") }
        static var splitType: String { l19("groups.l19.options.splitType") }
        static var personalSection: String { l19("groups.l19.options.personalSection") }
        static var personalToggle: String { l19("groups.l19.options.personalToggle") }
        static var personalInherit: String { l19("groups.l19.options.personalInherit") }

        // MARK: - Miembros con su saldo

        static var owesYouShort: String { l19("groups.l19.member.owesYouShort") }
        static var youOweShort: String { l19("groups.l19.member.youOweShort") }

        // MARK: - L19-13 · Los grupos que no se pudieron dejar

        static var batchReasonCreator: String { l19("groups.l19.batch.reasonCreator") }
        static var batchOpenSettings: String { l19("groups.l19.batch.openSettings") }

        // MARK: - L19-14 · Desasociar la cuenta de grupos

        static var detachBody: String { l19("groups.l19.detach.body") }
        static var detachKeep: String { l19("groups.l19.detach.keep") }
        static var detachRemove: String { l19("groups.l19.detach.remove") }
        static func detachKeepCount(_ count: Int, _ amounts: String) -> String {
            String(format: l19("groups.l19.detach.keepCount"), count, amounts)
        }
        static var detachRemoveEffect: String { l19("groups.l19.detach.removeEffect") }
    }
}
