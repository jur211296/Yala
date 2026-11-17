---
name: cuenta-desechable-para-la-nube-en-el-iphone-14
description: Para probar ida, vuelta y re-ida de la nube en el iPhone 14 contra staging, la cuenta de Google test@yala-app.pe entra sin contraseña y no la usa nadie más; medir con SQL de staging desde la Mini
metadata:
  type: reference
---

Medido el 2026-11-16 (encargo de los cinco bugs media de nube 2.3). En staging (`fostjbbwstyuunmmefuk`) solo había 4
usuarios, los `i5-*@test.yala` de los goldens: ninguno de Google. `test@yala-app.pe` (Google, sale en la lista de cuentas
del iPhone 14 y entra sin contraseña) creó cuenta nueva al «Pasar a tu cuenta de Yala». Sirve de cuenta desechable: no la
comparten otras sesiones.

- Estado de la cuenta y conteos: SQL por la Management API desde la Mini (ver [[secretos-de-staging-en-la-mini]]),
  filtrando `auth.users.email`.
- Una ida con 2.361 registros tarda ~9 min en subir (≈6 filas/s): espera con `wait_for` de 60 s, no con capturas seguidas.
- La consola de los pasos sale con `devicectl … --console`; los `CloudSyncReverse …` solo si imprimen en `#if DEBUG`.

Relacionado: [[reference-medir-la-entrada-a-la-cuenta-en-el-iphone]], [[qa-fisico-datos-dev-no-preguntes]].
