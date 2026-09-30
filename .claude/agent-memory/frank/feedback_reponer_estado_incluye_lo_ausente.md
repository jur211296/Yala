---
name: reponer-estado-incluye-lo-ausente
description: Al reenviar estado local a un canal donde el remoto gana, la clave AUSENTE también se expresa (borrarla), o el remoto la rellena.
metadata:
  type: feedback
---

Cuando repongo lo local en un canal cuyo merge da la razón al remoto, una clave que falta en local no se «salta»:
se retira del remoto. Si no, el merge siguiente la rellena con el valor viejo y es el mismo bug por otra puerta.

**Why:** en #306 (subir las preferencias al nacer la sesión privada) escribí «una clave ausente no se escribe: sería
inventar un valor». La lente adversarial de «de quién es el KV» lo tumbó: el idioma, los iconos o el primer día de
la semana de la vida anterior del Apple ID volvían en el arranque siguiente. Borrar no inventa nada, y era el gesto
que la app ya hacía (`LanguageManager` con `nil` → `removeObject`). Mi propio test no podía verlo: filtraba las
claves ausentes con el mismo `presentValue` de producción (circular).

**How to apply:** en cualquier reposición/reconciliación, pregunta qué significa la AUSENCIA en local y si el
receptor la ignora (aquí `guard let remote` ⇒ borrar es inocuo para los demás). Excepción deliberada: los registros
de trazabilidad (consentimientos) no se borran nunca. Y el test de «no revierte» recorre TODAS las claves, no las
presentes. Relacionado: [[una-key-nueva-esta-ausente-en-todo-el-parque]], [[un-gate-derivado-de-una-ausencia-falla-abierto]].
