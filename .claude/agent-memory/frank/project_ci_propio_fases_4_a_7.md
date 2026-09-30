---
name: project-ci-propio-fases-4-a-7
description: Encargo CI propio + auto-merge (ADR-053): fases 1-3 cerradas el 2026-09-30 en #307; qué espera cada fase 4-7 y a quién
metadata:
  type: project
---

Las fases 1-3 del encargo `2026-09-30-ci-propio-y-auto-merge` están mergeadas y validadas (#307, 2026-09-30):
aviso del CI vivo, `concurrency` en los PR y `docs/ESTADO.md` retirado.

**Por qué siguen paradas las 4-7:**
- **4 (runner en sombra):** Jürgen tiene que crear el usuario de macOS `ci` y generar el token de registro del runner.
  El token no va por chat. Hasta que el repo sea privado, el runner solo corre por `workflow_dispatch`.
- **5 (privado):** Jürgen contrata GitHub Pro, confirma si GitHub cobra el minuto de runner propio y cambia la visibilidad.
- **6-7 (auto-merge):** esperan a que se mergee el encargo de casa `2026-09-29-cierre-con-auto-merge` (`/cerrar-total` y playbook).

**Why:** el orden lo fija el encargo: cada fase se valida antes de la siguiente. Sin repo privado, un runner con
`pull_request` correría en la Mini el código de cualquier PR.

**How to apply:** antes de retomar, mide si el usuario `ci` existe (`dscl . -list /Users | grep '^ci$'`) y si el repo
ya es privado (`gh api repos/jur211296/Yala --jq .private`). Al reactivar la routine vuelve el aviso de cada push a
`2.1`, merges incluidos. Recortarlo es de la fase 7, no antes.

Lo que el encargo daba por causa del `HTTP 400` (el cuerpo del aviso) era falso: el cuerpo de la respuesta decía
«Automation … is disabled». Ver [[feedback_la_premisa_del_encargo_tambien_se_mide]].
