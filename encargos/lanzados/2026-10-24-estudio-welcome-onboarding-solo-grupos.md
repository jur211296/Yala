# Estudio del welcome y onboarding: caminos a solo grupos (antes del barrido) — card dq2g

## Contexto
Pedido de Jürgen 24/10 (DoFutalk): mucho foco en quien baja Yala solo para grupos, tipo reemplazar Splitwise. Hoy «vengo por un grupo» no representa a quien quiere probar algo como Splitwise: suele elegir «empezar de cero» y desde ahí no hay camino a solo-grupos.

Card: `tablero-estudio-del-welcome-y-onboarding-caminos-dq2g` (high, propuesta-visual, 2.2, ready→in progress).
Desbloqueos: lanzar ANTES del barrido de QA 2.2 (`…-fzmv`). Relacionada con `tablero-pasar-de-la-app-completa-a-solo-grupos-s-p0iu` (no implementar ese paso aquí).

Base: `origin/2.2`. PR #615 (tartas «Sin categoría») puede estar en cola de auto-merge: justo antes del gate de build/sim, mira si ese PR sigue en CI; si sigue, espera a que entre y rebasea una sola vez con el simulador apagado; si 2.2 no se movió, sigue de frente; si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador van después de ese rebase, una sola vez.

Pipeline serial en la Mini (1 sim): limpiar → build con `xcodebuild -jobs 2` sin sim → boot 1 sim → capturas/pruebas de recorrido → apagar/limpiar. Al cerrar: apagar sims, quitar DerivedData de ESTE worktree y cachés XcodeBuildMCP de worktrees que ya no existen; no preguntes.

## Que se pide
Sesión de ESTUDIO solamente: análisis y propuestas. No implementar el diseño final ni cambiar el flujo en código de producto (salvo tests/docs/capturas que hagan falta para documentar el estado actual).

1. Mapear cada camino del welcome y del onboarding relevante (primera apertura, «vengo por un grupo», «empezar de cero», ya tengo cuenta, invitación/enlace, solo-grupos si existe, nube vs iCloud donde toque al camino).
2. Para cada camino: qué ve la persona, a dónde llega, y dónde se pierde quien bajó la app para usar Yala solo como grupos (reemplazar Splitwise) sin enlace de invitación.
3. Evaluar y dejar propuestas concretas (copy y/o flujos), al menos estas ideas sin decidir aún:
   - mejorar el texto de «vengo por un grupo»;
   - reponer solo-grupos dentro de «empezar de cero»;
   - una opción más abierta que no obligue a crear grupo ni entrar solo con enlace.
4. Capturas del estado actual (antes) de las pantallas clave del welcome/onboarding que alimentan las propuestas; dejarlas en `capturas/` del worktree.
5. Entregar en el PR un documento claro (p. ej. bajo `docs/` o el ticket) con el mapa de caminos, hallazgos y 2–3 propuestas comparables (alcance, copy sugerido, riesgos). Jürgen elige después; esta sesión no inventa el diseño final.

## Que NO hay que tocar
- No implementar la opción ganadora ni rediseñar pantallas «en serio».
- No lanzar ni tocar el barrido de QA 2.2.
- No implementar `…-p0iu` (pasar de app completa a solo grupos).
- No tocar marketing/, App Store Connect, ni producción.
- No CloudAgent.

## Como se sabe que esta bien
- PR abierto a 2.2 con el análisis + propuestas concretas y capturas del estado actual.
- Card dq2g queda lista para que Jürgen elija (in qa o awaiting decision según el cierre); no hace falta su OK en vivo para cerrar la sesión.
- Cierra con `/cerrar-total` (no te quedes esperando la elección de Jürgen). Tests/unitarios del repo en verde si tocaste código de soporte; si solo docs/capturas, no hace falta suite completa.

## Paso 0 (Frank, 2026-10-24 — auto-contestado, sesión lanzada)

- **Entregable**: `docs/sessions/2026-10-24-welcome-caminos-solo-grupos.md` (mapa de caminos medido en código +
  hallazgos + 3 propuestas comparables) y un HTML de maquetas de las propuestas para verlas en el móvil. Sin código
  de producto. Asumido: `docs/sessions/` porque es donde viven los estudios del Welcome (2026-09-09).
- **Capturas del «antes»**: con un XCUITest conductor **local, sin commitear** (no hace falta como red; commitearlo
  obligaría a meterlo en el índice de cobertura). Van a `capturas/` y se copian a `~/Claude/worktrees/_capturas/<slug>/`.
- **Propuestas, no diseño**: las maquetas son HTML con la forma del Welcome (`WelcomeFormScreen`), no SwiftUI. Asumido
  por «no implementar el diseño final».
- **Entrega por PR** aunque el diff sea solo `docs/`: el encargo lo pide para que Jürgen mire antes. Cierre en modo cola.
- **PR #615**: no se espera (regla de sesión lanzada: un solo fetch + rebase antes del PR).
- **Card dq2g** → `awaiting decision` al cerrar, con la nota de qué elegir.
