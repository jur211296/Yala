---
id: closing-yala-during-the-icloud-return-wipe-cancels-it-silently
status: backlog
area: cloud-sync
priority: low
created: 2026-11-16
updated: 2026-11-16
source: card 120i del tablero (detalles menores del barrido final de 2.3), punto 1
---

# Cerrar Yala durante «Borrar los datos de antes» cancela la vuelta a iCloud sin decir nada

## Qué pasa

Barrido final de 2.3 (iPhone 14, 15-nov). En «Volver a tu iCloud», la persona elige borrar los datos de antes del iCloud
y, mientras se borran, cierra Yala. Al reabrir vuelve a salir el botón de «Volver a tu iCloud» como si no hubiera pasado
nada, y el iCloud queda medio borrado. No se pierden datos de la cuenta de Yala, pero la persona ya había elegido borrar
y Yala no le dice que el borrado quedó a medias.

## Por qué no entró en el lote del 16-nov

Es una fase de la vuelta a iCloud con su journal, sus techos y su salida (reglas de `swiftdata-cloudkit.md`, «Y las cuatro
fases previas al montaje también tienen techo y salida»). Decidir si se retoma el borrado al reabrir o si se avisa de que
quedó a medias es una decisión de producto, y el arreglo pide review adversarial. No cabía en un lote de bugs de la app.

## Qué falta decidir

- Al reabrir con el borrado a medias: ¿retomar el borrado solo, o enseñar «El borrado quedó a medias» con «Terminar»?

## Cómo se reproduce

1. Yala en una cuenta de Yala con datos, iCloud con datos de antes.
2. Ajustes › Dónde viven tus datos › Volver a tu iCloud › elegir borrar los datos de antes.
3. Durante «Borrar los datos de antes», cerrar Yala desde el selector de apps.
4. Abrir Yala: vuelve a salir «Volver a tu iCloud»; el iCloud tiene solo parte de lo de antes.
