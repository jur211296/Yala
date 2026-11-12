---
id: saved-record-notice-covers-the-panel-plus-button
status: done
priority: medium
area: "transactions, panel"
created: 2026-10-22
updated: 2026-10-28
source: lote decidido 2.2 · 02, sesión A (L2-5), review adversarial y XCUITest
---

# El aviso tras guardar tapa el «+» flotante del Panel durante sus 5 segundos

## Qué pasa

Desde 2.2, a partir del cuarto registro, guardar cierra el formulario y enseña sobre la pantalla de origen el aviso
«Gasto guardado · S/ 12.00» con «Editar» y «Deshacer» (L2-5). Es el mismo componente que el aviso de la Bandeja
(`DraftDiscardUndoNotice`): una ventana propia sobre la app, a 72 pt del borde inferior, de lado a lado.

En el Panel, esa franja cae sobre el «+» flotante. Quien apunta varios gastos seguidos —justo a quien ayuda el aviso—
toca el «+» para el siguiente y, durante esos 5 segundos, el toque no llega (medido con XCUITest:
`test_afterThreeRecords_openingAnotherFormRetiresTheNotice` no abría el menú del «+» con el aviso en pantalla). «Nuevo
registro» de arriba del Panel sí funciona, y al abrirse el formulario el aviso se retira.

## Qué hay que decidir (Jürgen)

Dónde va el aviso cuando la pantalla tiene un botón flotante:

- **A.** Más arriba que el «+» (por encima de los botones flotantes), en todas las pantallas.
- **B.** Donde está, pero más estrecho y a la izquierda, dejando libre el «+».
- **C.** Donde está; tocar el aviso fuera de sus botones lo retira (el primer toque se pierde).

## Decidido y hecho (2026-10-28)

Jürgen eligió **A** el 2026-10-22. El aviso sube por encima de la pila de botones flotantes en todas las pantallas
(`DraftDiscardUndoNotice.bottomClearance`: barra + `fabStackClearance`, dos botones; uno con poco alto). Abrir el menú
del «+» retira el aviso de guardado, porque el menú crece hacia arriba y caería bajo su franja.

Lo fija `TransactionFormDecided02UITests#test_afterThreeRecords_thePlusTakesTheFirstTapWithTheNoticeVisible`: rojo en
la base (el aviso acababa en y=796 y el «+» empezaba en 711) y verde con el arreglo.
