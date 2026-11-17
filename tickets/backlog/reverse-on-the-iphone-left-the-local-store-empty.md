---
id: reverse-on-the-iphone-left-the-local-store-empty
status: backlog
priority: high
area: "modo-nube, migración"
created: 2026-11-16
updated: 2026-11-16
source: "prueba de punta a punta del encargo «Nube 2.3: los cinco bugs media» (iPhone 14, Yala Dev, staging)"
---

# Tras «Volver a tu iCloud», el iPhone se quedó sin ningún dato y salió «Datos no disponibles»

## Lo que pasó (medido el 2026-11-16, iPhone 14, iOS 27.2, Yala Dev contra staging)

1. Instalación nueva de Yala Dev (el App Group se conserva entre instalaciones). «Entrar con iCloud privado» → «Traer
   mis datos»: 6 registros, 5 cuentas, 67 categorías de este Apple ID.
2. «Pasar a tu cuenta de Yala» con Google (`test@yala-app.pe`, cuenta nueva): subió 533 filas; en el servidor, 9
   movimientos y 6 cuentas vivos.
3. «Volver a tu iCloud» → reabrir. La vuelta llegó a `icloudActive` sin esperar nada (`rUpload>icloudActive` 0 s, ninguna
   línea `uploadPending` ni `uploadFailedRows`).
4. Justo después: el Panel aún pintaba los datos de antes, pero Registros decía «Crea tu primera cuenta» y al tocarlo
   salió «Datos no disponibles · Se vació Yala en otro de tus dispositivos». El store personal del App Group
   (`YalaModel-Dev.store`) tenía **0 movimientos, 0 cuentas y 0 categorías**, y siguió así minutos después.
5. La copia del servidor seguía con sus 9 movimientos (congelada, `groups_only`).

Rastro del arranque tras reabrir: `rMount>rReconcile.awaitingQuiescence`, `deletingZombies` (3 s; el servidor no tenía
ningún borrado), `rebindingUUIDs`, `dedupHealed`, `rUpload>icloudActive`, y después `remoteWipeAlert`.

## Hipótesis (sin medir)

- Una señal de «Vaciar datos» vieja en el iCloud de este Apple ID (el iPhone 14 probó «Vaciar mis datos» el mismo día,
  card lplc) que el receptor tardío aplica al montar el espejo en la vuelta: se lleva lo creado antes de la señal. Si es
  esto, el iCloud tampoco tendría esas filas.
- O la vuelta no subió nada a iCloud (muestra a 0 en la primera observación) y el remonte dejó el store sin lo que la nube
  tenía.

## Qué falta

- Repetirlo en un Apple ID sin señal de «Vaciar datos» en su iCloud, contando el store antes y después del remonte.
- Mirar si el iCloud del teléfono conserva esas filas (otro dispositivo del mismo Apple ID, o la consola de CloudKit).

## Causa medida (2026-11-17, iPhone 14, Yala Dev contra staging, encargo «Arreglar que Volver a tu iCloud deje el iPhone sin datos»)

Ninguna de las dos hipótesis. Se reprodujo la vuelta en el mismo teléfono (que estaba otra vez en la nube) con la consola
y copiando el store por `devicectl` en cada paso:

| Momento | Movimientos · cuentas · categorías | Historial del store | Espejo de iCloud |
|---|---|---|---|
| En la nube, antes de volver | 2.361 · 2 · 13 | solo la transacción 834 | posición guardada: transacción 825 |
| Tras reabrir (02:27) | **0 · 0 · 0** | 7.617 borrados con autor `NSCloudKitMirroringDelegate.reset` | exportación fallida, `NSCocoaErrorDomain 134301` |
| Relanzar (02:29) | 2.370 · 9 · 13 | — | importó de iCloud |

- **La purga del historial del motor en modo nube (`purgeHistoryOnce`, encendida desde julio) se llevó lo que el espejo,
  apagado, nunca leyó** (826–833). Al remontarlo, su exportación caduca (134301) y el espejo hace un «reset» que borra
  todo el store. Ayer, a las 18:33:20, la misma exportación con el mismo 134301: es la causa del ticket.
- **iCloud conserva sus filas**: el reset no exporta borrados, y el arranque siguiente las baja otra vez. Se pierde lo que
  solo estaba en el teléfono (lo hecho en la nube), que el backend congelado sigue teniendo.
- **La señal de «Vaciar datos» no interviene**: el KV del teléfono la tenía procesada (15-nov, 01:33) y la vuelta no pasó
  por `handleRemoteWipeSignal`. «Datos no disponibles» es la gracia del arranque en frío al ver el store vacío.
- La vuelta se cerró «drenada» con el store vacío (`rUpload>icloudActive`), como ayer.

## Arreglo

- `CloudSyncFlags.historyPurgeEnabled = false`: en modo nube el historial ya no se purga (el spike S2 que la encendió
  midió purgar con el espejo ENCENDIDO). Es como se midió en verde la vuelta en julio.
- `MirrorHistoryProbe` lee la posición del espejo del SQLite (acierta sobre los stores reales del teléfono: «caducado»
  antes del remonte malo, «intacto» después) y `ReverseEligibility.mirrorHistoryExpired` no ofrece la vuelta a quien ya
  purgó, con su texto en 16 idiomas. `startReverse` lo repite. Canario `cloudReverseMirrorHistoryExpired`.
- La recuperación de esos teléfonos queda en `reverse-blocked-after-history-purge-needs-a-recovery-path`.
