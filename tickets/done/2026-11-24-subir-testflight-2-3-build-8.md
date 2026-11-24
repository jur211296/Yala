---
id: 2026-11-24-subir-testflight-2-3-build-8
status: done
priority: high
area: "release, testflight"
created: 2026-11-24
updated: 2026-11-24
source: "encargo 2026-11-24 · Subir a TestFlight la build 8 de 2.3 y poner al día el artifact de novedades 2.3"
---

# Yala 2.3 (8) a TestFlight y guía de novedades al día

## Paso 0
- Se espera el PR de «Estadísticas › Resumen: opción B» (iOS), el único abierto contra 2.3. Quedó en conflicto de
  índices sin sesión viva: se mergeó 2.3 en su rama y se empujó.
- Build 8: la última de 2.3 en App Store Connect era la 7. Archivo en la Mini, dentro del tmux de la sesión, sobre
  `origin/2.3` + Estadísticas › Resumen + este cambio; se sube cuando ese PR está dentro.
- Guía de novedades: de la 2.3 (7) a la 2.3 (8), con el delta en `docs/guias/novedades-2-3/delta_2026_11_24.json`.
  Se publica en la URL de la cuenta de la Mini (la de la 2.3 (7) es de la Max y desde la Mini no se puede escribir).
- Pase de estrés: no aplica, este PR no toca UI.

## Resultado
- Notas «Qué probar» (es-MX): `docs/qa/testflight-2-3-8/notas-que-probar.txt`.
- Guía: https://claude.ai/artifact/G74UBFLDowih9f2Rt5xaoS (pública). 375 ítems, 24 nuevos o cambiados. Sin notas de
  Jürgen en ninguna de las dos guías.
