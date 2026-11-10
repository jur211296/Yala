---
name: el-iphone-de-pruebas-es-el-14-por-cable
description: El QA físico va en el iPhone 14 de pruebas (por cable), nunca en el iPhone 18 Pro Max de Jürgen; los dos se emparejan con la Max y devicectl lista ambos.
metadata:
  type: feedback
---

El aparato de QA es el **iPhone 14** («iPhone de JURGEN», por cable). El **iPhone 18 Pro Max** («iPhone de
Jurgen», por red) es su teléfono personal: no se instala nada ahí.

**Why:** 2026-11-05 instalé Yala Dev en el 18 porque era el único UDID que `devicectl` listaba al principio
(por red); el 14 apareció luego, por cable. Jürgen: «quiero que uses el 14 para las pruebas».

**How to apply:** antes de instalar, `xcrun devicectl list devices` y elige por modelo (iPhone14,7) y por
`connected`, no por el primer físico. Si hay dos, confirma con él cuál. Relacionado:
[[device-mcp-lo-enciende-jurgen]].
