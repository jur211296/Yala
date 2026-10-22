//
//  YalaAccountLogicTests.swift
//  YalaTests
//
//  Tabla de la lógica de composición de la pantalla "Tu cuenta de Yala" (§3.3.5):
//  provider × storageMode × canDeleteAccount → método, dónde viven los datos, desenlaces.
//

import Testing
@testable import Yala

@Suite("Pantalla «Tu cuenta de Yala» — lógica de composición (§3.3.5)")
struct YalaAccountLogicTests {
    typealias L = YalaAccountLogic

    @Test func method_mapsWireStrings() {
        #expect(L.method(fromProvider: "apple") == .apple)
        #expect(L.method(fromProvider: "google") == .google)
        #expect(L.method(fromProvider: nil) == .unknown)
        #expect(L.method(fromProvider: "garbage") == .unknown)
        #expect(L.method(fromProvider: "") == .unknown)
    }

    // Q1: la nota general de vínculo se muestra SIEMPRE (H4 no detectable client-side).
    @Test func linkingNote_alwaysShown() {
        for provider in ["apple", "google", nil] {
            for mode in [StorageMode.icloud, .cloud] {
                for can in [true, false] {
                    #expect(
                        L.model(provider: provider, storageMode: mode, canDeleteAccount: can, hasPrivateSession: true).showLinkingNote,
                        "linking note debe mostrarse siempre (\(provider ?? "nil"), \(mode), \(can))")
                }
            }
        }
    }

    @Test func dataLocation_byMode() {
        #expect(L.model(provider: "apple", storageMode: .cloud, canDeleteAccount: true, hasPrivateSession: true).dataLocation == .cloud)
        #expect(L.model(provider: "apple", storageMode: .icloud, canDeleteAccount: true, hasPrivateSession: true).dataLocation == .groupsOnly)
    }

    /// Paso 9: un solo-grupos SIN sesión privada llega aquí para borrar su cuenta, y la variante del
    /// «equipo» le decía «en este dispositivo y en tu iCloud privado».
    @Test func dataLocation_groupsOnlyWithoutPrivateSession() {
        #expect(L.model(provider: "google", storageMode: .icloud, canDeleteAccount: true,
                        hasPrivateSession: false).dataLocation == .groupsOnlyNoPrivate)
        #expect(L.model(provider: "google", storageMode: .icloud, canDeleteAccount: true,
                        hasPrivateSession: true).dataLocation == .groupsOnly)
        #expect(L.model(provider: "google", storageMode: .cloud, canDeleteAccount: true,
                        hasPrivateSession: false).dataLocation == .cloud)
    }

    @Test func signOut_alwaysFirst() {
        for mode in [StorageMode.icloud, .cloud] {
            for can in [true, false] {
                let m = L.model(provider: "apple", storageMode: mode, canDeleteAccount: can, hasPrivateSession: true)
                #expect(m.exits.first == .signOut, "signOut siempre primero (\(mode), \(can))")
            }
        }
    }

    @Test func returnToICloud_onlyInCloud() {
        for mode in [StorageMode.icloud, .cloud] {
            let m = L.model(provider: "apple", storageMode: mode, canDeleteAccount: true, hasPrivateSession: true)
            #expect(m.exits.contains(.returnToICloud) == (mode == .cloud),
                    "returnToICloud solo en .cloud (\(mode))")
        }
    }

    @Test func deleteAccount_onlyWhenAllowed() {
        for can in [true, false] {
            let m = L.model(provider: "apple", storageMode: .cloud, canDeleteAccount: can, hasPrivateSession: true)
            #expect(m.exits.contains(.deleteAccount) == can,
                    "deleteAccount solo si canDeleteAccount (\(can))")
        }
    }

    // Orden canónico (escalera de gravedad) por celda de la matriz.
    @Test func exits_canonicalOrder() {
        #expect(L.model(provider: "apple", storageMode: .cloud, canDeleteAccount: true, hasPrivateSession: true).exits
                == [.signOut, .returnToICloud, .deleteAccount])
        #expect(L.model(provider: "apple", storageMode: .icloud, canDeleteAccount: true, hasPrivateSession: true).exits
                == [.signOut, .deleteAccount])
        #expect(L.model(provider: "apple", storageMode: .cloud, canDeleteAccount: false, hasPrivateSession: true).exits
                == [.signOut, .returnToICloud])
        #expect(L.model(provider: "apple", storageMode: .icloud, canDeleteAccount: false, hasPrivateSession: true).exits
                == [.signOut])
    }
}
