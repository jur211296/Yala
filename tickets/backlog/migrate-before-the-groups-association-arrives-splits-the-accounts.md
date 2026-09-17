---
id: migrate-before-the-groups-association-arrives-splits-the-accounts
status: backlog
priority: low
area: "modo-nube, settings, groups"
created: 2026-09-16
source: "segunda pasada de la review de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de controller y vista, hallazgo 8), 2026-09-16"
---

# En un iPhone restaurado, «Activar la nube» puede migrar a otra cuenta antes de saber cuál es la de tus grupos

## El problema, en lenguaje de usuario

Restauro mi iPhone desde iCloud. Mis grupos viven en la cuenta A, asociada en mi otro dispositivo. Antes de que iCloud
traiga esa asociación, toco «Activar la nube» y entro con la cuenta B, nueva. Yala migra mis finanzas a B. Cuando llega
la asociación, tengo lo personal en B y los grupos en A: dos cuentas en la nube, justo lo que la comprobación quiere
impedir.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- La asociación se lee del almacén local y del iCloud-KV del Apple ID (`GroupsAccountAssociation.read`). Sin registro,
  `isAssociated(sub:)` devuelve `nil`.
- En la fila de Ajustes de `CloudIdentityRoutingLogic`, una cuenta nueva con `nil` recibe el cutover; solo `false` (otra
  asociada) bloquea (decisiones de Jürgen del 2026-09-16, D3 y D13).
- Inferido, sin medir: que el iCloud-KV tarde lo bastante tras una restauración para que alguien migre en esa ventana.

Es el gemelo de `settings-migrate-blocks-a-second-device-before-its-marker` por el otro almacén: allí lo que no ha llegado
es la marca de CloudKit; aquí, la asociación del iCloud-KV.

## Opciones, sin decidir

- Tratar como `false` el `nil` de un dispositivo que acaba de restaurarse hasta que el iCloud-KV sincronice por primera
  vez (`NSUbiquitousKeyValueStore.didChangeExternallyNotification` con `initialSyncChange`).
- Aceptarlo: la población es pequeña y el desasociar deja volver a juntarlo.

## Criterios de aceptación

- [ ] «Activar la nube» no migra a una cuenta nueva mientras la asociación de grupos del Apple ID no se ha podido leer, o
      el caso se decide y se documenta como aceptado.
