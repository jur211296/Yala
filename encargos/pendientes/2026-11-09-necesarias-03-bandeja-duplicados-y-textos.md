Yala
# Mejoras necesarias 2.3 · Bandeja: duplicados en el lote, borradores fuera de la lista y textos de Siri y Apple Pay
card: tablero-mejoras-necesarias-2-3-bandeja-duplicado-btrx
toca: Yala/App/Views/Inbox/,Yala/Services/DraftService.swift,Yala/App/Views/Settings/,Yala/Resources/
esfuerzo: high

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 03 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/38-bandeja-ia/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/860.

## Encargo y criterio de terminado
Implementar SOLO estos 4 puntos:
1. Guardar los N listos y deslizar para guardar no buscan duplicados; solo el borrador abierto lo hace (ticket inbox-bulk-save-and-swipe-skip-the-duplicate-check).
2. La lista lee como mucho los 500 borradores más recientes con archivados incluidos y un pendiente antiguo puede quedar fuera (ticket inbox-list-capped-at-500-may-hide-old-pending-drafts).
3. La pantalla de Siri dice Requiere Yala Pro aunque Anota un gasto en Yala funciona sin Pro con el modelo de Apple en el teléfono (ticket siri-shortcuts-screen-says-pro-required-for-on-device-users).
4. La guía de Apple Pay dice en su paso 4 «Haz lo mismo para Comercio y Nombre respectivamente» y su contador de pagos en la Bandeja no dice si la automatización está creada (Localizable tutorials.applePay.step3.desc).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Punto 1 con review adversarial: el lote y deslizar no pueden perder ni duplicar borradores. Lo mínimo es que salten los posibles duplicados y lo digan; no rediseñes la Bandeja (B1 y C1 de la revisión quedan para Jürgen).
- Punto 3: Siri gratis en el teléfono está encendido desde el 21-oct (SiriOnDeviceEntry.isEnabled = true). La card de QA de esa decisión no se toca: solo la pantalla de Siri dice la verdad según quién la mira.
- Punto 4: solo el texto de la guía y del contador; no muevas la guía de sitio (A2 queda para Jürgen).
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
FIN
