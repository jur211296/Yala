---
id: personal-sign-out-reads-an-unfinished-drain-as-nothing-pending
status: qa
priority: medium
area: "modo-nube, sync"
created: 2026-09-26
updated: 2026-09-26
source: "`groups-drain-failure-reads-as-nothing-pending` (2026-09-26), al buscar todas las instancias del patrón"
---

# Cerrar sesión en la nube puede llevarse un cambio personal que no llegó a capturarse

## El problema, en lenguaje de usuario

Casi nunca pasa. Si justo al cerrar sesión la app no consigue capturar tu último cambio (un fallo al leer o guardar), el
cierre puede creer que no queda nada por subir y borrar el teléfono con
ese cambio dentro.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- El push-all del cierre personal (`CloudMigrationController.pushAllForSignOut`) decide con
  `CloudSignOutFlowLogic.pushAllVerdict(livePendingCount:…)`: outbox vivo a 0 ⇒ `.drained`.
- El drain del ciclo (`CloudSyncRuntime.performCycle`, paso 1) descarta lo que devuelve `CloudSyncEngine.drainOnce`. Con
  una vuelta que aborta hace `rollback()`: el cambio no está en el outbox y el recuento da 0.
- Con la traducción cortada, `drainOnce` devuelve `true` a propósito (ver su docblock), así que ni leyéndolo bastaría
  para este llamador, que borra. **Desde `personal-clock-rollback-wedges-the-drain-forever` (2026-09-26) la deriva del
  reloj ya no corta**: solo un año fuera de 0001–9999, que en un iPhone no se da. Lo que sigue vivo de este ticket es el
  drain que ABORTA (una lectura o un `save` que falla).
- La rama con el candado cerrado sí lo cubre (`hasUncapturedPersonalChanges` en `pushAllVerdictWithoutEngine`); la rama
  con motor no.

Es el gemelo personal de `groups-drain-failure-reads-as-nothing-pending`, que en Grupos se cerró con una captura previa
que devuelve si terminó y una re-captura tras el ciclo que vacía el outbox.

## Por dónde va

Tras un `.drained` del bucle, preguntar `runtime.hasUncapturedPersonalChanges(context:)` (lectura del History sin
escribir, ya existe) antes de dar el outbox por vacío; `true` o `nil` ⇒ bloquear sin descartar, con el motivo que ya
use el push-all para el guardado que se asienta.

## Criterios de aceptación

- [x] Con un drain que aborta, el cierre en la nube no sale `.drained` con el outbox a 0.
- [x] Sin nada pendiente, el cierre no cambia (ni esperas ni red nuevas).

## Arreglado (2026-09-26)

**Cerrar sesión en la nube ya no da por subido un cambio personal que no llegó a capturarse.** Si queda algo fuera de la
cola de subida, Yala lo intenta otra vez y, si sigue ahí, no borra nada y dice «Un momento más» (el texto que ya existía).
**Y de paso, un cambio guardado mientras Yala sincronizaba ya no puede perderse para la nube**: la limpieza del historial
lo borraba antes de que nadie lo subiera, en cualquier momento, no solo al cerrar sesión.

- **El push-all relee el History tras el ciclo** (`CloudSignOutFlowLogic.personalVerdictAfterProbe`, cableado en
  `CloudMigrationController.pushAllForSignOut`), en `.drained` y en el bloqueo por App Attest (el único que deja perder
  cambios; molde `attestBlockAfterRecapture` de Grupos). Con algo sin capturar da otra vuelta hasta el tope y ahí bloquea
  `.transient`. **Otra vuelta y no bloqueo al momento** (review, lente del cierre): lo que escriben los reconciliadores del
  pull o el puente de Grupos después del drain lo cura el ciclo siguiente.
- **La purga del History ya no corta en `now`** (`CloudSyncEngine.purgeHistoryOnce`): corta en el menor de `now`, el ancla
  del drain y lo más viejo que queda sin consumir por token. **Esto no lo pedía el ticket y hacía falta**: medido con el
  primer test, en el ciclo real la purga del final borraba la edición del drain abortado y la sonda decía «nada pendiente».
  Lo mismo le pasaba, sin cerrar sesión, a toda edición guardada tras el último drain de un ciclo.
- **La sonda lee lo mismo que leerá el drain** (`hasUncapturedPersonalChanges`): su respaldo de token roto —con la purga
  vieja el token caducaba en cada ciclo y la sonda daba «no se sabe», así que el cierre se habría bloqueado siempre— y su
  paso 3-bis (token de otro mount).
- Regla nueva en `swiftdata-cloudkit.md` («Y con el motor abierto, el outbox a 0 tampoco prueba nada»).

**Verificado**: tests nuevos en `CloudSyncRuntimeTests` (drain que aborta, traducción cortada, edición real subida en un
ciclo sin red extra, edición tras el drain curada en la vuelta siguiente, attest con edición sin capturar, tabla de la
función pura, purga con reloj por detrás del ancla, sin ancla, lo no consumido, token purgado, token de otro mount), los
tres de purga existentes adaptados al contrato nuevo; mutantes; review adversarial de tres lentes (datos/purga, cierre,
regla + tests), cuyos hallazgos se arreglaron en la rama salvo los dos con ticket.

**Encontrado y no tocado**, con ticket: el drain que aborta SIEMPRE deja el cierre en «un momento más» para siempre
(`personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy`) y el recuento final del paso 4 sigue
contando solo la cola (`cloud-sign-out-final-recount-misses-edits-left-only-in-history`).

## Device-QA (pendiente, no bloquea)

Lo que este ticket bloquea (un guardado que falla al capturar) no se puede provocar en un iPhone: lo cubren los tests con
el seam. Lo que sí se mira en un iPhone es que **nada se rompa** en el cierre normal y en la sincronización.

**Montaje:** un iPhone con Yala en la nube (Perfil → «Dónde viven tus datos» dice que están en la nube) y, si lo tienes, un
segundo dispositivo con la misma cuenta. Con red.

1. En el iPhone, apunta un gasto («Prueba cierre»). Espera unos segundos.
2. Perfil → **Cerrar sesión** → confirma.
3. **Esperado**: la sesión se cierra como siempre, sin «Un momento más». (Si sale «Un momento más», vuelve a tocar: el
   segundo intento tiene que cerrar. Apúntalo igual.)
4. Vuelve a entrar con la misma cuenta. **Esperado**: «Prueba cierre» está.
5. Con el segundo dispositivo: apunta en el iPhone un gasto justo al volver a la app («Prueba al abrir») y otro un minuto
   después. **Esperado**: los dos aparecen en el otro dispositivo. Con el código de antes, el primero podía no llegar nunca.
6. Usa la app en la nube un día normal. **Esperado**: todo lo que apuntas llega al otro dispositivo y la app no va más lenta
   al abrir (el historial interno ahora se limpia menos; en uso normal, una vez al día).
