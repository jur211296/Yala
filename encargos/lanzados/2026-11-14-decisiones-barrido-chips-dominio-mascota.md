Yala
# Decidir lo que dejó el barrido: fila de chips en el iPhone SE, dominio del conector y mascota Yalitto
---
toca: docs/qa/barrido-iphone-2026-11-14/decisiones/
esfuerzo: medium
cierre: cierra-sola
---

Jürgen pidió (14-nov 13:52 Lima) el detalle con opciones y recomendación para desbloquear de una vez las tres decisiones que el barrido del iPhone dejó a su nombre en `docs/qa/barrido-iphone-2026-11-14/necesita-a-jurgen.md`:

1. Fila de chips de «Nuevo registro» en el iPhone SE (card «¿La fila de chips de «Nuevo registro» avisa de que hay un chip más a la derecha…»): sus opciones A/B/C/D están en la card y en `lista.md` (fila 104). En el iPhone 14 y el 17 Pro «Etiquetas» se ve entera; solo en el SE queda tapada.
2. Endurecer el conector MCP en producción: elegir dominio (workers.dev o mcp.yala-app.pe). Contexto en `docs/DECISIONS.md` y `docs/exploracion/plugin-claude-mcp.md`. Después despliega Dan.
3. Mascota «Yalitto»: sus 7 decisiones de la sección 8 de `docs/ux/mascota-yalitto-2.3/` (ficha.md, yalitto.html).

Entregable: UN artifact visual de Claude (no Markdown ni PDF) para decidir rápido. Por cada decisión: qué es en una frase, las opciones con su imagen o maqueta (capturas del SE en simulador para los chips; puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP), pros y contras cortos, la recomendada marcada con su porqué, y un selector de respuesta. Sin ids de cards en el texto visible; español neutro latinoamericano. Guarda la fuente en `docs/qa/barrido-iphone-2026-11-14/decisiones/` y pon el link del artifact en el cierre y en el PR. No implementes ninguna de las opciones. Commits sin firma de IA. Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en semi, sin preguntar: menores y reversibles)

- **Formato:** un HTML generado por `fuente/build.py` (Python de serie) en `docs/qa/barrido-iphone-2026-11-14/decisiones/`, publicado como artifact con la capacidad `db`: un documento por decisión en `respuestas`, para que Frank lea las respuestas sin pedirlas por chat.
- **Granularidad:** 9 selectores — chips (1), dominio (1) y mascota (7, una por decisión de la sección 8).
- **Capturas del SE:** simulador iPhone SE (3.ª gen.) propio en la Max, Yala Dev compilada desde la base de hoy, semilla `minimal`, con `sim-lock`. Las opciones B, C y D se ilustran como maquetas sobre la captura real, marcadas «Maqueta»; no se toca código de la app.
- **Dominio:** se mide el DNS de yala-app.pe antes de recomendar (el runbook dice RCP al 4-nov).
- **Sin código de la app ni tests:** el gate se reduce a la validación del índice (diff en `docs/`, `tickets/`, `encargos/`).
- **Decisiones capturadas de Yala web (lote 2 y 3):** se incorporan a `docs/DECISIONS.md` en este mismo PR.
