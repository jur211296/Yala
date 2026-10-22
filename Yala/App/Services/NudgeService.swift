//
//  NudgeService.swift
//  Yala
//
//  Frequency-capped nudge engine for converting invited/dormant/sporadic users.
//  Follows ProUpsellService pattern: UserDefaults persistence, singleton, @MainActor.
//

import Foundation
import SwiftData

@MainActor @Observable
final class NudgeService {

    // MARK: - Singleton

    static let shared = NudgeService()
    private init() {}

    // MARK: - State

    private(set) var currentNudge: NudgeType?
    private(set) var currentNudgeMessage: String?
    private var modelContext: ModelContext?
    private var shownThisSession = false
    private var evaluatedThisSession = false

    // MARK: - Constants

    private static let maxPerWeek = 1
    private static let maxPerMonth = 3

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lastShownDate = "nudge.lastShownDate"
        static let weeklyResetDate = "nudge.weeklyResetDate"
        static let weeklyShownCount = "nudge.weeklyShownCount"
        static let monthlyResetDate = "nudge.monthlyResetDate"
        static let monthlyShownCount = "nudge.monthlyShownCount"
        static let firstGroupJoinDate = "nudge.firstGroupJoinDate"

        static func interacted(_ nudge: NudgeType) -> String {
            "nudge.interacted.\(nudge.rawValue)"
        }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    // MARK: - Core Evaluation

    /// Evaluate which nudge (if any) to show. Call from view `.onAppear`.
    func evaluate() {
        guard !evaluatedThisSession else { return }
        guard canShowNudge(), let modelContext else { return }

        let segment = UserSegmentService.shared.currentSegment
        let candidates = NudgeType.nudges(for: segment)
        guard !candidates.isEmpty else {
            evaluatedThisSession = true
            return
        }

        let weeksSinceJoin = weeksSinceFirstGroupJoin()

        // Pre-filter by timing and interaction before expensive queries
        let eligible = candidates.filter { nudge in
            nudge.minimumWeek <= weeksSinceJoin && !isInteracted(nudge)
        }
        guard !eligible.isEmpty else {
            evaluatedThisSession = true
            return
        }

        let context = buildTriggerContext(modelContext: modelContext)

        for nudge in eligible {
            guard NudgeTriggerEvaluator.shouldShow(nudge, context: context) else { continue }

            currentNudge = nudge
            currentNudgeMessage = nudge.message(with: context)
            recordShown()
            return
        }

        evaluatedThisSession = true
    }

    // MARK: - Frequency Capping

    func canShowNudge() -> Bool {
        guard !shownThisSession else { return false }
        guard currentNudge == nil else { return false }

        resetWeeklyCountIfNeeded()
        resetMonthlyCountIfNeeded()

        let weekly = UserDefaults.standard.integer(forKey: Keys.weeklyShownCount)
        guard weekly < Self.maxPerWeek else { return false }

        let monthly = UserDefaults.standard.integer(forKey: Keys.monthlyShownCount)
        guard monthly < Self.maxPerMonth else { return false }

        return true
    }

    // MARK: - Recording

    private func recordShown() {
        shownThisSession = true
        evaluatedThisSession = true
        UserDefaults.standard.set(Date.now, forKey: Keys.lastShownDate)

        resetWeeklyCountIfNeeded()
        let weeklyCount = UserDefaults.standard.integer(forKey: Keys.weeklyShownCount) + 1
        UserDefaults.standard.set(weeklyCount, forKey: Keys.weeklyShownCount)

        resetMonthlyCountIfNeeded()
        let monthlyCount = UserDefaults.standard.integer(forKey: Keys.monthlyShownCount) + 1
        UserDefaults.standard.set(monthlyCount, forKey: Keys.monthlyShownCount)
    }

    func recordInteracted(_ nudge: NudgeType) {
        UserDefaults.standard.set(true, forKey: Keys.interacted(nudge))
        clearCurrentNudge()
    }

    /// Dismissed nudges can reappear next period (not permanently suppressed like interacted).
    func recordDismissed(_ nudge: NudgeType, autoDismissed: Bool = false) {
        clearCurrentNudge()
    }

    func clearCurrentNudge() {
        currentNudge = nil
        currentNudgeMessage = nil
        SessionState.shared.enteredViaGroupNotification = false
    }

    /// Record when user first joins a group (for timing gates).
    func recordGroupJoinIfNeeded() {
        guard UserDefaults.standard.object(forKey: Keys.firstGroupJoinDate) == nil else { return }
        UserDefaults.standard.set(Date.now, forKey: Keys.firstGroupJoinDate)
    }

    // MARK: - Testing Support

    func resetForTesting() {
        shownThisSession = false
        evaluatedThisSession = false
        currentNudge = nil
        currentNudgeMessage = nil
        modelContext = nil

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.lastShownDate)
        defaults.removeObject(forKey: Keys.weeklyResetDate)
        defaults.removeObject(forKey: Keys.weeklyShownCount)
        defaults.removeObject(forKey: Keys.monthlyResetDate)
        defaults.removeObject(forKey: Keys.monthlyShownCount)
        defaults.removeObject(forKey: Keys.firstGroupJoinDate)
        for nudge in NudgeType.allCases {
            defaults.removeObject(forKey: Keys.interacted(nudge))
        }
    }

    // MARK: - Private — Reset Logic

    private func resetWeeklyCountIfNeeded() {
        let calendar = Calendar.current
        if let resetDate = UserDefaults.standard.object(forKey: Keys.weeklyResetDate) as? Date {
            if !calendar.isDate(resetDate, equalTo: .now, toGranularity: .weekOfYear) {
                UserDefaults.standard.set(0, forKey: Keys.weeklyShownCount)
                UserDefaults.standard.set(Date.now, forKey: Keys.weeklyResetDate)
            }
        } else {
            UserDefaults.standard.set(Date.now, forKey: Keys.weeklyResetDate)
        }
    }

    private func resetMonthlyCountIfNeeded() {
        let calendar = Calendar.current
        if let resetDate = UserDefaults.standard.object(forKey: Keys.monthlyResetDate) as? Date {
            if !calendar.isDate(resetDate, equalTo: .now, toGranularity: .month) {
                UserDefaults.standard.set(0, forKey: Keys.monthlyShownCount)
                UserDefaults.standard.set(Date.now, forKey: Keys.monthlyResetDate)
                for nudge in NudgeType.allCases {
                    UserDefaults.standard.removeObject(forKey: Keys.interacted(nudge))
                }
            }
        } else {
            UserDefaults.standard.set(Date.now, forKey: Keys.monthlyResetDate)
        }
    }

    // MARK: - Private — Helpers

    private func isInteracted(_ nudge: NudgeType) -> Bool {
        UserDefaults.standard.bool(forKey: Keys.interacted(nudge))
    }

    private func weeksSinceFirstGroupJoin() -> Int {
        let joinDate: Date
        if let stored = UserDefaults.standard.object(forKey: Keys.firstGroupJoinDate) as? Date {
            joinDate = stored
        } else if let oldest = oldestGroupCreatedAt() {
            UserDefaults.standard.set(oldest, forKey: Keys.firstGroupJoinDate)
            joinDate = oldest
        } else {
            return 0
        }
        return Calendar.current.dateComponents([.weekOfYear], from: joinDate, to: .now).weekOfYear ?? 0
    }

    private func oldestGroupCreatedAt() -> Date? {
        guard let modelContext else { return nil }
        var descriptor = FetchDescriptor<SplitGroup>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first?.createdAt
        } catch {
            #if DEBUG
            print("NudgeService: Error fetching oldest group: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Private — Trigger Context

    private func buildTriggerContext(modelContext: ModelContext) -> NudgeTriggerContext {
        NudgeTriggerContext(
            totalSharedAmount: fetchTotalSharedAmount(modelContext),
            sharedExpenseCount: fetchCount(SplitExpense.self, modelContext),
            hasConfirmedSettlement: fetchHasConfirmedSettlement(modelContext),
            personalTransactionCount: fetchCount(TransactionItem.self, modelContext),
            groupMemberCount: fetchTotalMemberCount(modelContext),
            currentMonthSharedCount: fetchCurrentMonthSharedCount(modelContext),
            monthOverMonthVariation: fetchMonthOverMonthVariation(modelContext),
            enteredViaGroupNotification: SessionState.shared.enteredViaGroupNotification
        )
    }

    private func fetchCount<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) -> Int {
        do {
            return try context.fetchCount(FetchDescriptor<T>())
        } catch {
            #if DEBUG
            print("NudgeService: Error fetching count for \(T.self): \(error)")
            #endif
            return 0
        }
    }

    private func fetchTotalSharedAmount(_ context: ModelContext) -> Double {
        do {
            let expenses = try context.fetch(FetchDescriptor<SplitExpense>())
            return expenses.reduce(0.0) { $0 + $1.amount }
        } catch {
            #if DEBUG
            print("NudgeService: Error fetching shared amount: \(error)")
            #endif
            return 0
        }
    }

    private func fetchHasConfirmedSettlement(_ context: ModelContext) -> Bool {
        let predicate = #Predicate<SplitSettlement> { $0.isConfirmed == true }
        do {
            return try context.fetchCount(FetchDescriptor<SplitSettlement>(predicate: predicate)) > 0
        } catch {
            #if DEBUG
            print("NudgeService: Error fetching settlements: \(error)")
            #endif
            return false
        }
    }

    private func fetchTotalMemberCount(_ context: ModelContext) -> Int {
        do {
            return try context.fetchCount(FetchDescriptor<SplitMember>())
        } catch {
            #if DEBUG
            print("NudgeService: Error fetching member count: \(error)")
            #endif
            return 0
        }
    }

    private func fetchCurrentMonthSharedCount(_ context: ModelContext) -> Int {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let predicate = #Predicate<SplitExpense> { $0.date >= startOfMonth }
        do {
            return try context.fetchCount(FetchDescriptor<SplitExpense>(predicate: predicate))
        } catch {
            #if DEBUG
            print("NudgeService: Error fetching current month expenses: \(error)")
            #endif
            return 0
        }
    }

    private func fetchMonthOverMonthVariation(_ context: ModelContext) -> Double {
        let calendar = Calendar.current
        let now = Date.now
        guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) else {
            return 0
        }

        do {
            // Single fetch for both months, partition in memory
            let predicate = #Predicate<SplitExpense> { $0.date >= startOfLastMonth }
            let allRecent = try context.fetch(FetchDescriptor<SplitExpense>(predicate: predicate))
            let lastTotal = allRecent.filter { $0.date < startOfThisMonth }.reduce(0.0) { $0 + $1.amount }
            guard lastTotal > 0 else { return 0 }
            let thisTotal = allRecent.filter { $0.date >= startOfThisMonth }.reduce(0.0) { $0 + $1.amount }
            return abs(thisTotal - lastTotal) / lastTotal
        } catch {
            #if DEBUG
            print("NudgeService: Error calculating MoM variation: \(error)")
            #endif
            return 0
        }
    }
}
