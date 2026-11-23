---
name: barrido-en-la-mini-limites
description: Qué no se puede en un barrido desde la Mini (Duo, giro del iPhone 14, Device MCP gratis) y una trampa de idioma del iPhone 14
metadata:
  type: reference
---

Medido el 2026-11-23 (barrido de la 2.3 antes de la build 7, en la Mini):

- **El Duo no se crea en la Mini**: `simctl create … iPhone-Duo … iOS-27-2` da «Incompatible device». Su sistema
  simulado vive en la Max ([[duo-abierto-en-la-max]]). Un encargo que pida Duo desde la Mini: dilo en el Paso 0.
- **No hay app «Simulator»** (Xcode 27, Device Hub): `osascript` para girar con ⌘← falla. El giro del iPhone sale de
  `IPhoneLandscapeUITests`.
- **Device MCP gratis refleja UN aparato**: con el iPhone 14 tomado, nombrar el SE en `launch_app` da error. El resto
  se conduce con `axe`; `axe tap --label` a veces resuelve un punto fuera de pantalla y no toca nada (en el SE y el
  iPad): mejor `describe-ui` y tocar por coordenada (puntos, la captura de `simctl io` va a 2×).
- **El iPhone 14 tiene la rotación bloqueada** en el Centro de control; `rotate` falla.
- **El iPhone 14 está en español de España**: la app sale con los textos de `es-ES.lproj` («A revisar», «se ha pasado
  este periodo»). No es un fallo; compara con `es.lproj` antes de anotarlo.
- **El llavero sobrevive a desinstalar Yala Dev**: tras reinstalar, la sesión de la cuenta de Yala anterior sigue ahí
  durante el alta (card «Bienvenida: al entrar con iCloud privado tras reinstalar…», 23-nov).
- `set_accessibility` en el iPhone real abre el Centro de control y lo deja abierto: ciérralo con `press_button home`.
