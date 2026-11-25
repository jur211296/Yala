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

**Excepción medida el 2026-11-25:** cuando Jürgen reporta un bug que vio en SU 18, ese teléfono guarda el estado roto,
y él mismo ofreció usarlo («usa el iPhone 18 que es donde hice las pruebas»). Lo que sirvió sin instalar nada: copiar
del 18 el App Group y `Library/Preferences` de Yala Dev con `devicectl copy from` y leer sus claves (ahí apareció la
causa del bug de Primeros pasos). Leer, sí; instalar en el 18, solo si él lo pide.
