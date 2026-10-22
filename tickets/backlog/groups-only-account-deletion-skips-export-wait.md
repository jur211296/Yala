---
id: groups-only-account-deletion-skips-export-wait
status: backlog
priority: low
area: "settings, modo-nube"
created: 2026-09-11
updated: 2026-10-08
source: "review adversarial del paso 9 (`session-exits-one-verb-per-session`), lentes de pérdida de datos y de reglas"
---

# Borrar la cuenta en solo grupos no espera al export de iCloud cuando el store espeja

## Lo que pasa

Desde el paso 9, «Eliminar mi cuenta» en un solo-grupos sin sesión privada (F) cierra como la nube:
`AccountDeletionService` → `CloudSessionSignOut.closeLocalAfterAccountDeletionCloud`, que arma el boot-wipe
personal + sync-meta + grupos. El CIERRE DE SESIÓN de esa misma celda espera al export si su store espeja
(`CloudSignOutFlowLogic.exitPlan`); el borrado de cuenta no.

La población es estrecha: un solo-grupos cuyo store espeja (instalación anterior al paso 5, o un
`.groupInvite` que llegó por el iCloud KV a un teléfono privado). Ahí, lo último que guardó y aún no subió
se pierde sin aviso.

## Dos restos del mismo camino

- El consent de Grupos no se borra en sesión en ese cierre (lo borra el boot-hook). Un kill entre
  `signOut()` y el arm deja el consent de una cuenta ya borrada. Es inofensivo porque el snapshot va sellado
  con su `userID`, pero conviene que el cierre sea autocontenido.
- El breadcrumb dice `account-delete-cloud` también para F.

## Criterios de aceptación

- [ ] Con el store espejando, el borrado de cuenta en F pasa por la misma espera y la misma salida avisada.
- [ ] El breadcrumb distingue F de la nube.

## Medido en 2.1 (triage 2026-10-08)

- `AccountDeletionService.deleteAccount` sigue mandando la celda F (`!hasPrivateSession`) por `closeLocalCloud` → `CloudSessionSignOut.closeLocalAfterAccountDeletionCloud`, que no espera al export de iCloud.
- El breadcrumb sigue diciendo `account-delete-cloud` para F; la métrica `accountDeletionCompleted` sí distingue (`groupsOnlyNoPrivate`).
- El único commit posterior que toca esa función (`b10a672ed`) no añadió la espera. Población estrecha: solo-grupos con el store espejando.

Triage 2026-10-08: abierto · low → low · el borrado de cuenta en F sigue sin la espera del export; población estrecha y la persona está borrando su cuenta.
