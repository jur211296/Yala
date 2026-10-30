---
id: group-push-has-no-collapse-id-and-multi-device-duplicates
status: backlog
priority: low
area: notifications
created: 2026-10-30
updated: 2026-10-30
source: inventario del ticket notices-come-out-one-after-another-by-priority (sesión S27f, leído en el código, sin medir en simulador)
---
# El push de Grupos no colapsa y cada aviso local sale en cada dispositivo de la persona

Qué ve la persona: varias tandas de cambios de un grupo dejan varios «Novedades en tus grupos» apilados; y con dos iPhones/iPad, cada recordatorio de pago, presupuesto o informe sale en los dos.

Leído: `gateway/src/push/apns.ts` no manda `apns-collapse-id` ni `thread-id`; `fanOutGroupPush` manda un push por tanda. Los trackers de pagos, tarjeta, presupuesto, presupuesto de grupo, liquidación y el límite de 5 min de Grupos viven en `UserDefaults.standard` local. Ninguna notificación local fija `threadIdentifier`.

Ya hecho en el ticket padre: el aviso rico de un grupo retira el genérico entregado del mismo grupo.

Hecho cuando: el push lleva `apns-collapse-id` por grupo y `thread-id`, y se decide (Jürgen) si los avisos personales deben salir en un solo dispositivo. Toca la card 2.4 «Rediseñar las notificaciones desde cero».
