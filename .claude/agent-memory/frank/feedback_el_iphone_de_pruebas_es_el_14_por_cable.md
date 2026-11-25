---
name: el-iphone-de-pruebas-es-el-14-por-cable
description: El QA físico va en el iPhone 14 de pruebas; en el iPhone 18 Pro Max personal de Jürgen solo se instala Yala Dev cuando él lo pide (25-nov lo pidió para probar Dev y TestFlight en paralelo).
metadata:
  type: feedback
---

El aparato de QA es el **iPhone 14** («iPhone de JURGEN», por cable). El **iPhone 18 Pro Max** («iPhone de
Jurgen», por red) es su teléfono personal: ahí no se prueba. Solo se instala Yala Dev cuando él lo pide.

**Why:** 2026-11-05 instalé Yala Dev en el 18 porque era el único UDID que `devicectl` listaba al principio
(por red); el 14 apareció luego, por cable. Jürgen: «quiero que uses el 14 para las pruebas».

**How to apply:** antes de instalar, `xcrun devicectl list devices` y elige por modelo (iPhone14,7) y por
`connected`, no por el primer físico. Si hay dos, confirma con él cuál. Relacionado:
[[device-mcp-lo-enciende-jurgen]].

**Actualización 2026-11-25:** Jürgen pidió Yala Dev en su personal para probar Dev y TestFlight en paralelo. En la Mini
`devicectl` lo lista como «iPhone de Jurgen», iPhone19,3, UDID `00008160-000E158E20434036`. También aparece «iPhone de
Jur» (17 Pro Max, `unavailable`), que no es el actual. Receta: `xcodebuild -scheme "Yala Dev" -configuration Debug-Dev
-destination id=<UDID> -allowProvisioningUpdates build` + `devicectl device install app`. Si te lo vuelve a pedir, no
preguntes cuál es: es ese.
