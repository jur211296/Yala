//
//  YalaAIChatLayoutLogicTests.swift
//  YalaTests
//
//  Yala IA: columna en ventana ancha, hoja en compacta, nunca las dos, y el mismo «abierto» para las dos formas.
//

import Testing

@testable import Yala

struct YalaAIChatLayoutLogicTests {
    private typealias Logic = YalaAIChatLayoutLogic

    @Test func wideWindow_opensAsColumn_notSheet() {
        #expect(Logic.showsColumn(isPresented: true, isRegularWidth: true))
        #expect(!Logic.showsSheet(isPresented: true, isRegularWidth: true))
    }

    @Test func compactWindow_opensAsSheet_notColumn() {
        #expect(Logic.showsSheet(isPresented: true, isRegularWidth: false))
        #expect(!Logic.showsColumn(isPresented: true, isRegularWidth: false))
    }

    @Test func closed_showsNothing_inEitherWidth() {
        for regular in [true, false] {
            #expect(!Logic.showsColumn(isPresented: false, isRegularWidth: regular))
            #expect(!Logic.showsSheet(isPresented: false, isRegularWidth: regular))
        }
    }

    /// Redimensionar con el chat abierto: en cada ancho se ve exactamente una de las dos formas.
    @Test func openChat_isAlwaysVisible_inExactlyOneForm() {
        for regular in [true, false] {
            let column = Logic.showsColumn(isPresented: true, isRegularWidth: regular)
            let sheet = Logic.showsSheet(isPresented: true, isRegularWidth: regular)
            #expect(column != sheet)
        }
    }
}
