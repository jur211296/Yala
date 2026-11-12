---
id: inbox-strings-show-a-python-dict-in-four-languages
status: done
priority: medium
area: l10n
created: 2026-10-17
updated: 2026-10-17
source: merge 2.1 → 2.2 del 2026-10-17 · card `tablero-la-bandeja-ensena-un-diccionario-en-vez-g5qd`
---

# La Bandeja enseña un diccionario en vez de la traducción en alemán, francés, italiano y portugués

En 2.2, el commit `e3993094b` (lote 4 de la auditoría UX) escribió diez cadenas de la Bandeja como un diccionario
de Python serializado en lugar de la traducción: `"inbox.editDraft" = "{'de': 'Entwurf bearbeiten', 'fr': …}"`.
Afectaba a `de`, `fr`, `it`, `pt`, `pt-BR` y `pt-PT`, en `inbox.editDraft`, `inbox.cannotApprove`, `inbox.source*`,
`inbox.duplicateWarning*` e `inbox.createAnyway`. Medido en el simulador en alemán el 2026-10-17: el título de la
hoja de un borrador decía literalmente «{'de': 'Entwurf bearbeiten', 'fr'…».

## Resuelto (2026-10-17)

- `pt` y `pt-BR` se arreglaron en el propio merge, porque esas claves chocaban con las traducciones de 2.1.
- En `de`, `fr`, `it` y `pt-PT` cada valor pasa a ser la entrada de su idioma dentro del propio diccionario.
- `LocalizableValuesAreNotDictsTests` falla si algún valor de los 16 catálogos empieza por `{'`. Se verificó con
  el catálogo alemán de antes del arreglo, y el test se puso en rojo.
