---
id: generated-index-lands-above-yaml-frontmatter
status: done
priority: medium
area: "docs, tooling"
created: 2026-09-15
updated: 2026-10-07
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

- [x] Ningún `.md` del repo con `<!-- INDICE:inicio` tiene un frontmatter YAML por debajo del índice.
- [x] `indexar_doc.py --apply` sobre un fichero con frontmatter lo deja en la línea 1, y es idempotente.
- [x] Medido si `git-hooks.md` carga solo al tocar sus `paths:`.

## Resuelto (2026-10-07)

**Re-medido en el árbol del 2026-10-07:** los mismos 7 ficheros de la tabla, y ninguno más.

- **El script.** Los dos caminos (encabezados y viñetas) colocan el índice detrás del frontmatter, si el
  fichero abre con `---`, y detrás del `# Título` con sus citas, si lo hay. El camino de viñetas también
  fallaba: exigía un título detrás del frontmatter, y sin él el índice volvía a la línea 1. Y el título
  ahora es solo un h1: el patrón viejo tomaba un `## Sección` inicial por título y metía el índice debajo
  de la primera sección. Pasado el script nuevo por los 15 `.md` con índice, ninguno cambia de sitio.
- **Los 7 ficheros.** Frontmatter otra vez en la línea 1. Se movió el bloque existente tal cual: dos de
  ellos (`MODO-NUBE-DIFERIDOS`, `MODO-NUBE-AUDITORIA-ESCENARIOS`) regenerados darían un KB más en el aviso,
  y eso habría sido cambiar contenido. Comprobado por fichero: mismas líneas y mismas líneas en blanco.
- **El banco.** `bash scripts/indexar_doc_test.sh`: 9 casos (con y sin frontmatter, con y sin título,
  la forma del bug, los dos caminos, segunda pasada idéntica, líneas del índice de viñetas). Con el script
  viejo da 4/9; con el nuevo, 9/9. No lo corre el CI.
- **La carga de `git-hooks.md`, medida** con `claude -p` (Haiku, sin herramientas, hooks apagados) y el
  `CLAUDE.md` como control positivo:

  | Frontmatter | Al arrancar, sin tocar nada | Tras leer `.githooks/commit-msg` |
  |---|---|---|
  | línea 21 (antes) | **cargada** — entraba en toda sesión | — |
  | línea 1 (después) | no cargada | cargada |

  O sea: Claude Code solo reconoce el frontmatter en la línea 1, y sin él la regla se cargaba siempre. Lo
  observado el 2026-09-15 (entró tras editar `docs/TICKETS.md`) era eso. El resto de rules con índice ya
  abrían con `---`.

