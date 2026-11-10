Yala
# Decidido 9-nov 2.3 · iPad: ancho legible en Estadísticas, Flujo, Grupos y Cuentas
card: tablero-2-3-ancho-legible-en-el-ipad-estadistica-k1al
toca: Yala/App/Views/Statistics/,Yala/App/Views/Reports/,Yala/App/Views/Groups/,Yala/App/Views/Accounts/,Yala/App/DesignSystem/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 7 (opción C). Card reutilizada. Fichas: 35-estadisticas, 36-reportes-flujo, 37-grupos y 39-cuentas-categorias. Dos columnas quedan para después, vista por vista con maqueta: no las diseñes ahora.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. En el iPad, Distribución, el flujo de caja, el detalle de un grupo y la ficha de una cuenta pasan al ancho legible que ya existe (`DS.Adaptive.readableWidth`, 700 pt). La ficha de una cuenta deja de ir en una hoja de media pantalla.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- No diseñes el layout de dos columnas. Solo el ancho legible de 700 pt en las cuatro vistas.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Paso 0 — decisiones

> Modo semi: decisiones menores y reversibles, resueltas por Frank con su recomendación. Se discuten en el PR.

**Hechos medidos antes de decidir (10-nov).** `git rev-list --count origin/2.3..origin/2.2` = 3, y los tres son número de build y documentos: «casi 0», se sigue. La rama nació de 2.2 y se rehízo sobre `origin/2.3`. `git log origin/2.3..origin/2.2` sobre las seis carpetas: 0 commits, así que 2.2 no arregló nada de esto. La sesión que el aviso daba por viva sobre las mismas carpetas (`registrar-decisiones-2026-11-05`) no tiene rama remota, worktree ni tmux. El único PR abierto que toca estas carpetas (flujo proyectado) toca `TrendsTabView.swift`, que este lote no toca.

**D1 · ¿Qué es «la ficha de una cuenta» de la ficha 39?** → `AccountFormView` (Ajustes › Cuentas › una cuenta, y el alta). La captura `ipad-c08-form-ahorros` y el hallazgo («la ficha de una cuenta se abre en una hoja centrada de media pantalla») son de ese formulario. Alternativa descartada: `AccountDetailSheet` del Panel, que es de la ficha 30 y ya lleva el ancho legible.

**D2 · ¿Cómo deja de ser una hoja de media pantalla?** → `.presentationSizing(.page)` en el formulario, como la hoja de Ajustes, más el contenido a 700 pt. En el iPhone `.page` es la hoja de siempre. Alternativa descartada: pantalla completa (`fullScreenCover`), que cambia cómo se cierra y no lo pidió nadie.

**D3 · ¿Qué entra en «el flujo de caja»?** → Todo el contenido de la pestaña Reportes: la Comparativa, el armado del plan y el mes. El hallazgo de la ficha 36 nombra las tres («la Comparativa, el armado y las tarjetas del mes») y la decisión 7 cubre la ficha entera. Alternativa descartada: solo el mes, que dejaba la mitad de la pantalla de la ficha a todo lo ancho.

**D4 · ¿Qué se lleva a 700 pt?** → El contenido de cada página, dentro de su scroll, centrado (molde de `BudgetDetailView`). El scroll sigue a todo lo ancho, así que se desplaza tocando en los márgenes. Las barras de chips de arriba y el título grande se quedan como están: la de Estadísticas es común a Resumen y Tendencias, que siguen en dos columnas, y alinear unas sí y otras no sería diseñar. Alternativa descartada: recortar la página entera, que deja los márgenes sin scroll.

**D5 · ¿Pieza nueva del Design System?** → Un modificador `readableColumn()` en `DesignSystem/` que hace el `frame(maxWidth: readableWidth)` + `frame(maxWidth: .infinity)` de siempre. Por qué: son seis sitios con el mismo par de líneas, y una sola pieza evita que diverjan. No se migran los usos que ya existen (fuera de alcance).

**D6 · ¿Qué test de regresión?** → Un XCUITest por punto en `ReadableWidthIPadUITests`, que corre en el iPad Pro 13 y mide una fila o tarjeta real a todo lo ancho (≤ 700 con el arreglo, ~1.000 sin él). El grupo se mide en horizontal: en vertical, con la lista al lado, la columna ya mide menos de 700. La ficha de cuenta mide el campo del nombre: pasa de 580 pt, más que la hoja pequeña entera (~580), y no pasa de 700. En iPhone los casos se saltan diciéndolo. Alternativa descartada: source-scan, que no mide el ancho.

**D7 · Copy.** → No hay texto nuevo: no toca los 16 idiomas.
