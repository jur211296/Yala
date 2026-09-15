---
id: generated-index-lands-above-yaml-frontmatter
status: backlog
priority: medium
area: "docs, tooling"
created: 2026-09-15
updated: 2026-09-15
source: "hallazgo propio al cerrar `apple-id-close-blocked-has-no-visible-outcome` (2026-09-15): el recuento del board no encontraba el frontmatter de `groups-consent-door-spec`"
---

# El índice que genera `indexar_doc.py` cae ENCIMA del frontmatter YAML

## Qué pasa

`scripts/indexar_doc.py`, en su camino por encabezados, coloca el bloque `<!-- INDICE:inicio … -->` justo
después de un `# Título` inicial; si el fichero no empieza por `# `, lo pone en la línea 1. Un fichero que
abre con frontmatter (`---`) no empieza por `# `, así que el índice queda **encima** del frontmatter, y el
frontmatter deja de serlo para cualquier lector que lo busque al principio del fichero.

Las dos líneas, medidas en el árbol del 2026-09-15:

```python
m = re.match(r'(?s)(\A#[^\n]*\n+(?:>[^\n]*\n)*\n*)', s)
out = (m.group(1) + bloque + '\n\n' + s[m.end():]) if m else bloque + '\n\n' + s
```

El camino de viñetas (`indice_vinetas`) no lo tiene: `.claude/rules/testing.md` abre con `---` y lleva el
índice debajo.

## Medido el 2026-09-15: 7 ficheros con esa forma

| Fichero | Frontmatter en línea | Qué deja de leerse |
|---|---|---|
| `.claude/rules/git-hooks.md` | 21 | `description` y `paths:`. Es la única de las 8 rules que no abre con `---` |
| `tickets/qa/groups-consent-door-spec.md` | 34 | `id` y `status`: un recuento del board por frontmatter no lo encuentra |
| `docs/modo-nube/MODO-NUBE-DECISION-RELEASE-2.1.md` | 24 | su frontmatter |
| `docs/modo-nube/MODO-NUBE-AUDITORIA-ESCENARIOS.md` | 27 | su frontmatter |
| `docs/modo-nube/MODO-NUBE-DIFERIDOS.md` | 51 | su frontmatter |
| `docs/modo-nube/_archive/fase3-medicion/fase3-REMEDICION-2026-08-04.md` | 47 | su frontmatter (archivo) |
| `docs/modo-nube/_archive/groups-backend-v1.md` | 32 | su frontmatter (archivo) |

## Lo que más importa, y NO está medido

**Si Claude Code solo reconoce el frontmatter al principio del fichero, `git-hooks.md` perdió su carga por
ruta**: se cargaría en todas las sesiones, o en ninguna. Observado sin aislar: en la sesión del 2026-09-15 la
regla entró en contexto tras editar `docs/TICKETS.md`, que no está en sus `paths:`. Puede tener otra
explicación. La comprobación: mover su frontmatter a la línea 1 y ver si deja de cargarse al tocar un
fichero fuera de sus rutas.

## Alcance propuesto

1. Que `indexar_doc.py` inserte el índice **después** del frontmatter cuando el fichero abre con `---`, y
   después del `# Título` que venga detrás, si lo hay.
2. Regenerar los 7 ficheros para que el frontmatter vuelva a la línea 1.
3. Medir la carga de `git-hooks.md` antes y después.

## Criterios de aceptación

- [ ] Ningún `.md` del repo con `<!-- INDICE:inicio` tiene un frontmatter YAML por debajo del índice.
- [ ] `indexar_doc.py --apply` sobre un fichero con frontmatter lo deja en la línea 1, y es idempotente.
- [ ] Medido si `git-hooks.md` carga solo al tocar sus `paths:`.
