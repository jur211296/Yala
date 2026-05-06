//
//  InviteLinkServiceTests.swift
//  YalaTests
//
//  A4 — verifies alternate hosts (yala-pe.com etc.) accepted on paste manual,
//  foreign hosts rejected, custom schemes (yala/yaladev) work.
//

import Foundation
import Testing

@testable import Yala

struct InviteLinkServiceTests {

    // MARK: - isInviteLink

    @Test func isInviteLink_canonicalHost_returnsTrue() {
        let url = URL(string: "https://yala-app.pe/invite?s=ABC")!
        #expect(InviteLinkService.isInviteLink(url))
    }

    @Test func isInviteLink_wwwCanonicalHost_returnsTrue() {
        let url = URL(string: "https://www.yala-app.pe/invite?s=ABC")!
        #expect(InviteLinkService.isInviteLink(url))
    }

    @Test func isInviteLink_alternateHostYalaPeCom_returnsTrue() {
        let url = URL(string: "https://yala-pe.com/invite?s=ABC")!
        #expect(InviteLinkService.isInviteLink(url))
    }

    @Test func isInviteLink_alternateHostYalaAppComPe_returnsTrue() {
        let url = URL(string: "https://yala-app.com.pe/invite?s=ABC")!
        #expect(InviteLinkService.isInviteLink(url))
    }

    @Test func isInviteLink_wwwAlternateHosts_returnsTrue() {
        for host in ["www.yala-pe.com", "www.yala-app.com.pe"] {
            let url = URL(string: "https://\(host)/invite?s=ABC")!
            #expect(InviteLinkService.isInviteLink(url), "Host \(host) should be valid")
        }
    }

    @Test func isInviteLink_customSchemeYala_returnsTrue() {
        let url = URL(string: "yala://invite?s=ABC")!
        #expect(InviteLinkService.isInviteLink(url))
    }

    @Test func isInviteLink_customSchemeYaladev_returnsTrue() {
        let url = URL(string: "yaladev://invite?s=ABC")!
        #expect(InviteLinkService.isInviteLink(url))
    }

    @Test func isInviteLink_foreignHost_returnsFalse() {
        let url = URL(string: "https://attacker.com/invite?s=ABC")!
        #expect(!InviteLinkService.isInviteLink(url))
    }

    @Test func isInviteLink_canonicalHostNoShareParam_returnsFalse() {
        let url = URL(string: "https://yala-app.pe/invite")!
        #expect(!InviteLinkService.isInviteLink(url))
    }

    @Test func isInviteLink_canonicalHostWrongPath_returnsFalse() {
        let url = URL(string: "https://yala-app.pe/random?s=ABC")!
        #expect(!InviteLinkService.isInviteLink(url))
    }

    // MARK: - extractShareURL

    @Test func extractShareURL_alternateHostDecodesCorrectly() {
        // base64URL of "https://www.icloud.com/share/abc"
        // (matches base64URLEncode logic in InviteLinkService)
        let original = "https://www.icloud.com/share/abc"
        let encoded = Data(original.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let url = URL(string: "https://yala-pe.com/invite?s=\(encoded)")!

        let extracted = InviteLinkService.extractShareURL(from: url)
        #expect(extracted?.absoluteString == original)
    }

    @Test func extractShareURL_foreignHostReturnsNil() {
        let encoded = Data("https://www.icloud.com/share/abc".utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let url = URL(string: "https://attacker.com/invite?s=\(encoded)")!

        #expect(InviteLinkService.extractShareURL(from: url) == nil)
    }
}
