Yala
# Mejoras necesarias 2.3 · Grupos: pagos que se duplican, dígitos que se pierden y cambios sin aviso
card: tablero-mejoras-necesarias-2-3-grupos-pagos-que-d8nx
toca: Yala/App/Views/Groups/,Yala/Services/Groups/,Yala/App/ViewModels/,Yala/Resources/
esfuerzo: high

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 01 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/37-grupos/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/856 https://github.com/jur211296/Yala/pull/857.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. Reintentar tras un fallo solo de la confirmación duplica el pago entre personas (ticket settlement-retry-after-a-failed-confirmation-duplicates-the-payment).
2. El campo de un reparto desigual conserva el valor viejo y pierde dígitos: borrar y escribir 150 dejó 1,100.00 (ticket group-split-amount-field-keeps-the-old-value-and-drops-typed-digits).
3. Un grupo archivado deja apuntar gastos y saldar desde dentro aunque la lista no lo ofrece (ticket archived-group-still-allows-expenses-and-payments-from-inside).
4. Añadir un saldo inicial entre dos personas que ya tienen uno lo reemplaza sin avisar y con pagos el error habla de borrar el gasto (GroupExpenseService.swift:294-333 y :926-927).
5. Importar todo el historial del puente solo se ofrece si ya hay movimientos reflejados: al activarlo la primera vez no sale (ticket bridge-history-import-is-only-offered-when-something-was-already-bridged).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Review adversarial obligatoria (varias lentes y refutación por hallazgo): toca pagos entre personas, saldos y el puente con tus cuentas.
- Punto 2: el «1,100.00» se midió con toques sintéticos; confírmalo con el dedo en el iPhone 14 por DeviceMCP o déjalo en el guion de QA. Si no se reproduce con el dedo, documéntalo y no lo arregles a ciegas.
- Punto 4: el arreglo es preguntar antes de reemplazar (mueve datos) y corregir el texto del error; no cambies qué se guarda.
- No choques con el PR abierto de 2.2 sobre borradores de grupo duplicados ni con el encargo «Pasar un gasto personal a grupo»: si comparten fichero, rebasa y cita.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
FIN
