---
name: idioma-de-google-en-el-simulador
description: La página de Google Sign-In dentro de la app sigue el idioma del SISTEMA del simulador, no el -AppleLanguages de la app
metadata:
  type: reference
---

Para grabar el consentimiento de Google en inglés (12-nov-2026): lanzar la app con `-AppleLanguages (en)` cambia la app
pero **no** la hoja de `ASWebAuthenticationSession` ni el aviso de iOS; y el selector de idioma de la página de Google
no se abre con toques sintéticos de Device MCP. Lo que funciona: `simctl spawn <udid> defaults write -g AppleLanguages
-array en` (+ `AppleLocale en_US`), `shutdown` y `boot`. Hazlo en un simulador propio, no en uno ajeno.

**How to apply:** antes de la toma, no después: costó dos grabaciones tiradas.
