//
//  GroupSplitChipFormatter.swift
//  Yala
//
//  Pure-logic formatter for the split-detail chip shown below the amount
//  in GroupExpenseFormView. Decides what to display ("Tu: X · Resto: Y",
//  "Pagaste todo", "No participaste", etc.) based on user position in the
//  split and the current state.
//
//  Receives `formatAmount` and `localizedSharesWord` as closures/strings
//  to stay decoupled from AppPreferences and L10n — fully unit-testable.
//

import Foundation

enum GroupSplitChipFormatter {

    struct Input {
        let total: Double
        let splitType: SplitType
        /// Calculated share per member (nil if inputs unbalanced for exact/percentage/shares).
        let calculatedShares: [(memberID: String, amount: Double)]?
        /// Raw user input per member (percentages 0-100, shares counts, exact amounts).
        let participantValues: [String: Double]
        let currentUserMemberID: String?
        let paidByMemberID: String
        let selectedMemberIDs: Set<String>
        /// Closure that formats a Double as a localized currency string (e.g. "S/ 50.00").
        let formatAmount: (Double) -> String
        /// Localized word for "parts" / "shares" used in the shares suffix (e.g. "partes").
        let localizedSharesWord: String
    }

    struct Output: Equatable {
        enum Mode: Equatable {
            /// total == 0 — render only `splitType.displayName` + chevron.
            case fallbackTypeName
            /// calculatedShares == nil (exact/percentage/shares not balanced).
            /// Render `splitType.displayName` + warning glyph + chevron.
            case warningUnbalanced
            /// Only current user is selected → "Tu parte: S/ X".
            case youOnly(yourAmount: String)
            /// Current user is payer but NOT in split → "Pagaste todo · Total: S/ X".
            case youPaidAll(total: String)
            /// Current user neither payer nor in split → "No participaste · Total: S/ X".
            case notIncluded(total: String)
            /// Standard 2+ member display: "Tu: S/ X (suffix?) · Resto: S/ Y (suffix?)".
            case youAndRest(you: Segment, rest: Segment)
        }

        struct Segment: Equatable {
            let amountString: String
            /// "(50%)" or "(1/3 partes)" for percentage/shares, nil for equal/exact.
            let suffix: String?
        }

        let mode: Mode
    }

    static func format(input: Input) -> Output {
        // 1. No amount yet → just show the type name.
        guard input.total > 0 else {
            return Output(mode: .fallbackTypeName)
        }

        let userInSplit: Bool = {
            guard let myID = input.currentUserMemberID else { return false }
            return input.selectedMemberIDs.contains(myID)
        }()
        let userIsPayer = input.currentUserMemberID != nil
            && input.currentUserMemberID == input.paidByMemberID
            && !input.paidByMemberID.isEmpty

        // 2. Current user NOT in split → distinct copy depending on whether they're paying.
        if !userInSplit {
            let totalStr = input.formatAmount(input.total)
            if userIsPayer {
                return Output(mode: .youPaidAll(total: totalStr))
            } else {
                return Output(mode: .notIncluded(total: totalStr))
            }
        }

        // 3. User in split but shares not balanced → warning fallback.
        guard let shares = input.calculatedShares else {
            return Output(mode: .warningUnbalanced)
        }

        // 4. Find user's share. Defensive fallback if missing.
        guard let myID = input.currentUserMemberID,
              let myShare = shares.first(where: { $0.memberID == myID })?.amount else {
            return Output(mode: .fallbackTypeName)
        }

        let myAmountStr = input.formatAmount(myShare)

        // 5. Only current user in split → simpler "Tu parte: X".
        if input.selectedMemberIDs.count == 1 {
            return Output(mode: .youOnly(yourAmount: myAmountStr))
        }

        // 6. 2+ members → "Tu" + "Resto" with optional suffix per type.
        let restAmount = input.total - myShare
        let restAmountStr = input.formatAmount(restAmount)

        let mySuffix: String?
        let restSuffix: String?

        switch input.splitType {
        case .equal, .exact:
            mySuffix = nil
            restSuffix = nil

        case .percentage:
            let myPct = input.participantValues[myID] ?? 0
            let restPct = max(0, 100 - myPct)
            mySuffix = "(\(formatPercent(myPct))%)"
            restSuffix = "(\(formatPercent(restPct))%)"

        case .shares:
            // Shares values are integer-like; cast to Int for display.
            let myShares = Int((input.participantValues[myID] ?? 1).rounded())
            let totalShares = Int(input.participantValues.values.reduce(0, +).rounded())
            let restShares = max(0, totalShares - myShares)
            mySuffix = "(\(myShares)/\(totalShares) \(input.localizedSharesWord))"
            restSuffix = "(\(restShares)/\(totalShares) \(input.localizedSharesWord))"
        }

        return Output(mode: .youAndRest(
            you: Output.Segment(amountString: myAmountStr, suffix: mySuffix),
            rest: Output.Segment(amountString: restAmountStr, suffix: restSuffix)
        ))
    }

    // MARK: - Helpers

    /// Formats a percentage with at most 1 decimal place, trimming trailing zeros
    /// (e.g. 50.0 → "50", 33.3 → "33.3").
    private static func formatPercent(_ pct: Double) -> String {
        if pct == pct.rounded() {
            return String(Int(pct))
        }
        return String(format: "%.1f", pct)
    }
}
