---
id: 2026-11-19-subir-testflight-2-3-build-5
status: done
priority: high
area: "release, testflight"
created: 2026-11-19
updated: 2026-11-19
source: "encargo 2026-11-19 · Subir a TestFlight la build 5 de 2.3 con los PRs atascados, el Flujo de caja nuevo y el contraste del modo claro"
---

# Yala 2.3 (5) a TestFlight

## Paso 0
- Esperar a que entren a 2.3 los PRs atascados, el Flujo de caja nuevo y el contraste del modo claro. Los dos primeros ya estaban; el contraste quedó 3 h en la cola del CI y entró a las 17:13 Lima. El bot dueño decidió seguir esperando pasados los 30 min del encargo (tope 18:30 Lima).
- Build 5: la última en App Store Connect para 2.3 era la 4 (medido con `asc builds list`).
- Archivado en la Max, dentro del tmux de la sesión, con el DerivedData por defecto. Se archiva mientras corre el CI de la base, y solo se sube con ese CI en verde.
- Grupo «Test interno»: tiene acceso a todas las builds. No se envía a revisión de App Store ni a testers externos.
- Pase de estrés: no aplica a este PR, que no toca UI.
- La proyección inteligente entró a 2.3 después de que se subiera la build 4: va en las notas como novedad.

## Resultado
- Notas «Qué probar» (es-MX): `docs/qa/testflight-2-3-5/notas-que-probar.txt`.
