---
id: 2026-11-23-subir-testflight-2-3-build-7
status: done
priority: high
area: "release, testflight"
created: 2026-11-23
updated: 2026-11-23
source: "encargo 2026-11-23 · Subir a TestFlight la build 7 de 2.3 y poner al día la guía de novedades 2.3"
---

# Yala 2.3 (7) a TestFlight y guía de novedades al día

## Paso 0
- Se espera el PR de «Hacer recurrente» con pantalla de éxito (iOS). El de la web a Cloudflare entró solo con `Web/`.
  Ese PR quedó en conflicto de índices sin sesión viva: se mergeó 2.3 en su rama y se empujó.
- Build 7: la última de 2.3 en App Store Connect era la 6. Archivo en la Max, dentro del tmux de la sesión, sobre
  `origin/2.3` + «Hacer recurrente» + este cambio; se sube cuando ese PR está dentro.
- Guía de novedades: de la 2.3 (2) a la 2.3 (7), con el delta en `docs/guias/novedades-2-3/delta_2026_11_23.json`.
- Pase de estrés: no aplica, este PR no toca UI.

## Resultado
- Notas «Qué probar» (es-MX): `docs/qa/testflight-2-3-7/notas-que-probar.txt`.
- Archivo 2.3 (7): app, widgets y extensión en 2.3 (7); dSYM (3) en Sentry y commits asociados a la release.
- Guía: https://claude.ai/artifact/3PhSbBHvWRMX3pohZw5Gty (pública). 361 ítems, 148 nuevos o cambiados.
