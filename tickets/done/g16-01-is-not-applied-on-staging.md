---
id: g16-01-is-not-applied-on-staging
status: done
updated: 2026-09-24
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

- [x] `claim_account` de staging tiene la rama de g16_01 (el §2 lo imprime).
- [x] Goldens 1, g3_02 y 28 en verde contra staging.

## Cierre (2026-09-24, noche)

**Con `Yala Dev`, «Reintentar» tras perder la respuesta al activar la nube ya termina la activación, igual que
en producción.** Un device-QA contra staging deja de ver el bug viejo.

Lo medido, en orden:

1. **El conector entró a la primera.** `execute_sql` en `fostjbbwstyuunmmefuk` devolvió `current_user = postgres`
   y el md5 de partida `8668a13c3d452fd5f192a192dd415bbd`. El timeout de la sesión anterior no se repitió.
2. **`apply_migration` con el fichero entero, sin recortes**, a la primera: `success`. Como el §3 aborta la
   migración si falla algún escenario, eso quiere decir 13/13.
3. **Después:** md5 de llegada `e7f8bec957091abaa126d8100a3a53bd`, el mismo que producción. La marca de la rama
   está en el cuerpo, la función sigue `SECURITY INVOKER` con `search_path=public`, y quedan 0 usuarios
   `g16-01-verify-*` en `auth.users`.
4. **Goldens del claim contra staging** (`npx vitest run test/account.goldens.test.ts`): 34/35. En verde el 1, el
   de g3_02 y el 28, que eran los tres del criterio. El único rojo es el 20, que muere a 5013 ms, el mismo patrón
   que ya recoge `account-goldens-freeze-read-test-times-out`. Es un fallo ajeno y ya ticketado.

Preparación que hizo falta, y que queda escrita en `qa/cloud/README.md`:

- Borré las filas de `profiles` de A, B y C con el `delete` documentado. Ninguna FK apunta a `profiles`, así que
  `sync_seq_counters` sigue intacto, y el golden de g3_02 lo necesita.
- En un worktree nuevo, `gateway/` no trae `capability_manifest.json` porque está en el `.gitignore`. Primero hay
  que correr `npm run sync:manifest`; sin eso el fichero de goldens ni arranca.
- El README decía que el usuario C no existe en staging. Era falso: existe y tiene fila. Queda corregido.
