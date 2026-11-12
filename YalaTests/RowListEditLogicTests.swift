//
//  RowListEditLogicTests.swift
//  YalaTests
//
//  Card C3 (fluidez, 2026-11-01): solo una edición pequeña de una lista se anima —borrar, deshacer, añadir—; un cambio
//  de lista entero (otro filtro, otro período, la primera carga) sigue en seco.
//

import Testing
@testable import Yala

@Suite("Filas que entran o se van — qué cambio se anima")
struct RowListEditLogicTests {

    @Test func theSameList_doesNotAnimate() {
        #expect(!RowListEditLogic.isSmallEdit(from: [1, 2, 3], to: [1, 2, 3]))
    }

    @Test func deletingOneRow_animates() {
        #expect(RowListEditLogic.isSmallEdit(from: [1, 2, 3, 4], to: [1, 3, 4]))
    }

    @Test func undoingTheDeletion_animates() {
        #expect(RowListEditLogic.isSmallEdit(from: [1, 3, 4], to: [1, 2, 3, 4]))
    }

    @Test func addingARowAtTheTop_animates() {
        #expect(RowListEditLogic.isSmallEdit(from: [1, 2], to: [9, 1, 2]))
    }

    @Test func deletingTheLastRow_animates() {
        #expect(RowListEditLogic.isSmallEdit(from: [7], to: []))
    }

    /// Una liquidación que se confirma sale de «por confirmar» y entra en la lista: una fuera y otra dentro.
    @Test func oneOutAndOneIn_animates() {
        #expect(RowListEditLogic.isSmallEdit(from: ["p-1", "l-2"], to: ["l-1", "l-2"]))
    }

    /// El tope: tres sí, cuatro ya es otra lista.
    @Test func upToThreeChanges_animate_fourDoNot() {
        #expect(RowListEditLogic.isSmallEdit(from: [1, 2, 3, 4, 5], to: [1, 2]))
        #expect(!RowListEditLogic.isSmallEdit(from: [1, 2, 3, 4, 5], to: [1]))
    }

    /// La primera carga (de nada a una lista larga) y otro filtro (otra lista) van en seco.
    @Test func aWholeNewList_doesNotAnimate() {
        #expect(!RowListEditLogic.isSmallEdit(from: [Int](), to: Array(1...20)))
        #expect(!RowListEditLogic.isSmallEdit(from: Array(1...20), to: Array(21...40)))
    }

    /// Una fila que cambia de sitio (otra fecha) no es una edición pequeña: reordenaría la lista.
    @Test func aRowThatMoves_doesNotAnimate() {
        #expect(!RowListEditLogic.isSmallEdit(from: [1, 2, 3], to: [2, 1, 3]))
        #expect(!RowListEditLogic.isSmallEdit(from: [1, 2, 3, 4], to: [3, 1, 2]))
    }

    // MARK: - La lista y su vacío (card 1jvv)

    /// Borrar la última fila o apuntar la primera cruza entre la lista y el vacío: se funde.
    @Test func lastRowOut_orFirstRowIn_crossesEmpty() {
        #expect(RowListEditLogic.crossesEmpty(from: [7], to: []))
        #expect(RowListEditLogic.crossesEmpty(from: [Int](), to: [7]))
        #expect(RowListEditLogic.crossesEmpty(from: [1, 2, 3], to: []))
    }

    /// Una edición que deja filas no es cosa del contenedor del vacío (la anima el de las filas).
    @Test func anEditThatKeepsRows_doesNotCrossEmpty() {
        #expect(!RowListEditLogic.crossesEmpty(from: [1, 2], to: [1]))
        #expect(!RowListEditLogic.crossesEmpty(from: [1], to: [1, 2]))
        #expect(!RowListEditLogic.crossesEmpty(from: [Int](), to: [Int]()))
    }

    /// Un filtro que vacía una lista larga, o la primera carga de una lista larga, sigue en seco.
    @Test func aWholeListEmptiedOrLoaded_doesNotCrossEmpty() {
        #expect(!RowListEditLogic.crossesEmpty(from: Array(1...20), to: []))
        #expect(!RowListEditLogic.crossesEmpty(from: [Int](), to: Array(1...20)))
    }
}
