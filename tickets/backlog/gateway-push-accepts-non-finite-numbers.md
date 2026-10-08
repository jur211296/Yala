---
id: gateway-push-accepts-non-finite-numbers
status: backlog
priority: low
area: "cloud-backend, gateway"
created: 2026-10-08
updated: 2026-10-08
source: medido en wire-decoder-accepts-non-finite-money (2026-10-08)
---

# El gateway acepta un `"NaN"` en una columna de dinero al subir

## Qué pasa

`/sync/push` y `/groups/push` validan la FORMA de cada delta (`validateUpsertShape` en
`gateway/src/sync/manifest.ts`: columnas conocidas, unidades, grupos de coherencia enteros), pero no el
VALOR. Un delta con `"amount":"NaN"` pasa, y Postgres lo guarda: `'NaN'::numeric(18,4)` es válido (los
infinitos no caben en un `NUMERIC` con precisión, `NaN` sí). En Grupos el importe se cifra como
`pgp_sym_encrypt((x::numeric(18,4))::text)`, que también admite `'NaN'`.

Ninguna app de Yala lo emite: `Canonc1Codec` rechaza los no finitos al serializar. Lo que lo puede meter
es un cliente que no pase por el códec o una escritura directa por PostgREST (RLS deja que el dueño
actualice sus filas).

## Por qué importa

- Desde `wire-decoder-accepts-non-finite-money` el teléfono ya no lo deja entrar: lo pone en cuarentena
  (canal personal) o lo salta (Grupos). La fila se queda en el servidor sin que ningún dispositivo la
  materialice, hasta que alguien la reescriba.
- El Merkle del servidor no puede hashear esa fila: el re-serializador (`decimalFixedFromString`) lanza
  `malformedNumericText` y la ruta responde 502 (`groups/routes.ts` lo dice así; el personal, inferido del
  mismo `canon.ts`). La verificación de integridad de esa cuenta o ese grupo deja de funcionar entera.

## Criterio de hecho (AC)

- [ ] El push rechaza un valor no finito en una columna `decimal_fixed` con un error propio (422), con su
      canario, en los dos canales.
- [ ] Decidir si hace falta un `CHECK (amount <> 'NaN')` en las columnas de dinero (hoy no hay ninguno).
- [ ] Test en `gateway/test/` con `"NaN"`, `"Infinity"` y `"-Infinity"`.

Fuera de alcance de la sesión que lo encontró: no se toca el servidor ni las migraciones de `qa/cloud/`.

## Medido en 2.1 (triage 2026-10-08)

- `validateUpsertShape` (`gateway/src/sync/manifest.ts` y su espejo `gateway/src/groups/manifest.ts`) no comprueba valores no finitos; en `gateway/src` solo `canon.ts` los rechaza, y lo hace al re-serializar (lanza), no al aceptar el push.
- Ninguna app de Yala lo emite (`Canonc1Codec`); hace falta un cliente propio o PostgREST. En Grupos un miembro podría dejar sin verificación de integridad al grupo entero.

Triage 2026-10-08: abierto · low → low · el push sigue sin validar el valor; solo lo alcanza un cliente que no sea la app.
