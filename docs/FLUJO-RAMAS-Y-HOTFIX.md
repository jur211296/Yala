# Ramas y hotfix

Vigente desde el 22-oct-2026, cuando Apple publicó Yala 2.1 y su rama se cerró en `1.0`.

## Qué rama es qué

| Rama | Para qué | Cómo entra algo |
|---|---|---|
| `1.0` | La oficial: lo que está en la App Store y lo que publica la web (Vercel, proyecto `yala-app`, yala-app.pe). | Solo por PR con el CI en verde (`tests`, `coverage-index`, `gateway`). Sin push directo, para nadie. |
| `2.2` | Donde se trabaja: rama por defecto de GitHub y base de toda sesión (`lanzar-sesion` la declara en `~/.claude/scripts/ramas-base.conf`). | PR de cada sesión, o commit directo desde el árbol principal según `CLAUDE.md` § «Dónde se commitea». |

`2.1` ya no existe. Su historia está entera en `1.0`, con el tag `v2.1` (= `v2.1.0`) en el merge.

## Al publicar una versión

1. PR de la rama de la versión (hoy `2.2`) contra `1.0`, y merge con el CI en verde.
2. Tag `vX.Y.Z` anotado en el commit del merge, con el build en el mensaje: `X.Y.Z (build N) — publicada en la App Store`.
3. GitHub Release de ese tag con las «Novedades» de la App Store.
4. La rama de trabajo siguiente nace de la que se acaba de publicar. Pasan a ella la rama por defecto,
   `ramas-base.conf`, los filtros de `qa.yml`, `nocturna-vigilante.yml` y `avisar-grok-push-principal.yml`, y el
   ruleset de las ramas de trabajo.

## Hotfix sobre lo publicado

Un arreglo que no puede esperar a la próxima versión: un crash de 2.1 en la App Store, o un cambio de la web que tiene
que verse hoy.

1. **Sale de `1.0`:** `git fetch origin && git switch -c hotfix/<slug> origin/1.0`.
2. Arreglo mínimo, `/gate`, y PR contra `1.0`. Si es de la app, sube `MARKETING_VERSION` a `2.1.x` en el mismo PR.
3. Merge con el CI en verde.
4. **Tag `v2.1.x`** en el commit del merge, y su GitHub Release. Un cambio que solo toca `Web/` no lleva tag.
5. **Merge también a `2.2`:** PR de `1.0` contra `2.2`, o `git merge origin/1.0` en una rama nacida de `origin/2.2`.
   Sin este paso, la 2.2 vuelve a traer el bug.

La subida del build a TestFlight y a la App Store sigue siendo de Jürgen, desde la Mini.

## La web

Vercel publica en producción solo lo que entra en `1.0`. Un cambio en `Web/` mergeado en `2.2` se ve en un deploy de
preview, no en yala-app.pe, hasta que la 2.2 se publique. Si tiene que verse antes, es un hotfix.

**Un deploy CANCELED no es un error.** El «Ignored Build Step» del proyecto cancela el build cuando `Web/` no cambió
desde el último deploy que salió bien:

```bash
if [ -z "$VERCEL_GIT_PREVIOUS_SHA" ]; then exit 1; fi; git diff --quiet "$VERCEL_GIT_PREVIOUS_SHA" HEAD -- ./
```

Hasta el 22-oct comparaba `HEAD^` con `HEAD`, es decir, solo el último commit de cada push. Entre el 16 y el 21 de
octubre los 21 deploys de producción salieron CANCELED porque ningún merge tocó `Web/`, y la web publicada era ya la
de 2.1. El problema real de aquel paso era otro: un push de varios commits con el cambio de `Web/` en uno que no fuera
el último se habría cancelado sin publicar nada. Para forzar un deploy sin cambios en `Web/`, el paso se cambia un
momento a `exit 1` en Settings → Git, se despliega y se restaura.
