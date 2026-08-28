# Device QA 2026-08-28 — dinero fantasma al borrar un gasto de grupo

- `groups-ghost-tx-on-delete` cerrado con **PASS del owner** (Jurgen, Lima). Dos teléfonos, mismo grupo,
  **TF 2.1 build 12**: A crea un gasto de grupo (monto inusual, al 50/50) y se espera a que B lo vea en el
  grupo y en su Panel personal; A lo borra; en B, sin reabrir A, el gasto se va del grupo **y** la
  transacción puenteada desaparece del Panel — sin huérfana atascada.
- **Liquidaciones: no re-probadas hoy.** Iban en el ticket original como la misma clase de bug; este PASS
  no dice nada de ellas.
- **Nada más entra en el PASS**: no hay cola C (d)(e) más allá de este escenario de borrado de gasto.
- Sin subida a TestFlight hoy. HOLD sigue: A7/M5, App Store, tag.
