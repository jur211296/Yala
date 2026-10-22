---
name: el-atasco-se-prueba-con-segundos-y-el-mismo-cambio
description: Para dar algo por «atascado» (y abrir una salida que pierde datos) Jürgen exige reintentos con backoff durante varios segundos y el MISMO fallo repetido; 3×250 ms no vale.
metadata:
  type: feedback
---

Clasificar un fallo como permanente para abrir una salida destructiva exige **reintentos espaciados con espera creciente
durante varios segundos** y **prueba de que es el mismo cambio fallando cada vez**; solo entonces se ofrece la salida, con
la cifra exacta. Un fallo pasajero que se cura dentro de los reintentos nunca la abre. El timing va en constantes con nombre.

**Why:** 2026-10-05, ticket `groups-drain-that-always-aborts-takes-the-loss-exit-away`. Mi primera versión autónoma daba
la captura por atascada tras 3 vueltas × 250 ms (~0,5 s) y Jürgen la paró a mitad del gate: «Reintentos espaciados con
espera creciente durante varios segundos, mismo cambio fallando; luego ofrece la salida con la cifra.» Medio segundo no
distingue un `save` que choca de un drain roto, y sin «mismo cambio» un drain que avanza a trompicones parecía atascado.

**How to apply:** cuando un encargo pida separar «pasajero» de «permanente» antes de ofrecer perder algo, no elijas un
umbral corto por UX: backoff de segundos (aquí 0,5·1·2·4 s), evidencia de identidad del fallo (intersección de lo que
sigue fuera en cada intento) y lectura obligatoria para dar cifra exacta. Sin evidencia, no se abre la salida. Relacionado
con [[elige-la-propuesta-completa-aunque-aprieta]] y [[prefiere-lo-limpio-a-lo-defensivo]].
