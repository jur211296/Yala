# Columna de lista estrecha con AX5 en Pro Max girado

---
ticket: list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max
modo: autonomo
cola: adaptativo
---

## Contexto
Alternancia Cola A ↔ carril adaptativo (una sola sesión Yala a la vez). PR #320 ya mergeado a `2.1` (`7a9708657`): cabeceras de Registros y Estadísticas compactas con poco alto. Pause del carril LIFTED 2026-10-01 ~16:12 — chaining adaptativo es correcto. Cola A (#319/#321) puede seguir en auto-merge; este turno es el carril adaptativo — **no abras Cola A**.

Ticket: `tickets/backlog/list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max.md`. Sale del Paso 0 D6 de `iphone-landscape-headers-fill-the-short-screen`: aquel compacta cabecera por alto; esto es el **ancho de la columna de la lista** en el split. Con texto AX5 en el Pro Max girado (ancho regular → lista+detalle a la vez), `DS.Adaptive.listColumn*Width` deja la lista al ancho de un SE: «Este mes» se parte y el chip «Presupuestos» se corta. Se puede usar, pero se lee mal.

Evidencia: `qa/evidencia-adaptativo-20261001/iphone-supports-landscape-orientation/despues/promax-ax5__03-planificacion-h.jpg` y `promax-ax5__04-registros-h.jpg`.

`ListDetailOverlayLogic.listYieldsToDetail` aparta la lista **solo con algo abierto en el detalle**. Con «Elige un…» la lista se queda estrecha — justo el caso de las capturas. Toca Registros, Planificación y Grupos a la vez (y iPad con AX5): es decisión de layout del contenedor (`ListDetailSplit`), no de una pantalla.

ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo». Plan: `docs/exploracion/adaptativo-ipad-duo.md`. Fase Duo (paso 6) sigue bloqueada por Xcode 27.1 — no la toques. Pasos 12–13 (multiventana / widgets) fuera. Cola B (`cola-b-redesigns-must-hold-up-at-ipad-width`, floating-buttons…) fuera salvo anotar.

Los sims del carril se recrearon el 2026-10-01 (faltaban). UDIDs nuevos (iOS 27.0):

- `YalaLane-Adapt-iPhone-SE` → `0A9CB600-F3E2-4F7F-9F58-FBC45E5CF343`
- `YalaLane-Adapt-iPhone-ProMax` → `A277CDD8-068A-49F6-9582-7B4B202744B8`
- `YalaLane-Adapt-iPad-mini` → `4B26A954-18EC-4509-AE29-8B8D92B06555`
- `YalaLane-Adapt-iPad-Pro-13` → `5DE859DE-0963-4AAE-B2C7-5DE350DFA1AA`

## Qué se pide
1. Leer el ticket entero, el PR #320 (D6), `ListDetailSplit` / `ListDetailOverlayLogic` / `DS.Adaptive.listColumn*Width`, y la evidencia citada.
2. **Paso 0 autónomo** (tabla en el encargo o en el PR): con tamaños de accesibilidad, ¿el split da más ancho a la lista, o la deja sola hasta que se abre algo en el detalle? Umbral por ancho/categoría de contenido (no por modelo ni `if` de orientación). Qué pasa en iPad con AX5. Vertical compact / sin AX: sin cambios visibles materiales.
3. Implementar en el contenedor compartido (Registros + Planificación + Grupos heredan). Alcance mínimo coherente con el split.
4. Evidencia solo en sims del carril por UDID, DerivedData del worktree (`-derivedDataPath .ddp`). Capturas antes/después ProMax horizontal default+AX5 (Registros y Planificación al menos; Grupos si el cambio les aplica); SE vertical default (regresión / diff al píxel); iPad breve si tocas layout compartido. Carpeta `qa/evidencia-adaptativo-20261001/list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max/` (o fecha del día).
5. XCUITest por UDID que fije el criterio (p. ej. con AX5 en ProMax horizontal, con detalle vacío, el rótulo «Este mes» / chip de Planificación no se corta o la lista tiene ancho usable medido). Gate verde. PR a `2.1` (auto-merge). Ticket a `done`/`qa`. `docs/TICKETS.md` al día.
6. Al terminar: **`/cerrar-total` autónomo** — nunca dejes la sesión colgada.

## Qué NO hay que tocar
- Cola A / sync / cloud / sesiones. No lances ni abras otro encargo Cola A.
- `floating-buttons-cover-row-amounts-on-ipad-landscape` y `cola-b-redesigns-must-hold-up-at-ipad-width` (Cola B): solo anota si lo vuelves a ver; no lo arregles aquí.
- Fase Duo, Xcode 27.1, multiventana real, widgets grandes, `large-text-leftovers-outside-the-main-iphone-screens` (otro ticket).
- Simuladores sin prefijo `YalaLane-Adapt-`. Siempre `-destination id=<UDID>`, nunca por nombre ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator`.
- Cambiar sitio o función de controles; layout por espacio del contenedor, nunca por modelo ni `if` de orientación en la raíz.
- Producción / deploy. No preguntes a Jürgen por decisiones de producto reversibles.
- Disco: una sola `.ddp`; al cerrar limpia DerivedData y scratchpads propios (~45 GB libres; umbral cómodo ~25 GB). Sims recreados: si hace falta «Apps en ventanas» en iPad, actívalo solo en los YalaLane-Adapt (receta §6.2).

## Cómo se sabe que está bien
Con AX5 en Pro Max girado, Registros y Planificación (y Grupos si aplica) muestran la columna de lista legible sin partir «Este mes» ni cortar chips clave cuando el detalle está vacío («Elige un…»); sin AX / vertical compact, sin diferencias materiales vs antes; capturas default+AX5; XCUITest verdes por UDID; gate verde; PR mergeado o en auto-merge a `2.1`; board al día; **`/cerrar-total` ejecutado**.

MODO AUTÓNOMO HASTA TERMINAR: Paso 0 → implementar → `/gate` → commit → PR contra `2.1` (auto-merge) → board (`tickets/` + `docs/TICKETS.md`) → **`/cerrar-total`**. No mates un cierre si ya arrancó. AskUserQuestion solo por acceso, dispositivo físico o irreversible.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión/acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, resumen corto en lenguaje de usuario; (4) quieta a medias, una vez. NO avises por test rojo que vas a reclasificar ni CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: con AX5, «Este mes» y el chip «Presupuestos» caben en el Pro Max **vertical**
(440 pt de ventana) y se parten en el SE vertical (375). La columna de lista del split mide 375/400/480 (mín/ideal/máx)
y en el iPhone girado le quita además el margen seguro de la isla. `DetailContainerView` (Estadísticas › Registros en
panel) copia la misma regla con los mismos tokens.

**D1 · ¿Más ancho para la lista o plegar a pila?** → Las dos, según quepan: con texto de accesibilidad la columna de
lista es más ancha; y donde dos columnas así no caben (el Pro Max girado), la página se pliega a la pila de compacto
—la lista sola, lo abierto empujado o en hoja, como en vertical—.
Por qué (medido, revisa la primera versión de este D1): en el Pro Max girado el split **no pone al lado** una columna
que lea AX5 — a 522 y a 582 pt la superpuso sobre «Elige un…», que quedaba medio tapado. La de 446 de siempre sí va al
lado, pero ahí AX5 parte «Este mes». No hay ancho que cumpla las dos cosas. En iPad sí caben y el split se queda.
Cómo: `foldsListDetailForAccessibilityText()` en quien monta la página (`ContentView.viewForTab`), porque Registros y
Grupos leen el size class por su cuenta para decidir hoja o columna; el modificador vive junto a `ListDetailSplit`.
Alternativa descartada: dejar el split con la lista superpuesta — tapa el texto del detalle, y tocar fuera la retira.

**D2 · ¿Por qué se activa?** → `dynamicTypeSize.isAccessibilitySize` (AX1–AX5), leído en el contenedor.
Por qué: es categoría de contenido, no modelo ni orientación. Por debajo de AX1 se da por bueno el ancho de hoy (las capturas por defecto del encargo anterior se leen bien).

**D3 · ¿Cuánto?** → El contenido de la columna mide al menos lo del Pro Max vertical (408 pt), donde AX5 cabe:
408 + 32 de márgenes = 440. Tokens mín 440 / ideal 460 / máx 520 (medido en el «antes»: el chip «Presupuestos» mide
392 pt y acababa en x = 470, fuera de la columna; «Este mes» pasaba de 63 a 125 pt de alto).
Corrección medida a media sesión: la primera versión pedía 510/520 contando la isla del iPhone girado, y el split
**suma la isla encima** (pedida a 520, midió 582). A 582 el detalle se quedó con 374 pt y el split pasó a
**superponer** la lista sobre «Elige un…». De ahí el techo: el detalle tiene que conservar más de 375 pt.

**D4 · ¿Con detalle vacío o con algo abierto?** → En el Pro Max girado con AX deja de haber detalle al lado: lista
sola y lo abierto encima, como en vertical. Donde el split se queda (iPad Pro 13), `listYieldsToDetail` usa el mínimo
AX, y con Yala IA al lado la lista se aparta al abrir algo, igual que sin AX.

**D5 · iPad con AX5** → Misma regla por ancho, con el ancho que mide la página: el iPad mini (744 vertical, 853
girado junto a la barra lateral) se pliega a la pila; el iPad Pro 13 (1032 / 1096) sigue en split con la lista a 460.
Medido de paso: restar los márgenes seguros que reporta el proxy los cuenta dos veces (el ancho ya viene sin ellos) y
apartaba la lista en el Pro 13 con AX; se mide el ancho tal cual.

**D6 · Estadísticas › Registros (`DetailContainerView`)** → Mismos anchos AX: su comentario dice «la misma regla que
`ListDetailSplit`» y divergir sería la incoherencia. La columna de Yala IA (`YalaAIChatPresentation`) no es una lista
y no se toca.

**D7 · Sin AX / vertical compacto** → Los tokens de siempre, sin cambios: se comprueba con diff al píxel.

**D8 · Prueba** → XCUITest por UDID con AX5 por argumento de lanzamiento: en Pro Max girado, Planificación con
«Elige un…» deja el chip «Presupuestos» entero dentro de la columna y «Este mes» en una línea (alto ≤ el de vertical
en el mismo aparato); se salta donde el split va plegado. Unit del token y del umbral. Mutante: anchos AX = los de
siempre ⇒ rojo.

**D9 · Ticket** → `qa` si queda algo de iPad que no pueda capturar; si no, `done`.
