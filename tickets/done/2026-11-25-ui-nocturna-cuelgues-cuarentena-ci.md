---
id: 2026-11-25-ui-nocturna-cuelgues-cuarentena-ci
status: done
priority: medium
area: "ci, qa"
created: 2026-11-25
updated: 2026-11-25
card: tablero-cuelgues-de-10-min-en-la-ui-nocturna-5-p-nzbh
source: "análisis del CI del 25-nov (docs/analisis/ci-ui-rojo-2026-11-25/), lote de infraestructura"
---

# UI nocturna y CI: cuelgues de 10 min, cuarentena para la UI y CI de PR de 67 min

Tres cards del tablero (2.3) en un lote: los cuelgues de 10 min que pintan tandas de la nocturna
(`tablero-cuelgues-de-10-min-en-la-ui-nocturna-5-p-nzbh`), la cuarentena que solo leían los unit
(`tablero-cuarentena-tambien-para-la-ui-nocturna-u-h29j`) y el CI de un PR con código que tarda 67 min
(`tablero-el-ci-de-un-pr-con-codigo-tarda-67-min-d-8gzy`).

## Hecho cuando

- Los cuelgues tienen causa y remedio.
- Una prueba de UI en cuarentena que falla no pinta su tanda y sale aparte en el aviso (banco).
- El tiempo del CI de PR está medido por paso, con su recorte aplicado o su propuesta en una card.

## Resolución (2026-11-25)

**Cuelgues.** Leídos los logs de las tandas de las nocturnas del 22 al 25-nov (el CI no sube el
`.xcresult` de UI). En los cinco casos la app deja de avisar que está quieta («App animations complete
notification not received»): cada acción espera 60 s y el caso agota los 10 min. Once casos distintos en
cuatro noches, siempre formularios con teclado o el chat, ninguno repetido. `-retry-tests-on-failure` no
reintenta un caso cortado por tiempo: xcodebuild reinicia el runner y el caso queda rojo. Remedio: paso
«Veredicto de la tanda» (`qa/scripts/ci-ui-veredicto.py`) que relanza una vez, solo, cada caso cortado
(como mucho 3). Bajar el tope no lo arreglaba (el verde más lento sin esperas mide 444 s).

**Cuarentena de UI.** El mismo veredicto lee `qa/cuarentena.json` de 2.3: un rojo final en la lista no
pinta la tanda y sale aparte en el aviso (salidas `uiq_N`). Formato en el `_meta.ui` del fichero y en
`.claude/rules/ci-qa.md`. Banco `ci-ui-veredicto-test.sh` (24 comprobaciones) en `coverage-index`.

**CI de PR.** 63 runs verdes con código del 19 al 25-nov: mediana 66,6 min = build ~29-33 + cola de
macOS de los unit 12,6 (3 de día, 41 de noche, por la nocturna) + unit 24. El build no aprovechaba la
caché: el checkout deja todas las fechas nuevas, y la caché de compilación de Xcode invalida el módulo
entero con cualquier cambio. Medido en la Mini: una línea cambiada costaba 219-242 s con esa caché;
sin ella y con el paso «Fechas de los ficheros desde la caché» (`qa/scripts/ci-fechas-desde-cache.py`),
55-66 s. Clave de caché a `ddp-v2`. Trampa medida: fechas derivadas del contenido dieron un binario viejo
con el build en verde (el build compara «más nuevo que»); la regla que entra nunca da a un fichero
cambiado una fecha más vieja. Límite: un PR que cambia declaraciones recompila `YalaTests` entero
(518 s, como un build completo). Propuestas en dos cards: la cola de noche
(`tablero-ci-de-pr-de-noche-41-min-de-cola-de-maco-xfac`, Jürgen) y la recompilación de las pruebas
(`tablero-ci-de-pr-el-build-recompila-todas-las-pr-bf2e`, Frank).
