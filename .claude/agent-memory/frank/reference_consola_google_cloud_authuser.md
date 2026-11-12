---
name: consola-google-cloud-authuser
description: Cómo leer la consola de Google Cloud del proyecto yala-502622 desde Chrome del MCP sin pedir la llave de acceso a Jürgen
metadata:
  type: reference
---

En Chrome de la Max, la cuenta por defecto (`authuser=0`) es admin@yala-app.pe y la consola le pide **llave de acceso**;
el Touch ID de Jürgen no llegó a la pestaña del MCP (12-nov-2026, dos intentos). La dueña del proyecto es
jur211296@gmail.com y su sesión ya está abierta como **`authuser=1`**: `console.cloud.google.com/auth/scopes?project=yala-502622&authuser=1`
abre Data Access sin pedir nada.

**How to apply:** prueba `authuser=1` antes de pedirle la llave. Solo lectura salvo que el encargo pida cambiar algo.
Ver [[verificacion-gmail-video-v2]].
