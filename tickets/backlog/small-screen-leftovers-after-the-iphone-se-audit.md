---
id: small-screen-leftovers-after-the-iphone-se-audit
status: backlog
priority: low
area: "design-system, iphone, adaptativo"
created: 2026-09-28
source: "iphone-small-screens-and-safe-areas-audit (carril adaptativo, paso 3), capturas del 2026-09-28"
---

# En el iPhone más pequeño, lo que la auditoría vio y no arregló

**Sale del paso 3 del carril adaptativo** ([[iphone-small-screens-and-safe-areas-audit]]). Aquel ticket arregló lo
barato de las pantallas del recorrido en un iPhone SE. Aquí queda lo que cambiaba la estructura de una pantalla o
no se podía medir en el simulador. Lo ya apuntado en otros tickets no se repite: se enlaza al final.

## Qué le pasa al usuario

Nada de esto le impide usar la app. Lo que sí se lo impedía tiene ticket propio (abajo). Lo de aquí son textos
cortados que no son importes, dos pantallas por medir y una tarjeta que, en un caso concreto, puede quedar fuera
del borde.

## Lo que hay

1. **Las tarjetas de la guía de primeros pasos no se ajustan a los bordes.** `CoachMarkOverlay.tooltipCard` coloca
   la tarjeta a 80 pt por encima o por debajo del elemento señalado y no mira la barra de estado ni el indicador de
   inicio. Con un elemento alto cerca del borde, o con el texto grande en un SE, la tarjeta puede salirse de la
   pantalla y dejar fuera sus botones «Omitir» y «Siguiente». **Inferido del código, no visto**: los recorridos
   guiados se apagan bajo `-uitest` (`guard !UITestHooks.isActive` en `PanelView`), así que el guion de capturas no
   los alcanza. El arreglo es medir el alto de la tarjeta (`onGeometryChange`) y acotar su centro dentro del área
   segura. Pide antes una forma de lanzar el recorrido en un test, porque sin captura no se puede verificar.
2. **Dos pantallas de éxito más con la misma forma, sin medir:** `SubscriptionSuccessView` y
   `InboxBulkApproveSuccessView` reparten su alto con `Spacer`s y no tienen scroll, como las dos que la auditoría
   arregló (tras guardar un registro y tras aprobar un borrador, que en el SE se salían por arriba y por abajo a
   tamaño normal). No se capturaron: la de la suscripción pide una compra y la del lote no estaba en el recorrido.
   Si se confirma, el arreglo es el mismo molde (regla en `.claude/rules/swiftui-ds.md`).
3. **Detalle de registro a AX5:** al desplazar la tarjeta, el texto pasa por debajo de los botones «Cerrar» y
   «Editar», que no tienen fondo. Se leen y se tocan, pero se solapan con el texto. Visto en el SE.
4. **La tarjeta de Tendencias del Panel a AX5 en el SE:** su cabecera («Saldo», el importe y los tres botones de
   tipo) no cabe y se sale por los dos lados («aldo?»). Es un widget de alto fijo, y va con el punto 5 de
   [[large-text-leftovers-outside-the-main-iphone-screens]], que ya recoge su eje de fechas. Visto.
5. **Títulos del sistema truncados a AX5:** «Planificaci…», «Viaje a Cus…». Es el título grande de
   `navigationTitle`, que iOS trunca así. No se toca salvo que se decida un título propio.

## Ya apuntado en otro sitio

- La Bandeja a AX5 en el SE, sin sitio para los borradores: [[inbox-header-leaves-no-room-for-drafts-at-large-text]].
- El aviso del primer gasto que se come la pantalla de éxito:
  [[first-expense-practice-alert-tears-down-the-success-screen]].
- La última fila tapada por los botones flotantes (Panel, Registros, Planificación, detalle de grupo):
  [[floating-buttons-cover-row-amounts-on-ipad-landscape]].
- Rótulos del selector de tipo y de la fila de acciones de Nuevo registro, filtros de la Bandeja, widgets pequeños
  del Panel y la píldora «Nuevo registro» contra el borde: [[large-text-leftovers-outside-the-main-iphone-screens]].
