---
name: sign-out-de-depuracion-borra-el-proveedor
description: Para montar «modo nube sin sesión» en el iPhone 14 sirve el «Sign out» del panel Modo Nube · Auth, pero también borra el proveedor guardado
metadata:
  type: reference
---

El estado «datos en la nube, sin sesión» (el del bug de Vaciar datos del 2026-11-25) se monta en Yala Dev con Ajustes ›
Dónde viven tus datos › «Modo Nube · Auth» › «Sign out»: suelta la sesión y deja `storageMode = cloud`.

Ojo: ese cierre local borra también el proveedor guardado, así que la puerta de «Iniciar sesión» abría **Apple** en una
cuenta de Google (desde el 2026-11-25 cae al proveedor del faro). Un fallo real de renovación no borra el proveedor.

Y la consola de una build Debug en el iPhone: `xcrun devicectl device process launch --device <udid> --terminate-existing
--console com.jurgenschmidt.yala.dev > log` en segundo plano. La configuración `Release-Dev` no compila fuera del
archivo (las pantallas de depuración exigen DEBUG): para el teléfono, `Debug-Dev` con `-derivedDataPath` propio.
Relacionado: [[conducir-el-iphone-real-con-device-mcp]].
