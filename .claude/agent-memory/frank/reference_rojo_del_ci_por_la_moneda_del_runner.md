---
name: rojo-del-ci-por-la-moneda-del-runner
description: Un test verde en la Mac y rojo en el CI que depende de la moneda principal: el runner es en_US (USD). Cómo reproducirlo con la app de pruebas correcta.
metadata:
  type: reference
---

El runner del CI es en_US: sin `defaultCurrencyCode` guardada, la moneda principal es USD; en la Mac (región PE) es PEN.
Un test con una cuenta en "PEN" fijo y un flujo que pregunta la moneda «si hay más de una» pasa aquí y cae allí.
Pasó el 17-nov con el guiado de tarjeta de crédito (PR de cuenta, categoría y favorito, 3 de 3 rojo en CI).

**Cómo reproducirlo:** `xcrun simctl spawn <udid> defaults write <contenedor>/Library/Preferences/<bundle> defaultCurrencyCode USD`
(ruta SIN `.plist`; leer el fichero con `plutil` no ve el valor hasta que cfprefsd lo vuelca). **El bundle es el del
scheme que corres**: `com.jurgenschmidt.yala` con `-scheme Yala`, `com.jurgenschmidt.yala.dev` con `Yala Dev`. Escribirlo
en el otro no reproduce nada (me costó una corrida). Al terminar, `defaults delete` en los dos.

**Arreglo:** el test usa `CurrencyDefaults.currentPreferred` para la cuenta, no un literal. Ver también la regla del
diccionario con la preferida en `.claude/rules/testing.md` («Cerrar esa fuga…»).
