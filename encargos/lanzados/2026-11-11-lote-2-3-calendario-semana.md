Yala
# Decidido 9-nov 2.3 · Registros: el calendario deja la semana a la vista, también en el iPad
card: tablero-2-3-calendario-de-registros-la-semana-a-rjsz
toca: Yala/App/Views/Records/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 19, 66 y 67. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/31-registros/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO estos 3 puntos:
1. Al tocar un día del calendario, su lista queda a la vista. Opción C2: el mes se pliega a la semana del día elegido y su lista queda debajo. C3 (moneda en la celda) no.
2. En el iPad, el calendario deja de apretarse en la columna de la lista: va en la columna de detalle o a ancho legible.
3. En el iPad, el título de la columna deja de salir cortado («Registr…»): el título cabe entero.

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

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

Precondiciones medidas: `git rev-list --count origin/2.3..origin/2.2` = 0 (2.3 ya tiene lo de 2.2) y `git log origin/2.3..origin/2.2 -- Yala/App/Views/Records/ Yala/App/Views/Statistics/RecordsTabView.swift` vacío: ninguno de los tres puntos viene arreglado de 2.2. Los tres siguen vivos en el código de 2.3 (calendario sin plegar, en la columna de la lista, título en línea).

1. **C2, qué pliega y cómo se despliega.** Plegado ⇔ hay día elegido (sin estado nuevo). La semana del día queda con su cabecera «13–19 oct 2026 ▾» en el sitio del mes; tocarla suelta el día y vuelve el mes, igual que tocar el día otra vez. Dentro de la semana se pasa de día en día. Plegado no se cambia de mes deslizando. Vale para los dos modos del calendario (mes con flechas y tira de semanas).
2. **«A la vista» se garantiza, no se espera.** Al elegir un día la página sube hasta el calendario (la semana arriba y la lista debajo, como la maqueta C2), también con texto grande. En seco: dentro de una pestaña un `withAnimation` no anima (lo fija `TabImplicitAnimationsWiringTests`).
3. **C3 no** (moneda en la celda): decidido el 9-nov.
4. **iPad, punto 2: «a ancho legible», no «columna de detalle».** Con la vista calendario la página de Registros en ventana ancha va en una sola columna (como en el iPhone) y su contenido a 700 pt; lo abierto, en la hoja de siempre. Poner el calendario en la columna de detalle lo perdía en cuanto se abría un registro. Con la lista vuelve el split. Al pasar a calendario se cierra lo abierto en la columna. El modo, el día y el mes del calendario suben al `RecordsViewModel` para sobrevivir al plegado del split.
5. **iPad, punto 3:** primero se probó el título grande en la columna de la lista y **no actúa** (medido: la columna lateral del split lleva siempre el título en la barra). Se deja sitio al título: en esa columna «Seleccionar» va con su icono (el de «···»), sigue a la vista (L8-12) y VoiceOver lo nombra igual. En el iPhone, en el Duo cerrado y en la página de una columna, el texto de siempre.
6. **Copy:** solo la pista de VoiceOver de la cabecera de la semana («Muestra el mes entero»), en los 16 idiomas. El rango de fechas lo escribe el sistema.
7. **Estadísticas › Registros** monta la misma vista: hereda el plegado (1 y 2), no el ancho legible ni el título.
8. **Tests:** `RecordsCalendarWeek23UITests` (un caso por punto; los dos del iPad por UDID en un iPad Pro 13 propio) + unit `RecordsCalendarFoldTests`. Rojo sin el arreglo por mutante (los tres arreglos revertidos en una compilación), verde con él.
