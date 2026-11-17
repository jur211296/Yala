---
name: ida-que-no-cuadra-en-el-iphone-14
description: 17-nov, la re-ida de test@yala-app.pe en el iPhone 14 (store re-bajado de iCloud tras un reset del espejo) no cuadra la verificación y sale por su techo; bloqueó la prueba de punta a punta del arreglo
metadata:
  type: project
---

El 2026-11-17 (03:00–04:00 Lima), con el arreglo de la vuelta a iCloud instalado, «Pasar a tu cuenta de Yala» con
`test@yala-app.pe` subió las 3.260 filas y la verificación devolvió a la subida tres veces (`verify>upload`) hasta
`verify>failed`: «No pudimos pasar tus datos a tu cuenta de Yala». El store venía de un reset del espejo seguido de una
re-bajada de iCloud (6.236 tipos de cambio, que la ida fundió a 732) y la cuenta tenía la copia congelada de la vuelta
anterior. Un segundo intento (≈04:00, «Reintentar» → «Usar en este dispositivo», que volvió a ser una ida entera) repitió el patrón: tras la verificación volvió a la subida desde 0. Sin el motivo medido: la consola estaba filtrada.

**Why:** dejó sin hacer la ida → nube → vuelta de punta a punta con el arreglo; quedó como device-QA.

**How to apply:** antes de repetir esa prueba en el 14, mide por qué no cuadra (consola con `merkle|mismatch`) o usa
otra cuenta de Google sin copia congelada. Ver [[cuenta-desechable-para-la-nube-en-el-iphone-14]].
