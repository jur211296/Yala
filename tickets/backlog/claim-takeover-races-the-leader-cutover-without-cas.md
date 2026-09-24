---
id: claim-takeover-races-the-leader-cutover-without-cas
status: backlog
priority: low
area: "modo-nube, migración, backend"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `claim-grants-a-takeover-after-the-leader-passed-the-cutover` (2026-09-24), lente de servidor"
---

# El relevo y el cutover del líder pueden cruzarse sin CAS

## El problema, en lenguaje de usuario

El teléfono A lleva más de una hora sin dar señales en mitad de la activación de la nube y, justo en el mismo instante en
que vuelve y termina el último paso, el teléfono B pide entrar. Si las dos peticiones se cruzan en el servidor, B puede
quedarse con el relevo de una activación que ya había terminado, y volver a subir todos sus datos encima. Es el caso que
g16_04 cerró, pero por una rendija de milisegundos.

## Lo medido (2026-09-24, leyendo los cuerpos vivos; sin reproducir)

- El UPDATE del relevo en `claim_account` (md5 `35423724…`) filtra solo `where id = v_uid`: no vuelve a comprobar el
  estado que leyó el SELECT (`migrated_at` nulo, lease vencido, líder ajeno).
- El UPDATE de `migration_progress('cutover')` (md5 `14fc5e2c…`) tampoco vuelve a comprobar el líder: filtra solo `id`.
- Con B leyendo `migrated_at` nulo y A estampándolo en paralelo, el UPDATE de B espera el bloqueo, re-evalúa `id = v_uid`
  y escribe `leader=B`: B recibe `created`. En el orden contrario, el cutover de A se escribe sobre el relevo ya hecho.
- Anterior a g16_04, que no la abre ni la cierra. El banco de g16_04 corre en serie y no la ve.
- Parque medido el 2026-09-24 como `postgres`: producción 0 perfiles; staging 6, ninguno con migración en curso.

## Candidata

CAS en los dos UPDATE, en el molde de `reverse_claim`: el relevo con `and migration_in_progress and migrated_at is null
and migration_updated_at = v_updated` y, si no hay `found`, re-leer y clasificar; el `cutover` con `and leader_device_id =
p_device_id`, y `other_leader` si no hay `found`. Se prueba con dos sesiones y `pg_sleep`, no con el banco en serie.

## Criterios de aceptación

- [ ] Un relevo que se cruza con el cutover del líder no devuelve `created` sobre una cuenta con `migrated_at`.
- [ ] Un cutover que se cruza con un relevo no estampa `migrated_at` para un líder que ya no lo es.
