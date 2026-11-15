---
name: reference-medir-la-entrada-a-la-cuenta-en-el-iphone
description: Cómo medir paso a paso «Conectando con tu cuenta» en el iPhone 14: prints con hora bajo DEBUG + devicectl --console, misma cuenta y reinstalación entre corridas
metadata:
  type: reference
---

Medido el 2026-11-14 (card «Conectar con la cuenta tarda 22–50 s»).

- Traza temporal: un `print("⏱ADOPT <ms> <paso>")` bajo `#if DEBUG` en el claim, cada paso de `runAdoptFlow` y cada
  página de `enumerateBackendSyncIDs`; se retira antes del commit.
- Lanzar con `xcrun devicectl device process launch --console --terminate-existing com.jurgenschmidt.yala.dev > log` en
  segundo plano: el stdout llega al log. La hora de inicio, con `python3 -c 'import time;print(int(time.time()*1000)%10**8)'`
  justo antes de tocar «Cargar mis datos y entrar».
- Cada corrida: desinstalar + instalar (`devicectl device uninstall/install app`) y «Entrar con Google» → jur211296 →
  «Continue» de Google → «Cargar mis datos y entrar». La hoja de Google acepta toques de Device MCP por coordenadas.
- Cifras de ese día (7.221 filas): 55 s antes; 32 s con páginas de 1.000 y el Merkle en paralelo; 16 s con el gateway en
  paralelo. Una página vacía costaba lo mismo que una llena: coste fijo por petición, no por fila.

Relacionado: [[reference-conducir-el-iphone-real-con-device-mcp]].
