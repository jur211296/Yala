---
name: limpiar-staging-es-sus-cuentas
description: «Limpia staging, todas las cuentas» = borrar sus cuentas de Google con todos sus datos; los usuarios sintéticos i5-…@test.yala de los tests del servidor se quedan.
metadata:
  type: feedback
---

Cuando Jürgen pide «limpiar staging, todas las cuentas, para probar desde cero», borra sus cuentas reales de Google
(jur…@gmail.com, adm…@yala-app.pe, tes…@yala-app.pe en noviembre de 2026) con todo lo suyo, y deja los cuatro
usuarios sintéticos `i5-…@test.yala`.

**Why:** 2026-11-16, se le preguntó con las tres opciones (sus 3 de Google / las 7 / solo datos) y eligió la
recomendada: los sintéticos son los de los goldens del gateway contra staging, y borrarlos los rompe hasta recrearlos.

**How to apply:** lista primero `auth.users` de staging (SQL por la Management API desde la Mini, ver
[[secretos-de-staging-en-la-mini]]); si aparece una cuenta que no es suya ni sintética, pregunta. El borrado va por
las funciones de la app (`groups_forget_user()` y `delete_personal_account()` con el `sub` del usuario), no a mano.
Suele venir junto a «déjame Yala Dev recién instalado en el iPhone 14». Relacionado: [[qa-fisico-datos-dev-no-preguntes]].
