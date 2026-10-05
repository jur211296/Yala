# Cabeceras de Registros y Estadísticas con poco alto (hallazgo del paso 11)

---
ticket: iphone-landscape-headers-fill-the-short-screen
modo: autonomo
cola: adaptativo
---

## Contexto
Alternancia Cola A ↔ carril adaptativo (una sola sesión Yala a la vez). PR #318 ya mergeado a `2.1` (`a6b957630`): Yala gira a horizontal en iPhone. Cola A #319 está en cola de auto-merge; este turno es el carril adaptativo — no abras Cola A.

Ticket: `tickets/backlog/iphone-landscape-headers-fill-the-short-screen.md` (créalo en el worktree si el `fetch` lo trae; está en `origin/2.1`). Sale del paso 11: con poco alto (375 pt SE / ~440 Pro Max en horizontal) las cabeceras de **Registros** y **Estadísticas › Resumen** (período, neto, entradas/salidas, recuento) llenan casi toda la pantalla; la primera fila queda bajo la barra de pestañas y hay que deslizar. Nada se corta: se llega deslizando. Evidencia: `qa/evidencia-adaptativo-20261001/iphone-supports-landscape-orientation/despues/*-h.jpg` (`04-registros`, `02-estadisticas`). Con AX5 en Pro Max girado la columna de la lista también se estrecha (anotado en el ticket; evaluar si `ListDetailOverlayLogic.listYieldsToDetail` ya basta o si hace falta un ajuste mínimo).

El ticket dice que es decisión de diseño y «no entra por §6.1». En autónomo **tú decides el Paso 0** (como en #318 y #316): no preguntes a Jürgen por detalle reversible. La pista del ticket y de la fase 2b: decidir por el **alto del contenedor**, no por orientación; con alto compacto, cabecera en banda más baja o que se pliegue al desplazar. Reusa el molde de `HeaderBandLayout` / `PairedColumnsLayout` (`Views/Shared/PairedColumnsLayout.swift`) y lo documentado en `.claude/rules/swiftui-ds.md` («Layout adaptativo»). ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo».

Plan: `docs/exploracion/adaptativo-ipad-duo.md` §7 (paso 11 hecho; este es hallazgo residual, no una fila nueva del plan). Fase Duo (paso 6) sigue bloqueada por Xcode 27.1 — no la toques. Pasos 12–13 (multiventana / widgets) fuera.

## Qué se pide
1. Leer el ticket entero, el PR #318 (hallazgos), la fase 2b hecha (`ipad-and-duo-panel-and-statistics-use-the-width`) y el código de cabeceras de Registros y Estadísticas › Resumen.
2. **Paso 0 autónomo** (tabla en el encargo o en el PR): cómo se compacta con poco alto (banda / pliegue al scroll / contenido esencial en una fila), umbral por alto medido del contenedor, qué pasa con AX5, y si la lista estrecha del Pro Max girado entra aquí o queda en ticket propio.
3. Implementar solo Registros + Estadísticas › Resumen (alcance del ticket). Vertical / alto suficiente: sin cambios visibles (diff al píxel en SE vertical default).
4. Evidencia solo en sims del carril por UDID, DerivedData del worktree (`-derivedDataPath .ddp`):
   - `YalaLane-Adapt-iPhone-SE` → `C248A9E8-BBBE-4370-AF7E-77ADB01A1A07`
   - `YalaLane-Adapt-iPhone-ProMax` → `AACA53D7-DCAE-456A-A779-6BF0D8F9926A`
   - `YalaLane-Adapt-iPad-mini` → `91B4E3F8-B14D-478A-8FF5-07DC0D3EFAC1` (regresión breve si tocas layout compartido)
   - `YalaLane-Adapt-iPad-Pro-13` → `A31B3363-C8F4-4F96-8C1F-1772D1140C7E`
   Si faltan, recrearlos con la receta §6.2 (runtime instalado). Capturas antes/después SE + ProMax, vertical y horizontal, default y AX5, al menos Registros y Estadísticas › Resumen. Carpeta `qa/evidencia-adaptativo-20261001/iphone-landscape-headers-fill-the-short-screen/` (o fecha del día).
5. XCUITest por UDID que fije el criterio (p. ej. con poco alto se ve al menos una fila de lista / contenido útil sin depender solo del scroll ciego). Gate verde. PR a `2.1` (auto-merge). Ticket a `done`/`qa`. `docs/TICKETS.md` al día.
6. Al terminar: **`/cerrar-total` autónomo** — nunca dejes la sesión colgada.

## Qué NO hay que tocar
- Cola A / sync / cloud / sesiones. No lances ni abras otro encargo Cola A.
- `floating-buttons-cover-row-amounts-on-ipad-landscape` (Cola B): solo anota si lo vuelves a ver; no lo arregles aquí.
- Fase Duo, Xcode 27.1, multiventana real, widgets grandes.
- Simuladores sin prefijo `YalaLane-Adapt-`. Siempre `-destination id=<UDID>`, nunca por nombre ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator`.
- Cambiar sitio o función de controles (solo compactar cabecera con poco alto). Layout por alto/ancho del contenedor, nunca por modelo ni `if` de orientación en la raíz.
- Producción / deploy. No preguntes a Jürgen por decisiones de producto reversibles.
- Disco: una sola `.ddp`; al cerrar limpia DerivedData y scratchpads propios (hay ~55 GB libres; umbral cómodo ~25 GB).

## Cómo se sabe que está bien
Con poco alto (iPhone horizontal SE y Pro Max), Registros y Estadísticas › Resumen muestran contenido útil de la lista/resumen en la primera pantalla sin que la cabecera se coma casi todo el alto; en vertical / alto suficiente, sin diferencias materiales vs antes (diff al píxel en SE vertical); capturas default+AX5; XCUITest verdes por UDID; gate verde; PR mergeado o en auto-merge a `2.1`; board al día; **`/cerrar-total` ejecutado**.

MODO AUTÓNOMO HASTA TERMINAR: Paso 0 → implementar → `/gate` → commit → PR contra `2.1` (auto-merge) → board (`tickets/` + `docs/TICKETS.md`) → **`/cerrar-total`**. No mates un cierre si ya arrancó. AskUserQuestion solo por acceso, dispositivo físico o irreversible.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión/acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, resumen corto en lenguaje de usuario; (4) quieta a medias, una vez. NO avises por test rojo que vas a reclasificar ni CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo se compacta la cabecera con poco alto?** → **Banda**: con poco alto, la cifra y su rótulo van a la
izquierda y período, entradas/salidas y recuento a la derecha, en vez de cinco filas apiladas; margen vertical de 12
a 4 y sin margen lateral propio. Si la banda no cabe a lo ancho, escalones: período al lado de la cifra con el detalle
debajo (columna de lista del Pro Max girado), detalle en una fila, la pila de siempre. Corrección tras medir: con el
período ENCIMA de la cifra (la primera versión) la fila de Registros del SE girado seguía bajo la barra; y en la
columna del Pro Max el hueco era 320 pt contra 340 que pide «período al lado», que caben al quitar el margen lateral.
Por qué: conserva la cifra grande (identidad) y quita las filas que sobran. Alternativa descartada: plegar al
desplazar — la cabecera ya se va con el scroll; lo que falla es la primera pantalla. Descartado también bajar el
tamaño de la cifra: toca identidad visual.

**D2 · ¿Qué decide «poco alto»?** → El **alto medido del `ScrollView`** que contiene la cabecera **contando las
barras que se le superponen** (tamaño + márgenes de seguridad), por debajo de `DS.Adaptive.shortContainerMaxHeight`
= 500 pt. Medido: girados ≤ ~440 (Pro Max), en vertical ≥ ~615 (Estadísticas en un SE, bajo su barra de chips).
Por qué: el ADR «se adapta por espacio» y la regla de layout prohíben el `if` de orientación; el alto del contenedor
también cubre una ventana baja en iPad. Corrección tras medir: el alto VISIBLE a secas no sirve — en el SE vertical,
bajo el título grande y los chips de Estadísticas, ya baja de 420 y habría compactado el vertical. Alternativa
descartada: `verticalSizeClass` — es un trait de ventana, no del contenedor, y no ve la barra de chips.

**D3 · Vertical / alto suficiente** → la rama de siempre, el mismo árbol: diff al píxel en SE vertical = 0.

**D4 · Alcance** → la cabecera de `RecordsTabView` (la comparten Registros y Estadísticas › Registros, así que
Estadísticas › Registros lo hereda: es el mismo componente y sería incoherente partirlo) y la de
Estadísticas › Resumen (`InsightsTabView`). Tendencias/Distribución y el Panel, fuera.

**D5 · AX5** → no hay rama propia: la banda solo se usa si cabe a lo ancho (`ViewThatFits`), así que con AX5
cae sola a la pila con margen reducido. Nada se corta; se llega deslizando, como hoy.

**D6 · La lista estrecha del Pro Max girado con AX5** → **ticket propio**, no aquí. Por qué: es la anchura de la
columna del split (que la lista ceda sitio con texto de accesibilidad), otra decisión y otro componente
(`ListDetailSplit`); `listYieldsToDetail` solo actúa con algo abierto en el detalle, así que no basta.

**D7 · Prueba** → unit de la función del umbral + XCUITest por UDID: en horizontal en SE y Pro Max, en Registros la
primera fila de registro queda por encima de la barra de pestañas sin deslizar, y en Estadísticas › Resumen la
cabecera ocupa menos de la mitad del alto visible. Mutante: sin la banda, rojo.
