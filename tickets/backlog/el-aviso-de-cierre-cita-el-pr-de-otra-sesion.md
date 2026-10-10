---
id: el-aviso-de-cierre-cita-el-pr-de-otra-sesion
status: backlog
priority: low
area: infra
created: 2026-09-09
source: medido al cerrar fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
updated: 2026-10-08
---

# El aviso de cierre cita el PR de otra sesión, y `--rama` no lo arregla


## Segunda causa, medida el 2026-09-09 (PR #118): en una sesión autónoma larga NO se anota ningún PR

El ticket describe un aviso que cita el PR **equivocado**. Hay un modo de fallo distinto y más
silencioso: que no cite **ninguno**.

Medido al cerrar el #118. El fichero de sesión sólo traía dos claves y ninguna era un PR:

```
~/.claude/cache/avisos-grok/sesiones/<id>.json  →  claves: ['fallos', 'rastro']
PR anotados: (ninguno)
```

**Por qué:** quien anota el PR es el hook `artefacto-pr`, y el hook **corre al TERMINAR un turno**.
En una sesión autónoma que abre el PR y sigue trabajando —gate, merges de `2.1`, arreglos, CI— el
turno no termina hasta mucho después, y en este caso el hook no llegó a anotarlo nunca. El aviso de
cierre salió `HTTP 200`, con aspecto correcto, **y mudo en lo único que ya no tiene wake propio**
desde ADR-021.

⇒ Al arreglar esto, las dos causas piden cosas distintas: la del ticket es de **resolución** (usa el
puntero de la rama equivocada); ésta es de **captura** (el rastro nunca se escribe). Un arreglo que
solo toque la resolución deja este caso igual, y es el que se da en toda sesión lanzada larga —
justo aquellas en las que Jürgen no está delante.

## Qué pasa

El aviso de «la sesión ha llegado a su fin» que llega al móvil lleva arriba y en negrita el PR de la
sesión, y **puede ser el de otra**. En el cierre del 2026-09-09 el aviso citó **PR #109** —de una
sesión anterior— cuando los de esa sesión eran **#111 y #112**.

Para quien lo lee desde el móvil, el aviso es correcto en todo lo demás: el resumen es el suyo. Solo
el puntero al trabajo está mal, que es justo lo único que no se puede reconstruir después.

## Medido el 2026-09-09

El hook indexa por `repo + rama` en `~/.claude/cache/avisos-grok/ultimas/`, y la anotación de la
sesión estaba **bien**:

| puntero | sesión | PRs anotados |
|---|---|---|
| `Yala__encargo-2026-09-09-fx-approximate-…` | `3cce8309…` | **#111, #112** ✅ |
| `Yala__2.1` | `84afc49e…` | #109 |

El aviso salió del árbol principal —donde la rama es `2.1`— **con `--rama` puesto y apuntando a la
del encargo**, y aun así resolvió por `Yala__2.1`. `--dry-run` da `#109` con `--rama` y sin él: el
resultado no cambia, así que el flag no llega a la resolución del puntero.

`~/.claude/skills/cerrar-total/SKILL.md` §9 documenta `--rama` como **obligatorio** por este motivo
exacto («sin `--rama` la clave no coincide y el PR no viaja»). La documentación describe la
intención; el comportamiento medido es otro.

## Por qué es `medium` y no `low`

Afecta a **todas** las sesiones lanzadas que cierran con `/cerrar-total`, que es el flujo normal, y
falla en silencio: el envío responde `HTTP 200` y la línea del PR sale con aspecto correcto. Solo se
ve comparando el número con el PR real. El canal existe para las sesiones que Jürgen no ve trabajar;
un puntero equivocado ahí manda a leer el trabajo de otro.

## Qué hay que mirar

- Si `--rama` se usa para componer el aviso pero no para **resolver la sesión** en `ultimas/`.
- Si la normalización del nombre difiere entre quien escribe el puntero (`encargo/x` → `encargo-x`)
  y quien lo lee con el flag.
- El respaldo por «sesión más reciente del repo» es el que acaba ganando; conviene que **avise**
  cuando cae en él, en vez de servir un PR ajeno con la misma cara que el bueno.

## Criterio de hecho (AC)

- [ ] `--avisar cierre-resumen --rama <rama>` resuelve el puntero de ESA rama, y hay un caso que lo
      fija contra dos sesiones del mismo repo.
- [ ] Cuando el puntero no resuelve, el aviso lo dice en vez de caer al de otra sesión en silencio.
- [ ] El §9 de `cerrar-total` describe lo que hace, no lo que se quiso que hiciera.

## Nota de la sesión que lo encontró

El aviso del 2026-09-09 02:41 (`ENVIADO destino=frank motivo=cierre-resumen HTTP 200`) es el que
lleva el `#109` equivocado. **No se mandó un segundo aviso corregido a propósito**: ADR-021 protege
ese canal y un duplicado por una línea vale menos que el ruido que mete. Los PR buenos son #111 y
#112.

## Reincidencia medida el 2026-09-12

Vuelve a pasar, y ahora con el mecanismo entendido del todo. El aviso de las 02:41
(`ENVIADO destino=frank motivo=cierre-resumen HTTP 200`) salió citando **PR #146** — el de la sesión
anterior — cuando los de esta eran **#147 y #148**. Se pasó `--rama` y no cambió nada; `--dry-run`
con el flag da exactamente el mismo texto.

**El dato nuevo es qué hay dentro del puntero.** El fichero de la rama existe y **no contiene ningún
PR**:

```
$ cat ~/.claude/cache/avisos-grok/ultimas/Yala__encargo-2026-09-12-diez-worktrees…txt
89b43ac6-664a-4338-9a8a-c9272875fd7c        ← el session-id, y nada más
```

O sea que no es que la resolución elija mal el fichero: es que **el hook nunca anotó el PR bajo la
clave de la rama** en esta sesión. El PR se abrió con `gh pr create` desde el worktree y el hook no
lo vio, así que la resolución cae al respaldo (`Yala__2.1.txt`) y sirve el del último que cerró. Con
eso, el criterio de hecho de arriba se puede afinar: antes de arreglar la resolución hay que
comprobar **quién escribe el PR en ese fichero y cuándo**, porque puede que el agujero esté en la
anotación y no en la lectura.

Tampoco aquí se mandó un segundo aviso corregido, por lo mismo que la vez anterior.

## Medido en 2.1 (triage 2026-10-08)

- Resolución: `modo_avisar` (`~/.claude/hooks/avisar_grok.py:2052-2065`) sí usa `--rama` para buscar el puntero (`sesion_del_arbol(dict(d, rama=…))`). El primer AC funciona por código.
- Captura: el PR se anota en `PostToolUse` al ver `gh pr create` (`:1733-1736`), no al terminar el turno. En `~/.claude/cache/avisos-grok/ultimas/`, 192 de 194 punteros `Yala__encargo-*` desde el 20-sep tienen PR. Los 2 sin PR (`groups-purge-…` #321 y `groups-detach-…` #319, 01-oct) tuvieron PR y no se anotó.
- Sigue abierto: `sesion_del_arbol` (`:762`) cae al respaldo por repo sin decirlo, y un puntero exacto sin PR produce un aviso sin línea de PR, también sin decirlo (AC 2). El §9 de `cerrar-total` no se ha revisado.

Triage 2026-10-08: abierto · medium → low · `--rama` ya resuelve el puntero y la captura falla en 2 de 194 sesiones desde el 20-sep (#319, #321), pero el respaldo y el aviso sin PR siguen callados (AC 2).
