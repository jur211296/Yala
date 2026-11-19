# Revisión mensual de escapes

Propuesta P5 de verificación (17-nov-2026, aprobada por Jürgen: «Apliquemos todo lo recomendado»). Una
sesión al mes cuenta qué bugs llegaron a `2.3` y otro PR tuvo que arreglar, dice qué gate los habría
parado, propone ítems para la checklist de confiabilidad y poda lo que ya no sirve. La primera revisión
(3 al 17-nov) está en [`escapes/2026-11.md`](escapes/2026-11.md); esta página es el método para que la
siguiente lo haga igual.

**Quién y cuándo.** Frank, una sesión al mes; puede ir con la planificación de los viernes. La ventana es
del día siguiente a la revisión anterior hasta hoy. El resultado es un PR a `2.3` con
`docs/verificacion/escapes/AAAA-MM.md`, el artifact con las propuestas y, si toca, la poda.

## Vocabulario

- **Aterrizaje**: cada commit de `2.3` por primer padre (`git log --first-parent`). Es un merge de PR, un
  squash o un commit directo.
- **Arreglo**: commit `fix…` (commits convencionales) dentro de un aterrizaje de la ventana.
- **Origen**: el aterrizaje que escribió las líneas que el arreglo borra o cambia.
- **Escape**: un arreglo cuyo origen es OTRO aterrizaje. Dos clases, separadas por la rama `1.0`, que es lo
  publicado:
  - `escape-publicado`: el origen ya estaba en `1.0`; el bug llegó a los usuarios.
  - `escape-rama`: el origen solo estaba en `2.3`; lo paró algo antes de publicar, pero después de mergear.
- `mismo-pr`: el origen es el propio aterrizaje del arreglo. Lo cazó su revisión, **no es escape**.
- `sin-codigo`: el arreglo no toca código de producción (pruebas, CI, docs). No se atribuye.

## Qué se mide, y de dónde

| Qué | Cómo | Fuente |
|---|---|---|
| Arreglos, escapes y su origen | `python3 -I docs/verificacion/escapes/medir_escapes.py --desde AAAA-MM-DD --hasta AAAA-MM-DD --origen-declarado --json /tmp/escapes.json` | `git blame` en el padre de cada arreglo; `gh` para la línea `Origen:` |
| Cuántos PRs de arreglo declaran su origen | la línea `con línea Origen: X de N` de la misma salida | cuerpo de los PRs (sin comentarios HTML: la plantilla trae ejemplos dentro de uno) |
| Qué ítems de la checklist habrían saltado en el PR de origen | `python3 -I qa/scripts/checklist-elegir.py --rango <merge>^1..<merge> --formato json` sobre cada origen, con el selector y la checklist de `origin/2.3` | el diff del origen |
| Último disparo de cada ítem | `python3 -I docs/verificacion/escapes/ultimo_disparo.py --dias 90` | el selector de `origin/2.3` sobre cada aterrizaje de los últimos 90 días |
| Rojos de interfaz que llegaron a `2.3` | los tickets de las tandas de la nocturna (`tickets/*/…ui-tests-rojos…`) y `gh run list --workflow QA --event schedule` | el script no los ve: se arreglan con `test(…)`, no con `fix(…)` |
| Rescates de pruebas inestables | resumen del job `tests` («Rescate fuera de cuarentena») | `qa/cuarentena.json` y los logs de CI |

**El blame se equivoca, y hay que mirarlo.** En la primera revisión, de 90 escapes, la atribución se
confirmó en 45; 29 quedaron dudosas y 16 refutadas. El blame cae en un refactor que movió líneas, en el merge
grande del 19-jun-2026 (`64116650b`), en la línea vecina de un arreglo que solo añade, o en quien movió un
texto que el arreglo amplía. Cuando el revisor encuentra el origen real (con `git log -S`), lo anota. Por eso cada escape pasa por un revisor que confirma o refuta la atribución leyendo los dos
commits, y la tabla final dice cuál de las dos es. La clase (`publicado` / `rama`) solo vale si la
atribución se confirma.

## Cómo se juzga cada escape

Un revisor por lote de unos 20 escapes (subagentes en paralelo, solo lectura). Para cada uno devuelve:
el bug en lenguaje de usuario, la atribución (`confirmada` · `dudosa` · `refutada`), quién lo encontró
(barrido en el iPhone, simulador, Sentry, nocturna, Jürgen, revisión) y **el gate más barato que lo habría
parado antes de mergear el origen**:

| Gate | Cuándo |
|---|---|
| `unit` | una prueba unitaria de la lógica |
| `ui-de-lo-tocado` | el XCUITest de las pantallas que tocó el origen (P2) |
| `texto-grande-voiceover` | un pase de accesibilidad |
| `checklist-existente` | un ítem que trata ESE fallo, no solo uno que se dispara por la carpeta |
| `checklist-nuevo` | haría falta un ítem que no existe |
| `solo-dispositivo` | iCloud real, dos teléfonos, memoria o rendimiento en un iPhone, permisos |
| `decision-producto` | no era un bug: cambió el criterio o el texto |
| `ninguno-razonable` | nada proporcionado lo habría visto |

## Cuándo se propone un ítem nuevo de checklist

Las tres condiciones, sin excepción (son las mismas que la cabecera de `qa/checklist-confiabilidad.yaml`):

1. **El patrón salió en dos PRs de origen distintos** de la ventana o de revisiones anteriores. Dos arreglos
   del mismo origen cuentan como uno.
2. **Se ve en un diff**: hay un texto que el selector puede buscar (`rutas` + `simbolos` o `patrones`) y que
   un revisor reconoce.
3. **Lo refuta un revisor independiente**, que no vio el razonamiento: intenta tumbarlo (¿ya lo cubre un
   ítem?, ¿ya lo vigila una prueba?, ¿el disparador saltaría en medio repo?, ¿los dos casos son el mismo
   patrón?). Si sobrevive, se propone.

**Ningún ítem nuevo entra en el YAML sin el visto de Jürgen.** Van como propuesta en el artifact de la
revisión y en `escapes/AAAA-MM.md`; el PR que los mete es aparte, cuando él diga cuáles.

## La poda

### De la checklist: lo que no se disparó en 90 días

`ultimo_disparo.py --dias 90` lista los ítems sin disparo. Cada uno se mira antes de archivar, porque «no se
disparó» tiene dos lecturas:

- **Nadie tocó su zona.** El riesgo sigue: se queda, y se anota en la revisión con la fecha.
- **Su disparador ya no casa con el código** (una ruta movida, un símbolo renombrado). Se arregla el
  disparador, no se archiva. El banco (`qa/scripts/checklist-confiabilidad-test.sh`) caza lo que ya no
  existe, pero no lo que existe y ya no se toca.
- **El riesgo desapareció** (el código se borró, una prueba automática lo vigila ya). Se archiva: el ítem
  sale del YAML a una sección `## Archivados` de `docs/verificacion/checklist-confiabilidad.md` con fecha y
  porqué. No se borra.

### De las reglas de `.claude/rules/`

Una entrada de una regla sale a `.claude/rules/archivo/<regla>.md` con uno de dos motivos:

- **Cubierta**: su lección la comprueba la `comprobacion` de un ítem de la checklist. En la regla viva queda
  una línea con el título, el ítem y la sección `§N` del archivo, para que quien escribe código en esa
  carpeta sepa que existe. Un revisor independiente comprueba, entrada por entrada, que el título y el ítem
  no pierden ninguna regla operativa; las que pierden algo se quedan.
- **No aplica**: describe código que ya no existe, medido con `git grep` **sin contar comentarios** (en este
  repo los nombres de lo borrado sobreviven en comentarios: `SplitSyncManager` sale 49 veces en `Yala/` y no
  se declara en ninguna). No deja línea.

**«Lo cita un ítem» no es «lo cubre un ítem».** En la primera poda (17-nov) se propusieron 41 entradas
«cubiertas» porque un `regla:` de la checklist las citaba; el revisor independiente encontró en 32 una regla
operativa que ni el título ni la comprobación del ítem dicen (p. ej. «no añadas un case a `MigrationPhase`,
es append-only», «el rollback del drain cubre solo los pasos 6-7»), y se quedaron en la regla viva. La
checklist es el disparador de la revisión; la regla es lo que lee quien escribe el código. Solo se archiva lo
que el revisor da por `ok`.

El archivo no se carga solo: su frontmatter tiene `paths: [".claude/rules/archivo/**"]`. **Un fichero de
`.claude/rules/` sin `paths:` se carga en cada sesión**, también desde una subcarpeta: no lo olvides.

Después de mover texto, **los `regla:` de la checklist se recalculan**: apuntan a líneas, y el banco solo
comprueba que la línea exista, no que siga siendo la misma lección. En la poda del 17-nov los punteros a
`testing.md` ya estaban desplazados unas nueve líneas por cambios de ese mismo día. Se regenera el índice de
la regla con `python3 scripts/indexar_doc.py <regla> --apply`.

## Qué queda escrito

- `docs/verificacion/escapes/AAAA-MM.md`: las cifras, la tabla de escapes con gate y atribución, los
  patrones repetidos, los ítems propuestos con su refutación, lo podado y lo que queda para el mes siguiente.
- Un artifact con lo mismo para Jürgen (antes/después, qué se midió, qué se propone).
- El ticket en `tickets/done/` y su fila en `docs/TICKETS.md`.
- **No** se escribe el detalle en las reglas: si un escape enseña una lección nueva que no es un ítem de
  checklist, va a la regla de su área como siempre.
