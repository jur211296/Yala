---
id: groups-pull-cuesta-cinco-viajes-por-grupo
status: backlog
priority: low
area: "backend, sync"
created: 2026-09-08
source: medido al instrumentar los goldens de staging (goldens-de-staging-solo-pasan-a-trozos, 2026-09-08)
updated: 2026-10-08
---

# El pull de Grupos cuesta 5 peticiones por grupo, haya o no algo que traer

## El hecho, medido

`handleGroupsPull` (`gateway/src/groups/routes.ts`) resuelve primero las membresías del usuario y
luego, **por cada grupo de la lista**, dispara las 5 tablas en paralelo. El cursor no interviene en
esa decisión: se pasa como `p_after_seq` a cada una de las 5 llamadas, así que un grupo sin cambios
**cuesta exactamente lo mismo que uno con cambios**. El coste de un pull es

    1 + 5 × (número de grupos de los que eres miembro)

Medido el 2026-09-08 instrumentando `fetch` en los goldens contra staging:

| Usuario | Grupos | Peticiones de UN pull | Duración |
|---|---|---|---|
| `i5-user-b` | 678 | **3 391** | 33 s |
| `i5-user-a` | 530 | 2 651 | ~26 s |

Una corrida entera de los 25 goldens hizo **32 793 peticiones HTTP**, y el 99,7 % de ellas salieron
de los 5 tests que hacen un pull completo.

## Por qué importa, y dónde muerde de verdad

En los tests el gateway corre **en proceso** (`app.fetch`), así que lo único que se nota es la
lentitud. En producción corre como Worker de Cloudflare, y ahí **hay un techo duro: el cap de
subrequests por invocación** (1000 en el plan paid, según lo anotado en
`docs/modo-nube/_archive/groups-backend-v1.md`). Con esa aritmética:

- **200 grupos ⇒ 1 001 subrequests ⇒ el pull se rompe.** No degrada: se cae.
- **20 grupos** —una persona con muchos viajes y pisos compartidos— ⇒ **101 peticiones a PostgREST
  en cada pull**, en cada cadencia de sync, para traer casi siempre cero filas.

Ningún usuario real anda hoy cerca de 200, así que esto no es un incidente. Es el techo del diseño
actual, y conviene tenerlo escrito con su número antes de que alguien lo encuentre por accidente.

## No es nuevo, y esa es la mitad interesante

El residual está documentado desde el **2026-07-15**, en la entrada que cerró la perf del pull
(`68f5555d`): «el count de subrequests sigue O(grupos×5) — con ~200 grupos el cap de 1000 de Workers
sería el límite (batch con rediseño de cursor + detección de truncación; **no aplica a v1**)».

Aquel día el corpus del usuario de test tenía **76 grupos** (381 subrequests). Hoy tiene 678. Lo que
cambió no es el código: es que el número contra el que se juzgó «no aplica a v1» se multiplicó por 9.

## Lo que ya está descartado, con su razón

**No se batchea con `group_id=in.(...)`** — está razonado en el comentario del propio handler y sigue
siendo correcto: el cursor `server_seq` es POR GRUPO y el `limit` de PostgREST es GLOBAL por query, así
que una truncación dejaría grupos de la cola sin filas de una tabla mientras el merge avanza el cursor
con filas de otras tablas de `server_seq` mayor ⇒ **deltas perdidos en silencio**. Cualquier arreglo
tiene que resolver eso, no ignorarlo.

## Caminos posibles (ninguno elegido — esto es el planteamiento, no el plan)

1. **Un RPC que devuelva varios grupos en una llamada**, con el cursor por grupo dentro del payload y
   una marca explícita de truncación por grupo. Mueve el problema al servidor, que es donde el cursor
   por grupo es barato.
2. **Preguntar primero qué cambió.** Una llamada que devuelva los `group_id` con `server_seq >
   cursor` y sólo entonces pedir esas tablas. Un usuario en reposo pasaría de 5N a 1-2 peticiones,
   que es el caso dominante.
3. **Acotar el fan-out por página**: procesar como mucho K grupos por invocación y devolver un
   `more: true`. No baja el coste total, pero pone un techo por invocación y quita el cap duro.

## Acceptance Criteria

- [ ] El coste de un pull deja de ser lineal en el número de grupos **para el caso sin cambios**, o
      queda acotado por invocación de forma que el cap de subrequests no se pueda alcanzar.
- [ ] Sigue sin haber deltas perdidos por truncación: el caso que descartó el `in.(...)` se prueba,
      no se argumenta.
- [ ] Medido antes y después con el mismo método (contar peticiones, no estimarlas).

## Medido en 2.1 (triage 2026-10-08)
- `handleGroupsPull` en `gateway/src/groups/routes.ts:431`; `fetchGroupPage` (`:491-517`) lanza los 5 RPC `groups_pull_rows_<tabla>` por grupo, con el cursor solo como `p_after_seq`.
- Sin commits en ese fichero desde el 2026-09-08. Baja a `low`: ningún usuario real se acerca a 200 grupos.

Triage 2026-10-08: abierto · medium → low · handleGroupsPull sigue haciendo 1 + 5×grupos llamadas por pull; ningún usuario real está cerca del techo, así que no es urgente.
