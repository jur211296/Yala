---
id: 2026-11-26-deuda-gate-y-docs-2-3
status: done
priority: medium
area: "tests, gate, docs, l10n, conector"
created: 2026-11-26
updated: 2026-11-27
---
# Deuda de 2.3: gate sin «AX loaded», prueba de la foto del widget, índice de tickets, textos sin uso y guía del conector

Decisión de Jürgen (26-nov, 17:55 Lima) sobre la primera pasada de hallazgos de cierres: «B. Ok a la cola · C. Ok
encola · D. Ok». Cinco arreglos chicos que varias sesiones anotaron en sus cierres. Nada cambia para quien usa la app.

## Qué se hizo

1. **El gate reinicia el simulador entre la unitaria y la interfaz.** `qa/scripts/sim-reiniciar.sh` (nuevo) pide el
   turno de `sim-lock.sh`, apaga el «iPhone 17 Pro» si está encendido, lo arranca, espera a que esté listo (techo de
   3 min) y deja 15 s de reposo. `xcodebuild test` apaga al terminar el simulador que arrancó él, así que tras la
   unitaria lo normal es encontrarlo apagado: el script lo arranca igual. El paso 3 de `.claude/commands/gate.md` lo
   llama antes de cada XCUITest, y está en `allowed-tools`. Medido: apagado → listo en 5 s (20 s con el reposo);
   encendido → 9 s (24 s).
2. **`FotoWidgetPorEtapasTests` aislada de lo que dejan otras suites.** Sin tocar la app: `aislar()` desarma el borrado
   de cierre de sesión que otra suite deja armado (y lo restaura al salir), cancela la foto pedida y espera a que no
   quede una a medias; el contador de reinicios se lee pegado al gesto que reinicia y se mide «al menos uno más»; el
   umbral de vueltas del hilo baja de 8 a 3 (de una vez da 0 o 1). Verde en dos corridas seguidas de `YalaTests` entero
   (16 627 casos).
3. **`docs/TICKETS.md`:** el encabezado decía 177 filas y había 1537. Las dos del 16-nov ya estaban, con su `id` del
   frontmatter (`groups-import-splitwise-tricount`, `new-transaction-form-sometimes-never-goes-idle-for-xcuitest`), no
   con el nombre del fichero. Se añadieron las nueve que faltaban de verdad y la de este ticket; había una sola cabecera
   de conteo. Tras el rebase sobre el lote 3 de Compartido, 1548 filas para 1548 tickets.
4. **Textos sin uso:** `rfr.planning.fromRecord` y `rfr.picker.footer` solo los usaban sus accesores (`fromRecord`,
   `pickerFooter`). Fuera accesores y claves en los 16 idiomas.
5. **`mcp/RUNBOOK-produccion.md`:** Grok web y Grok Bot ya están en la lista de vueltas del conector desde el 24-nov, y
   producción lo tiene desplegado desde el 25-nov (medido con `wrangler deployments list`).

Pin: `YalaTests/DeudaGateYDocs/DeudaGateYDocsTests.swift` (claves ausentes en los 16 idiomas y en el bundle; el paso 3
reinicia antes de cada XCUITest; el script pide el turno antes de apagar).

## Hecha cuando

- El gate reinicia el simulador entre fases y se probó completo una vez. ✓
- La foto del widget pasa dos veces seguidas en la suite entera. ✓
- El índice cuenta lo que tiene. ✓
- Las dos claves sin uso no están en ningún idioma. ✓
- La guía dice cómo funciona hoy la vuelta de Grok, y si está desplegada. ✓
