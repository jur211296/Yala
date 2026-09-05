//
//  InviteLinkGateBackendPairTests.swift
//  YalaTests
//
//  Pieza 3 de `invite-link-five-causes-one-message`: la PUERTA de entrada de un invite
//  (`InviteLinkService.isInviteLink`) era más estrecha que el PARSER (`extractBackendInvite`). El parser
//  lee `g`+`t` sin `s`; la puerta exigía `s`. Un `yala://invite?g=..&t=..` no llegaba a
//  `handleInviteLink`: caía al `switch url.host` de `handleIncomingURL` y moría en su `default` sin una
//  línea de UI.
//
//  El invariante que fija esta suite NO es «acepta esta URL concreta» sino la RELACIÓN entre las dos
//  funciones: **todo lo que el parser sabe leer, la puerta lo deja pasar**. Escrito como propiedad, un
//  formato nuevo en el parser que alguien olvide reflejar en la puerta se pone rojo solo.
//
//  Cada caso lleva su CONTROL POSITIVO (`extractBackendInvite != nil`): sin él, un cambio que rompiera el
//  parser dejaría estas aserciones pasando en vacío sobre URLs que ya no son invites.
//

import Foundation
import Testing

@testable import Yala

@Suite("InviteLinkService · la puerta acepta lo que el parser lee")
struct InviteLinkGateBackendPairTests {

    /// Formas que `extractBackendInvite` acepta y que NO llevan `s`.
    private static let backendPairURLs: [String] = [
        // Universal link mínimo, host canónico.
        "https://yala-app.pe/invite?g=SplitGroup-ABC&t=deadbeef",
        // Host alterno + www (los redirects de `Web/vercel.json`; el paste manual no los sigue).
        "https://www.yala-pe.com/invite?g=SplitGroup-ABC&t=deadbeef",
        "https://yala-app.com.pe/invite?g=SplitGroup-ABC&t=deadbeef",
        // Custom scheme: la forma que moría en el `default` de `handleIncomingURL`.
        "yala://invite?g=SplitGroup-ABC&t=deadbeef",
        "yaladev://invite?g=SplitGroup-ABC&t=deadbeef",
        // Con cosméticos pero sin `s`.
        "https://yala-app.pe/invite?g=SplitGroup-ABC&t=deadbeef&n=Viaje&i=airplane&c=FF8800",
    ]

    @Test func gate_acceptsEveryFormTheParserReads() throws {
        for raw in Self.backendPairURLs {
            let url = try #require(URL(string: raw), "URL de test malformada: \(raw)")
            // Control positivo: si el parser dejara de leer esta forma, la aserción de abajo pasaría
            // en vacío y la suite se volvería decorativa.
            #expect(InviteLinkService.extractBackendInvite(from: url) != nil,
                    "Control positivo roto — el parser ya no lee \(raw)")
            #expect(InviteLinkService.isInviteLink(url),
                    "La puerta rechaza una forma que el parser SÍ lee: \(raw)")
        }
    }

    /// El caso que costó el diagnóstico: sin `s` y con la app cerrada, la URL entra por
    /// `handleIncomingURL`, cuyo `switch url.host` no tiene rama `invite`.
    @Test func gate_acceptsCustomSchemeWithoutShareParam() throws {
        let url = try #require(URL(string: "yala://invite?g=SplitGroup-Z&t=abc123"))
        #expect(InviteLinkService.isInviteLink(url))
    }

    // MARK: - Lo que la puerta sigue rechazando (el ensanche no es un coladero)

    @Test func gate_rejectsPartialBackendPair() throws {
        // Solo `g`, solo `t`, y el par con un valor vacío: `backendPair` exige los dos NO vacíos.
        for raw in [
            "https://yala-app.pe/invite?g=SplitGroup-ABC",
            "https://yala-app.pe/invite?t=deadbeef",
            "https://yala-app.pe/invite?g=&t=deadbeef",
            "https://yala-app.pe/invite?g=SplitGroup-ABC&t=",
        ] {
            let url = try #require(URL(string: raw))
            #expect(InviteLinkService.extractBackendInvite(from: url) == nil,
                    "Control: el parser tampoco debería leer \(raw)")
            #expect(!InviteLinkService.isInviteLink(url), "La puerta no debe aceptar \(raw)")
        }
    }

    @Test func gate_rejectsForeignHostEvenWithBackendPair() throws {
        let url = try #require(URL(string: "https://attacker.com/invite?g=SplitGroup-ABC&t=deadbeef"))
        #expect(!InviteLinkService.isInviteLink(url))
    }

    @Test func gate_rejectsWrongPathEvenWithBackendPair() throws {
        let url = try #require(URL(string: "https://yala-app.pe/random?g=SplitGroup-ABC&t=deadbeef"))
        #expect(!InviteLinkService.isInviteLink(url))
    }
}
