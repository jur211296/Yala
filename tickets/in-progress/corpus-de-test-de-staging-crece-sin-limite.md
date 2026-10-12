---
id: corpus-de-test-de-staging-crece-sin-limite
status: in-progress
priority: high
area: "qa, cloud"
created: 2026-09-08
source: medido al investigar goldens-de-staging-solo-pasan-a-trozos (2026-09-08)
---

# Los usuarios de test de staging acumulan grupos para siempre, y eso pone fecha de caducidad a los goldens

## El hecho, medido el 2026-09-08

Los dos usuarios de test de staging arrastran los grupos de todas las corridas que se han hecho desde
julio. Contado contra la misma query que usa el pull (`group_members` del usuario, no borrado, en
`active|pendingApproval|rejected`):

| Usuario | 2026-07-15 (según el log de perf del pull) | 2026-09-08, antes | después de UNA corrida |
|---|---|---|---|
| `i5-user-a` | 76 | 530 | **550** (+20) |
| `i5-user-b` | — | 678 | **693** (+15) |

**Cada corrida completa de los 25 goldens añade ~20 grupos a A y ~15 a B, y nadie los quita.** No es
un descuido: el `DELETE` está revocado por diseño (el tombstone es `UPDATE deleted=true`) y
`groups_forget_user` está prohibido en los tests porque es destructivo global y rompería las
re-corridas de los dos usuarios compartidos.

## Por qué importa

Un pull cuesta 5 peticiones por grupo del usuario (ver `groups-pull-cuesta-cinco-viajes-por-grupo`),
así que el coste de los goldens que hacen pull crece linealmente con un número que sólo sube. Medido
hoy, cuánto de su presupuesto de tiempo consume cada uno:

| Golden | Duración | Timeout | Consumido | Se rompe si el tiempo se multiplica por |
|---|---|---|---|---|
| `G2 · 2` (pull de B) | 33,3 s | 60 s | **55 %** | ×1,80 |
| `G3 · 3-ter` (2 pulls de B) | 65,0 s | 120 s | **54 %** | ×1,85 |
| `G2 · 7` (6 pulls de A) | 130,0 s | 360 s | 36 % | ×2,77 |
| `G7 · roundtrip` (1 pull de A) | 26,2 s | 90 s | 29 % | ×3,44 |
| `G3 · 3-bis` (1 pull de B) | 31,6 s | 120 s | 26 % | ×3,80 |

Con el ritmo de hoy, el primero en caer es `G2 · 2`: rompe cuando B llegue a **~1 220 grupos**, es
decir dentro de unas **35 corridas completas** — antes si la latencia de red del día es peor, porque
las dos variables se multiplican. Ese es el mecanismo que hizo que estos goldens dieran 15/25 el
2026-09-08 por la mañana y 25/25 por la tarde sin que nadie tocara el código.

## La decisión que hace falta (owner)

**Limpiar el corpus es destructivo y no lo decide Claude.** Las opciones, con lo que cuesta cada una:

1. **Vaciar los grupos de los dos usuarios de test.** Devuelve los goldens a los ~7 s por pull de
   julio y deja el margen en 50×. Requiere credencial de DDL en staging (que hoy **no hay** — ver
   `docs/RUNBOOK-staging-ddl.md`) o llamar a `groups_forget_user`, que es exactamente lo que los
   tests tienen prohibido. Riesgo: si alguien depende de datos históricos de esos usuarios, se
   pierden.
2. **Un tercer usuario de test, limpio, para los goldens de Grupos**, dejando A y B para el resto.
   No borra nada; mueve el problema tres meses adelante y cuesta sembrar credenciales nuevas.
3. **No tocar los datos y arreglar el coste** (`groups-pull-cuesta-cinco-viajes-por-grupo`). Es el
   arreglo de fondo —el mismo que hace falta para producción— pero es un rediseño del cursor, no un
   parche.
4. **Subir los timeouts.** Compra tiempo y no arregla nada; y deja los goldens tardando 10 minutos.

**Lo que NO conviene hacer es nada**: hoy el margen es de ×1,8, y el modo de fallo es un rojo por
timeout sin aserción — es decir, la forma más cara de fallar, porque no dice qué está mal. Ya costó
una investigación completa.

## Acceptance Criteria

- [ ] Decisión del owner sobre cuál de los cuatro caminos.
- [ ] Si se limpia: el conteo de grupos de A y B queda medido antes y después, y los goldens se
      vuelven a correr para dejar el número nuevo escrito.
- [ ] El margen (cuánto del timeout consume el golden más ajustado) queda anotado donde se consulte,
      para que la próxima vez se lea en un minuto y no en un día.

---

## Re-medido el 2026-09-10: la fecha de caducidad ya llegó

Corriendo los goldens del gateway para `backend-account-kind-complete-or-groups-only`:

| | 2026-09-08 | 2026-09-10 |
|---|---|---|
| `split_groups` (corpus total) | — | **983 → 1 042 en una sola sesión** (+59) |
| grupos ACTIVOS del usuario A | 530 | **631** |
| grupos ACTIVOS del usuario B | 678 | **702** |
| `groups.goldens.test.ts` | 25/25 (frágil, el más ajustado al 55 % de su timeout) | **15 pasan · 10 fallan** |

**Los 10 rojos son TODOS timeouts** (60 s, 90 s, 120 s, 360 s) y ninguno trae línea de aserción.
Fallan **igual corriendo el fichero solo**, así que ya no es contención entre ficheros como en
`goldens-de-staging-solo-pasan-a-trozos`: es el corpus. A ~5 peticiones por grupo y por pull, un solo
pull del usuario B son unas **3 500 llamadas** contra un timeout de 60 s.

**Descartado que lo causara la migración de ese día** (`g15_01`, que añade un trigger a `profiles`),
con control negativo: **desactivando el trigger, el test 2 de G2 falla exactamente igual** — mismo
timeout de 60 000 ms. El trigger corre sobre una tabla de 6 filas; el corpus está en `group_members`
(1 766) y `split_groups` (1 042).

⇒ **Los goldens de grupos ya no dan señal**, y eso es lo que este ticket venía a evitar. Sube a
prioridad real: hasta que el corpus se acote, un rojo ahí no distingue «el código está roto» de «el
corpus creció otra vez».

## Medición del 2026-09-10, tras desplegar el Worker de staging

El deploy de staging de hoy subió **`f84620b5` («los goldens de Grupos seguían pidiendo el canon
viejo»)**, un fix que llevaba **sin desplegar desde el 8-sep** — así que cabía la esperanza de que el
rojo de los goldens fuera eso y no el corpus.

**No lo es.** Con el Worker nuevo (`53e181d4`) y las credenciales cargadas, `groups.goldens.test.ts`
**avanza pero no termina**: se quedó recorriendo G2 y G3 durante más de veinte minutos, un caso cada
varios minutos, hasta que se cortó a mano. O sea: el canon ya no es la causa, **el corpus sigue
siéndolo**, y este ticket sigue en pie tal cual.

Lo que sí cambia es cómo se lee un rojo viejo: **cualquier veredicto de los goldens de Grupos anterior
al 2026-09-10 se midió contra un Worker sin ese fix**, así que no vale como línea base. Al retomar
esto, la primera corrida es la que fija el punto de partida.

Y un dato de método que se pagó hoy: **sin `GROUPS_ENC_KEY` y `PUSH_ROLE_JWT` exportados, tres ficheros
de goldens fallan al CARGAR** (`groups.goldens`, `push.fanout`, y `account.goldens` sin `USER_A_PASS`).
Eso se lee como «el código está roto» cuando es «falta un export» — y es la clase de confusión que hace
perder una vuelta de diagnóstico. Están en `~/Secrets/yala-groups-enc/staging*` y
`~/Secrets/yala-supabase-test/test-users.env`.

---

## 2026-10-12 — Decisión y plan de purga (escrito ANTES de ejecutarla)

**Camino elegido** (encargo `2026-10-12-corpus-test-staging-grupos`, Paso 0): ni vaciar por SQL ni subir timeouts.
Un **relevo** con RPCs públicos: al terminar cada corrida, los grupos que creó se le traspasan a un cuarto usuario de
test, el **custodio** (`i5-goldens-custodio@test.yala`, creado hoy por SQL como C), y A y B salen. El dueño no puede
salir de un grupo por ninguna vía pública, así que siempre queda una membresía: la del custodio, con quien ningún golden
hace pull. Nunca `groups_forget_user`, nunca `service_role`.

**Medido antes** (staging `fostjbbwstyuunmmefuk`, predicado del pull): A **736**, B **838**. Una corrida completa de
`groups.goldens` crea 19 grupos (19 al pull de A, 14 al de B) y `push.fanout` 3 más en los dos.

**Qué se va a relevar** — criterio: grupo con prefijo `g2-goldens-` o `g8-fanout-` en el que A o B están en el set del
pull (`deleted=false`, `status in (active,pendingApproval,rejected)`). **960 grupos distintos** (A 705, B 799):

| Clase | Grupos | Qué hace el relevo |
|---|---|---|
| dueño A, con B dentro | 432 | B sale; el custodio entra; A traspasa y sale |
| dueño B (G10·1) | 249 | A sale; el custodio entra; B traspasa y sale |
| solo A | 143 | el custodio entra; A traspasa y sale |
| archivado | 68 | su dueño lo desarchiva; luego como arriba |
| B pendiente | 41 | B sale; luego como «solo A» |
| B rechazado | 9 | B vuelve a entrar con invitación nueva y sale; luego como arriba |
| **borrado** | **18** | **no se toca**: un grupo borrado no admite traspaso. Queda en el pull de A como residuo |

**Fuera de alcance, sin tocar**: `g6-migrate-*` (A 31, B 26), `rls-g1*` (B 13) y cualquier grupo de otros usuarios.
Ningún borrado de filas: lo que cambia es el `status` de la membresía de A/B (`left`) y el dueño del grupo (custodio).

**Cómo**: `gateway/scripts/relevo-corpus-staging.ts` — dry-run por defecto (dio exactamente estas cifras), piloto con
`--solo=` sobre un grupo de cada clase, y luego `--aplicar` entero.
