---
id: uitest-seam-for-a-seeded-groups-association
status: done
priority: low
area: "testing, groups, modo-nube"
created: 2026-09-11
updated: 2026-11-07
source: "review adversarial de `detach-failure-looks-like-success`"
---

# Falta un seam de QA que siembre la asociación de grupos, y con él se quedan dos estados sin probar

## El problema

Dos estados de la sección «Grupos» de «¿Dónde viven tus datos?» **no son alcanzables en el simulador**,
así que nadie comprueba que la pantalla los pinte:

1. **«Asociada sin sesión viva»** — el segundo móvil del mismo Apple ID. La cabecera de
   `GroupsAssociationRowUITests` ya lo dice desde el paso 10: «necesita una asociación sembrada en el
   iCloud-KV».
2. **«Quedó un desasociar a medias»** (2026-09-11) — el botón «Terminar de soltar la cuenta» y el cuerpo
   que lo explica.

## Lo medido (2026-09-11)

`-uitest-fake-cloud-session` finge **solo** el predicado `CloudAuthService.hasSession`. Su docblock
(`CloudAuthService.swift:206-213`) declara que el override **no** se propaga a `currentUserID`, y es
deliberado: fingir el `sub` volvería alcanzables los resolvedores de identidad del canal backend con una
identidad que no existe.

Consecuencia para el estado (2): `GroupsDetachPendingPurge` va sellada con el `sub` de la cuenta, y ese
`sub` sale de `GroupsAccountAssociation.shared.associatedSub ?? CloudAuthService.shared.currentUserID`.
En el simulador los dos son `nil` ⇒ la marca **no se arma** (por diseño: sin sello no se sabe a qué
cuenta pertenece lo pendiente) ⇒ el botón no aparece y el XCUITest no puede afirmarlo.

## Lo que hay que hacer

Un seam `-uitest-groups-association <sub>` que escriba un `GroupsAccountAssociation` local —sin tocar el
iCloud-KV del Apple ID de la máquina, molde de `-uitest-icloud-identity`— y que **no** finja la sesión:
son ejes distintos, y combinarlos es lo que produce cada celda.

Cuidado con la trampa de su familia (`.claude/rules/testing.md` L103): el seam PERSISTE en defaults, así
que `applyUITestHooksEarly` tiene que limpiarlo en el reset o contamina la corrida siguiente — como ya
hacen sus cuatro vecinos, y como hubo que hacer con `GroupsDetachPendingPurge` el 2026-09-11.

## Qué se desbloquea

- La celda `associatedNeedsSignIn` de `GroupsAssociationRowUITests`, sin cobertura desde el paso 10.
- El botón «Terminar de soltar la cuenta» y el cuerpo «Quedó a medias» del ticket
  `detach-failure-looks-like-success`, hoy cubiertos solo por unit. *(Corrección 2026-09-16: no hay
  device-QA que los cubra; ese ticket se cerró como no replicable en device, así que este seam es la única
  vía para verlos en pantalla.)*

## Medido en 2.1 (triage 2026-10-08)

- `grep` de `uitest-groups-association` en `Yala/` no da nada.
- `YalaUITests/Flows/GroupsAssociationRowUITests.swift:197-206` sigue explicando que el botón «Terminar de soltar la cuenta» no se puede comprobar y remite aquí. Mientras tanto lo cubren solo los unit de `GroupsDetachPurgeFailureTests`.
- Por qué low: es un hueco de cobertura en pantalla, y la lógica está cubierta por unit.

Triage 2026-10-08: abierto · medium → low · No existe ningún seam -uitest-groups-association, y el XCUITest sigue remitiendo a este ticket para los dos estados sin cubrir

## Hecho (2026-11-07, lote 2.3 de tests y rastros)

- Seam `-uitest-groups-association`: escribe la asociación solo en el espejo LOCAL (`GroupsAccountAssociation.seedLocalForUITest`, DEBUG), con `sub` fijo (`UITestHooks.uitestGroupsAssociationSub`) y proveedor Apple. No finge la sesión ni toca el iCloud-KV. El reset de `-uitest-reset` borra el espejo local (`AppBootstrapper.applyUITestHooksEarly`). En el helper es el parámetro nombrado `groupsAssociation:`.
- Dos XCUITest nuevos en `GroupsAssociationRowUITests`:
  - `test_associationWithoutALiveSession_offersSignInAndDetach`: la celda `.associatedNeedsSignIn` ofrece «Entrar» y «Desasociar», no «Asociar». Control: `test_privateWithoutAccount_offersAssociate_andNoDetach`.
  - `test_detachWithFailingWipe_andASeededAssociation_offersToFinish`: con el borrado que falla, la marca se sella con el `sub` y la sección ofrece «Terminar de soltar la cuenta» en vez de «Desasociar». Control: el mismo gesto sin asociación (`test_detachWithFailingWipe_showsFailureAlert`).
- La cabecera de la suite y los dos comentarios que remitían aquí, al día.
