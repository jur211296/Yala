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

**Refresco del 2026-08-12 (chip F5), contra HEAD `6c6eb3fe`.** Las olas W (el Welcome habla claro), G
(Grupos-first), C (consent y puertas) y M (frontera de sesión secundaria) —19 commits— movieron el flujo 1
y reescribieron el 6. El Atlas pasa de **66 a 82 paneles**: la vía del ORGANIZADOR entera con su puerta,
las CUATRO puertas de Grupos unificadas, el consent que viaja con la cuenta, el empty state de cinco casos,
el retiro de los grupos de la era CloudKit y los cuatro ajustes que una visita ya no toca. Los flujos **3 y
4 no se tocan**, y está MEDIDO: `git diff 724f661e..HEAD` no roza un solo fichero suyo, y sus 12
coordenadas se re-verificaron una a una.

> **Lo que este refresco enseñó sobre el propio pin.** `check.mjs` estaba en exit 1 con 24 fallos de l10n,
> todos del flujo 1 — y eso era la parte BARATA. Lo que el pin no puede ver son las pantallas que FALTAN y
> las coordenadas que se desplazaron: **35 símbolos citados se habían movido de línea** sin que ningún
> bloque lo notara, y ocho capturas retrataban pantallas que la app ya no pinta. Un `check.mjs` en verde no
> significa que el Atlas esté completo.

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
| `data/nodes.js` | El CONTENIDO de los paneles (82 nodos con sus coordenadas de código) |
| `data/flows.js` | Los 7 grafos (sintaxis mermaid, SSOT de la estructura) + la auto-auditoría + los hallazgos |
| `data/f2.js` | El estado de las capturas: `device-only` con motivos, los `pending` de F5, las `stale` y los hallazgos F2 |
| `data/l10n.js` | **F4**: las keys de l10n del copy visible de cada pantalla, con su valor exacto de `es.lproj` |
| `data/storyboard.js` | **F4**: el ORDEN de presentación (camino feliz + ramas) — solo orden, cero narrativa |
| `vendor/elk.bundled.js` | elkjs 0.11.0 vendorizado — **1,6 MB**, la única dependencia (sustituye a mermaid, 2,5 MB) |
| `img/` | Las capturas reales del simulador (35), una por `id` de screenshot capturable en sim |
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
(82 paneles · 64 `id` · 35 imágenes · 29 sin captura · 64 entradas l10n).

**Lo que el pin NO puede ver, y conviene saber antes de fiarse de su verde:** una pantalla que nadie añadió
(detecta una key mal citada, no un nodo ausente), una coordenada `Fichero.swift:línea` que se desplazó
—cita el fichero, no la línea— y una captura que sigue existiendo pero ya no retrata lo que la app pinta.
Las tres cosas mordieron en F5 y las tres se resolvieron a mano: re-anclando 35 coordenadas contra el árbol,
derivando los 16 paneles nuevos del código y rehaciendo en el simulador las 8 capturas caducadas.

**Muerde** (mutaciones verificadas el 2026-08-11, todas a exit 1): declarar a ELK la mitad del ancho real
→ 51 solapes; inventar una key de l10n → FAIL l10n; quitar un frame del storyboard → FAIL story; borrar
una imagen → nodo VACÍO + conteo. El pin de solapes comprueba las cajas **visuales** en las posiciones
finales — mentirle al layouter sobre el tamaño no lo esquiva.

## Estado de las capturas (F2 2026-08-10 · F3 2026-08-11 · F5 2026-08-12)

**F5 sí abrió el simulador** (iPhone 17 Pro · Yala Dev · **configuración `Debug-Dev`**): se **rehicieron las
8 capturas caducadas** por las olas W/G/C/M y se estrenaron **3 pantallas** que el Atlas no tenía — el
chooser de grupos, la puerta cerrada por canal apagado y el sign-in de Grupos. Quedan **35 imágenes**.

Tres categorías, que el Atlas distingue en pantalla porque confundirlas sería mentir: **device-only** (el sim
no puede producir ese estado — 25 nodos), **pendiente** (el sim SÍ puede y no se llegó — 4 nodos, marcados
`pending: true`, cada uno con lo que se intentó y por qué no salió) y **caducada** (`stale`, hoy **vacío**;
el mecanismo se conserva porque el problema vuelve en cuanto una pantalla se re-escribe).

> ⚠️ **Dos trampas que costó descubrir, para el yo-futuro.** (1) El scheme «Yala Dev» compila con
> **`Debug-Dev`**, no con `Debug`: con `Debug` sale el bundle de producción, sin `DEV_BUILD` y con los
> percents apagados, así que ni el sub-chooser de nube ni el canal de Grupos aparecen. (2) En un build Dev,
> **una instalación limpia no nace virgen en preferencias**: a los 12 s de un launch sin tocar nada ya hay
> `onboardingMode`, `userName` y `defaultCurrencyCode` escritas (las tres SINCRONIZADAS; ninguna per-device).
> No lo escribe la rama del organizador —se comprobó sin interactuar— y no se identificó al escritor ⇒ la
> invariante «nada se persiste hasta que la cadena confirma» **no se puede verificar en Dev leyendo el plist**.


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
