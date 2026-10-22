# Device QA 2026-08-28 — dinero fantasma al borrar en un grupo

- `groups-ghost-tx-on-delete` cerrado con **PASS del owner** (Jurgen, Lima). Dos teléfonos, mismo grupo,
  **TF 2.1 build 12**, tres comprobaciones seguidas:
  1. **Borrado de gasto**: A crea un gasto de grupo (monto inusual, al 50/50) y se espera a que B lo vea en
     el grupo y en su Panel personal; A lo borra; en B, sin reabrir A, el gasto se va del grupo **y** la
     transacción puenteada desaparece del Panel — sin huérfana atascada.
  2. **Liquidación hacia delante**: A registra una liquidación (B le pagó a A, monto inusual) y B, sin
     force-quit, la ve con los balances cuadrando con A.
  3. **Borrado de la liquidación**: A la borra en A; en B, sin force-quit, la liquidación desaparece y los
     balances no quedan colgados.
- Con las tres, la clase de fantasma del ticket queda cubierta en device para **gasto y liquidación**, las
  dos entidades del reporte original.
- **Lo que no entra**: los dos borrados salieron de A, así que el sentido contrario (borrar desde B, el bug
  era bidireccional) no se corrió; en la liquidación el reporte llega al grupo y a los balances, no al
  Panel de B; y no hay cola C (d)(e) más allá de estos tres escenarios.
- Sin subida a TestFlight hoy. HOLD sigue: A7/M5, App Store, tag.
