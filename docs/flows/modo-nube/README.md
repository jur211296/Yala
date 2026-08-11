# Atlas de Flujos · Modo Nube

Herramienta de la **revisión integral de los flujos de Modo Nube**. Desde el chip **F4** es un
**storyboard**: una pestaña por flujo y, dentro, la secuencia de pantallas como **frames grandes visibles
sin un solo clic** — la captura real a tamaño legible, el **copy exacto con su key de l10n** (seleccionable),
qué queda persistido, cómo se sale y la coordenada de código. Cada flujo tiene además una vista **Mapa**
con todas las ramas (layout calculado con ELK, no dibujado a mano).

**Se abre con doble clic en `index.html`.** Funciona offline: no hay ni una URL remota.

    open docs/flows/modo-nube/index.html

Deep-link para citar un nodo en un ticket: `index.html?node=<id>` (salta a su frame y lo resalta).
Cada frame tiene un botón **«⧉ referencia»** que copia al portapapeles una plantilla de ticket con el id,
el flujo, las keys de l10n visibles y la coordenada.

## Anclaje

Todo lo que hay aquí se midió el **2026-08-09** contra **HEAD `9d6f0f1c`** (branch `2.0.5`, D-A7 con
A1–A6 completos). El anclaje está visible en la cabecera del propio Atlas — si el código se mueve, lo que
caduca es el Atlas, y su fecha lo dice.

**Refresco del 2026-08-11 (chip F3), contra HEAD `24b4bc91`.** La tanda del «relanzamiento cero»
(`6d0358b5`…`24b4bc91`) movió el relanzamiento de sitio, así que los flujos **1, 2, 5 y 7** están
re-derivados: nodos nuevos (el terminal «Un último paso: reabre Yala», la pantalla «Tu cuenta está lista»,
el swap de persona del sign-out y el mount NEUTRO) y coordenadas re-resueltas una a una. Los flujos **3, 4
y 6** siguen anclados al 2026-08-09 porque la tanda no toca su código — comprobado con
`git diff f4d10fa6..HEAD`, no asumido.

**Rediseño del 2026-08-11 (chip F4).** Presentación nueva (storyboard + mapa), **cero re-derivación de
narrativa**: `data/nodes.js`, `data/flows.js` y `data/f2.js` conservan su contenido de F3. Lo único nuevo
de CONTENIDO son las **keys de l10n por pantalla** (`data/l10n.js`), medidas del código y de
`es.lproj/Localizable.strings` contra `24b4bc91`.

## La regla madre

> El contenido se deriva de las **tablas de la lógica pura** y de lo que la app hace de verdad —
> **jamás de `MODO-NUBE-ARQUITECTURA`**. Donde el diseño y el código difieren, gana el código y la
> divergencia se **anota** en el frame del nodo con ⚠︎.

Un Atlas derivado del diseño sería el mismo drift documental que esta épica lleva un mes pagando, en
bonito. Por eso la sección **Cobertura** existe: dice, tabla por tabla, cuántas celdas tiene y cuántas se
dibujaron. Un desajuste es un hueco **dicho**, no silencioso.

## Qué hay en la carpeta

| Ruta | Qué es |
|---|---|
| `index.html` | El Atlas: pestañas por flujo, storyboard + mapa, cobertura, hallazgos, guion device |
| `lib/graph.js` | Parser de los grafos + medición de texto + geometría — **compartido** entre la página y `check.mjs`, para que el pin de solapes mida exactamente lo que se pinta |
| `data/nodes.js` | El CONTENIDO de los paneles (66 nodos con sus coordenadas de código) |
| `data/flows.js` | Los 7 grafos (sintaxis mermaid, SSOT de la estructura) + la auto-auditoría + los hallazgos |
| `data/f2.js` | El estado del chip **F2**: lista `device-only` con motivos, notas de captura y hallazgos F2 |
| `data/l10n.js` | **F4**: las keys de l10n del copy visible de cada pantalla, con su valor exacto de `es.lproj` |
| `data/storyboard.js` | **F4**: el ORDEN de presentación (camino feliz + ramas) — solo orden, cero narrativa |
| `vendor/elk.bundled.js` | elkjs 0.11.0 vendorizado — **1,6 MB**, la única dependencia (sustituye a mermaid, 2,5 MB) |
| `img/` | Las capturas reales del simulador (32), una por `id` de screenshot capturable en sim |
| `check.mjs` | El pin — ver abajo. Desde F4 corre **sin dependencias** (`node check.mjs` y listo) |

### Sobre el peso de `vendor/elk.bundled.js`

1,6 MB en un fichero, versión pinneada (elkjs 0.11.0, `lib/elk.bundled.js` de npm vía unpkg). Se vendoriza
porque el Atlas tiene que abrir sin red desde el repo. Sustituye a `mermaid.min.js` (2,5 MB): el peso total
vendorizado **baja** ~0,9 MB con el rediseño. Los grafos siguen editándose en texto (`data/flows.js`); lo
que cambió es quién los dibuja: ELK calcula el layout (capas + ruteo ortogonal + espacio reservado para las
etiquetas de arista, que es lo que mata el solape) y los nodos son HTML con la captura dentro — lo que
Mermaid no puede hacer. El pan/zoom son ~40 líneas propias, sin dependencia.

## Cómo se verifica

    node docs/flows/modo-nube/check.mjs

Sin instalar nada: el parser y la geometría salen de `lib/graph.js` y el layout del elkjs vendorizado
(`jsdom` ya no hace falta — era para renderizar Mermaid).

Once bloques: los 7 grafos **parsean** con el parser real (una línea desconocida es error duro, no un
skip) · cada `click … showNode("x")` resuelve · ningún panel **huérfano** · `id` de screenshot únicos y con
convención · panel completo con coordenada · **offline** (ni una URL remota, y todo script local existe) ·
contrato F2 (cero nodos vacíos) · **SOLAPES**: el layout de cada flujo, medido con las cajas visuales que
la página pinta, no produce ninguna intersección nodo-nodo, etiqueta-nodo ni etiqueta-etiqueta · **L10N**:
toda key citada existe en `es.lproj` y su **valor coincide** (el Atlas promete copy exacto) · **STORYBOARD**:
todo nodo con pantalla aparece en el storyboard de su flujo · y el **conteo esperado**
(66 paneles · 56 `id` · 32 imágenes · 24 device-only · 56 entradas l10n).

**Muerde** (mutaciones verificadas el 2026-08-11, todas a exit 1): declarar a ELK la mitad del ancho real
→ 51 solapes; inventar una key de l10n → FAIL l10n; quitar un frame del storyboard → FAIL story; borrar
una imagen → nodo VACÍO + conteo. El pin de solapes comprueba las cajas **visuales** en las posiciones
finales — mentirle al layouter sobre el tamaño no lo esquiva.

## Estado de las capturas (F2 2026-08-10 · F3 2026-08-11)

Recorrido en el simulador (iPhone 17 Pro · scheme Yala Dev contra staging) el **2026-08-10** sobre HEAD
`f4d10fa6`, con un refresco el **2026-08-11** sobre HEAD `24b4bc91`. De los 56 `id` de screenshot: **32
capturas reales** y **24 `device-only`** — cada una con su motivo y qué debería verse, en `data/f2.js`.
Desde F4 los huecos son **frames visibles** en el storyboard (borde violeta discontinuo, con el motivo y
el «qué debería verse» dentro) y la pestaña **«Capturas · guion device»** los ordena por flujo como guion
de captura para la pasada del owner.

Lo que el simulador no pudo dar (marcado, no fingido): todo lo que exige una **sesión backend real**
(SIWA/Google no completan en sim) — claim `created`, adopt, reversa conducida, cutover, banner de sesión,
push-all —, los estados **multi-device** (marcador de líder, faro cross-device) y los que dependen de una
**respuesta del servidor** no fabricable (403, `claiming_in_progress`). El owner los captura en device y
se integran en una pasada posterior.
