---
id: groups-batch-facts-plural-identity
status: backlog
priority: low
area: groups
created: 2026-09-06
updated: 2026-10-08
source: review adversarial de groups-owner-transfer-and-leave (2026-09-06)
---

# `batchFacts` cuenta como co-miembro mi propia fila gemela

## Qué le pasa al usuario

En «salir de todos mis grupos», un grupo en el que yo tengo **dos filas de miembro** —la legacy y la
que estrenó `member_key` al re-unirme— se clasifica mal: mi segunda fila cuenta como si fuera otra
persona.

## Qué se midió

`GroupService.batchFacts` deriva «quién soy yo» con `GroupExpenseService.resolveCurrentUserMember`,
que **colapsa a UNA fila** (`min(by: joinedAt)`). El servidor, en cambio, descarta por `user_id`, o
sea **todas** mis filas. En una zona migrada el mismo humano tiene dos (el repo lo documenta en
`GroupExpenseService` y en `AppBootstrapper`), y nada lo impide server-side: la PK es
`(group_id, member_key)` y el índice sobre `user_id` no es único.

Consecuencia en la clasificación de `GroupBatchLeaveLogic`:

- `activeCoMemberCount` cuenta mi gemela ⇒ un grupo donde soy el único humano activo sale por
  `.transferThenLeave` o `.needsDecision` en vez de `.deleteSolo`.
- `eligibleHeirCount` la cuenta como heredero elegible ⇒ el batch cree que hay a quién ceder cuando
  no lo hay, y el RPC devuelve `no_eligible_owner`.

**Es un patrón heredado, no una regresión**: existía antes de que se tocara nada. El gemelo
`ownerExitOffer` ya se arregló en [[groups-owner-transfer-and-leave]] usando
`resolveAllCurrentUserMembers`; éste se dejó a propósito, por alcance.

## Criterio de hecho (AC)

- [ ] `batchFacts` excluye TODAS mis filas, no solo la canónica (mismo arreglo que `ownerExitOffer`).
- [ ] Unit con dos filas del mismo usuario que hoy dé rojo y con el fix dé verde.
- [ ] Revisar si el mismo patrón singular aparece en otros consumidores que pregunten por CONTEO.

## Relacionados

- [[groups-owner-transfer-and-leave]] — el gemelo ya arreglado.

## Medido en 2.1 (triage 2026-10-08)
- `GroupService.batchFacts` está en `GroupService.swift:998-1013`; `:1004` sigue con `resolveCurrentUserMember` (una fila) y `:1005-1006` cuentan co-miembros y herederos excluyendo solo esa.
- `resolveAllCurrentUserMembers` (`GroupExpenseService.swift:700`) ya se usa en `GroupService.swift:969` y `:1181`: el arreglo es el mismo molde.
- Solo afecta a quien tiene dos filas propias en un grupo (zonas migradas); no pierde datos, el RPC devuelve `no_eligible_owner`.

Triage 2026-10-08: abierto · medium → low · batchFacts sigue resolviendo «yo» con resolveCurrentUserMember (singular); el gemelo ownerExitOffer ya usa la variante plural.
