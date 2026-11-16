---
id: adopt-over-cloud-block-uses-the-foreign-data-copy
status: backlog
area: cloud-sync
priority: low
created: 2026-11-13
updated: 2026-11-13
source: review adversarial del arreglo de adopt-over-a-device-already-in-cloud-mode-has-no-exit (13-nov)
---

# El bloqueo de «entrar sobre un teléfono en la nube» usa el texto de datos de otra cuenta

## Qué pasa

Desde el 13-nov, la entrada a una cuenta en el Welcome no adopta si el teléfono sigue en `.cloud` sin el sello de esa
cuenta (`AdoptOverCloudGuardLogic.refusesAdopt`). Se para con la pantalla `.blockedForeignData`, cuyo texto dice «Este
dispositivo ya tiene datos guardados… Quien los guardó puede volver a entrar», aunque el teléfono no tenga filas. La salida
existe (Volver → «Empezar de cero» deja el teléfono recién instalado), pero el texto no la cuenta.

## Qué haría falta

Un texto propio para este caso, en los 16 idiomas, que diga que el teléfono sigue conectado a otra cuenta de la nube y
que «Empezar de cero» lo deja como nuevo. Leer `BRAND-VOICE.md`. Mirar antes cuántas veces salta el canario
`adoptOverCloudRefused` en la flota: si es cero, no merece el copy.

Relacionado y sin verificar que sea alcanzable: con grupos que el aviso tardío conservó para esa persona y el modo en
`.cloud`, el borrado del arranque retira la sesión y el consentimiento de Grupos.
