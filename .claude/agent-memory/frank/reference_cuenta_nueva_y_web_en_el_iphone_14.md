---
name: cuenta-nueva-y-web-en-el-iphone-14
description: Cómo conseguir una cuenta «nueva» de Yala en el iPhone 14 sin Jürgen, y cómo probar Yala web staging en su Safari con Google
metadata:
  type: reference
---

Medido el 2026-11-15 (barrido final de 2.3, iPhone 14, Yala Dev contra staging):

- **Google entra sin contraseña** con `jur211296@gmail.com` y `test@yala-app.pe` (Safari del iPhone tiene la sesión).
  `admin@yala-app.pe` también aparece; `jurgen@2b.pe` y la de Zealit piden contraseña.
- **Cuenta nueva sin Jürgen:** entra con test@ › Ajustes › Tu cuenta de Yala › Eliminar mi cuenta. El correo queda libre
  y la siguiente entrada sale «Vamos a crear tu cuenta». Es staging y datos de prueba ([[qa-fisico-datos-dev-no-preguntes]]).
- **Ojo con el orden:** tras «Volver a tu iCloud» desde una cuenta, «Pasar a tu cuenta de Yala» con ESA cuenta dice
  «todavía no está disponible». Para medir una activación de la nube con cuenta nueva, borra la cuenta ANTES de volver.
- **Web staging en el iPhone:** `xcrun devicectl device process launch --device <udid> --payload-url
  "https://yala-web-staging.misty-surf-6866.workers.dev" com.apple.mobilesafari` (sin pedir aprobación a `open_url`).
  «Continuar con Google» › jur211296 entra sin contraseña. Apple pide Face ID: eso es de Jürgen.
- **Ver qué quedó en el teléfono:** [[contar-el-store-del-iphone-con-devicectl]]; cuenta todas las tablas Z de
  `YalaModel-Dev.store` para medir «cuántos elementos subiría».
