---
id: readme-index-duplicates-internal-worktree-files
status: done
priority: low
area: "docs"
created: 2026-09-09
updated: 2026-10-08
source: visto al reindexar en el cierre del candado anti-atribución
---

# El índice del README duplica cada fichero grande

## Qué pasa

`scripts/indice_readme.py` escanea el árbol entero, y dentro hay un worktree interno
(`.claude/worktrees/elastic-ritchie-9f2188/`) con una copia del repo. Resultado: la lista
de «ficheros de más de 60 KB» sale con cada entrada **dos veces**, una real y otra dentro
de ese worktree.

```
✓ docs/DECISIONS.md (246 KB) · ✓ .claude/worktrees/elastic-ritchie-9f2188/docs/DECISIONS.md (243 KB) · …
```

Son 6 ficheros reales y 12 filas, y las copias además traen **tamaños desfasados** (243 KB
frente a 246), porque el worktree se quedó en un commit anterior. Un lector que siga esa
ruta llega a una copia vieja.

## Qué haría falta

Excluir del escaneo `.claude/worktrees/` y cualquier otro worktree anidado —lo mismo vale
para `scripts/frescura.py` y `glosario.py` si comparten el recorrido, conviene mirarlo—.

## Criterio de hecho (AC)

- [ ] El índice del README lista cada fichero una sola vez.
- [ ] Comprobado que ningún otro generador arrastra el mismo doble conteo.


## Se ha vuelto a abrir TRES veces más, y eso es parte del problema (2026-09-14)

Cada cierre que corre `indice_readme.py --apply` desde el árbol principal tropieza con esto, ve un diff
que no entiende, lo revierte y abre un ticket nuevo sin buscar el que ya había. Duplicados retirados a
`discarded`, todos apuntando aquí:

| id | creado | en el cierre de |
|---|---|---|
| `readme-index-generator-counts-worktree-copies` | 2026-09-13 | #151 |
| `readme-index-lists-files-from-other-worktrees` | 2026-09-13 | #152 |
| `readme-index-scans-internal-worktrees` | 2026-09-14 | #156 |

**Lo que añaden y conviene conservar:** el contenido de la línea depende de **qué worktrees existan en
el instante de correr el script**, así que el diff cambia en cada cierre y nunca converge — en el #152
pasó de citar uno a citar cuatro, y desplazó fuera de la lista entradas reales del repo. La
comprobación que cierra esto en una frase: **correr el generador con varios worktrees vivos y con
ninguno tiene que dar el MISMO resultado**. Hoy no lo da.

**Y la entrada de `elastic-ritchie-9f2188` sigue commiteada en `README.md`**: se limpia con el arreglo.

**Cuarta vez, en el cierre del #160 (2026-09-14) — y con un dato que acota el arreglo: el prefijo del
nombre CAMBIÓ.** Esta vez los intrusos eran tres `.claude/worktrees/bridge-cse_<uuid>/`, no
`elastic-ritchie-*`. Así que excluir por nombre concreto no sirve: hay que excluir **`.claude/worktrees/`
entero** (o cualquier directorio que contenga un `.git`, que es el término que también cubre worktrees
anidados fuera de esa ruta). Y se confirmó el daño que el #152 describía: con doce filas de tope, las
copias **expulsaron de la lista** a `docs/modo-nube/MODO-NUBE-DIFERIDOS.md`,
`tickets/qa/groups-consent-door-spec.md` y `docs/audit/AUDIT-UI-patterns.md` — ficheros reales del repo
que el índice existe para nombrar. El cierre revirtió el diff, otra vez.

**Quinta vez, en el cierre del #161 (2026-09-14).** Mismo diff, misma causa, mismos tres ficheros
expulsados: no aporta medición nueva y por eso no lleva bloque propio. Lo que sí es dato es **la
frecuencia** — cinco cierres seguidos han corrido el generador, han leído un diff que no converge y lo
han revertido a mano. El arreglo es una línea en el `dirs[:]` de `scripts/indice_readme.py:90`, que hoy
excluye `.git`, `node_modules`, `.build` y `DerivedData` y no `.claude/worktrees`. Sigue en `low`; si el
sexto cierre vuelve a tropezar, el coste acumulado ya no es `low`.

## Tres duplicados más, retirados el 2026-10-07

`readme-index-generator-walks-into-claude-worktrees` (2026-09-15), `indice-readme-cuenta-los-ficheros-de-los-worktrees-anidados`
(2026-09-16) e `indice-readme-barre-worktrees-anidados` (2026-09-21) pasan a `discarded` apuntando aquí. Lo que traían y
este ticket no tenía:

- **Git ya sabe que no es del repo**: `.claude/worktrees/elastic-ritchie-9f2188` está en `.git/info/exclude:18` (medido el
  2026-09-15). De ahí la opción que cierra la familia entera: barrer solo lo que git conoce (`git ls-files`), en vez de
  acordarse del siguiente directorio que aparezca.
- **Otro fichero expulsado de la lista**: el 2026-09-16 las copias sacaron del índice a las cinco últimas entradas reales,
  entre ellas `.claude/rules/swiftdata-cloudkit.md`.
- **Las cifras reales se quedan desfasadas**: como cada cierre revierte el diff entero, los cambios de tamaño verdaderos
  (`aprendizajes-tecnicos.md` 205→207 KB, `groups-consent-door-spec.md` 96→98, el 2026-09-21) tampoco entran.
- **Un hermano más que mirar**: además de `frescura.py` y `glosario.py`, `reorg_docs.py`, que corre en el mismo paso del
  cierre. En esas corridas ninguno ensució nada, pero no se midió si es por diseño o por suerte.
- Reaperturas: con éstas son ocho cierres que tropezaron con el mismo diff.

## Medido en 2.1 (triage 2026-10-08)

- Arreglado en ef7813db2 (2026-09-21): el `dirs[:]` de `scripts/indice_readme.py` excluye además cualquier subdirectorio que contenga un `.git` (fichero en un worktree, directorio en un clon), sin depender del nombre. Así el resultado es el mismo con worktrees vivos o sin ellos.
- `README.md` de hoy: la línea de «Ficheros de más de 60 KB» lista 12 ficheros reales, cada uno una vez, sin ninguna ruta `.claude/worktrees/`, y con los tres que las copias expulsaban (`MODO-NUBE-DIFERIDOS.md`, `groups-consent-door-spec.md`, `AUDIT-UI-patterns.md`).
- Hermanos: `frescura.py` recorre con `glob('**/*.md')`, que no entra en directorios ocultos como `.claude/`; `glosario.py` y `reorg_docs.py` solo leen rutas concretas. Ninguno arrastra el doble conteo.

Triage 2026-10-08: resuelto · low → — · ef7813db2 excluye los checkouts anidados por su `.git` y el README ya lista cada fichero una vez.
