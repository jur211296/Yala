---
id: account-goldens-freeze-read-test-times-out
status: backlog
priority: medium
area: qa, cloud
created: 2026-09-03
updated: 2026-09-03
source: aparecido al correr la batería del gateway con credenciales vivas (2026-09-03)
---

# El golden 20 del freeze se cuelga siempre, y llevaba invisible porque el fichero ni arrancaba

## Qué pasa

`gateway/test/account.goldens.test.ts`, test **«20. la cuenta congelada NO bloquea pull/merkle ni
prefs/pull (la reversa §h DEPENDE de leer)»**, falla por **timeout de vitest** (5.000 ms).

No afecta a ningún usuario: es una red de QA del gateway. Lo que sí significa es que **el invariante
que ese test protege no está siendo comprobado por nadie** — y es un invariante con consecuencias: si
el freeze llegara a bloquear las LECTURAS, la reversa de migración no podría releer y se quedaría a
medias.

## Por qué aparece ahora

No es una regresión: **el fichero entero moría antes en su `beforeAll`** por falta de credenciales de
staging, así que sus 29 tests ni se ejecutaban. Al rotar las cuentas de test el 2026-09-03 y cargar
`PUSH_ROLE_JWT` y `GROUPS_ENC_KEY`, la batería pasó de 242 a 286 tests ejecutados — y este rojo salió
a la luz por primera vez.

⇒ **Antigüedad desconocida.** Puede llevar meses. No se ha medido contra qué commit empezó.

## Lo MEDIDO (2026-09-03)

- **Determinista, no flaky: 3 de 3 corridas.** Duraciones `5010 ms`, `5012 ms`, `5010 ms`.
- El número clavado en el límite dice que **el test no tarda: se cuelga**, y el timeout lo corta. Un
  test lento daría duraciones dispersas.
- Sus vecinos del mismo `describe` pasan y son rápidos: el 19 en `1149 ms`, el 19-bis en `747 ms`, el
  21 en `1404 ms`. El estado congelado que comparten se monta bien.
- El test hace **tres GET** contra el Worker montado EN PROCESO (`app.fetch`, no un gateway
  desplegado): `/sync/pull?since=0&limit=1`, `/sync/merkle` y `/prefs/pull?since=0`.
- **No se ha medido cuál de las tres se cuelga.** Es el siguiente paso obvio y cuesta tres `curl`.

**Re-confirmado el 2026-09-04** (de paso, al correr la batería para `rejoin-tap-renotifies-admins`):
sigue colgándose, `5017 ms`, y **falla idéntico contra `HEAD` limpio** — o sea que no lo introdujo el
trabajo del 3-sep, sólo lo destapó. Sigue siendo el único rojo de la batería del gateway con las tres
credenciales cargadas.

## Una hipótesis REFUTADA, para que nadie la repita

Parecía que la cuenta de test B hubiera acumulado datos de meses y que `/sync/merkle` o el
`prefs/pull?since=0` sin límite se atragantaran. **Medido y no se sostiene:**

| Tabla | Filas del usuario B |
|---|---|
| `group_members` | 429 |
| `tx_items` | 123 |
| `user_preferences` | 123 |

Son cantidades que no explican cinco segundos, y menos en un `pull` con `limit=1`. El volumen de
`group_members` (429) sí llama la atención como residuo de corridas, pero es otro asunto.

## Por dónde seguir

1. **Aislar la llamada**: instrumentar el test con un `console.time` por cada uno de los tres GET, o
   hacerlos a mano. Sale en una corrida cuál no vuelve.
2. Si el que cuelga es `/sync/merkle`, mirar si el cálculo del árbol depende del corpus del usuario y
   si el freeze lo mete en algún camino distinto.
3. **Subir el timeout NO es el arreglo** mientras no se sepa qué se cuelga: un `await` que no resuelve
   seguirá sin resolver con 30 s, y habríamos convertido un rojo en un test lento que nadie mira.

## Cómo reproducirlo

```bash
cd gateway
set -a; source ~/Secrets/yala-supabase-test/test-users.env; set +a
export PUSH_ROLE_JWT="$(cat ~/Secrets/yala-groups-enc/staging-push-role.jwt)"
export GROUPS_ENC_KEY="$(cat ~/Secrets/yala-groups-enc/staging.key)"
npx vitest run test/account.goldens.test.ts -t "20. la cuenta congelada"
```

## Relacionado

- El resto de la batería del gateway queda en verde con esas tres cosas cargadas; el procedimiento
  está en `qa/cloud/README.md`.
- **El usuario C no existe** en `auth.users` de staging (comprobado el mismo día). No afecta a este
  test, pero el `.env` lo prometía.
