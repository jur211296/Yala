---
id: cloud-signout-upstream-rejections-with-a-healthy-pull-say-a-moment-more
status: backlog
priority: low
area: "modo-nube, sesión"
created: 2026-09-25
source: "review adversarial de `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` (2026-09-25)"
---

# Con el Postgres del servidor fallando y el pull sano, cerrar sesión dice «un momento más»

## El problema, en lenguaje de usuario

Tengo cambios sin subir a mi cuenta en la nube y el servidor contesta pero no guarda (su base de datos está caída). Toco
«Cerrar sesión», espero unos segundos y Yala me dice «Un momento más… espera unos segundos». Vuelvo a intentarlo y pasa
lo mismo: no es un guardado que se asienta, es el servidor.

## Lo medido (leído, sin ejecutar)

- El Worker contesta 200 con resultados `rejected` + `upstream_*`. `SyncPushClient.applyResults` no purga la fila y desde el
  2026-09-25 enciende el testigo (`lastPushFailedAtServer`).
- Si el pull va bien, el ciclo es `.completed` y el push-all itera hasta el tope (20). `CloudSignOutFlowLogic.pushAllVerdict`
  clasifica el tope con `classify(.completed)`, que devuelve `.transient` **sin mirar el testigo**. Con el pull fallando, en
  cambio, sale `.uploadRetryLater` (arreglado el mismo día).
- `classify` y `pushAllVerdict` los comparte el cierre de Grupos (`CloudSessionSignOut.swift`, el push-all de grupos), y el
  test `theStillDrainingOutboxIgnoresTheUploadWitness` fija que el tope ignora el testigo. Cambiarlo es una decisión de los
  dos canales.

## Lo que hay que decidir

¿El tope de iteraciones con el testigo encendido es `.uploadRetryLater` en los dos canales, o solo en el personal?
