Yala
# Mejoras necesarias 2.3 · Planificación: saltar no es pagar, mes cerrado, presupuesto de un día y límite gratis
card: tablero-mejoras-necesarias-2-3-planificacion-sal-7nwx
toca: Yala/App/Views/Planning/,Yala/App/ViewModels/,Yala/Resources/
esfuerzo: high

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 04 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/34-planificacion/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/852.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. Tras Saltar este mes el detalle dice Noviembre de 2026 ya está pagado; y «No se apunta nada; los demás meses siguen igual» va bajo los dos botones y se lee también como explicación de Ya lo pagué (card tablero-tras-saltar-este-mes-el-detalle-del-pago-86m8; ScheduledPaymentDetailView.swift:202-210 y :251-258).
2. Un mes cerrado sigue diciendo Te quedan S/ 266.00: en un mes que ya acabó es lo que sobró.
3. Un presupuesto Único de un solo día no se puede guardar porque exige inicio menor que fin y por defecto las dos fechas son hoy: el ✓ se apaga sin decir qué falta (BudgetEditorView.swift:869-879).
4. Reactivar un presupuesto inactivo no comprueba el límite del plan gratis (inferido en BudgetEditorView; reproducir antes de arreglar).
5. VoiceOver: el segmentado de pagos se llama Tab; seis selectores del editor de pagos no tienen nombre; la fila de presupuesto no dice lo que queda ni los días (ScheduledPaymentsView.swift:127; ScheduledPaymentEditorView.swift:296 1010 1024 1137 1145 1297; BudgetRowView.swift:142-145).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Punto 1 construye sobre la card en QA de los botones que nombran el mes (PR 753): no la rehagas. El arreglo es que saltado no se rotule pagado y que el aviso de «No se apunta nada» vaya con Saltar.
- Punto 4: reprodúcelo antes con un test; si no se reproduce, documéntalo y no toques nada. El límite del plan no se salta nunca: la persona elige qué entra o pasa a Pro.
- Punto 5: comprobación con VoiceOver en el iPhone 14 en el guion de QA; no bloquea el merge.
- No toques umbrales ni la barra: el naranja al 80 % ya está en 2.2 y viene con la integración de 2.2 en 2.3.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
FIN
