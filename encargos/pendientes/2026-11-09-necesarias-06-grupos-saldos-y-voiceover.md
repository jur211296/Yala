Yala
# Mejoras necesarias 2.3 · Grupos: saldos que se contradicen y lectura con VoiceOver
card: tablero-mejoras-necesarias-2-3-grupos-saldos-que-pl00
toca: Yala/App/Views/Groups/,Yala/Resources/
esfuerzo: high

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 06 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/37-grupos/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/856 https://github.com/jur211296/Yala/pull/857.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. Saldos dice «Tú no le debes nada a nadie» encima de «Tú pagas a Ana S/ 40.00» (problema 1 A4 de la zona 37; GroupBalancesView).
2. La tarjeta de deuda dice «Beto paga a Tú» (ticket group-debt-card-reads-pays-to-tu).
3. ¿Quién puso más?: las barras pasan por encima de los nombres también a tamaño normal y la tuya dice Lucía y no Tú (ticket group-stats-who-paid-most-bars-cover-the-names).
4. VoiceOver lee el importe del gasto como 0.00 y la moneda y las filas de pago sin su dato (problema 5 E4 de la zona 37).
5. ¡Están al día! sale también en un grupo recién creado sin ningún gasto (GroupBalancesView.swift:69-76).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Punto 1: la frase tiene que ser verdad con «Menos pagos» encendido y apagado; no cambies el valor por defecto de «Menos pagos» (A1 queda para Jürgen).
- Punto 4: comprobación con VoiceOver en el iPhone 14 en el guion de QA; no bloquea el merge.
- El vocabulario de saldar y los nombres del puente siguen sin decidir: no los toques.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
FIN
