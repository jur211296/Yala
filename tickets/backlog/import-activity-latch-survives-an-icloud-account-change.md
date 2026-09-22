---
id: import-activity-latch-survives-an-icloud-account-change
status: backlog
priority: low
area: "icloud, sync"
created: 2026-09-21
source: "review adversarial de `leaving-and-reentering-restore-renews-the-hard-cap`, 2026-09-21"
---

# El latch de actividad de import sobrevive a un cambio de cuenta de iCloud

## El problema, en lenguaje de usuario

No tiene síntoma visible hoy. Es una afirmación que deja de ser cierta sin que nadie la corrija: la
app sigue creyendo que «hay datos bajando» después de que el teléfono haya cambiado de cuenta de
iCloud, cuando lo que bajaba era de la cuenta anterior.

## Medido (2026-09-21)

`iCloudSyncService.accountDidChange` limpia el ancla de export (`confirmedExportStart`) y, desde
`leaving-and-reentering-restore-renews-the-hard-cap`, también `lastImportActivityAt` — el sello con
fecha que lee el re-ancla de la ventana de sesión del restore, porque ése abre un guard de frontera de
cuenta.

**`hasObservedImportActivity` se quedó fuera a propósito, y por eso hay ticket**: es un latch de
proceso con otros consumidores —`BootSaveGateLogic` y el gate del sync de Grupos— que preguntan por el
store de ESTE proceso y no por la cuenta. Limpiarlo desde aquí les cambia el suelo, y eso hay que
medirlo con ellos delante, no de paso.

La rama `notAuthenticated` de `apply` tiene la misma forma: limpia el ancla de export y no toca ninguno
de los dos testigos de import.

## Criterios de aceptación

- [ ] Está medido qué le pasa a `BootSaveGateLogic.resolveWaitByQuiescence` y al gate de Grupos si el
      latch se apaga en un cambio de cuenta, con un caso por consumidor.
- [ ] Se decide si el latch es del PROCESO o de la CUENTA, y queda escrito donde se declara.

## Relación con otros tickets

- `leaving-and-reentering-restore-renews-the-hard-cap` — de donde sale; cerró la mitad del sello.
