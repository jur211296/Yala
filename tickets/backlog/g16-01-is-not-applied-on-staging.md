---
id: g16-01-is-not-applied-on-staging
status: backlog
priority: medium
area: "modo-nube, backend"
created: 2026-09-24
source: "cierre de `claim-promotion-lost-response-blocks-the-retry` (2026-09-24)"
---

# El arreglo del reintento del alta está en producción y no en staging

## Qué pasa, en lenguaje de usuario

En la app de producción, si se pierde la respuesta al activar la nube, «Reintentar» termina la activación.
Con `Yala Dev` (que habla con staging) sigue el comportamiento viejo: «Tu cuenta ya tiene finanzas
personales». No le pasa a ningún usuario real, pero un device-QA con `Yala Dev` vería el bug y lo
tomaría por una regresión.

## Por qué quedó así (medido el 2026-09-24)

- `qa/cloud/g16_01_claim_replays_for_the_same_device.sql` se aplicó en PRODUCCIÓN (md5 de llegada
  `e7f8bec957091abaa126d8100a3a53bd`).
- En staging el conector MCP devolvió «Connection terminated due to connection timeout» a `execute_sql`
  (cuatro veces) y a `apply_migration` durante toda la sesión. La REST de staging sí contestaba (401 a
  una petición sin clave, 0,4 s). Es el mismo síntoma del 16-sep que recoge la ficha de acceso al backend.

## Qué hacer

1. Comprobar que el conector entra: `select md5(prosrc) from pg_proc … proname='claim_account'` en
   `fostjbbwstyuunmmefuk`. Tiene que dar `8668a13c3d452fd5f192a192dd415bbd`.
2. Aplicar el fichero tal cual con `apply_migration`. Su §0 exige ese md5 y su §3 aborta si la conducta
   falla, así que es seguro reintentarlo.
3. Correr los goldens del claim contra staging (`gateway/test/account.goldens.test.ts`, receta en
   `qa/cloud/README.md`). El 28 exige el usuario C sin fila en `profiles` (el `delete` está en su
   comentario); los pasos 4-6 son los de g16_01.

## Criterios de aceptación

- [ ] `claim_account` de staging tiene la rama de g16_01 (el §2 lo imprime).
- [ ] Goldens 1, g3_02 y 28 en verde contra staging.
