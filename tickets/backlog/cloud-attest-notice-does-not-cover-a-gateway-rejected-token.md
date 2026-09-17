---
id: cloud-attest-notice-does-not-cover-a-gateway-rejected-token
status: backlog
priority: medium
area: "modo-nube, attest, avisos"
created: 2026-09-16
updated: 2026-09-16
source: "review adversarial de `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-16), decisión D15 de su Paso 0"
---

# El aviso «este teléfono no puede sincronizar» no sale cuando el gateway rechaza un token de App Attest bueno

## El problema, en lenguaje de usuario

Tengo mis datos en la nube. Mi iPhone atesta bien, pero el servidor rechaza su token: un build de Yala que no manda la
cabecera, el reloj del teléfono atrasado o un fallo del servidor. Mis cambios no suben. Ajustes me dice «Todo
sincronizado» y ningún aviso me cuenta lo que pasa. Si intento cerrar sesión, «Hay cambios sin subir… Revisa tu
conexión», y mi conexión está bien.

## Lo medido (leído en el código, sin ejecutar)

- Desde el 2026-09-16 el canal personal lee el 401 `yala_attest_required` como pasajero: reintenta con backoff, deja el
  rastro `CloudSync attestRequired edge=…` y cuenta el canario `cloudSyncAttestRequired`, una vez por proceso y ruta.
  Antes paraba el motor y Ajustes pedía «Inicia sesión para subir N cambios», que tampoco lo arreglaba.
- **No suma a la racha del teléfono** (`GroupsAttestStreakStore`), así que el aviso fijo del canal personal
  (`CloudAttestNoticeLogic`, Panel y Ajustes) no sale nunca para esta población, y el cierre en la nube no ofrece la
  salida con pérdida.
- Por qué no suma: `CloudSyncRuntime.performCycle` consigue el token en su puerta (`resolveAttest`) antes de subir. Una
  petición del motor llega al gateway con un token que el teléfono acuñó bien, así que su 401 no habla del teléfono. En
  Grupos no hay puerta, y el mismo 401 incluye al teléfono que no pudo acuñar. La migración, la vuelta a iCloud y el adopt
  usan los mismos clientes sin la puerta; ahí tampoco suma, como antes de este cambio.
- Contarlo como del teléfono se probó en la sesión del 2026-09-16 y lo tumbó la review con tres casos:
  1. Con el reloj atrasado 24 h y el proceso vivo, la puerta dejaba de borrar la racha que Grupos suma tras su refresh
     forzado, y el cierre en la nube ofrecía «Cerrar sesión y perderlos» a un teléfono que atesta.
  2. Una regresión de build que no manda la cabecera en `/sync/*` acababa, a las 24 h, diciendo a todo el parque
     «Este teléfono no puede sincronizar tus datos… usa otro teléfono» y ofreciendo perder cambios que el hotfix subiría.
  3. Una subida que falla de forma persistente por otra cosa dejaba el aviso puesto para siempre.
- Cuánta gente cae aquí no está medido. El canario nuevo es la medición, **con una salvedad**: también cuenta el 401 que
  reciben la migración y el adopt, que sí puede ser un teléfono sin App Attest. Para separar las dos poblaciones haría
  falta que el canario dijera desde dónde sale.

## Lo que hay que decidir (Jürgen)

1. **Dejarlo así**: el aviso fijo es para el teléfono sin App Attest, y esta población la vigila el canario, que apunta a
   una regresión o al servidor. Lo que ve la persona lo arregla `cloud-sync-status-says-all-synced-with-changes-still-pending`.
2. **Un aviso distinto, sin salida con pérdida**: «No podemos sincronizar tus datos ahora mismo» tras N horas de 401 sin un
   200, con copy nuevo en los 16 idiomas y sin culpar al teléfono.
3. **Contarlo en la racha como en Grupos**, aceptando los tres falsos positivos de arriba.

Recomendación: la 1, con el canario vigilado desde el día 1. La 2 es la única que da algo a la persona sin culpar al
teléfono, y merece la pena si el canario enseña que la población existe.

## Relación con otros tickets

- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — de donde sale.
- `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` — el aviso fijo (#177).
- `attest-session-token-rejected-by-the-gateway-stays-cached` — el token que el servidor ya rechaza sigue en la caché.
- `cloud-sync-status-says-all-synced-with-changes-still-pending` — «Todo sincronizado» con cambios sin subir.
