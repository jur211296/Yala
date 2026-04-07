//
//  UserSegmentServiceTests.swift
//  YalaTests
//
//  Tests for UserSegment.classify() — pure logic, no SwiftData.
//

import Foundation
import Testing

@testable import Yala

struct UserSegmentServiceTests {

    // MARK: - Invited (groupInvite always wins)

    @Test func classify_groupInvite_alwaysInvited() {
        let result = UserSegment.classify(
            onboardingMode: .groupInvite,
            totalTransactions: 200,
            avgDaysBetweenSessions: 1,
            usesAdvancedFeatures: true
        )
        #expect(result == .invited)
    }

    @Test func classify_groupInvite_zeroTransactions() {
        let result = UserSegment.classify(
            onboardingMode: .groupInvite,
            totalTransactions: 0,
            avgDaysBetweenSessions: 0,
            usesAdvancedFeatures: false
        )
        #expect(result == .invited)
    }

    // MARK: - Dormant (<5 tx)

    @Test func classify_dormant_zeroTransactions() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 0,
            avgDaysBetweenSessions: 0,
            usesAdvancedFeatures: false
        )
        #expect(result == .dormant)
    }

    @Test func classify_dormant_fourTransactions() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 4,
            avgDaysBetweenSessions: 3,
            usesAdvancedFeatures: false
        )
        #expect(result == .dormant)
    }

    @Test func classify_dormant_completedMode() {
        let result = UserSegment.classify(
            onboardingMode: .completed,
            totalTransactions: 2,
            avgDaysBetweenSessions: 10,
            usesAdvancedFeatures: false
        )
        #expect(result == .dormant)
    }

    // MARK: - Sporadic (5-30 tx or irregular)

    @Test func classify_sporadic_fiveTransactions() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 5,
            avgDaysBetweenSessions: 10,
            usesAdvancedFeatures: false
        )
        #expect(result == .sporadic)
    }

    @Test func classify_sporadic_thirtyTransactions_irregularSessions() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 30,
            avgDaysBetweenSessions: 8,
            usesAdvancedFeatures: false
        )
        #expect(result == .sporadic)
    }

    @Test func classify_sporadic_twentyTransactions_regularSessions() {
        let result = UserSegment.classify(
            onboardingMode: .completed,
            totalTransactions: 20,
            avgDaysBetweenSessions: 3,
            usesAdvancedFeatures: false
        )
        #expect(result == .sporadic)
    }

    // MARK: - Active (>30 tx, avg <=7 days)

    @Test func classify_active_thirtyOneTransactions_regularSessions() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 31,
            avgDaysBetweenSessions: 5,
            usesAdvancedFeatures: false
        )
        #expect(result == .active)
    }

    @Test func classify_active_hundredTransactions_noAdvancedFeatures() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 100,
            avgDaysBetweenSessions: 2,
            usesAdvancedFeatures: false
        )
        #expect(result == .active)
    }

    @Test func classify_active_boundarySevenDays() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 50,
            avgDaysBetweenSessions: 7,
            usesAdvancedFeatures: false
        )
        #expect(result == .active)
    }

    // MARK: - Power User (>100 tx + advanced features)

    @Test func classify_powerUser_manyTransactions_advancedFeatures() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 101,
            avgDaysBetweenSessions: 2,
            usesAdvancedFeatures: true
        )
        #expect(result == .powerUser)
    }

    @Test func classify_powerUser_completedMode() {
        let result = UserSegment.classify(
            onboardingMode: .completed,
            totalTransactions: 150,
            avgDaysBetweenSessions: 1,
            usesAdvancedFeatures: true
        )
        #expect(result == .powerUser)
    }

    @Test func classify_notPowerUser_advancedButFewTransactions() {
        // Advanced features but only 50 tx → active (not power)
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 50,
            avgDaysBetweenSessions: 2,
            usesAdvancedFeatures: true
        )
        #expect(result == .active)
    }

    @Test func classify_notPowerUser_manyTransactionsNoAdvanced() {
        // 101 tx but no advanced features → active (not power)
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 101,
            avgDaysBetweenSessions: 3,
            usesAdvancedFeatures: false
        )
        #expect(result == .active)
    }

    // MARK: - Boundary Cases

    @Test func classify_sporadic_exactlyFiveTransactions_highGap() {
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 5,
            avgDaysBetweenSessions: 30,
            usesAdvancedFeatures: false
        )
        #expect(result == .sporadic)
    }

    @Test func classify_active_irregularSessions_manyTransactions() {
        // >30 tx but avg >7 days → sporadic
        let result = UserSegment.classify(
            onboardingMode: .full,
            totalTransactions: 50,
            avgDaysBetweenSessions: 8,
            usesAdvancedFeatures: false
        )
        #expect(result == .sporadic)
    }
}
