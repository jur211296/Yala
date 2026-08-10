# Atlas de Flujos · Modo Nube

Herramienta de la **revisión integral de los flujos de Modo Nube**: diagramas de decisión por flujo,
**derivados del CÓDIGO**, con cada nodo clickeable → qué ve el usuario · qué queda persistido · cómo se
sale · la coordenada de la Logic que decide ese branch.

**Se abre con doble clic en `index.html`.** Funciona offline: no hay ni una URL remota.

    open docs/flows/modo-nube/index.html

## Anclaje

Todo lo que hay aquí se midió el **2026-08-09** contra **HEAD `9d6f0f1c`** (branch `2.0.5`, D-A7 con
A1–A6 completos). El anclaje está visible en la cabecera del propio Atlas — si el código se mueve, lo que
caduca es el Atlas, y su fecha lo dice.

## La regla madre

> Los diagramas se derivan de las **tablas de la lógica pura** y de lo que la app hace de verdad —
> **jamás de `MODO-NUBE-ARQUITECTURA`**. Donde el diseño y el código difieren, gana el código y la
> divergencia se **anota** en el panel del nodo con ⚠︎.

Un Atlas derivado del diseño sería el mismo drift documental que esta épica lleva un mes pagando, en
bonito. Por eso la sección **Cobertura** existe: dice, tabla por tabla, cuántas celdas tiene y cuántas se
dibujaron. Un desajuste es un hueco **dicho**, no silencioso.

## Qué hay en la carpeta

| Ruta | Qué es |
|---|---|
| `index.html` | El Atlas: índice, 7 diagramas, panel lateral, cobertura, hallazgos |
| `data/nodes.js` | El CONTENIDO de los paneles (62 nodos con sus coordenadas de código) |
| `data/flows.js` | Los 7 diagramas Mermaid + la auto-auditoría + los hallazgos |
| `data/f2.js` | El estado del chip **F2**: lista `device-only` con motivos, notas de captura y hallazgos F2 |
| `vendor/mermaid.min.js` | Mermaid 11.6.0 vendorizado — **2,5 MB**, la única dependencia |
| `img/` | Las capturas reales del simulador (31), una por `id` de screenshot capturable en sim |
| `check.mjs` | El pin: valida diagramas, enlaces, convención de ids, que el HTML sea offline y el contrato F2 (cero nodos vacíos) |

### Sobre el peso de `vendor/mermaid.min.js`

2,5 MB en un fichero, versión pinneada. Se decidió **vendorizarlo** en vez de cargarlo de un CDN porque el
Atlas tiene que abrir sin red desde el repo, y en vez de dibujar los diagramas a mano en SVG porque un SVG
escrito a mano es exactamente el tipo de artefacto que nadie vuelve a actualizar cuando el código cambia.
El coste es un blob binario-ish en el historial; el beneficio es que los diagramas se editan en texto.

## Cómo se verifica

`jsdom` NO es dependencia del proyecto y no debe serlo — se instala en un directorio temporal:

    mkdir -p /tmp/atlas-check && cd /tmp/atlas-check && npm init -y && npm i jsdom
    node /Users/jur/Yala/docs/flows/modo-nube/check.mjs

Comprueba siete cosas: los 7 diagramas **parsean**, uno **renderiza** de verdad a SVG, cada
`click … showNode("x")` resuelve a un panel existente, ningún panel queda **huérfano**, los `id` de
screenshot son únicos y siguen la convención `<flujo>-<nodo>.png`, todo panel tiene sus 4 campos y al menos
una coordenada de código, y `index.html` no referencia **ni una** URL remota.

**Muerde** (verificado el 2026-08-09): apuntar un `click` a un nodo inexistente da 2 fallos (el enlace roto
y el panel que se queda huérfano); devolver el `<script>` de mermaid a un CDN da el fallo de offline.

## Estado de las capturas (F2, 2026-08-10)

Recorrido en el simulador (iPhone 17 Pro · scheme Yala Dev contra staging) el **2026-08-10** sobre HEAD
`f4d10fa6`. De los 54 `id` de screenshot: **31 capturas reales** y **23 `device-only`** — cada una con su
motivo y qué debería verse, en `data/f2.js` y en la sección «Capturas» del propio Atlas. `check.mjs`
valida el contrato: cero nodos vacíos, ninguna imagen huérfana, ningún device-only con imagen presente.

Lo que el simulador no pudo dar (marcado, no fingido): todo lo que exige una **sesión backend real**
(SIWA/Google no completan en sim) — claim `created`, adopt, reversa conducida, cutover, banner de sesión,
push-all —, los estados **multi-device** (marcador de líder, faro cross-device) y los que dependen de una
**respuesta del servidor** no fabricable (403, `claiming_in_progress`). El owner los captura en device y
se integran en una pasada posterior.

**Muerde también el contrato F2** (verificado el 2026-08-10): borrar una imagen da `nodo VACÍO`; marcar
device-only un nodo con imagen da la contradicción. Ambos, exit 1.
