---
name: reference-sentry-tokens-y-api
description: Dónde vive el acceso a Sentry (org yala-is, región us) para leer eventos por API sin navegador, y qué token es de qué
metadata:
  type: reference
---

Sentry de Yala: org `yala-is`, región `https://us.sentry.io`, proyectos `yala-ios` y `yala-gateway`. Chrome NO tiene sesión
iniciada (pide login): se lee por API.

- **Token de solo lectura** (event:read + project:read), creado por Jürgen el 2026-10-26: `~/Secrets/yala-sentry/read-token`.
  Se pegó en el chat de aquella sesión, así que está en su transcript: Jürgen quedó en revocarlo cuando tenga el del llavero.
- **Token con escritura** (project:write, event:write): en el Llavero de la Mini, servicio `sentry-yala`, cuenta `jur`,
  desde el 2026-11-04. Leer con `security find-generic-password -s sentry-yala -a jur -w`, sin imprimirlo; nunca al repo
  ni por chat (lo pidió el bot dueño). Pendiente ese día: que Jürgen lo copie al vault de Yala en 1Password.
- **Resolver un issue «en la release que trae el arreglo»**: `PUT /api/0/organizations/yala-is/issues/?id=<id numérico>`
  con `{"status":"resolved","statusDetails":{"inRelease":"com.jurgenschmidt.yala@2.2+6"}}`. Las releases se llaman así
  (bundle@versión+build); comprueba con `git merge-base --is-ancestor` que el arreglo está en ese bump. «En la próxima»
  (`inNextRelease`) no sirve si ya existe la release con el arreglo: la daría por mala.
- Leer un evento entero: `GET /api/0/projects/yala-is/<proyecto>/events/?statsPeriod=1h` y luego `/events/<id>/`.
  Para comprobar la limpieza, busca los datos falsos en el JSON ENTERO, no solo en el mensaje.

**Simbolizar sin dSYM no sale (medido el 2026-10-31, YALA-IOS-2, build 2.2 (5)).** Los frames de Yala llegan sin nombre
porque nadie sube dSYM a Sentry. `asc builds dsyms --build-id …` contestó «No dSYM files available» y no quedaba
`.xcarchive` en la Mini; recompilar Release del mismo commit dio otro UUID y otro tamaño de `__TEXT`, y `atos` devolvió
basura. No repetirlo: diagnosticar por la forma del stack (qué framework, qué executor) y medir en local. Desde el 2026-11-04 el
post-action «Archive» del scheme `Yala` sube los dSYM de cada archivado (`scripts/sentry-subir-dsym.sh`).
