# Device QA 2026-08-28 — dinero fantasma al borrar un gasto de grupo

- `groups-ghost-tx-on-delete` cerrado con **PASS del owner** (Jurgen, Lima). Dos teléfonos, mismo grupo,
  **TF 2.1 build 12**: A crea un gasto de grupo (monto inusual, al 50/50) y se espera a que B lo vea en el
  grupo y en su Panel personal; A lo borra; en B, sin reabrir A, el gasto se va del grupo **y** la
  transacción puenteada desaparece del Panel — sin huérfana atascada.
- **Liquidaciones: solo la mitad.** Comprobación posterior del mismo día, mismo grupo y mismo binario: A
  registra una liquidación (B le pagó a A, monto inusual) y B, **sin force-quit**, la ve con los balances
  cuadrando con A. Owner: **PASS**. Eso levanta el lado hacia delante; **borrar una liquidación NO se
  corrió**, y es la otra mitad del bug original (el fantasma salía al borrar) ⇒ sin cobertura completa de
  liquidaciones.
- **Nada más entra en el PASS**: no hay cola C (d)(e) más allá de esos dos escenarios (borrado de gasto y
  liquidación hacia delante).
- Sin subida a TestFlight hoy. HOLD sigue: A7/M5, App Store, tag.
