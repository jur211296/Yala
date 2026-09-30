---
description: Lista items del Backlog con status, prioridad y area para elegir en que trabajar.
---

Muestra el estado del Backlog de features.

## PASO 1: LEER BACKLOG

Leer todos los archivos `.md` en `tickets/backlog/` y `tickets/in-progress/` (ignorar `.gitkeep` y README.md). Índice: `docs/TICKETS.md`.
Para cada archivo, extraer del frontmatter: `status`, `priority`, `area`, `created`.

## PASO 2: MOSTRAR TABLA

Presentar ordenado por prioridad (`critical` > `very-high` > `high` > `medium` > `low` > `very-low`; sin priority al final), luego por fecha:

```
## Backlog

| # | Feature | Status | Prioridad | Area | Creado |
|---|---------|--------|-----------|------|--------|
| 1 | nombre  | backlog | alta     | panel | 2026-03-24 |
| 2 | nombre  | in-progress | media | stats | 2026-03-20 |
```

### Resumen
- Total: N features
- En progreso: N
- Listos para spec: N (status = backlog)
- En `tickets/qa/`: N

## PASO 3: SUGERIR ACCION

Si hay items con status `backlog` sin spec:
> Hay N features sin spec. Usa `/spec [nombre]` para desarrollar uno.

Si hay items con status `in-progress`:
> Hay N features en progreso. Continua desde donde quedaste (el último PR mergeado lo cuenta: `gh pr list --state merged --base 2.1 -L 5`).

## REGLAS
- Si el Backlog esta vacio, sugerir crear un feature: "Crea un archivo en `tickets/backlog/` o dime una idea y la creo yo."
- NO modificar ningun archivo, solo lectura
