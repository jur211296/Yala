---
description: Lista items del Backlog con status, prioridad y area para elegir en que trabajar.
---

Muestra el estado del Backlog de features.

## PASO 1: LEER BACKLOG

Leer todos los archivos `.md` en `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki/Backlog/` (ignorar README.md).
Para cada archivo, extraer del frontmatter: `status`, `priority`, `area`, `created`.

## PASO 2: MOSTRAR TABLA

Presentar ordenado por prioridad (alta > media > baja), luego por fecha:

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
- Con spec: N (status = spec-ready)

## PASO 3: SUGERIR ACCION

Si hay items con status `backlog` sin spec:
> Hay N features sin spec. Usa `/spec [nombre]` para desarrollar uno.

Si hay items con status `spec-ready`:
> Hay N features listos para implementar. Usa Plan Mode con el spec.

Si hay items con status `in-progress`:
> Hay N features en progreso. Continua desde donde quedaste (revisa STATE.md).

## REGLAS
- Si el Backlog esta vacio, sugerir crear un feature: "Crea un archivo en Backlog/ desde Obsidian o dime una idea y la creo yo."
- NO modificar ningun archivo, solo lectura
