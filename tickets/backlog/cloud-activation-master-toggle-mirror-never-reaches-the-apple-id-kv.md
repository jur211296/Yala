---
id: cloud-activation-master-toggle-mirror-never-reaches-the-apple-id-kv
status: backlog
priority: low
area: "sesiones, notificaciones"
created: 2026-09-30
source: "residual de `full-activation-local-state-never-reaches-the-apple-id-kv`"
updated: 2026-10-08
---

# Tras «Activar Yala completo → nube», el espejo del interruptor maestro de pagos no llega al iCloud del Apple ID

## El síntoma, en lenguaje de usuario

Activo Yala completo en la nube desde solo-grupos y apago a propósito los avisos de pagos programados. Si
reinstalo la app, me los vuelve a encender.

## Lo medido (2026-09-30)

- En solo-grupos `ScheduledPaymentNotificationService.flipMasterToggleIfNeeded` marca su centinela en local y
  la puerta del iCloud-KV se traga el espejo. Desde ahí el one-shot sale en su primera línea (centinela local en
  `true`) y nunca vuelve a intentar el espejo.
- `PrivateBirthKeyValueHandover` sube ese espejo solo en la rama privada NUEVA (decisión de Jürgen del
  2026-09-30). En `.freshCloud` no se arma: sus preferencias van al outbox del backend, pero este espejo va al
  iCloud-KV en todos los modos.
- Población: quien active la nube desde solo-grupos (medida en cero el 2026-09-14) y además apague el interruptor
  y reinstale.

## Qué hay que decidir

Si `.freshCloud` arma también la subida del espejo (solo el espejo, no las preferencias), o se acepta.

## Medido en 2.1 (triage 2026-10-08)

- `FullModeActivationFlowLogic.handsLocalStateToAppleID` sigue devolviendo `false` para `.freshCloud`, así que `PrivateBirthKeyValueHandover.arm()` no se arma en la rama de la nube; `ScheduledPaymentNotificationService` no tiene commits desde el 2026-09-30.

Triage 2026-10-08: abierto · low → low · `.freshCloud` sigue sin subir el espejo del interruptor; población medida en cero el 2026-09-14 y solo cuesta un ajuste tras reinstalar.
