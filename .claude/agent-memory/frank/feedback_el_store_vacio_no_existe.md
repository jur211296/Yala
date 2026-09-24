---
name: el-store-vacio-no-existe
description: Una condición «sin nada que subir / store vacío» se mide con el inventario de un teléfono REAL — el arranque ya siembra filas antes del Welcome
metadata:
  type: feedback
---

Cuando una guarda exime el caso «no hay nada local» (un recién instalado, el 2.º dispositivo de una cuenta nacida en la
nube), antes de escribirla pregunta **qué filas tiene un teléfono real en ese instante**, no un store de test vacío.

**Why:** el 2026-09-24 (`adopt-uploads-a-foreign-corpus-without-a-lineage-check`) eximí de la prueba de linaje a quien
no tenía nada que subir, y mi test lo «demostraba» con un inventario vacío. La lente del dispositivo legítimo midió que
`AppBootstrapper` guarda tipos de cambio sin identidad ANTES del Welcome: ese teléfono nunca llega vacío, y la excepción
no protegía a nadie. Con el D2 escrito en el Paso 0, el error estaba en la premisa, no en el código.

**How to apply:** ante «sin filas locales» / «store vacío» / «nada que subir», grep de lo que el arranque inserta sin
condición de onboarding (`AppBootstrapper`, servicios de caché) y ponlo en el fixture del test. Emparenta con
[[el-fixture-hereda-la-anatomia-de-produccion]] y [[la-premisa-del-encargo-tambien-se-mide]].
