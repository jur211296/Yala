---
id: 2026-11-17-verificacion-escapes-y-poda
status: done
priority: medium
area: "qa, verificacion, reglas"
created: 2026-11-17
updated: 2026-11-17
source: "propuesta P5 de la verificación del 17-nov (docs/verificacion/), aprobada por Jürgen: «Apliquemos todo lo recomendado»"
---

# «Origen:» en los arreglos, primera revisión de escapes y poda de reglas

Hasta hoy nadie medía qué bugs llegaban a `2.3` ni qué gate los habría parado, ningún PR de arreglo decía de
dónde venía el bug y las reglas solo crecían. Ahora hay una convención, dos scripts que hacen la revisión
repetible, la primera revisión hecha y una poda con criterio.

## Qué se hizo

- **Convención `Origen:`.** `.github/pull_request_template.md` (nueva) la pide en todo PR de arreglo: `Origen:
  #N`, `Origen: desconocido — <por qué>` o `Origen: este PR`. Como las sesiones abren los PRs con `gh pr create
  --body`, que no lee la plantilla, la misma línea está en `/cerrar` (bloque 5, el cuerpo del PR) y en el
  skill `bugfix` (paso 9).
- **`docs/verificacion/escapes/medir_escapes.py`**: recorre `2.3` por primer padre, toma cada commit `fix…`,
  hace `git blame` de lo que borra y lo lleva a su PR de origen. Clasifica en `escape-publicado` (el origen
  está en `1.0`), `escape-rama`, `mismo-pr` y `sin-codigo`. `--origen-declarado` lee la línea `Origen:` de los
  PRs (sin contar la plantilla, que va en un comentario HTML).
- **`docs/verificacion/escapes/ultimo_disparo.py`**: recalcula cuándo se disparó por última vez cada ítem de la
  checklist pasando el selector de `2.3` por cada aterrizaje de los últimos 90 días. `ultimo_disparo` del YAML
  no lo escribe nadie (a propósito), así que el criterio de los 90 días necesitaba esto.
- **`docs/verificacion/revision-de-escapes.md`**: el método de la revisión mensual (qué se mide y de dónde,
  cómo se juzga cada escape, cuándo entra un ítem nuevo, la poda y su criterio de 90 días).
- **Primera revisión, 3 al 17-nov: `docs/verificacion/escapes/2026-11.md`.** 115 commits de arreglo en 80 PRs:
  90 escapes (79 de código ya publicado, 11 solo de 2.3), 7 cazados en su propio PR, 18 sin código de
  producción. Cuatro revisores en paralelo juzgaron los 90. Ítems nuevos: solo propuestos, en el artifact.
- **Poda.** 10 entradas de `swiftdata-cloudkit.md` (3 «no aplica»: describen el transporte CloudKit de Grupos,
  borrado el 2026-08-06; 7 «cubiertas» por la checklist) y 2 de `testing.md` pasan a `.claude/rules/archivo/`,
  con su porqué y una línea en su sitio. Se propusieron 41 «cubiertas»; un revisor independiente encontró en 32
  una regla operativa que la checklist no dice y se quedaron. Los `regla:` de `qa/checklist-confiabilidad.yaml`
  se recalcularon por texto (los de `testing.md` ya estaban desplazados por cambios del mismo día).
- **«Lista Negra».** `testing.md` y `/gate` citaban `TESTING-STRATEGY.md`, que no existe: ahora apuntan a la
  cuarentena (`qa/cuarentena.json`) o a un ticket.

## Qué se probó

- `medir_escapes.py` sobre la ventana real (115 commits, ~2 min) y `ultimo_disparo.py` con 15 días contra una
  rama local con la checklist y el selector juntos (249 aterrizajes, 30 ítems, 2 sin disparo).
- `qa/scripts/checklist-confiabilidad-test.sh` con los `regla:` nuevos.
- `scripts/indexar_doc.py` regenera los índices de las dos reglas.

## Lo que queda

- Los ítems propuestos esperan el visto de Jürgen en el PR; el que los meta en el YAML es otro PR.
- La próxima revisión: mediados de diciembre, con la ventana 18-nov → hoy.
