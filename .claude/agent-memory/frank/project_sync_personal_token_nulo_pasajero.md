---
name: sync-personal-token-nulo-pasajero
description: Encargo nocturno del 16-sep — el canal personal ya lee pasajeros el token nulo con la sesión guardada y el 401 del attest; en qa con un guion de ventana estrecha; dos decisiones de producto esperan a Jürgen
metadata:
  type: project
---

`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` queda en `qa` (PR del 2026-09-16, sesión nocturna y
autónoma). **Lo que espera cada cosa:**

- **El device-QA** necesita montar una ventana: relanzar Yala con red a menos de 10 min de la `exp` del JWT, modo avión, y
  volver pasada `exp` pero antes de 14 min. Fuera de esa ventana el build viejo se comporta igual (la puerta de attest sale
  antes). La activación del modo completo sin red sí distingue siempre.
- **`cloud-attest-notice-does-not-cover-a-gateway-rejected-token`** (medium): decisión de Jürgen sobre si el aviso fijo debe
  salir a quien el gateway rechaza un token bueno. La recomendación es no, y vigilar el canario `cloudSyncAttestRequired`.
- **`cloud-sync-status-says-all-synced-with-changes-still-pending`** (medium): copy nuevo, decisión de Jürgen.

**Why:** de noche el encargo pedía elegir lo recomendado sin preguntar y aparcar lo que fuera producto; esas dos lo son.

**How to apply:** si Jürgen pregunta por qué el aviso de attest personal «no sale», la respuesta está medida en
[[tras-la-puerta-el-error-es-otro]], no es un olvido. Y si alguien propone contar ese 401 en la racha «como Grupos», la
review del 16-sep ya lo probó y lo retiró.

Relacionado: [[aviso-attest-personal-en-dos-superficies]] · [[el-guion-de-qa-tiene-que-distinguir-builds]].
