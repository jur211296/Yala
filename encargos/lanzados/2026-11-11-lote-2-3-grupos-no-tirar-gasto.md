Yala
# Decidido 9-nov 2.3 · Grupos: no tirar el gasto a medias y unificar «Saldos» y «Saldar»
card: tablero-2-3-grupos-no-tirar-el-gasto-a-medias-y-6qf0
toca: Yala/App/Views/Groups/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 39 y 40. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/37-grupos/ficha.md. El saldar C1–C3 y la moneda al apagar «deudas en una moneda» ya van en el lote necesario 01, ya encolado.

## Encargo y criterio de terminado
Implementar SOLO estos 2 puntos:
1. La X deja de tirar el gasto a medias sin preguntar (F1 + F3): preguntar antes de descartar si hay algo escrito (también en «Apuntar pago» y «Saldo inicial»). Cambiar de grupo conserva lo escrito y «Nuevo gasto» abre en el último grupo usado.
2. Un solo vocabulario para saldar y el puente, en los 16 idiomas: «Saldos» (pantalla), «Saldar» (acción y botón; sustituye «Apuntar pago» y «Liquidar»), «Pago» (lo registrado, estado «Confirmado»); «Para quedar a mano» solo como título de sección. Puente: un nombre, «Reflejar en tus cuentas».

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones (semi; resueltas por Frank, menores y reversibles)

- **Base.** `origin/2.3..origin/2.2` daba 16. Jürgen autorizó (11-nov) hacer el merge corto aquí: va en su propio PR a 2.3 y el lote se apoya en esa rama. Ninguna de las vistas del lote tiene cambios en 2.2 (`git log origin/2.3..origin/2.2` vacío en las cinco).
- **«Algo escrito» (F1)** = lo de ahora es distinto de lo que había al abrir, precargado incluido (molde de Nuevo registro, `formSnapshot` contra la foto de partida). Así «Saldar» sin tocar nada no pregunta (su importe viene precargado) y la edición de un gasto solo pregunta si se cambió algo.
- **Qué preguntan**: la X y el gesto de bajar la hoja, en «Nuevo gasto» (crear y editar, también desde la Bandeja), «Saldar» y «Saldo inicial». Alerta «¿Descartar este gasto / pago / saldo inicial?» con «Descartar» y «Seguir editando» (los textos de Nuevo registro). Sin mensaje debajo, como Nuevo registro.
- **F3, qué viaja al cambiar de grupo**: descripción, importe, moneda, fecha, nota, categoría y cuenta (las dos últimas son tuyas, no del grupo). Quién pagó y el reparto vuelven a empezar (son personas del grupo de antes), y una línea lo dice. La moneda se queda porque el importe se escribió en ella.
- **«Último grupo usado»** = el último donde guardaste un gasto en este teléfono (`groups.lastExpenseGroupID`). Si ya no admite gastos, abre en el primero, como antes. Se borra con las demás preferencias al cerrar sesión. Aplica a «Nuevo gasto» de la lista, al flotante y al «Grupo» del + del Panel sin grupo pedido; el menú de una tarjeta sigue abriendo en esa tarjeta.
- **Vocabulario (decisión 40)**: «Saldar» en el título y el botón del formulario (antes «Apuntar pago»); «Confirmado» (antes «Confirmada»); el resumen compartido titula su sección «Para quedar a mano» (antes «Para saldar»); el puente se llama «Reflejar en tus cuentas» en los tres interruptores y en la pregunta tras guardar («¿Reflejar en tus cuentas?» · «Sí, reflejar»). Las claves sin uso (`groups.settlement.settle` «Liquidar», `groups.summary.pendingSettlements`) y las categorías del sistema («Pago de liquidación»…, nombres que pueden estar guardados) no se tocan: se anotan.
- **Tests**: XCUITest `GroupsNoTirarLoEscritoUITests` (F1 en las tres hojas, F3 y el último grupo) y unit `VocabularioSaldarYReflejarTests` (16 idiomas) + `GroupFormDiscardLogicTests`. Rojos sin el arreglo antes de darlos por buenos.
- **PR #894 (lote 01, abierto)** toca `SettlementFormView` y `GroupOpeningBalanceFormView`: no hace lo mismo (pregunta antes de REEMPLAZAR un saldo inicial). Si entra antes, se resuelve el cruce al ponerse al día.
