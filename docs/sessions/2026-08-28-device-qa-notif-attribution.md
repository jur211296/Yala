# Device QA 2026-08-28 — a quién se atribuye la notificación de un gasto de grupo

- `group-notif-credits-payer-not-editor` cerrado con **PASS del owner** (Jurgen, Lima). Dos teléfonos, el
  mismo grupo que el resto del QA de hoy, **TF 2.1 build 12**: **A** fue quien actuó (crear/editar) y **A no
  recibió notificación** —ningún eco que atribuyera su cambio a **B**—; **B sí la recibió**.
- **La notificación de B llegó solo al abrir la app.** Hallazgo de la misma corrida, pero es *cuándo* se
  entrega, no *a quién* se atribuye: va en ticket aparte (`groups-expense-notif-only-on-foreground`, en alta
  separada). **No se dobla en este cierre** ni como PASS ni como FAIL de la atribución.
- **El escenario original (pagado por Pia, editado por el owner) no consta re-corrido palabra por palabra.**
  El reporte no fija quién era el pagador; con pagador = A el silencio hacia A ya existía antes del fix (guard
  legado `paidByMemberID == me`), así que esa variante no discrimina.
- **Sin medir hoy:** el texto literal de la notificación de B, el gasto nuevo atribuido al creador, el eco de
  liquidaciones (Caso D), «un tercero edita un gasto pagado por otro» y el 2º device con el mismo iCloud.
- Cierre de **QA**, no fix nuevo: sin cambio de código y sin subida a TestFlight. HOLD sigue: A7/M5, App
  Store, tag.
