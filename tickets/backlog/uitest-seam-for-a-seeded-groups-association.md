---
id: uitest-seam-for-a-seeded-groups-association
status: backlog
priority: medium
area: "testing, groups, modo-nube"
created: 2026-09-11
updated: 2026-09-16
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
