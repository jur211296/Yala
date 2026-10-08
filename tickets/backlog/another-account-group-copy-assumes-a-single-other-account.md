---
id: another-account-group-copy-assumes-a-single-other-account
status: backlog
priority: very-low
area: "grupos, copy"
created: 2026-10-05
updated: 2026-10-08
source: "medido al implementar `fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason` (2026-10-05)"
---

# Los textos de cambios de otra cuenta dicen «con ella» aunque puedan ser de varias

## El problema, en lenguaje de usuario

Cuando el teléfono guarda cambios de grupos de otra cuenta, varios avisos dicen «se apuntaron con otra cuenta y solo se
pueden subir con ella» o «hasta que entres con esa cuenta». Los cambios pueden ser de más de una cuenta (un iPhone que
pasó por varias manos), y entonces «ella» no señala a ninguna.

## Lo medido (es-419, árbol de 2026-10-05)

- `groups.errors.groupsChangesFromAnotherAccount` — «…solo se pueden subir con ella… hasta que entres con esa cuenta».
- `groups.errors.otherAccountAndCaptureUnfinishedSignOutLoss` y su `…Unknown` — «…solo se suben con ella…».
- `welcome.groups.neutralOtherAccountAndCaptureUnfinishedLossBody` y su `…Unknown`.
- `groups.freshStartPending.lossOtherAccountAndCaptureUnfinished` — «…solo pueden subir con ella… si entras con ella».
- `storage.groups.detachBlockedOtherAccountAndCaptureUnfinished` — «…solo se pueden subir con ella… esa cuenta».

`groups.freshStartPending.lossOtherAccount` ya se reescribió sin número el 2026-10-05 («entrando con la cuenta que apuntó
cada uno»). Los de «…AndCaptureUnfinished» los fija `GroupsStuckDrainHeldRowsTests.theSpanishCopy` por frase literal, así
que cambiarlos pide tocar ese test a la vez.

## Por dónde va

El molde de `lossOtherAccount`: «la cuenta que apuntó cada uno» y «si eso no va a pasar». En los 16 locales.

## Medido en 2.1 (triage 2026-10-08)

- Las claves del ticket siguen diciendo «con ella» en `es-419.lproj` (`groups.errors.groupsChangesFromAnotherAccount`:6197, `…SignOutLoss`:6204, `welcome.groups.neutral…LossBody`:6218, `storage.groups.detachBlocked…`:5904).

Triage 2026-10-08: abierto · very-low → very-low · el copy sigue igual; es pulido.
