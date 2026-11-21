---
id: 2026-11-20-subir-testflight-2-3-build-6
status: done
priority: high
area: "release, testflight"
created: 2026-11-20
updated: 2026-11-21
source: "encargo 2026-11-21 · Subir a TestFlight la build 6 de 2.3 con todo lo mergeado desde la build 5"
---

# Yala 2.3 (6) a TestFlight

## Paso 0
- Base: `origin/2.3` al arrancar (merge del Flujo de caja con varios pagos y moneda). No había PRs abiertos en cola de auto-merge contra 2.3: no se esperó a nadie.
- Build 6: la última en App Store Connect para 2.3 era la 5 (medido con `asc builds list`).
- Archivado en la Mini, dentro del tmux de la sesión, con el DerivedData por defecto. Se archiva mientras corre el CI de la base; solo se sube con ese CI en verde.
- Grupo «Test interno»: recibe todas las builds solo. No se envía a revisión de App Store ni a testers externos.
- Pase de estrés: no aplica, este PR no toca UI.
- Notas en español neutro (es-MX), sacadas de los PRs mergeados desde la build 5, sin ids.

## Resultado
- Notas «Qué probar» (es-MX): `docs/qa/testflight-2-3-6/notas-que-probar.txt`.
