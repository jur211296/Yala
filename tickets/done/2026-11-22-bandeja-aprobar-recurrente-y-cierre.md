---
id: 2026-11-22-bandeja-aprobar-recurrente-y-cierre
status: done
area: "bandeja, pagos planificados"
created: 2026-11-22
updated: 2026-11-22
source: "Jürgen, 22-nov (15:08 Lima): encolar lo pendiente del backlog que esté claro; este encargo junta tres tickets de la Bandeja"
---

# Bandeja: «Aprobar y hacer recurrente» y el cierre tras «Guardar los listos»

## Qué cambia para quien usa la app

Nada visible. «Aprobar y hacer recurrente» ya aprobaba y abría el editor del pago planificado, también con el aviso de
posible duplicado, y «Guardar los listos» ya cerraba la Bandeja al quedar vacía: los dos rojos de los tickets no se
reproducen hoy en `2.3`. Este encargo deja ese comportamiento fijado con pruebas de interfaz.

## Qué se hizo

- Medido sobre `origin/2.3`: los dos XCUITest que estaban rojos pasan 1 de 1 y 3 de 3 cada uno. Sus tickets van a `done`
  con esa evidencia: `inbox-approve-and-make-recurring-no-longer-opens-the-editor`,
  `inbox-does-not-close-after-saving-the-last-ready-drafts-in-2-3`.
- Prueba nueva con el gemelo sembrado (`-uitest-inbox-duplicate-draft`):
  `YalaUITests/BandejaRecurrenteCierre/BandejaRecurrenteDuplicadoUITests` (dos casos, verdes 2 de 2). Cierra
  `2026-11-18-bandeja-aprobar-y-recurrente-choca-con-posible-duplicado`.
- Los dos botones del aviso «Posible duplicado» del editor llevan id (`inbox_duplicate_cancel`,
  `inbox_duplicate_save_anyway`). Es el único cambio en código de la app.
- Sospecha refutada: «Cancelar» en el aviso no deja lo recurrente armado; «Guardar» lo desarma antes de aprobar. El
  segundo caso lo fija: cae con el mutante que quita ese desarme.

## Fuera

Device-QA: ninguno. No hay textos nuevos (sin tabla `.strings`).
