---
name: salir-del-grupo-espera-decision
description: PR #75 cerró el error crudo al salir de un grupo; lo que queda abierto es una decisión de producto sobre el dueño con deuda, y device-QA
metadata:
  type: project
---

`groups-leave-rpc-error-10` está **en `qa`** desde el 2026-09-06 (PR #75). El código está hecho y
verificado; lo que queda no es código.

**Why:** el «error 10» del device-QA del 28-ago no era el kill-switch del canal, como creían el
ticket y el encargo: era `ownerCannotLeave` — el servidor decía «eres el dueño, no puedes salir»
mientras el flag device-local `SplitGroup.isOwner` decía lo contrario, así que la pantalla escondía
«Eliminar grupo», que era justo lo que ese usuario venía a hacer. Ver
[[la-premisa-del-encargo-tambien-se-mide]].

**Lo que espera a Jürgen, y es decisión suya, no de implementación:** el dueño con **deuda pendiente**
sigue sin salida — «Eliminar» se deshabilita con deuda, y el bloqueo mira la deuda de TODO el grupo,
no la suya, así que puede quedar bloqueado por una deuda entre otras dos personas con un aviso que le
pide liquidar deudas ajenas. Las salidas posibles: ofrecer «transferir y salir» (el RPC
`transfer_group_ownership` y `GroupBatchLeaveLogic` ya existen, falta UI y copy), permitir eliminar
con deuda como ya se permite salir con deuda, o dejarlo así.

**Y falta device-QA**, que es lo que cierra el ticket: dos teléfonos, reproducir el rechazo por
ownership, comprobar que el mensaje se entiende y que «Eliminar grupo» aparece después.

**How to apply:** si Jürgen retoma este ticket, no rehagas el diagnóstico —está medido y fijado por
test— y no empieces por el código: lo bloqueado es la decisión. Verifica antes de citar: los estados
de ticket caducan.
