Yala
# Decidido 9-nov 2.3 · Registros: buscar dentro de la lista, también por importe
card: tablero-2-3-buscar-dentro-de-registros-tambien-p-e7ss
toca: Yala/App/Views/Records/, Yala/App/Views/Search/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 14 (B1, sin texto que explique la diferencia). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/31-registros/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. Buscar deja de desaparecer justo en Registros y entiende importes. Campo «Buscar en Registros» arriba de la lista (aparece al tirar hacia abajo), busca también por importe y respeta período y filtros. No se añade explicación de en qué se diferencia de la pestaña Buscar.

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

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: `origin/2.3..origin/2.2` = 0 commits (2.2 ya está en 2.3); 2.2 no tocó `Views/Records` ni
`Views/Search` después; no hay PR que lo haga. El «Nota contiene» de Filtros es `SessionState.searchText`, un filtro de
sesión que también filtran el Panel, Estadísticas e Informes y que solo mira la nota.

**D1 · ¿El campo escribe en el filtro de sesión «Nota contiene» (como sugería la ficha B1) o es de Registros?** → De
Registros: una búsqueda propia del ViewModel de Registros, aplicada encima del período y los filtros de sesión.
Por qué: la decisión dice «buscar dentro de la lista» y «respeta período y filtros»; escribir en la sesión filtraría el
Panel y Estadísticas por lo que se teclea, y cambiar ese filtro a importe/categoría cambiaría lo que hace «Nota contiene»
en todas las pantallas. Alternativa descartada: reutilizar `searchText` de sesión (fuga a otras pantallas).

**D2 · ¿Cómo «aparece al tirar hacia abajo» sin el cajón `.automatic` de la barra?** → Campo propio dentro del scroll,
encima de la cabecera, oculto en reposo y que asoma al tirar de la lista hacia abajo estando arriba. Se queda mientras
tenga texto; la X lo vacía y lo vuelve a esconder. Con VoiceOver está siempre a la vista (no hay gesto de tirar).
Por qué: `.navigationBarDrawer(displayMode: .automatic)` está prohibido en `Yala/App/Views` por el salto de ~45 pt al
volver a una pestaña (`GroupsSearchDrawerWiringTests`, `swiftui-ds.md`); `.always` no «aparece al tirar». Alternativa
descartada: cajón del sistema (rompe esa regla) o campo siempre visible (no es lo decidido).

**D3 · Importe: ¿exacto o con tolerancia?** → Con decimales, al céntimo («45.90»); sin decimales, toda la parte entera
(«45» casa con 45,00–45,99). Sin signo y en la moneda del registro, como el filtro de monto. Acepta «,» o «.» decimal,
símbolos de moneda y miles. Además del importe, el mismo texto busca en nota, categoría, subcategoría, cuenta y etiquetas,
sin distinguir mayúsculas ni tildes.
Por qué: así se recuerda un importe; ±1 mezclaría resultados. Alternativa descartada: ±1 (la ficha lo dejaba abierto).

**D4 · ¿La cabecera (Te queda / Entró / Salió) refleja la búsqueda?** → Sí: suma lo que la lista enseña.
Por qué: «la UI dice lo mismo que el número» (`session-filters.md`); una cabecera con todo y una lista con 3 se
contradirían. «Seleccionar todo» también actúa sobre lo encontrado.

**D5 · ¿Estadísticas › Registros (misma vista) también lleva el campo?** → No. Solo Registros, como dice la decisión.

**D6 · ¿La pestaña Buscar aprende importes?** → No: la decisión 14 eligió solo B1. Queda igual.

**D7 · Sin resultados** → el vacío de «Sin resultados / Prueba con otro término» que ya usa Buscar (sin texto nuevo que
compare con la pestaña Buscar). Texto nuevo solo uno: el marcador «Buscar en Registros», en los 16 idiomas.

**D8 · Prueba de regresión** → unit (regla y ViewModel: importe, texto, respeta período/filtro) + XCUITest con un fixture
nuevo (`-uitest-seed-records-search`, un «Almuerzo de trabajo» de 45,90 de hoy): tirar → campo → «45,90» → una fila.
