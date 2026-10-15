---
name: conducir-simulador-con-axe
description: Para recorrer muchas pantallas en el simulador, axe (describe-ui filtrado + tap por id o punto) cuesta una fracción de snapshot_ui; sus trampas medidas el 2026-10-15
metadata:
  type: reference
---

En el barrido de QA del 2026-10-15 recorrí ~40 pantallas con `axe` (CLI en `/opt/homebrew/bin/axe`, v1.8.0) en vez de
`snapshot_ui` de XcodeBuildMCP, que devuelve 3-5 k tokens por pantalla porque arrastra todo lo que hay debajo de una hoja.

- **Leer:** `axe describe-ui --udid <U>` devuelve JSON; un script que imprime `rol|label|id|valor @x,y` filtrado por
  texto da 2-10 líneas. Ojo: también lista lo que queda **detrás** de la hoja, así que filtra por id.
- **Tocar:** `axe tap --id <accessibilityIdentifier> --wait-timeout 5 --udid <U>` resuelve el punto solo. Con ids que
  llevan espacios falló en silencio: toca por punto.
- **Pulsación con duración:** `axe touch -x <x> -y <y> --down --up --delay 0.15` (son `-x/-y`, no `--x`). Hace falta
  para widgets, la pantalla de inicio (pulsación larga de 2 s) y vistas que se repintan.
- **Escribir:** `axe type` no escribe tildes ni «ñ» («No keycode found for character: 'é'»): escribe sin ellas.
- **Ver:** `simctl io <U> screenshot` + `sips -Z 700` a JPEG; las coordenadas de la imagen × (402/ancho) dan puntos.
- Las marcas de selección de Fotos se pintan con retraso: el contador «Mostrar selección (N)» es la verdad, no la captura.

**How to apply:** en cualquier `/qa` o `/barrido-qa` largo. Para un toque suelto con elementRef, el MCP sigue valiendo.
Relacionado: [[capturar-el-menu-de-compartir]], [[el-tap-de-xcodebuildmcp-se-pierde-en-pantallas-vivas]].
