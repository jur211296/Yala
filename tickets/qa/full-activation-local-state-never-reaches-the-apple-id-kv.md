---
id: full-activation-local-state-never-reaches-the-apple-id-kv
status: qa
updated: 2026-09-30
qa-status: needs-testing
priority: medium
area: "sesiones, sync, settings"
created: 2026-09-14
source: "consecuencia medida del guard del iCloud-KV (`icloud-kv-prefs-cross-sessions-on-a-lent-phone`), review adversarial"
---

# Quien activa Yala completo desde solo-grupos no sube sus preferencias al iCloud de su Apple ID

## El síntoma, en lenguaje de usuario

Empecé en Yala solo con grupos. Activo «Yala completo» en privado y hago el onboarding: elijo nombre, moneda y
periodo. **Mis otros dispositivos del mismo Apple ID no reciben esas preferencias**, y si ese Apple ID ya tenía
una vida privada antes, **al volver a abrir la app me aparecen las de entonces** en vez de las que acabo de
elegir.

## Lo medido (2026-09-14)

- `OwnerKeyValueGate` cierra el iCloud-KV del Apple ID mientras el eje 1 está en `false` (celda F), y sigue
  cerrado durante toda la activación: `FullModeActivationView.completeFullActivation` enciende el eje al FINAL
  del plan (`FullModeActivationFlowLogic.commitPlan` pone `.persistOnboarding` antes de `.completeActivation`),
  y ese orden es de kill-safety — su docblock explica por qué no se invierte.
- `.persistOnboarding` escribe las preferencias del onboarding por `PreferenceSyncService.set`: llegan a local,
  no al iCloud-KV. Nada las sube cuando el eje se enciende.
- El siguiente `applyRemoteValues` —arranque, pull-to-refresh del Panel o cambio externo— aplica el remoto
  encima de lo local si existe y difiere (`PreferenceMergeLogic.decide`: el remoto gana).
- **El mismo mecanismo, en otra clave** (lente de regresión del dueño):
  `ScheduledPaymentNotificationService.flipMasterToggleIfNeeded` marca su centinela en local y el espejo del
  iCloud-KV no llega. Desde ahí el one-shot sale antes de mirar el iCloud-KV en cada arranque; si el dueño
  apaga el interruptor a propósito y reinstala, el volteo vuelve a correr y se lo enciende.
- La rama **Restaurar** de la activación aplica las preferencias del Apple ID tarde: en el siguiente
  `applyRemoteValues`, no al terminar.

## Por qué no se abrió la puerta durante la activación

Abrirla tras el relanzamiento fue la primera versión del arreglo, y la review la tumbó: «volver» desde
Restaurar deja la activación pendiente sin límite (`CancelEffect.keepPending`) en una sesión que sigue siendo
solo-grupos, y el arranque del relanzamiento aplicaba las preferencias del dueño a quien luego cancelaba. La
puerta no tiene cómo distinguir una activación en curso de una abandonada.

## Decisión que falta (de Jürgen)

1. **Subir al nacer la sesión privada.** En `completeFullActivation`, después de encender el eje, escribir al
   iCloud-KV las preferencias locales y el espejo del interruptor maestro, **solo en la rama privada nueva**:
   en Restaurar, las del Apple ID son las que valen.
2. **Aceptarlo.** Población F medida en cero; el coste es que las preferencias de quien viene de grupos no
   viajan hasta que las vuelva a tocar.

Recomendación de Frank: **1**, acotada a la rama privada nueva y con un test del orden.

## Decisión (Jürgen, 2026-09-30)

Opción 1, acotada a la rama privada nueva. Restaurar no sube. La puerta no se abre durante la activación.

## Criterios de aceptación

- [x] Decidida la opción.
- [x] Tras «Activar Yala completo → privado», lo elegido está en el iCloud-KV del Apple ID y el arranque siguiente
      no lo revierte; en Restaurar no se sube nada. Fijado en unit (`PrivateBirthKeyValueHandoverTests`).
- [ ] Device-QA: el viaje real por iCloud a un segundo dispositivo (guion abajo).

## Lo hecho (2026-09-30)

- `PrivateBirthKeyValueHandover`: marca durable armada en `completeFullActivation` ANTES del eje, solo con
  `.freshPrivate`; se paga justo después del eje y, si el proceso muere antes, en el arranque, antes de
  `PreferenceSyncService.bootstrap`. Con la puerta cerrada (kill antes del eje) el arranque la descarta.
- Sube el estado local ENTERO de las `PrefSyncKey` (lo presente se escribe, lo ausente se retira del KV, salvo el
  consentimiento de la nube) y el espejo del interruptor maestro si está en `true`.
- Medido primero: el caso de control de la suite reproduce el hueco sin la subida (lo elegido no llega y el merge
  lo revierte).
- Review adversarial de tres lentes: la de «de quién es el KV» cazó que saltar las claves ausentes dejaba entrar
  el remoto viejo; la de tests, seis mutantes que sobrevivían (cerrados con casos nuevos).
- Residuales con ticket: `full-activation-onboarding-signal-never-reaches-the-apple-id-kv` y
  `cloud-activation-master-toggle-mirror-never-reaches-the-apple-id-kv`. Aceptado sin ticket: el KV puede
  descartar lo local si iCloud aún no hizo su descarga inicial (`NSUbiquitousKeyValueStoreInitialSyncChange`);
  afecta igual a cualquier escritura de la app y no se puede medir sin dispositivo.

## Guion de device-QA (Jürgen, un iPhone)

**Montaje:** un iPhone con un **Apple ID de pruebas, sin datos reales**: el paso 4 BORRA lo que haya en su iCloud.
Build de TestFlight que lleve este cambio. Una cuenta de Grupos (invitación o crear un grupo) para entrar por Grupos.

1. Instala Yala. En el Welcome: «Es mi primera vez en Yala» → «Tu cuenta en tu iCloud privado». En el onboarding
   pon el nombre «Ana» y la moneda EUR. Así quedan «Ana» y EUR en el iCloud de ese Apple ID.
2. Borra Yala del iPhone y vuelve a instalarla (el iCloud del Apple ID se queda con «Ana» y EUR).
3. En el Welcome: «Vengo por un grupo», y entra en un grupo hasta ver la pestaña de Grupos.
4. Grupos → «Activar Yala completo» → «Tu cuenta en tu iCloud privado». Saldrá «Ya tienes datos en tu iCloud»:
   toca «Empezar de cero» y confirma. En el onboarding pon «Luis» y la moneda PEN.
5. Cierra Yala del todo (desliza hacia arriba desde el selector de apps) y vuelve a abrirla.
   **Esperado:** Perfil dice «Luis» y la moneda es PEN. Antes del arreglo volvían «Ana» y EUR.
6. Tira hacia abajo en el Panel para forzar la sincronización de preferencias.
   **Esperado:** siguen «Luis» y PEN.

Si en el paso 4 no sale «Ya tienes datos en tu iCloud», el paso 1 no llegó a subir a iCloud: espera un minuto con
la app abierta tras el onboarding del paso 1 y repite desde el paso 2.
