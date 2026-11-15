Yala
# Decidido 9-nov 2.3 · Registros: chips rápidos y la banda del filtro a la vista
card: tablero-2-3-filtros-de-registros-chips-rapidos-y-rywa
toca: Yala/App/Views/Filters/, Yala/App/Views/Records/, Yala/App/Views/Panel/, Yala/App/Views/Statistics/, Yala/App/Views/Reports/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 15 y 16. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/31-registros/ficha.md. La banda también llega a Panel, Estadísticas e Informes.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. Filtrar por cuenta y categoría deja de pedir 7 toques dentro de «···». Opción F2 + F3: chips rápidos sobre la lista (Cuenta · Categoría · Fecha · Más filtros), aplican al tocar; y la hoja con buscador de categorías, filas enteras tocables y resumen con lo elegido.
2. En Categorías, los once círculos dejan de llamarse «Seleccionar todo» para VoiceOver (lo resuelve F3).
3. El resumen de Categorías deja de decir subcategorías («Delivery +3») cuando se eligió el grupo (lo resuelve F3).
4. Con la lista vacía, el filtro culpable queda a la vista. Opción L1 integrada con F2 + L3: banda que se parte en líneas, con «Quitar todo» y X de 44 pt; los chips dicen lo elegido y la banda, lo de «Más filtros»; llega también a Panel, Estadísticas e Informes. «Limpiar filtros» sube a la cabecera de la hoja, aplica y cierra. Los filtros siguen siendo de la sesión.
5. «Limpiar filtros» y «Borrar filtros» pasan a un solo nombre (lo resuelve L3).

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

## Paso 0

Medido antes de tocar (11-nov, noche): `git rev-list --count origin/2.3..origin/2.2` = 0, así que 2.3 ya tiene todo lo
de 2.2 y `git log origin/2.3..origin/2.2 -- <vista>` sale vacío para las cinco carpetas: nada que 2.2 haya arreglado ya.
Los cinco puntos siguen vivos en `origin/2.3` (Filtros solo en «···»; círculos con `accessibilityLabel(selectAll)`;
`selectedCategoriesText` = «primera subcategoría +N»; chips en `ScrollView(.horizontal)` con X de `chipClose`;
«Borrar filtros» en `action.clearAll` y «Limpiar filtros» en la hoja).

Decisiones (auto-contestadas, modo nocturno; la de producto ya la tomó Jürgen el 9-nov):

1. **Dónde salen los chips rápidos:** solo en Registros (la pestaña). Estadísticas › Registros comparte la lista, pero la
   decisión habla de Registros; allí sigue la banda completa.
2. **Qué hace cada chip:** Cuenta ▾ = menú con «Todas las cuentas» + cada cuenta (las tarjetas una vez, sin líneas, como
   la hoja); Categoría ▾ = hoja corta con buscador (categorías y subcategorías), aplica y cierra; Fecha ▾ = el menú de
   períodos de siempre + «Personalizado…»; Más filtros = la hoja completa. Elegir en un chip REEMPLAZA esa dimensión
   (un toque, una cuenta). Lo múltiple sigue en «Más filtros».
3. **Qué dice el chip:** lo elegido («Cuenta Principal», «2 cuentas», «Alimentación», «Este mes»); vacío, su nombre.
4. **Banda:** se parte en líneas (layout propio que no desborda), con «Quitar todo» siempre que haya algo, y la X de cada
   cápsula con 44 × 44 pt de toque. En Registros la banda NO repite lo incluido de cuenta/categoría/subcategoría (eso lo
   dicen los chips); enseña lo de «Más filtros», también lo oculto. En Panel, Estadísticas e Informes, todo.
5. **Nombres:** «Quitar todo» en la banda (decidido así en L1) y «Limpiar filtros» para la acción de la hoja y del vacío.
   «Borrar filtros» desaparece. El botón de la cabecera aplica y cierra, sin aviso de «Deshacer» (la decisión no lo pide).
6. **F3 en la hoja:** buscador de categorías dentro de la propia hoja, bajo la fila Categorías; las filas del selector
   completo se eligen tocando la fila entera, y el chevrón aparte despliega. VoiceOver lee el nombre de cada categoría.
7. **Resumen de Categorías:** por grupo: si están todas las subcategorías visibles de una categoría, dice la categoría;
   si no, las subcategorías. «Alimentación», «Alimentación +1», «Restaurantes».
8. **Saldo en el menú de cuentas** (lo enseñaba la maqueta, no la decisión): fuera de este lote.
