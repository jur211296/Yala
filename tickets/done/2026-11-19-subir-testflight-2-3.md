---
id: 2026-11-19-subir-testflight-2-3
status: done
priority: high
area: "release, testflight"
created: 2026-11-19
updated: 2026-11-19
source: "encargo 2026-11-19 · Subir a TestFlight la 2.3 con Flujo de caja nuevo y el CI en verde"
---

# Yala 2.3 (4) a TestFlight

## Paso 0
- Base `origin/2.3` al día; el CI QA de esa base terminó en verde antes de subir (run 44532911992).
- Build 4: la última en App Store Connect para 2.3 era la 3 (medido con `asc builds list`).
- Archivado con el DerivedData por defecto (8 GB libres en la Mini: un DerivedData aparte no cabía holgado).
- Grupo «Test interno»: tiene acceso a todas las builds, así que la recibe solo; no se envía a revisión externa ni de App Store.
- Pase de estrés: no aplica a este PR, que no toca UI; lo cubre el barrido de QA que viene después.

## Resultado
- 2.3 (4) archivada (app, widgets y extensión de compartir en 2.3 (4)), dSYM a Sentry por el post-action del scheme, subida con `xcodebuild -exportArchive` y `.asc/ExportOptions.plist`.
- App Store Connect: VALID, `internalBuildState` IN_BETA_TESTING.
- Notas «Qué probar» (es-MX): `docs/qa/testflight-2-3-4/notas-que-probar.txt`.
- Decisión del 19-nov sobre la proyección de Flujo de caja registrada en `docs/DECISIONS.md` (sin ejecutar).
