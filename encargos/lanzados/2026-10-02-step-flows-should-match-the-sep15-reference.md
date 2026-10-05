# Acercar los flujos por pasos de Yala a la referencia del 15-sep

## Contexto
Cola B (Cola A real-risk vacía; adaptive 13/13 ya cerrado). Acaba de cerrar `ai-chat-reads-heavier-than-a-messaging-app` con PR #332 en cola de merge a 2.1. Siguiente del pack UI 15-sep: este ticket.

Ticket: `tickets/backlog/step-flows-should-match-the-sep15-reference.md`
Referencia visual: `docs/design/referencias/2026-09-15-flujo-por-pasos-cancelar-suscripcion.jpg`
Memoria: `.claude/agent-memory/frank/reference_ui_flujo_por_pasos.md`
Reglas de pulido si aplican: `.claude/agent-memory/frank/reference_skills_pulido_ui.md` (better-ui / emil-design-eng) — contrastar, no copiar recetas web.
Checklist iPad del carril B: `tickets/backlog/cola-b-redesigns-must-hold-up-at-ipad-width.md` — ancho legible ~700 pt centrado cuando el contenedor es ancho; decisión por size class / ancho, nunca por tipo de dispositivo. No implementes barra lateral ni lista-detalle de iPad.

Hermano pendiente del pack (NO tocar en esta sesión): `onboarding-login-should-match-the-sep15-reference`, `apply-better-ui-emil-design-eng-rules-to-redesigns`, cuentas/widgets post-rediseño.

## Qué se pide
1. Lee el ticket entero, la captura de referencia y la memoria `reference_ui_flujo_por_pasos.md`. Inventaria qué flujos por pasos existen hoy en Yala (cancelar, migrar, activar, y los que midas) — no te quedes con la lista del ticket.
2. Acerca esos flujos al patrón de la referencia, sin inventar copy ni flujos nuevos:
   - Progreso doble arriba (barras + «Paso N de M»).
   - Cabecera con contexto (qué se hace + datos vivos).
   - Lista numerada con hilo; solo el paso activo es accionable.
   - Miniatura «lo que vas a ver» cuando se sale de la app (si el flujo ya sale).
   - Línea de garantía (qué NO va a pasar).
   - Dos salidas al pie con jerarquía (éxito / me atasqué).
3. El componente vive en el design system si el patrón se reusa. Empieza por el flujo más visible / medible; migra los demás en commits separados si caben en la sesión. Lo que no quepa queda anotado en el ticket.
4. Ancho: tope legible (~700 pt) centrado en contenedores anchos. Nada decide por tipo de aparato.
5. Tests/UITests que afirmen el antes→después sin un segundo simulador. Pipeline de 1 sim abajo.
6. PR a `2.1` en cola de auto-merge. Ticket a `qa` o `done` según si Jürgen tiene que verlo en un iPhone. Al terminar: `/cerrar-total` autónomo (no dejar la sesión colgada).

## Pipeline Mini (obligatorio — serial, 1 sim)
1. Limpiar sims muertos / basura previa
2. Build con `xcodebuild -jobs 2` **sin** sim booteado
3. Boot **1** solo sim
4. Tests
5. Apagar / erase ese sim
Prohibido solapar swift-frontend + SpringBoard + app + UITests. Norma flota: 1 simulador a la vez.

## Qué NO hay que tocar
- Onboarding/login (ticket hermano).
- Chat Yala IA (#332) y Ajustes (#331) salvo componentes compartidos rotos.
- Cola A: nube, sesiones, migración de datos, grupos, CloudKit, schema.
- Carril adaptativo iPad/iPhone (fases, widgets grandes).
- Prod deploy. No CloudAgent.
- Identidad de tarjetas blancas sobre fondo no blanco.
- No inventar copy nuevo en idiomas sin necesidad; reusar cadenas.

## Cierre limpio Mini
Tras `/cerrar-total` exitoso: apagar sim usado → erase/limpiar data del device → si PR mergeado o worktree inútil, quitar worktree + caches; no acumular Devices apagados ni worktrees. Si creaste keys en Llavero, el bot dueño las mueve a 1Password (vault Yala); Shared with Grok Bot solo logins/paneles. Esta sesión no debería crear secretos.

## Cómo se sabe que está bien
- Al menos un flujo por pasos medible se lee como la referencia (progreso, cabecera viva, paso activo único, salidas con jerarquía).
- Capturas antes/después (iPhone + una ancha si aplica checklist B).
- Tests verdes en el pipeline serial de 1 sim.
- PR abierto a 2.1 + resumen de cierre en lenguaje de usuario + `/cerrar-total`.

## Paso 0 — decisiones
Día (Lima): si hace falta una decisión de producto que el ticket no haya cerrado (qué flujos entran primero, si un rasgo de la referencia no cabe en un flujo concreto), pregunta con AskUserQuestion y la opción recomendada. Técnicas (componente, ancho, tests, qué pantallas migrar en esta sesión) las resuelves tú midiendo el código actual.
