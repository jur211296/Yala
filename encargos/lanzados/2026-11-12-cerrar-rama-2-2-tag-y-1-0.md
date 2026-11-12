Yala
# Cerrar la rama 2.2: tag v2.2, merge en 1.0, rama por defecto 2.3 y borrar 2.2
---
toca: git (tag v2.2, release GitHub, rama 1.0, rama por defecto del repo, rama 2.2); sin código de la app salvo conflictos del merge en 1.0
cierre: cierra-sola
---
La 2.2 ya salió en el App Store y está distribuida. Jürgen pidió cerrarla igual que la 2.1 el 22-oct: tag `v2.2` con release en GitHub, merge de la rama en 1.0 y borrar la rama. El GO de Jürgen está en el chat de Frank (t1584u, respuesta «Sí, encola el cierre de 2.2 con los 4 pasos»).

Pasos, en este orden:
1. Tag y release: crea el tag anotado `v2.2` y el release «Yala 2.2» sobre el commit de la build distribuida, es decir la build 9 de TestFlight (merge del PR 890, `d1c480b`, que trae `c12c396 chore(release): TestFlight 2.2 (9)`). Confirma que el número de versión y la build del proyecto en ese commit coinciden con lo distribuido. No pongas el tag sobre los documentos posteriores (PR 909). Usa como modelo las notas del release `v2.1`.
2. 2.3 al día: verifica `git rev-list --count origin/2.3..origin/2.2`. Si da más de 0, haz tú el merge corto de esos commits a 2.3 (PR a 2.3 con auto-merge). La rama 2.2 se borra solo si el conteo da 0; si al final de la sesión no da 0, no la borres y anótalo en el cierre.
3. Merge de 2.2 en 1.0, como el commit «Merge branch '2.1' into 1.0» del 22-oct. 1.0 tiene 5 commits propios de hotfix que no están en 2.2 (PR 606, 785, 803 y 871: política de Gmail, política del correo del banco, el guard del manifest del gateway y la invitación web). Si chocan, conserva el contenido de esos hotfix, salvo que 2.2 ya traiga una versión igual o más nueva. Importante: 1.0 publica yala-app.pe en Vercel y su merge despliega la web de producción. Antes de empujar, compila la web (`next build` o lo que use el repo) y revisa que las páginas de política y términos sigan teniendo las secciones de Gmail y del correo del banco. Después del deploy, comprueba que yala-app.pe responda bien y que esas páginas estén. Si el deploy falla, deja el detalle como BLOQUEANTE y no borres 2.2.
4. Cambia la rama por defecto del repo de 2.2 a 2.3 (`gh repo edit --default-branch 2.3`). Revisa que no queden PR abiertos con base 2.2. Si hay, cámbiales la base a 2.3 o anótalos. Revisa también workflows, rutinas del CI o scripts de la flota que apunten a la rama 2.2 y anota en el cierre cuáles hay que cambiar. Recién después borra la rama 2.2 remota (y la local en las dos máquinas si existe y no tiene worktree vivo).
Sin firma de IA en commits, tags ni PR. Al terminar, cierra con `/cerrar-total` en el mismo turno.

## Paso 0

- **Tag:** sobre el commit de la build 9 (`d1c480b`), como pide el encargo, aunque `docs/FLUJO-RAMAS-Y-HOTFIX.md` decía «en el commit del merge». Medido: ese commit tiene `MARKETING_VERSION = 2.2` y `CURRENT_PROJECT_VERSION = 9`, y App Store Connect tiene la 2.2 a la venta con la build 9.
- **Choques del merge en 1.0:** texto de la web, se conserva el correo del banco de 1.0 (2.2 no lo traía); test del guard del manifest, versión de 2.2 más el test de los dos predeploy de 1.0, sin el test que afirmaba que 1.0 era más vieja que el Worker.
- **Árboles principales en 2.2 (Mini y Max):** borrar `origin/2.2` haría fallar el `git pull --ff-only` de `lanzar-sesion` y rechazaría toda sesión de Yala. Asumido: antes de borrar, los dos árboles pasan a `2.3` (estaban limpios salvo ficheros sin seguimiento) y `ramas-base.conf` pasa a `Yala 2.3` en las dos máquinas.
- **Workflows que dicen `2.2`** (`qa.yml`, `nocturna-vigilante.yml`, `avisar-grok-push-principal.yml`): se anotan en el cierre, como pide el encargo; no se cambian aquí.
- **Documentación de ramas:** `CLAUDE.md` y `docs/FLUJO-RAMAS-Y-HOTFIX.md` pasan a `2.3` y `v2.2.x` (solo documentación, directo a `2.3`).
