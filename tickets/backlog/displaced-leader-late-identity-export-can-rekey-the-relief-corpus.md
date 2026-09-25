---
id: displaced-leader-late-identity-export-can-rekey-the-relief-corpus
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived` (2026-09-24), lente del duplicado"
---

# Las identidades que el líder desplazado exporta TARDE pueden pisar las del relevo y duplicar

## El problema, en lenguaje de usuario

El iPhone A empieza a activar la nube, prepara mis movimientos y se queda sin conexión antes de mandarlos a iCloud. El
iPhone B toma el relevo y termina. Días después A recupera la conexión y manda a iCloud lo que tenía preparado: B podría
acabar con los mismos movimientos dos veces.

## Lo medido y lo inferido (2026-09-24)

- **Inferido, sin medir**: los dos teléfonos hacen su backfill (`SyncIdentityService.backfillIdentities`, en
  `assignIdentity`) y acuñan identidades distintas para las mismas filas; el rebind no las une porque los testigos son
  locales. B pasa la comprobación del relevo cuando A no subió nada (`has_personal_writes=false` o backend sin filas vivas)
  o cuando todo lo que subió llegó a B, y sube con sus identidades. Si la exportación tardía de A gana el campo `syncID`
  en CloudKit, la fila local de B cambia de identidad y el siguiente push/pull la trata como otra: libro doble.
- Es la clase del residual (c) del adopt, escrito en el docblock de `MigrationWorkExecutor.runAdoptOrphanReconcile`
  (import-lag → identidad fresca → duplicado), pero en la ida y con el líder volviendo.
- **Sin medir**: cómo resuelve el espejo de CloudKit el conflicto del campo `syncID` entre los dos teléfonos.

## Criterios de aceptación

- [ ] Medido si la exportación tardía del líder cambia la identidad de filas ya subidas por el relevo; si sí, que no
      duplique.
