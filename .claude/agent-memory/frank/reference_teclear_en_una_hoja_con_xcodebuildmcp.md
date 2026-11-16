---
name: reference-teclear-en-una-hoja-con-xcodebuildmcp
description: type_text de XcodeBuildMCP no escribe en un TextField de una hoja; key_press HID tras tocar el campo sí. Los dos dejan el teclado físico puesto.
metadata:
  type: reference
---

Para capturas con texto en un campo de una hoja (16-nov, editor de tarjeta, iOS 27.2): `type_text` sobre el ref devolvía
éxito y el campo seguía vacío (dos intentos). Lo que escribió: `tap` en el campo y luego `key_press` con códigos HID
(1=30, 2=31, 3=32 … 0=39). Después, el simulador queda con `HardwareKeyboardLastSeen = 1` (lo dice la regla de tests) y
los XCUITest que escriben caen: `xcrun simctl spawn <udid> defaults write com.apple.keyboard.preferences
HardwareKeyboardLastSeen -int 0` lo devolvió a 0 y `CardDesignUITests` (que teclea) pasó a continuación, sin borrar el
simulador.

**Cómo aplicarlo:** capturas con texto, al final y con el reseteo de la preferencia antes del siguiente XCUITest.
Relacionado: [[feedback-capturas-en-el-chat-antes-de-preguntar]].
