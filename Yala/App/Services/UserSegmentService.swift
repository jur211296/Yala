//
//  UserSegmentService.swift
//  Yala
//
//  Recalculates user segment on each session (app launch / became active).
//  Uses pure UserSegment.classify() — this service provides the SwiftData integration.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class UserSegmentService {

    // MARK: - Singleton

    static let shared = UserSegmentService()

    // MARK: - State

    private(set) var currentSegment: UserSegment = .active
    private var modelContext: ModelContext?

    /// Gate critical decisions on this flag to avoid reading a stale segment
    /// during cold start before CloudKit's first import completes.
    private(set) var hasRecalculatedAfterFirstImport = false

    private var firstImportObserver: NSObjectProtocol?

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
        registerFirstImportObserver()
    }

    private func registerFirstImportObserver() {
        if let firstImportObserver {
            NotificationCenter.default.removeObserver(firstImportObserver)
        }
        firstImportObserver = NotificationCenter.default.addObserver(
            forName: .iCloudFirstImportCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.markRecalculatedAfterFirstImport()
            }
        }
        // Cold-start race: CloudKit may have completed the first import before
        // the observer was registered.
        if iCloudSyncService.shared.hasCompletedFirstImport {
            markRecalculatedAfterFirstImport()
        }
    }

    private func markRecalculatedAfterFirstImport() {
        guard !hasRecalculatedAfterFirstImport else { return }
        hasRecalculatedAfterFirstImport = true
        recalculate()
    }

    // MARK: - Recalculate

    /// Recalculate the user's segment based on current data.
    /// Call on app launch and when scene becomes active.
    func recalculate() {
        let onboardingMode = SessionState.shared.onboardingMode

        let totalTransactions = fetchTransactionCount()
        let avgDays = calculateAvgDaysBetweenSessions()
        let usesAdvanced = detectAdvancedFeatureUsage()

        currentSegment = UserSegment.classify(
            onboardingMode: onboardingMode,
            totalTransactions: totalTransactions,
            avgDaysBetweenSessions: avgDays,
            usesAdvancedFeatures: usesAdvanced
        )

        #if DEBUG
        let suffix = hasRecalculatedAfterFirstImport ? "" : " (pre-import)"
        print("UserSegmentService: segment=\(currentSegment.rawValue) (tx=\(totalTransactions), avgDays=\(avgDays), advanced=\(usesAdvanced))\(suffix)")
        #endif
    }

    // MARK: - Constants

    private static let sessionTimestampsKey = "sessionTimestamps"
    private static let minimumSessionGap: TimeInterval = 3600 // 1 hour
    private static let secondsPerDay: TimeInterval = 86400
    private static let maxSessionHistory = 10

    // MARK: - Data Collection

    private func fetchTransactionCount() -> Int {
        guard let context = modelContext else { return 0 }
        do {
            return try context.fetchCount(FetchDescriptor<TransactionItem>())
        } catch {
            #if DEBUG
            print("UserSegmentService: Error fetching transaction count: \(error)")
            #endif
            return 0
        }
    }

    private func calculateAvgDaysBetweenSessions() -> Double {
        let defaults = UserDefaults.standard
        let now = Date.now.timeIntervalSince1970

        // Track session timestamps (keep last 10)
        var sessions = defaults.array(forKey: Self.sessionTimestampsKey) as? [Double] ?? []

        if let last = sessions.last, now - last < Self.minimumSessionGap {
            // Update last timestamp instead of adding new
            sessions[sessions.count - 1] = now
        } else {
            sessions.append(now)
        }

        if sessions.count > Self.maxSessionHistory {
            sessions = Array(sessions.suffix(Self.maxSessionHistory))
        }
        defaults.set(sessions, forKey: Self.sessionTimestampsKey)

        // Calculate average gap
        guard sessions.count >= 2 else { return 0 }

        var totalGap: Double = 0
        for i in 1..<sessions.count {
            totalGap += sessions[i] - sessions[i - 1]
        }
        let avgSeconds = totalGap / Double(sessions.count - 1)
        return avgSeconds / Self.secondsPerDay
    }

    private func detectAdvancedFeatureUsage() -> Bool {
        guard let context = modelContext else { return false }

        // Check budgets
        let budgetCount: Int
        do {
            budgetCount = try context.fetchCount(FetchDescriptor<Budget>())
        } catch {
            #if DEBUG
            print("UserSegmentService: Error fetching budget count: \(error)")
            #endif
            budgetCount = 0
        }
        if budgetCount > 0 { return true }

        // Check if AI insights consent was given
        if SessionDefaults.current.bool(forKey: "aiInsightsConsentAccepted") { return true }

        // Check if export was used
        if SessionDefaults.current.bool(forKey: "hasExportedData") { return true }

        return false
    }

    // MARK: - Testing Hooks

    #if DEBUG
    /// Reset state between tests. Not exposed in release.
    func _testReset() {
        if let firstImportObserver {
            NotificationCenter.default.removeObserver(firstImportObserver)
            self.firstImportObserver = nil
        }
        hasRecalculatedAfterFirstImport = false
        currentSegment = .active
        modelContext = nil
    }
    #endif
}
