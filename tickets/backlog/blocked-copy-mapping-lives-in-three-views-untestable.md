---
id: blocked-copy-mapping-lives-in-three-views-untestable
status: backlog
priority: medium
area: "modo-nube, settings, testing"
created: 2026-09-13
source: "review adversarial de `groups-killswitch-403-blocks-detach-forever`, lente de tests"
---

# El copy del bloqueo se decide en tres vistas, y ningún test de comportamiento puede tocarlo

## El problema

Qué frase ve la persona cuando un cierre de sesión o un desasociar se bloquea lo deciden tres computed
properties privadas, en tres vistas distintas: `GroupsAssociationSection.blockedMessage`,
`ProfileView.signOutBlockedMessage` y la rama `.blocked` de `WelcomeGroupsGateView`. **Ninguna es
alcanzable desde un test**: `CloudSessionSignOut` es un singleton con `private init()`, `phase` es
`private(set)`, y el camino exige `GroupsSyncClient.shared`, `CloudAuthService.shared`,
`GroupsAccountAssociation.shared` y `CloudMigrationController.shared`.

Lo que hay hoy es un **source-scan** (`PausedChannelReasonWiringTests`) y dos `switch` exhaustivos. El
scan se endureció el 2026-09-13 tras medir cuatro mutantes que lo atravesaban, pero sigue siendo un
escaneo de ortografía: fija los literales que hay, no la propiedad «el motivo llega intacto a la frase».

## Lo que se espera

Sacar el mapeo a una función pura —del tipo `blockedCopyKey(for reason:, gesture:)`— y probarla como
función, con su tabla exhaustiva por `CaseIterable`. El source-scan se reduce entonces a «la vista llama
a esa función», que es una línea estable y no una lista de literales que envejece.

**Nota de alcance:** el `gesture` que esa firma pide es el mismo que falta en
`signout-alert-fires-on-detach-blocks-it-did-not-cause`. Los dos tickets quieren la misma pieza.
