---
id: ci-checkout-v4-runs-on-deprecated-node
status: backlog
priority: low
area: ci
created: 2026-09-07
updated: 2026-10-08
source: anotación del propio CI, vista de camino en el-job-de-tests-del-ci-no-tiene-timeout
---

# El CI corre `actions/checkout@v4` sobre un Node deprecado, y GitHub ya lo está forzando

## Qué se midió

Todo run de `qa.yml` deja hoy esta anotación de nivel `warning` (leída el 2026-09-07 del run
34172213241 vía `/actions/runs/<id>/jobs` → `check-runs/<job_id>/annotations`):

> Node.js 20 is deprecated. The following actions target Node.js 20 but are being forced to run on
> Node.js 24: `actions/checkout@v4`.

Alcance medido con `grep -rn "uses:" .github/workflows/`: **dos apariciones, las dos de
`actions/checkout@v4`, las dos en `qa.yml`** (jobs `coverage-index` y `tests`).
`avisar-grok-push-principal.yml` no hace checkout a propósito — todo lo que envía viene del payload
del evento. La otra acción de terceros, `maxim-lobanov/setup-xcode@v1`, **no** aparece en el aviso.

## Por qué importa

Hoy no rompe nada: GitHub ya lo está ejecutando sobre Node 24 por su cuenta, que es justo lo que
dice el aviso. Importa por dos motivos, y ninguno es urgente:

1. **Correr forzado sobre un runtime que la acción no declara es una diferencia silenciosa.** Si
   algún día `@v4` se comporta distinto bajo Node 24, el síntoma aparecerá en un job que no cambió.
2. **El aviso es ruido permanente en cada run**, y el ruido permanente entrena a no mirar las
   anotaciones — que es donde este repo pone cosas que sí importan (`::notice Suite en verde`,
   `::error No se pudo avisar…`). Un canal que siempre trae la misma advertencia deja de leerse.

## Qué hacer

Subir las dos a `actions/checkout@v5`, que ya declara Node 24. Es un cambio de dos líneas, pero
**toca el CI, así que va por PR y se comprueba en el propio PR**: el check tiene que seguir en verde
y la anotación desaparecer. Verificar de paso que `setup-xcode@v1` no empieza a avisar igual.

## Distinto de

- `el-job-de-tests-del-ci-no-tiene-timeout` — de donde salió esto. Ése iba del tiempo sin tope y de
  mover la suite de UI a una nocturna; no tocó ninguna acción.
- `ci-workflow-cites-missing-testing-strategy` — el otro hallazgo de la misma sesión, de documentación.

## Acceptance Criteria

- [ ] Las dos `actions/checkout@v4` de `qa.yml` suben a `@v5`.
- [ ] Un run posterior no trae la anotación de Node 20 (comprobado en `check-runs/<job_id>/annotations`,
      no a ojo en la UI).
- [ ] Comprobado si `maxim-lobanov/setup-xcode@v1` necesita el mismo trato.

## Medido en 2.1 (triage 2026-10-08)

- `grep -rn "uses:" .github/workflows/` da hoy siete `actions/checkout@v4`, no dos: cuatro en `qa.yml` (`:72`, `:121`, `:362`, `:550`) y una en cada uno de `ping-avisador.yml`, `nocturna-vigilante.yml`, `ci-sombra.yml` y `avisar-grok-push-principal.yml` (este ya hace checkout).
- Aparece además `actions/setup-node@v4` (`qa.yml:122`), que habría que mirar con el mismo criterio que `setup-xcode@v1`.

Triage 2026-10-08: abierto · low → low · todos los checkouts siguen en `@v4` y ahora son siete; hoy no rompe nada, pero el CI es la red del auto-merge.
