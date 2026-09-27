---
id: activation-private-gate-leaves-a-late-notice-that-purges-groups
status: backlog
priority: medium
area: "groups, onboarding, modo-nube"
created: 2026-09-27
source: "review adversarial de `private-gate-leave-after-a-halfway-wipe-forgets-the-zone` (2026-09-27, lente de alcance); inferido por lectura, NO reproducido"
---

# Activar Yala completo sin poder mirar iCloud deja un aviso cuyo borrado se lleva los grupos

## El síntoma, en lenguaje de usuario

Estoy en solo-grupos y activo Yala completo → privado, sin red (o sin iCloud). La app me deja seguir, termino la
activación y conservo mis grupos. Días después, con iCloud funcionando, aparece «Encontramos datos tuyos en iCloud». Si
elijo borrarlos, el borrado se lleva también mis grupos: justo lo que la activación existía para conservar.

## Lo medido (2026-09-27, leyendo código)

- La puerta privada de la activación sale por `unverifiedExit: .proceedWatchingTheMirror`
  (`FullModeActivationView.swift`), así que `continueWithoutValidating` escribe el testigo del espejo tardío
  (`markPrivateChoseWithoutICloud`).
- `completeFullActivation` retira el arm, la marca «a medias» y el neutro solo-grupos, pero no ese testigo.
- Tras la activación la sesión es privada: `runLateICloudMirrorCheck` sondea y presenta `.corpus`, cuyo borrado es
  `performICloudCorpusWipe(.handover)` (dominio de Grupos incluido).
- La puerta de «Restaurar → Empezar desde cero» lo evitó a propósito con `.returnWithoutClaimingAWipe`; la privada no.
  Es el mismo criterio de `private-gate-leave-after-a-halfway-wipe-forgets-the-zone` por otra puerta.

## Qué hay que decidir

¿El aviso tardío de quien activó borra con otro alcance (`.importedRows`, sin purgar Grupos), o la activación no deja
el testigo y valida de otra forma? La primera conserva la validación aplazada; la segunda la pierde.

## Criterios de aceptación

- [ ] Ningún aviso que vea quien activó Yala completo ofrece un borrado que purgue sus grupos.
- [ ] La validación de iCloud que no se pudo hacer al activar sigue ocurriendo cuando se pueda.

## Relacionados

- [[private-gate-leave-after-a-halfway-wipe-forgets-the-zone]]
- [[activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable]]
