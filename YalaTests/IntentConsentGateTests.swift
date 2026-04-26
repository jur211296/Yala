//
//  IntentConsentGateTests.swift
//  YalaTests
//
//  Verifies that VoiceEntryIntent and ImageEntryIntent throw `consentRequired`
//  when the user has not accepted AI data consent.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct IntentConsentGateTests {

    private static let consentKey = AppPreferences.Keys.aiDataConsentAccepted

    private func resetConsent() {
        UserDefaults.standard.removeObject(forKey: Self.consentKey)
    }

    @Test func voiceEntryIntent_consentNotAccepted_throwsConsentRequired() async {
        resetConsent()
        UserDefaults.standard.set(false, forKey: Self.consentKey)

        do {
            _ = try await VoiceEntryIntent().perform()
            Issue.record("Expected throw")
        } catch let error as VoiceImageIntentError {
            #expect(error == .consentRequired)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        resetConsent()
    }

    @Test func imageEntryIntent_consentNotAccepted_throwsConsentRequired() async {
        resetConsent()
        UserDefaults.standard.set(false, forKey: Self.consentKey)

        do {
            _ = try await ImageEntryIntent().perform()
            Issue.record("Expected throw")
        } catch let error as VoiceImageIntentError {
            #expect(error == .consentRequired)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        resetConsent()
    }
}

extension VoiceImageIntentError: Equatable {
    public static func == (lhs: VoiceImageIntentError, rhs: VoiceImageIntentError) -> Bool {
        switch (lhs, rhs) {
        case (.consentRequired, .consentRequired): return true
        }
    }
}
