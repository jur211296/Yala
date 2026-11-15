Yala
# Bienvenida 2.3 · Pasos 3, 4 y 5: presupuesto, pagos y grupos
card: tablero-bienvenida-2-3-paso-3-primer-presupuesto-4l1q,tablero-bienvenida-2-3-paso-4-primer-pago-planif-s5nd,tablero-bienvenida-2-3-paso-5-grupos-con-el-esti-yuyn
toca: Yala/App/Views/Planning/, Yala/App/Views/More/, Yala/App/Views/Groups/, Yala/App/Views/Panel/, Yala/App/Views/Notifications/, Yala/App/ViewModels/, Yala/App/Logic/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3, Yala/bienvenida-2-3-pasos-1-y-2-cuenta-y-registrar

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 04 de 5 de la implementación oficial de Primeros pasos de Yala 2.3. Fuente: docs/onboarding-2-3/SPEC.md, cards Y23-11, Y23-12 y Y23-13. Prototipo oficial v35, pestañas 5 · Primer presupuesto, 6 · Pagos planificados y 7 · Grupos: https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6. Depende del lote 03 (el mazo llega al paso 3 con el Panel ya lleno). Usa las pestañas por defecto, las guías hacia Más y los momentos de permiso del lote 01. Las decisiones ya están en el SPEC; no se reabren.

## Encargo y criterio de terminado
Implementar SOLO estas 3 cards, cada una tal como está en su sección del SPEC:
1. Y23-11 · Paso 3 · Primer presupuesto (atajo `#pre`). Crear preguntando; 75 por ciento y 100 por ciento por defecto; guía «Tus presupuestos viven en Más»; widget en el Panel solo si dijo que sí. Permiso de notificaciones solo si elige aviso (Y23-17). Fuera de alcance: cuentas, etiquetas, necesidad, gastos de grupo, 50/90 por ciento, personalizar y sugerir el monto.
2. Y23-12 · Paso 4 · Primer pago planificado (atajo `#pag`). Elegir por subcategoría al empezar (sin marcas tipo Netflix); nombre precargado; preguntar si va al Panel; reintento de notificaciones (Y23-17). Fuera de alcance: «Cada N», plazos 2/5/7/14/30 días y gasto compartido.
3. Y23-13 · Paso 5 · Grupos con este estilo (atajo `#gru`). El onboarding de hoy como página del tutorial. Si hasShownGroupsOnboarding ya está en sí, el paso se salta y un aviso lo dice; si se completa aquí, se marca para que Grupos no lo repita. Guía «Tus grupos, a un toque».

Reglas del lote:
- Los textos exactos y el comportamiento salen del SPEC y del prototipo. No se reabren decisiones. Si el artifact y la ficha no coinciden, manda la ficha y se avisa en el cierre.
- Compara con el prototipo (https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6, versión 35) y deja capturas antes y después de lo que se vea, en `capturas/` del worktree.
- Accesibilidad de la ficha «Cómo usar esta especificación»: Reducir movimiento deja solo fundidos y las páginas que avanzan solas se quedan quietas; VoiceOver no avanza solo; texto grande no corta.
- Textos en español neutro, con «tú», según docs/planning/BRAND-VOICE.md. Los textos marcados «de la app» se copian de Localizable.strings, no se reescriben.
- Un test de comportamiento por card (unit o XCUITest según `qa/coverage-index.json`). Review adversarial obligatoria.
- Si un punto exige una decisión de producto que no esté ya en el SPEC, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa. Infraestructura o un hueco del servidor: `BLOQUEANTE:`, sin inventar.
- No choques con otras sesiones de bienvenida ni con los lotes 2.3 ya en cola: si comparten fichero, rebasa y cita.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:55 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- La especificación oficial vive en `docs/onboarding-2-3/SPEC.md` (entró por el PR 873 en 2.2; tras el merge tiene que estar en origin/2.3). Léela completa para las cards de este lote y no implementes lo que sea de otra card.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve las cards a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones (resueltas en autónomo, modo semi)

1. **Base.** La rama 2.2 ya no existe (se borró al cerrar la 2.2); `origin/1.0` solo trae 7 arreglos de web/gateway que no están en 2.3. El merge de 2.2 en 2.3 está hecho. El lote 03 (pasos 1 y 2) sigue en cola de auto-merge (PR 938) y comparte ficheros (Panel, mazo, textos): la rama se apila sobre la suya y se rebasa sobre `origin/2.3` antes del gate.
2. **Decisión pendiente de los workflows de 2.2 → 2.3**: ya la hizo el lote 03 (commit `chore(ci)` en su PR). Aquí no se repite; se dice en el cierre.
3. **Prototipo.** El artifact no se lee desde Claude Code; la fuente v35 está en la Max (`09e`, `09g`, `09h`). Textos del prototipo donde la ficha no los da.
4. **Pasos 3 y 4: flujo propio a pantalla completa desde el mazo**, con el molde del paso 1 (página corta de tres partes + preguntas con la tarjeta llenándose). Guardan con los ViewModels de hoy (`BudgetEditorViewModel.saveBudget`, `ScheduledPaymentEditorViewModel.savePayment`): mismos datos que el editor, sin camino de guardado nuevo.
5. **«¿Lo ponemos en tu Panel?» = sí** enseña la sección Planificación con SOLO ese widget (al terminar el paso 2 el Panel solo tiene cuenta y Últimos registros); en presupuestos además marca «Mostrar en el widget».
6. **Avisos del presupuesto**: 75 % y 100 % destacado. Elegir aviso pide el permiso de iOS si nunca se pidió (Y23-17) y enciende las alertas de presupuesto globales si queda permitido, como el editor.
7. **Aviso del pago**: 3 días antes (defecto), 1 día antes, el mismo día, No → un solo aviso guardado (`notifyDaysBefore` 3/1, o `notifyOnDueDate` el mismo día). Reintento de notificaciones con `tutorialNotificationRetry` del lote 01.
8. **Pago: subcategoría** por icono del seed (único por subcategoría de gasto); «Otra subcategoría» reusa `SubcategorySelectorSheet` (rejilla de 4 y buscador). Cuenta: la última usada o la primera activa, como el editor.
9. **Paso 5 Grupos**: el onboarding de hoy (tres pantallas, mismos textos) como página del tutorial; el consentimiento no avanza solo y acepta por el mismo escritor (`GroupsConsentView.registerAcceptance`). «¿Qué quieres hacer?»: crear → el formulario de grupo de siempre en la pestaña Grupos (misma puerta de cuenta y consentimiento, que da «Conecta tu cuenta» con iCloud privado); enlace → la pantalla de pegar enlace de siempre y la unión de siempre. No se construye un camino de creación de grupos nuevo: la ficha dice que GroupFormView y la hoja de invitar ya existen. La guía «Tus grupos, a un toque» sale al volver al Panel tras elegir crear o unirse.
10. **Marcas del paso 5**: Omitir antes del consentimiento no marca `hasShownGroupsOnboarding` y omite el paso; «Ahora no» tras verlo lo marca y omite el paso; crear o unirse lo marca y da el paso por hecho. Con la marca ya puesta, el paso se da por hecho con el aviso.
11. **Textos**: claves nuevas `pasos23.budget.*`, `pasos23.payment.*`, `pasos23.groups.*` en los 16 idiomas; se reusan las que ya existen (onboarding de Grupos, consentimiento, guías, períodos, cadencias del resumen del pago).
12. **Pruebas**: unit por card (lógica pura + guardado contra un contexto en memoria) y XCUITest del flujo del presupuesto si cabe en el presupuesto de 30 min.
