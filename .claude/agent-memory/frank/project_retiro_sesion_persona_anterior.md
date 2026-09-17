---
name: retiro-sesion-persona-anterior
description: PR #192 (2026-09-17) — un iPhone que cambia de dueño ya no deja abierta la cuenta en la nube de la persona anterior; en qa con 9 pasos en iPhone, y el paso 4 es el que decide si se puede publicar
metadata:
  type: project
---

`previous-person-cloud-session-survives-fresh-start-and-reinstall`, en `qa`. Cierra la RAÍZ de la familia
que #190 había empezado a tapar puerta a puerta: el JWT se retira, así que no hay sesión que reusar.

**Why:** decisión de Jürgen del 2026-09-17, «las dos mitades» — cerrar en el relevo y purgar en el primer
arranque tras instalar, aceptando que quien reinstala su propia app vuelva a entrar.

**How to apply:**

- **Lo que espera es el device-QA (9 pasos).** El **paso 4** es el que decide si esto se publica:
  actualizar el build ENCIMA de una instalación viva **no** debe cerrar la sesión. Si ahí pide volver a
  entrar, es la regresión de parque y no se mergea — ver [[una-key-nueva-esta-ausente-en-todo-el-parque]].
- **Dos consumidores, no uno, y confundirlos es el error que ya se pagó:** `purgeIfArmed()` PRE-MOUNT
  (síncrono, sin red, con el SDK aún sin construir) es el principal; `retireForHandover()` en proceso es
  solo para el relevo, que no relanza. Si alguien propone «unificarlos en el bootstrap», eso reintroduce
  los 60 s de red delante de la primera pantalla — [[un-await-de-red-en-el-arranque-bloquea-la-pantalla]].
- **El sello del handover y el retiro de la sesión son decisiones distintas.** Si alguien propone sellar
  también donde no hay filas locales «porque el enum lo promete», eso se lo come quien reinstala su propia
  app: lo midieron dos lentes por separado y el docblock del scope ya está corregido.
- **El cursor de Grupos se conserva**, y esa es la medición que Jürgen pidió: cerrar la sesión no invierte
  su signo. Está pinneado en los dos sentidos en `HandoverGroupsDomainTests`.
- Residuales con ticket propio: `reinstall-without-network-has-no-cloud-door` (medium — tras reinstalar y
  sin red no hay puerta a la nube y el mensaje que sale es falso; es OTRO mecanismo que
  `reentry-killswitch-closes-both-doors`, la ventana antes del primer fetch) y
  `handover-leaves-the-storage-mode-without-a-session` (low, sin entrada alcanzable encontrada).
- Le abrió el camino al hermano `secondary-session-retirement-leaves-the-guest-cloud-session`: su opción B
  es hoy una línea, y está anotado allí.

Relacionado: [[sesion-anterior-tras-empezar-de-cero]] (#190, la puerta que este cierra por la raíz),
[[review-adversarial-caza-lo-mio]].
