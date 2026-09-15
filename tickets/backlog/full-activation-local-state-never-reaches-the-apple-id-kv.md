---
id: full-activation-local-state-never-reaches-the-apple-id-kv
status: backlog
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

## Criterios de aceptación

- [ ] Decidida la opción.
- [ ] Si 1: tras «Activar Yala completo → privado», lo elegido en el onboarding está en el iCloud-KV del Apple ID
      y el arranque siguiente no lo revierte; y en Restaurar no se sube nada.
