---
id: el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo
status: done
priority: high
area: "proceso"
created: 2026-09-08
updated: 2026-09-09
source: medido el 2026-09-05; escalado a ticket el 2026-09-08 al colarse un commit real
---

# El candado que prohíbe atribuir un commit a una IA no está puesto en Yala

## Qué pasa

ADR-013 dice que la regla «ningún commit dice que lo escribió una IA» **no depende de acordarse**,
porque hay un hook `commit-msg` global que la impone. En este repo ese hook **no corre**, y la única
razón de que el historial esté limpio desde el 2026-09-02 es que las sesiones se han acordado.

El 2026-09-08 una sesión commiteó con `Co-Authored-By: … <noreply@anthropic.com>` y el hook no dijo
nada. Se detectó al comparar el mensaje con los commits vecinos —ninguno de los últimos lo lleva— y
se corrigió con `--amend` antes de subir nada, así que no hay daño en el historial: el último commit
con atribución sigue siendo `f09689b2`, del 2026-09-02. Pero la detección dependió de mirar, y eso
no se puede prometer.

## La cronología importa, y no deja bien al método

**Esto se midió el 2026-09-05** y quedó anotado — en la memoria del agente, que es un sitio que solo
lee él. El 2026-09-08 la misma sesión que tenía la nota delante commiteó igualmente con el trailer:
la instrucción por defecto de la herramienta pide ponerlo, y en el instante de redactar el mensaje
ganó ella. Se corrigió con `--amend` antes de subir nada.

O sea que el fallo tiene **dos capas**, y la segunda es la que crea este ticket: el candado no está
puesto, y saberlo no bastó. Una nota que solo evita el error cuando alguien se acuerda de leerla es
justo lo que ADR-013 dice que no quiere. Por eso pasa de nota privada a ticket del repo.

## Por qué no corre (medido el 2026-09-05, re-comprobado el 2026-09-08 en este árbol)

`core.hooksPath` no es acumulativo: **el valor local gana y sustituye al global**, no se fusionan.

```
core.hooksPath (global) = /Users/jur/.claude/git-hooks   →  commit-msg          (ADR-013)
core.hooksPath (local)  = .githooks                      →  pre-commit          (el sello del gate)
```

Yala pone `core.hooksPath` local para su `pre-commit` —el que corre `qa/scripts/precommit-gate.sh`,
añadido el 2026-08-30 en `3fb52618`— y con eso deja fuera **todo** el directorio global, incluido el
`commit-msg` del 2026-09-04. Los dos hooks son correctos por separado; lo que falla es que no pueden
convivir así.

Es probable que afecte a **cualquier repo con `core.hooksPath` local**, no solo a éste. Sin
comprobar en los demás.

## El volumen histórico, medido el 2026-09-09

El ticket dice arriba que «el historial está limpio desde el 2026-09-02», y es cierto en el sentido
que importa —no se han sumado más—. Pero el acumulado de antes no se había contado, y conviene
tenerlo delante al elegir camino: **768 de 3335 commits (23 %)** llevan `Co-Authored-By: Claude` o
`🤖 Generated with` como línea propia del mensaje. El más antiguo es del 2026-01-13 (`40e7c3ce`).

Medido con dos métodos independientes que coinciden. **No cambia el arreglo** —reescribir la
historia rompería todos los SHAs y no se plantea—, pero sí el tamaño de lo que ya viaja en cualquier
clon, que es el argumento de confidencialidad de abajo.

## Por qué importa

No es cosmético: engancha con la regla de confidencialidad del `CLAUDE.md` global —«no se revela el
uso de IA al cliente ni al equipo, **tampoco en el historial de git**»—. Un trailer es permanente,
viaja con el repo y sale en cualquier clon. Y Yala es el repo donde más se commitea.

## Caminos, con su coste

1. **`.githooks/commit-msg` como shim de una línea** que delega en el global
   (`exec bash ~/.claude/git-hooks/commit-msg "$@"`). No duplica la lógica, y si el global cambia el
   repo hereda el cambio. Contra: fija una ruta absoluta del Mac dentro del repo.
2. **Copiar el hook global a `.githooks/`.** Simple hoy, dos copias que divergen en tres meses.
3. **Quitar el `core.hooksPath` local** y llevar el `pre-commit` del gate al directorio global, con
   un guard que compruebe que el repo es Yala. Contra: mete algo de Yala en la config de la casa.
4. **Dejarlo y documentarlo.** Es lo que hay hoy sin saberlo; al menos pasaría a estar escrito.

Elegir es de Jürgen: ADR-013 es suyo y el arreglo toca infraestructura común a todos los agentes.

## Criterio de hecho (AC)

- [x] **Decidido el camino.** Jürgen, 2026-09-09: **hook propio en el repo**, con la lógica
      de atribución, sin delegar en el global. Y la mención a secas de «Claude» **se permite
      en Yala** (ver abajo). Los otros tres caminos y su coste quedan arriba.
- [x] **Un commit de prueba con el trailer se rechaza en este repo** (control positivo: uno
      sin él pasa). Verificado con commits reales, no solo con el banco — abajo.
- [x] **Comprobado si hay otros repos con `core.hooksPath` local en la misma situación.**
      **Yala es el único de los 25 repos del Mac.** Los 9 worktreees que aparecen en el
      barrido comparten su `.git/config`, así que son el mismo repo, no casos nuevos.

## Lo que se midió, y lo que cambió el plan

**La causa del ticket se confirma**: `core.hooksPath` local sustituye al global, y el
`commit-msg` de ADR-013 nunca corrió aquí.

**El volumen se confirma con el hook real**, no con un grep aproximado: se corrió
`~/.claude/git-hooks/commit-msg` contra los 3348 mensajes de la historia. **768 (23 %)**
llevan atribución. La cifra del ticket (768 de 3335) era correcta; el total subió porque se
han sumado 13 commits desde que se escribió.

**Lo que no estaba en el ticket y cambió el camino elegido: el hook global tiene un segundo
nivel.** Prohíbe la *mención* de «Claude» o «Anthropic» fuera de `casa`, `~/.claude` y
`tim`. Aplicado a Yala tal cual, rechaza **216 commits legítimos más** — todos citando
rutas del propio árbol (`CLAUDE.md`, `.claude/rules/testing.md`,
`.claude/agent-memory/`), 29 de ellos solo en septiembre. Verificado con control positivo:
`docs: actualiza CLAUDE.md con la sección de hooks` sale **RECHAZADO**. Por eso el camino 1
del ticket (shim que delega en el global) rompía el flujo normal del repo.

**Y un agujero que ningún nivel 1 veía:** el trailer `Claude-Session:
https://claude.ai/code/session_…` no es un `co-authored-by` y `claude.ai` no casa con el
patrón `claude.com/claude-code` del global. **Ya se coló 7 veces** (la última el
2026-09-02), y 6 commits de febrero llevan la URL suelta sin ningún trailer. El hook de
Yala los caza por dominio; el global solo los pillaba de rebote, por su nivel 2.

## Qué se hizo

- **`.githooks/commit-msg`** — el candado. Rechaza: trailers cuyo *nombre* menciona a
  Claude/Anthropic, trailers de coautoría con Claude/Anthropic en el valor, los dominios
  `claude.ai` / `claude.com` / `anthropic.com`, `generated with/by … Claude` y el emoji 🤖.
  Deja pasar la mención de rutas y **la coautoría humana**.
- **`qa/scripts/commit-msg-test.sh`** — banco de 17 casos + comparación con el hook global.
- **`.github/workflows/qa.yml`** — el banco corre en cada push (job `coverage-index`).
- **`.claude/rules/git-hooks.md`** — la trampa de `core.hooksPath` y las dos diferencias
  deliberadas con el hook global, en una tabla.

## La verificación

**Sobre la historia entera** (3348 mensajes, hook nuevo contra hook global):

| | |
|---|---|
| Rechaza los que el global rechazaba por atribución | **768 / 768** — cero fugas |
| Rechaza además lo que el nivel 1 global no veía | **+6** (URLs de sesión sueltas) |
| Deja pasar las menciones legítimas de rutas | **216 / 216** — cero falsos positivos |

**Los siete controles del banco** (mutantes sobre copias, el fichero real intacto):

| Mutante | Esperado | Resultado |
|---|---|---|
| Hook que siempre pasa | caen los 10 de atribución | 10 fallos, exit 1 |
| Solo los patrones del global | caen los casos 3 y 4 | 2 fallos + DIVERGE |
| Endurecido a lo bruto (`grep -qi claude`) | caen los legítimos | 4 fallos |
| El hook no existe | falla cerrado | exit 1 |
| Hook que solo caza el emoji | divergencia detectada | 5 DIVERGE reales |
| Error interno en el bloque de divergencia | ROJO | ROJO |
| Sin hook global (escenario CI) | verde, y lo dice | «divergencia: saltado» |

**Dos fallos propios que los mutantes cazaron**, y que sin ellos habrían quedado dentro:

1. El banco salía **VERDE tras reventar por dentro** — `mapfile` no existe en el bash 3.2
   de macOS, y el error se colaba por la puerta de «corpus corto». El veredicto es ahora una
   variable explícita, y un corpus anómalo con el hook global presente es **rojo**.
2. La comparación con el global usaba «los últimos 400 commits» como corpus, y **los
   últimos 400 de este repo tienen cero atribución**: el más reciente con trailer está en la
   posición **408**. Medía nada y salía verde. El corpus se elige ahora por contenido, y el
   banco falla si no trae ni un caso de atribución.

## La review adversarial: 28 evasiones, 11 cerradas

Una lente independiente intentó romper el hook y midió **28 falsos negativos**. No se
cerraron todos: se refutó uno a uno por probabilidad real y por lo que costaría.

**Las tres que importaban de verdad, y ninguna estaba en el mensaje:**

1. **El autor del commit.** `git commit --author="Claude <noreply@anthropic.com>"` deja
   atribución **permanente en la cabecera** —más visible que un trailer— y el hook no la
   veía: `$1` solo trae el mensaje. La lente lo dio por incerrable «por construcción».
   Medido después: `git var GIT_AUTHOR_IDENT` **sí** devuelve la identidad efectiva desde
   dentro de un `commit-msg`. Cerrado.
2. **El diff de `git commit -v` se pega en el mensaje SIN comentar**, tras la línea de
   tijera. Y el diff de este mismo fichero contiene `claude.ai` y `Co-Authored-By`: sin
   cortar por la tijera, **tocar el candado con `-v` hacía que el candado se rechazara a
   sí mismo**. Es un falso positivo, no un falso negativo, y lo habría encontrado el
   primero que editara el hook.
3. **`grep -v '^#'` borraba de más.** Los comentarios de git llevan `#` **más un
   espacio**; una línea `#Co-Authored-By: …` pegada **sobrevive al `git commit -m`**
   (el cleanup por defecto es `whitespace`, medido con `git stripspace`). Esconder la
   firma ahí funcionaba.

Y una de volumen: el ancla `^[[:space:]]*` se desactivaba con un guion delante, y **el
37 % de los cuerpos de commit de este repo usan viñetas `- `**.

**Lo que se dejó abierto a propósito**, porque cerrarlo haría más daño:

| | Por qué |
|---|---|
| «IA» / «AI» a secas | Yala **tiene** features de IA y sus commits las nombran: falso positivo semanal |
| «Opus», «Sonnet» sueltos | Palabras comunes; sin «Claude» al lado no distinguen nada |
| Ofuscación (`claude[.]ai`) | Es un candado contra el olvido, no contra un adversario — quien quiera tiene `--no-verify` |

**Re-medido tras endurecer**, sobre los 3348 mensajes: mismos **774** rechazos, mismas
**0** fugas y **0** falsos positivos nuevos. El banco pasa de 17 a **28 casos**, dos de
ellos sobre el autor —que no se pueden montar con un fichero de mensaje y se montan con
el entorno.

## La segunda lente: el endurecimiento traía su propio bug

La primera lente atacó el candado; la segunda buscó dónde **estorba**. Cazó cuatro cosas, y
la primera invalidaba parte del arreglo anterior:

1. **Las reglas de prosa que acababa de añadir creaban falsos positivos.** Con una ventana
   de 60 caracteres, «generado con … `.claude/rules/testing.md`» disparaba. El caso que
   duele: **«Escrito por Jürgen; el índice vive en CLAUDE.md» salía RECHAZADO** — el
   candado tumbaba un commit por atribuir el trabajo **a Jürgen**. Y no era hipotético:
   **7 commits reales** dicen «Generated with» citando `.claude/…` y solo sobreviven por la
   distancia entre las dos mitades. Arreglado **borrando las rutas del repo del texto antes
   de escanear** — que es coherente con la decisión de Jürgen: aquí nombrarlas se puede. Los
   dominios no son rutas y siguen siendo firma.
2. **El candado no corre en `rebase`, `cherry-pick` ni `revert`** (sí en `commit`, `amend`,
   `fixup`, `squash` y `merge`), ni en los botones de merge de la web. No se puede cerrar
   desde un `commit-msg`: git no lo invoca. → ticket
   `rebase-and-cherry-pick-skip-the-attribution-hook`.
3. **Tres fallos del banco.** `mktemp` fallando dejaba `TMP` vacío, los mensajes se
   escribían en `/` y salía **VERDE 17/17** sin haber probado nada; `HOME` sin definir lo
   tumbaba con `unbound variable` y ni una línea útil. Los dos, arreglados.
4. **Un caso que pasaba sin comprobar nada** (el del autor humano, si `git var` no
   contestaba). Añadí un guard… y un mutante demostró que **el guard no podía fallar** y que
   su pareja —el caso del autor falsificado— **ya cubría el escenario**. Retirado el guard:
   antes de apuntalar, comprobar si el mecanismo que ya existe basta.

**Re-medido con el hook final** sobre los 3348 mensajes: **el conjunto de 774 rechazos es
idéntico** al de antes de neutralizar rutas. Cero fugas, cero falsos positivos. El banco
queda en **32 casos**.

## Lo que queda abierto

- **El candado vive en el árbol de trabajo**, así que una rama que no traiga
  `.githooks/commit-msg` no lo tiene. Los worktrees vivos lo heredan al rebasar sobre `2.1`.
- **En ubuntu no se pudo probar en local** (no hay GNU grep en este Mac). Lo verifica el
  propio CI de este PR.
- El hook global de `~/.claude` **no se tocó**: ADR-013 sigue siendo la SSOT para los otros
  24 repos. Que Yala tiene el suyo conviene anotarlo allí — ticket aparte.
