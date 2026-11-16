Yala
# Mejoras necesarias 2.3 · Texto grande en Estadísticas, Reportes, Bandeja, Ajustes y Etiquetas
card: tablero-mejoras-necesarias-2-3-texto-grande-en-e-zoid
toca: Yala/App/Views/Statistics/,Yala/App/Views/Reports/,Yala/App/Views/Inbox/,Yala/App/Views/Settings/,Yala/App/Views/Profile/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 05 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/35-estadisticas/ficha.md · docs/ux/revision-vistas-2.3/36-reportes-flujo/ficha.md · docs/ux/revision-vistas-2.3/38-bandeja-ia/ficha.md · docs/ux/revision-vistas-2.3/39-cuentas-categorias/ficha.md · docs/ux/revision-vistas-2.3/40-perfil-ajustes/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/853 https://github.com/jur211296/Yala/pull/859 https://github.com/jur211296/Yala/pull/860 https://github.com/jur211296/Yala/pull/862 https://github.com/jur211296/Yala/pull/864.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. Estadísticas › Distribución con AX3 corta los importes de las filas (S/2,3….00) y las pestañas (problema 3 de la zona 35; las fichas de Resumen ya las arregló 2.2).
2. Reportes › Comparativa con AX3 pierde los nombres de fila y corta importes; el mes sale partido «No-viem-bre» (problema 5 de la zona 36).
3. Bandeja con AX3 parte por sílabas los botones que deciden: Edi-tar, Gua rdar, S/ 120.0 0 (problema 7 de la zona 38).
4. Ajustes con AX3 parte los títulos de fila por sílabas (problema 7 de la zona 40).
5. Etiquetas y Cuentas calculan a mano el alto de su lista (filas × alto fijo) y con texto grande la última fila queda cortada (TagsSettingsListView.swift:127 y AccountsSettingsListView; problema 8 H2 de la zona 39).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Solo cambia en tamaños de accesibilidad: a tamaño normal, al píxel (diff de capturas). El patrón es AdaptiveRowStack o apilar, como hizo 2.2 en Resumen y Pagos planificados.
- No dupliques el ticket large-text-leftovers-outside-the-main-iphone-screens ni la card de 2.4 de texto muy grande: si una vista coincide, cítalo y cierra ese punto allí.
- Capturas antes y después a tamaño normal y AX3 en iPhone 17 Pro, y en iPad Pro 13 donde haya columnas.
- No elijas el rediseño de ninguna zona (filas de Estadísticas D1 completas, iconos de Ajustes G1): solo que nada se corte ni se parta por sílabas.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Paso 0 (Frank, 10-nov)

Medido antes de decidir:
- `origin/2.3..origin/2.2` = 13 commits, ninguno en estas vistas salvo el arreglo de Grupos (avisos de borradores sobrantes, ajeno). El merge corto de 2.2 en 2.3 ya entró: se sigue.
- El worktree nació sobre `origin/2.2`; se reapuntó a `origin/2.3` antes de tocar nada.
- La «sesión viva» del aviso (registrar decisiones del 5-nov) está mergeada y sin worktree: aviso viejo.
- Ningún punto lo arregló ya 2.2 ni el ticket `large-text-leftovers…` ni la card de 2.4 (k0ay), que no nombran estas vistas.

Decisiones (todas solo a tamaños de accesibilidad; a tamaño normal el `HStack` de siempre, por construcción):
1. Distribución: nombre arriba e importe debajo (`AdaptiveRowStack`) en filas de categoría y subcategoría. Pestañas: la fila de chips desplaza el chip elegido hasta verse entero (`scrollTo` con ancla `nil`).
2. Comparativa: la fila de la tabla y «Te quedó» se apilan (nombre a lo ancho; cifras y cambio debajo). El mes: título, estado y «Llevas el…» uno debajo del otro.
3. Bandeja: la barra de selección pone «Editar» debajo del contador; la fila «¿Ya lo apuntaste?» baja el importe; la tarjeta de borrador del chat (Yala IA) pone sus tres botones uno debajo del otro. **Asumido**: la tarjeta del chat vive en `Views/Chat`, fuera del `toca:`; entra porque «Gua rdar» es ejemplo del propio encargo.
4. Ajustes: el icono va encima del título (se queda; G1 sigue siendo de Jürgen). Una palabra que no cabe ni a todo lo ancho se sigue partiendo, como «Entreteni-miento» en Categorías, que la revisión 39 dio por buena.
5. Etiquetas y Cuentas: a tamaños de accesibilidad la lista mide su propio contenido (`onScrollGeometryChange`) en vez de filas × alto fijo.
