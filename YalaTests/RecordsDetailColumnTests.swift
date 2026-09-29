//
//  RecordsDetailColumnTests.swift
//  YalaTests
//
//  Tocar un registro lo abre en la columna de detalle solo cuando la vista tiene columna y la ventana
//  es ancha (`opensDetailInColumn`); en cualquier otro caso, la hoja de siempre con su encadenado al
//  editor. Y desde la columna, Editar abre el editor directo sin cerrar el registro.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct RecordsDetailColumnTests {

    private func makeTransaction() -> TransactionItem {
        let account = Account(name: "Main", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let category = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        return TransactionItem(
            date: Date(), amount: -12, currencyCode: "USD", note: "Café",
            category: category, account: account, tags: [], amountInPreferredCurrency: -12)
    }

    /// Por defecto (iPhone, ventana estrecha, Estadísticas › Registros): la hoja.
    @Test func withoutColumn_opensTheSheet() {
        let vm = RecordsViewModel()
        let tx = makeTransaction()
        vm.showRecordDetail(tx)
        #expect(vm.showTransactionDetail)
        #expect(vm.editingTransaction === tx)
        #expect(vm.openRecordID == nil)
    }

    @Test func withColumn_opensInTheColumn_andNoSheet() {
        let vm = RecordsViewModel()
        vm.opensDetailInColumn = true
        let tx = makeTransaction()
        vm.showRecordDetail(tx)
        #expect(vm.openRecordID == tx.persistentModelID)
        #expect(!vm.showTransactionDetail)
        #expect(vm.editingTransaction == nil)
    }

    /// Editar desde la columna: editor directo, y el registro sigue abierto detrás.
    @Test func editFromColumn_presentsEditor_keepingTheRecordOpen() {
        let vm = RecordsViewModel()
        vm.opensDetailInColumn = true
        let tx = makeTransaction()
        vm.showRecordDetail(tx)
        vm.editOpenRecord(tx)
        #expect(vm.showEditTransaction)
        #expect(vm.editingTransaction === tx)
        #expect(vm.openRecordID == tx.persistentModelID)
        #expect(!vm.showTransactionDetail)
    }
}
