---
id: private-sign-out-misses-group-edits-made-during-the-icloud-wait
status: backlog
priority: low
area: "settings, groups"
created: 2026-09-28
source: "residual de `groups-outbox-rows-without-a-live-session-have-no-exit` (review adversarial, 2026-09-28)"
---

# Un gasto de grupo apuntado durante la última espera del cierre privado se pierde sin aviso

## El problema, en lenguaje de usuario

Cierro sesión en mi sesión privada sin sesión de grupos. Mientras Yala espera a que lo último llegue a iCloud, vuelvo a la
app y apunto un gasto en un grupo. El cierre termina y ese gasto se pierde sin que ningún aviso lo contara.

## Lo medido (leído, sin ejecutar, 2026-09-28)

- La celda C (`privateOnly`) no sube grupos. Desde `groups-outbox-rows-without-a-live-session-have-no-exit` captura lo que
  vive en el History antes de contar (`CloudSessionSignOut.captureGroupsBeforeCountingThem`): al empezar el cierre y al
  entrar en `finalizeSessionExit`, tras la primera espera de iCloud.
- Queda la SEGUNDA espera: la de `armAfterCredentials` con `.confirm`, con la sesión ya suelta. La comprobación pegada al arm
  (`blockIfGroupsCannotUpload`) no vuelve a capturar —ahí no puede haber `await`, y el drain necesita la quiescencia del
  import—, así que lo apuntado en grupos durante esa espera solo está en el History y el borrado se lo lleva.
- Es anterior a ese ticket (antes la celda C no capturaba nunca).

## Lo que se espera

Capturar tras la segunda espera y antes del tramo sin `await`, o una lectura del History sin escribir, como
`CloudSyncEngine.hasUncapturedPersonalChanges`, para el recuento pegado al arm.
