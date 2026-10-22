---
description: Los hooks de git de Yala — por qué el repo tiene su propio commit-msg, qué bloquea y qué no, y la trampa de core.hooksPath. Se cargan al tocar .githooks/ o los scripts del gate.
paths:
  - ".githooks/**"
  - "qa/scripts/commit-msg-test.sh"
  - "qa/scripts/precommit-gate.sh"
  - "qa/scripts/worktree-stamp*.sh"
---

# Hooks de git en Yala

<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->

## Índice (10 entradas)

> **No hace falta leer este fichero entero** — son 8 KB. Localiza la entrada
> aquí y salta a ella.

- `—` [`core.hooksPath` NO es acumulativo: el local SUSTITUYE al global](#corehookspath-no-es-acumulativo-el-local-sustituye-al-global)
- `—` [El candado anti-atribución vive aquí, y es propio](#el-candado-anti-atribucin-vive-aqu-y-es-propio)
- `—` [Tres cosas que no son el mensaje, y el hook las mira igual](#tres-cosas-que-no-son-el-mensaje-y-el-hook-las-mira-igual)
- `—` [El candado no corre en rebase, cherry-pick ni revert](#el-candado-no-corre-en-rebase-cherry-pick-ni-revert)
- `—` [Aviso: documentar el candado choca con el candado](#aviso-documentar-el-candado-choca-con-el-candado)
- `—` [Lo que NO se bloquea, y es una decisión](#lo-que-no-se-bloquea-y-es-una-decisin)
- `—` [Si tocas los patrones, el banco tiene que seguir en verde](#si-tocas-los-patrones-el-banco-tiene-que-seguir-en-verde)
- `—` [La trampa que queda abierta: el hook vive en el árbol de trabajo](#la-trampa-que-queda-abierta-el-hook-vive-en-el-rbol-de-trabajo)
- `—` [El otro hook: `pre-commit`](#el-otro-hook-pre-commit)
- `—` [Las rutas del repo se borran del texto antes de buscar atribución](#las-rutas-del-repo-se-borran-del-texto-antes-de-buscar-atribucin)

<!-- INDICE:fin -->

## `core.hooksPath` NO es acumulativo: el local SUSTITUYE al global

Es la trampa que costó este ticket. Yala pone `core.hooksPath = .githooks` en su config
local para el `pre-commit` del gate, y con eso **el directorio global entero queda fuera**
— no se fusionan, gana el local y punto.

```
global : /Users/jur/.claude/git-hooks   →  commit-msg   (ADR-013, anti-atribución)
local  : .githooks                      →  pre-commit   (el sello del gate)
        ⇒ efectivo: .githooks. El commit-msg global NO CORRE AQUÍ.
```

Se comprueba en un comando, y conviene hacerlo antes de dar por puesto cualquier hook:

```bash
git config --show-origin --show-scope --get-all core.hooksPath
```

Consecuencia medida el 2026-09-09: **Yala es el único repo del Mac con `core.hooksPath`
local**, así que es el único donde el candado global no llegaba. Los otros 24 lo heredan.
Si algún día otro repo pone el suyo, hereda también este problema.

## El candado anti-atribución vive aquí, y es propio

`.githooks/commit-msg` rechaza los commits que dicen que los escribió una IA. **No es una
copia del global**: es más ancho en atribución y más estrecho en mención.

| | Global (ADR-013) | Yala |
|---|---|---|
| Trailer `Co-Authored-By:` con Claude | rechaza | rechaza |
| Trailer cuyo NOMBRE es Claude (`Claude-Session:`) | **pasa** | rechaza |
| URL `claude.ai/code/session_…` suelta | **pasa** | rechaza |
| `🤖 Generated with…` | rechaza | rechaza |
| Nombrar `CLAUDE.md` o `.claude/rules/…` | **rechaza** | pasa |

Las dos diferencias son deliberadas y están medidas sobre los 3348 commits del repo:

- **Más ancho**: el trailer `Claude-Session:` no es un `co-authored-by` y `claude.ai` no
  casa con el patrón `claude.com/claude-code` del global, así que el nivel 1 global no lo
  ve. Ya se coló **7 veces**, la última el 2026-09-02.
- **Más estrecho**: el global prohíbe la mención a secas fuera de `casa`, `~/.claude` y
  `tim`. Aplicarlo aquí rechazaría **216 commits legítimos** que citan rutas del propio
  árbol. Decisión de Jürgen (2026-09-09): en Yala el sistema de Claude también es objeto
  de trabajo, así que se permite nombrarlo. Lo que no pasa es la **firma**.

## Tres cosas que no son el mensaje, y el hook las mira igual

Las cazó una lente adversarial el 2026-09-09, y las tres estaban abiertas:

- **El AUTOR del commit no viaja en el mensaje.** `git commit --author="Claude
  <noreply@anthropic.com>"` deja atribución permanente en la cabecera —más visible que
  un trailer— y `$1` no la contiene. El hook se la pide a git con
  `git var GIT_AUTHOR_IDENT`, que en un `commit-msg` ya devuelve la identidad efectiva.
- **Lo que va tras la línea de tijera lo tira git**, así que aquí tampoco cuenta. No es
  teórico: con `git commit -v` el diff se pega ahí **sin comentar**, y el diff de este
  mismo fichero contiene `claude.ai` y `Co-Authored-By`. Sin ese corte, tocar el candado
  con `-v` hacía que **el candado se rechazara a sí mismo**.
- **`grep -v '^#'` borraba de más.** Los comentarios que git genera llevan `#` **más un
  espacio** (o son el `#\t<fichero>` de un merge). Una línea `#Co-Authored-By: …` pegada
  **sobrevive al `git commit -m`** —el cleanup por defecto es `whitespace`, que no quita
  comentarios; medido con `git stripspace`— así que esconder ahí la firma funcionaba.

Y el prefijo de línea tolera viñetas y comillas de cita: **el 37 % de los cuerpos de
commit de este repo usan `- `**, y un guion delante desactivaba el ancla `^[[:space:]]*`.

## Las rutas del repo se borran del texto antes de buscar atribución

Porque nombrarlas está permitido aquí, y si no se borran, cuentan como si fueran la firma.
Sin ese paso el hook rechazaba **«Escrito por Jürgen; el índice vive en CLAUDE.md»** — o
sea, tumbaba un commit por atribuir el trabajo **a Jürgen**. Y hay **7 commits en la
historia** que dicen «Generated with» citando `.claude/…` y solo sobreviven por la
distancia entre las dos mitades.

Se borran `CLAUDE.md` y cualquier ruta que contenga `.claude/`. Los **dominios** no son
rutas del repo y no se tocan: `claude.ai` y `anthropic.com` siguen siendo firma.

## El candado no corre en rebase, cherry-pick ni revert

Medido: git **no invoca** `commit-msg` en `cherry-pick`, `revert`, `rebase` ni
`rebase --continue`. Sí lo invoca en `commit`, `--amend`, `--fixup`, `--squash`, `merge` y
`merge --squash`. Y los botones de merge de la web de GitHub crean el commit en servidor,
donde no hay hook que valga.

O sea que el candado cubre **escribir** un commit, no **replayarlo**. Cerrar eso pide otra
superficie (un `pre-push` o un check de CI) y tiene su ticket:
`rebase-and-cherry-pick-skip-the-attribution-hook`.

Dos detalles de flujo, por si te muerden: si el hook tumba un `git merge`, el árbol queda a
medias (`MERGE_HEAD` y `MERGE_MSG` puestos, índice staged, `HEAD` sin mover) y hay que
commitear otra vez o `git merge --abort`. Y un `--fixup` cuyo commit destino lleve el
disparador en el **asunto** no tiene arreglo posible salvo `--no-verify`, porque git copia
ese asunto y no te deja editarlo.

## Aviso: documentar el candado choca con el candado

Pasó en el primer uso. El commit que endurecía este hook explicaba que «el diff de este
fichero contiene claude.ai» — y salió **RECHAZADO** por el patrón de dominios, que es
justo el que caza las URLs de sesión.

No es un defecto y no se relaja: el patrón 3 es el que cierra las 13 URLs de sesión del
historial. **La salida es escribir el mensaje sin el literal** («el dominio de las
sesiones», «el patrón de dominios»). En el ticket y en esta regla sí se puede citar, que
son ficheros y no pasan por el hook.

## Lo que NO se bloquea, y es una decisión

No es que se haya olvidado. Cerrar estas tres haría más daño que bien:

| | Por qué se queda fuera |
|---|---|
| «IA» / «AI» a secas | Yala **tiene** features de IA (el chat, la categorización) y sus commits las nombran. Sería un falso positivo por semana |
| «Opus», «Sonnet» sueltos | Palabras comunes; sin «Claude» al lado no distinguen nada |
| Ofuscación (`claude[.]ai`, `claude . ai`) | Esto es un candado contra el **olvido**, no contra un adversario. Quien quiera saltárselo tiene `--no-verify`, y que exista esa salida es a propósito |

## Si tocas los patrones, el banco tiene que seguir en verde

```bash
bash qa/scripts/commit-msg-test.sh      # 28 casos + divergencia con el global
```

Lo corre el CI en cada push (job `coverage-index`). Sus casos legítimos son los que impiden
"arreglar" un fallo endureciendo a lo bruto: un `grep -qi claude` los tumba, y con ellos
el derecho a citar `CLAUDE.md` en un mensaje.

La segunda mitad compara con el hook global **sobre los mensajes reales del repo**, no
sobre los 17 casos: en esos Yala ya rechaza por su cuenta, así que compararlos no puede
dar señal. Y el corpus se elige por contenido, no por recencia — los últimos 400 commits
de este repo tienen **cero** atribución (el más reciente con trailer está en la posición
408), así que un corpus «los últimos N» sale verde sin medir nada.

En el CI esa comparación no corre: allí no hay `~/.claude`. Se dice en la salida.

## La trampa que queda abierta: el hook vive en el árbol de trabajo

`core.hooksPath` apunta a un directorio del **working tree**, así que un worktree cuya
rama no traiga `.githooks/commit-msg` **no tiene candado** — medido, no supuesto. Al
abrir un worktree desde una rama vieja, o rebasa sobre `2.1`, o comprueba:

```bash
test -x .githooks/commit-msg && echo "candado puesto" || echo "SIN CANDADO"
```

## El otro hook: `pre-commit`

Corre `qa/scripts/precommit-gate.sh`, que comprueba el sello de `/gate`. Sale 0 sin
mirar nada si no hay ficheros `.swift` en staging: un cambio de solo docs no necesita
gate. Su banco es `qa/scripts/worktree-stamp-test.sh`, y a ése **no lo corre nadie**
automáticamente.
