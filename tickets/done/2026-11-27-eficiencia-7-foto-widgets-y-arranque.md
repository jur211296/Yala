---
id: 2026-11-27-eficiencia-7-foto-widgets-y-arranque
status: done
priority: medium
area: "performance, widgets, panel, arranque"
created: 2026-11-27
updated: 2026-11-27
source: "decisión de Jürgen del 27-nov-2026, 06:17 Lima (encolar los tres lotes de 2.3), lote 7 del plan de eficiencia (docs/qa/rendimiento-iphone14-2026-11-26/); cards «Eficiencia 7: foto de los widgets y arranque en frío más livianos» y «La app se traba unos segundos armando el resumen del período del widget (Sentry YALA-IOS-16)»"
---

# La foto de los widgets, el arranque en frío y la proyección dejan de trabar la app

Con 16.004 movimientos en el iPhone 14, al abrir Yala en frío la foto de los widgets ocupaba 5,6 s del hilo principal en
bloques de hasta 1,25 s, el Panel a veces se calculaba dos veces y la proyección del saldo era un bloque de ~0,9 s.

## Qué se hizo

- La foto lee cada movimiento una vez (`FilaFotoWidget`) y sus etapas largas se cortan a ~20 ms; la lectura de los
  movimientos va por tramos con la pieza del Panel (`LecturaMovimientosPorTramos`). Cifras idénticas al código previo.
- El empujón de `dataVersion` del final del arranque ya no recalcula el Panel si nada cambió desde su carga
  (`EmpujonFinDeArranque`).
- La proyección del saldo convierte los movimientos del motor por trozos (`ProjectedFlowBuilder.PrecalculoMotor`) en la
  foto y en el Panel.
- Medido el suelo de pasadas fuera de pantalla del scroll: son las barras del sistema (32 → 18 sin ellas). No se tocó.

## Resultado (iPhone 14, 16 k)

Foto: 5,6 → 2,9 s de hilo, bloque mayor 1.250 → 216 ms. Arranque: cuelgues > 250 ms de 21 (11,9 s) a 6 (2,4 s); Panel
listo de ~15 s a ~10,6 s. Informe: `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-7-foto-widgets-y-arranque/`.

## Fuera

- Tres tramos de 170-216 ms en calculadoras compartidas (saldo vivo, `BalanceValuation`, saldos por cuenta).
- La proyección con plan (`CashFlowProjectionCalculator`) sigue de una vez.
- La carga del Panel (`loadData` + saldos de cuentas) deja un bloque de ~0,55 s en el arranque.
- Quitar el cristal de las barras del sistema para bajar el suelo de render es decisión de diseño.
