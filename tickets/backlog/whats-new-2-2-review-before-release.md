---
id: whats-new-2-2-review-before-release
status: backlog
priority: medium
area: "copy, l10n, novedades"
created: 2026-10-17
updated: 2026-10-17
source: "auditoría UX 2.2 · lote 5 (L5-15), implementación del 2026-10-17"
---

# Revisar las Novedades de 2.2 antes de publicarla

L5-15 (opción A) dio contenido a la hoja de Novedades de 2.2 y una fila «Novedades» en Ajustes › Ayuda. El contenido se escribió el 2026-10-17 con lo que ya estaba mergeado en 2.2 en esa fecha: el Panel más claro (lote 3), voz, foto y Bandeja (lote 4) y «Primeros pasos» sin candados (lote 5). Son tres tarjetas en `WhatsNewConfig.version2_2`, con textos `whatsNew.v22.*` en los 16 idiomas.

2.2 sigue recibiendo trabajo (los lotes 6 a 20, Siri con IA, el conector MCP…), así que la hoja puede quedarse corta o nombrar algo que cambió. Hoy no la ve nadie: `MARKETING_VERSION` sigue en 2.1, y la hoja sale solo al actualizar a una versión con entrada.

## Hecho cuando

Antes de subir el primer build 2.2 a TestFlight, las tarjetas de `version2_2` cuentan lo que de verdad trae 2.2 (como mucho tres o cuatro, en lenguaje de usuario), en los 16 idiomas, y `WhatsNewLaunchUITests` comprueba la hoja de 2.2.
