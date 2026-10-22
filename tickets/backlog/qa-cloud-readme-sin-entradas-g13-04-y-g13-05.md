---
id: qa-cloud-readme-sin-entradas-g13-04-y-g13-05
status: backlog
priority: very-low
area: docs, backend
created: 2026-09-08
updated: 2026-10-08
source: medido al escribir `docs/RUNBOOK-staging-ddl.md` (2026-09-08)
---

# Una migración remite a una entrada del README que no existe

## Qué pasa

`qa/cloud/g13_04_join_group_reports_transition.sql:171`, dentro de su bloque de verificación, dice:

> `-- transaccional que corrió esta migración — ver la entrada g13_04 de este README.`

**Esa entrada no existe.** Medido: `qa/cloud/README.md` menciona `g13_04` **una sola vez**, y no
como sección propia; lo mismo con `g13_05`. El README tiene entrada para casi todas las demás
—g5_01, g6_01, g8_01, g10_01, g12_01, g12_02, g14_01…— y estas dos se quedaron fuera.

Quien siga el puntero busca, no encuentra, y se queda sin el contexto que el propio fichero
consideraba necesario para interpretar su verificación.

## Qué lo tapa hoy, y por qué no lo cierra

`docs/RUNBOOK-staging-ddl.md` (2026-09-08) cubre lo que hacía falta para **aplicarlas**: orden,
idempotencia, dónde está cada bloque de verificación y las trampas. Pero es un documento de
ejecución para una tanda concreta; el README de `qa/cloud/` es el registro por migración, y es donde
mira quien llegue dentro de seis meses.

## Acceptance Criteria

- [ ] `qa/cloud/README.md` tiene entrada para `g13_04` y para `g13_05`, con el formato de sus
      vecinas (aplicación, md5 registrado, verificación).
- [ ] El puntero de `g13_04…sql:171` resuelve a algo real.
- [ ] Si el runbook y el README se solapan, uno enlaza al otro en vez de repetirlo — dos copias del
      mismo conteo es como nació el drift que arregla este ticket.

## Medido en 2.1 (triage 2026-10-08)

- `qa/cloud/README.md` nombra `g13_04` y `g13_05` solo de pasada (hacia las líneas 1602 y 1645, dentro de otras entradas); ninguna sección propia.
- `qa/cloud/g13_04_join_group_reports_transition.sql:171` sigue diciendo «ver la entrada g13_04 de este README».

Triage 2026-10-08: abierto · low → very-low · doc de mantenimiento interno: un puntero roto en el registro de migraciones, sin efecto en la app ni en el gate.
