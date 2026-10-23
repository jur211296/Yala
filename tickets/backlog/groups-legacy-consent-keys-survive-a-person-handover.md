---
id: groups-legacy-consent-keys-survive-a-person-handover
status: backlog
area: groups
priority: low
created: 2026-10-21
updated: 2026-10-21
source: review adversarial del lote decidido 2.2 · 13 (L12-4)
---

# Las keys legacy del consentimiento de Grupos sobreviven a «Empezar desde cero»

## Qué pasa

`GroupsConsentState.readSnapshot()` deriva un snapshot SIN sello de las keys legacy
(`groupsConsentAcceptedAt` / `groupsConsentTextVersion`). Ninguna frontera de persona las borra
(`DataWipeService.removeGroupsDomainPreferenceKeys`, la rama sin datos de `startFreshPrivateOnboarding`), así
que la persona siguiente las ve aceptadas y `adoptLegacyIfNeeded` se las atribuye al entrar. Desde este lote el
snapshot sin sello del formato nuevo sí se retira en esas fronteras (`removeUnsealedSnapshot`); las keys legacy no
se tocaron porque el caso ya existía y la población se va reduciendo.
