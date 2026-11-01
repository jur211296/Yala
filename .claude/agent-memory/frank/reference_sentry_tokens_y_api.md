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
- **Token completo para futuras sesiones**: Jürgen lo guarda en el Llavero, servicio `sentry-yala`, cuenta `jur`
  (instrucciones dadas el 2026-10-26). Leer con `security find-generic-password -s sentry-yala -a jur -w`. Antes de
  usarlo, comprueba que existe; si no, pídelo una vez ([[feedback-credencial-pendiente-se-aparca]]).
- Leer un evento entero: `GET /api/0/projects/yala-is/<proyecto>/events/?statsPeriod=1h` y luego `/events/<id>/`.
  Para comprobar la limpieza, busca los datos falsos en el JSON ENTERO, no solo en el mensaje.

**Simbolizar sin dSYM no sale (medido el 2026-10-31, YALA-IOS-2, build 2.2 (5)).** Los frames de Yala llegan sin nombre
porque nadie sube dSYM a Sentry. `asc builds dsyms --build-id …` contestó «No dSYM files available» y no quedaba
`.xcarchive` en la Mini; recompilar Release del mismo commit dio otro UUID y otro tamaño de `__TEXT`, y `atos` devolvió
basura. No repetirlo: diagnosticar por la forma del stack (qué framework, qué executor) y medir en local. El token con
escritura y la subida de dSYM esperan a Jürgen (card «Sentry: token con escritura…», 2026-10-31).
