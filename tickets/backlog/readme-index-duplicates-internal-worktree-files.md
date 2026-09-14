---
id: readme-index-duplicates-internal-worktree-files
status: backlog
priority: low
area: "docs"
created: 2026-09-09
updated: 2026-09-14
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
