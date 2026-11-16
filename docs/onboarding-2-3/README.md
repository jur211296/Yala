# Bienvenida y Primeros pasos · Yala 2.3

Diseño **oficial** (9-nov-2026) de la bienvenida, el alta y el tutorial «Primeros pasos» de 7 pasos.

- **Prototipo navegable (artifact privado de Claude):** https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6 — versión 35.
  Ocho pestañas: 1 Mis finanzas · 2 Viene por grupos · 3 Primera cuenta · 4 Nuevo registro · 5 Primer presupuesto ·
  6 Pagos planificados · 7 Grupos (paso 5) · 8 Pasos 6 y 7. Debajo del teléfono, la especificación por cards.
- **Especificación:** [`SPEC.md`](SPEC.md) — 19 cards (Y23-01 … Y23-19) con: dónde se ve, qué ve la persona, textos exactos,
  qué existe hoy, qué hay que construir, dependencias, fuera de alcance y criterios de aceptación.
- **Cómo partir en cards:** una card del tablero por ID. Cada card lee su sección de `SPEC.md` y su pestaña del artifact
  (el atajo `#…` abre la pantalla exacta). No se implementa nada que no esté en su card.
- **Fuente del prototipo** (no está en el repo): `~/Claude/entregas/onboarding-yala-20261107/prototipo/` en la Max
  (`fuente-actual/`, `build-actual.py`, `gen_spec.py`, README con el historial de decisiones).
- **Sesiones:** 7-nov (bienvenida y alta, encargo `2026-11-07-onboarding-artifact-tres-direcciones`) y 9-nov
  (Primeros pasos, encargo `2026-11-09-onboarding-artifact-procesos`).

Decisiones que más pesan (detalle en SPEC.md):
- Prueba de Pro: **la oferta de la App Store de 30 días** al completar Primeros pasos, con un toque; Apple no deja activarla sola (3.1.2).
- Pestañas por defecto para instalaciones nuevas: **Panel · Grupos · Registros** + Más y Buscar.
- Permisos solo cuando la persona elige usar la función; las notificaciones se piden al decir «sí, recuérdame».
- «Tu correo» (reenvío automático) es una feature nueva del roadmap 2.3: hasta que exista, el paso 7 muestra 4 maneras.
