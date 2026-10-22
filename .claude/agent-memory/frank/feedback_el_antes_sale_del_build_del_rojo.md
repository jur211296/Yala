---
name: el-antes-sale-del-build-del-rojo
description: Las capturas del «antes» y el rojo del XCUITest nuevo salen de UN build con el arreglo revertido a mano (copia en el scratchpad), antes de compilar el arreglo.
metadata:
  type: feedback
---

Cuando el encargo pide capturas de antes/después y un XCUITest nuevo, el «antes» se saca de un único build con el
arreglo revertido: el mismo binario da el rojo del test (prueba que el test caza el bug) y la captura del bug en
pantalla. Luego se restaura desde la copia y se compila el arreglo una vez.

**Why:** 2026-10-07 (`fresh-start-alert-cancel-after-an-adopt-exit-lands-in-the-app`): con la Mini justa y el pipeline
serial del encargo (build sin simulador, un solo simulador), separar «capturar el antes» de «probar que el test es
rojo» costaba dos builds más. Así fueron dos builds en total.

**How to apply:** copia el fichero arreglado al scratchpad, revierte a mano solo las líneas del arreglo, build →
XCUITest (rojo en la aserción final, no antes) → capturas con `simctl io … screenshot` (el `screenshot` de
XcodeBuildMCP devuelve un JPEG reducido) → `cp` de vuelta y `cmp`. Nunca `git checkout` para restaurar
([[revertir-sin-commit-destruye]]). Las capturas, a `_capturas/<slug>/` antes de sellar
([[capturas-sobreviven-en-worktrees-capturas]]).
