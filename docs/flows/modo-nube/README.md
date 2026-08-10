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
| `vendor/mermaid.min.js` | Mermaid 11.6.0 vendorizado — **2,5 MB**, la única dependencia |
| `img/` | Las capturas. Las puebla el chip **F2**, una por `id` de screenshot |
| `check.mjs` | El pin: valida diagramas, enlaces, convención de ids y que el HTML sea offline |

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

## Para el chip F2

Cada nodo con `id` de screenshot espera su imagen en `img/<id>.png`. Los nodos marcados «decisión pura,
sin pantalla» no tienen captura **por construcción** y no cuentan como hueco — el propio Atlas los cuenta
aparte en la sección «Qué le toca a F2».

Lo que el simulador no puede dar (y se marca `device-only`, no se finge): el sheet real de SIWA/Google
completándose, la atestación contra producción y el faro cross-device real (iCloud KV sin cuenta en el
simulador).
