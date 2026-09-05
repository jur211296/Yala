---
updated: 2026-09-05
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-05 (Lima)

**Rama** `2.1` · HEAD al día — el enlace de invitación ya no pierde el nombre del grupo, y la visita
en el móvil de otra persona ya no deja huella en el Yala del dueño.
TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.** `yala-app.pe` sirve la web
nueva desde el 4-sep.

## Esta sesión, en una línea

**`secondary-visitor-writes-owner-domain` pasa a `qa`** (PR #66): quien entra de visita en el móvil de
otra persona termina su onboarding sin marcar el del dueño —antes la marca se escribía en el cajón de
él y se leía del de ella, y la pantalla de bienvenida podía reabrírsele— y el permiso de Grupos del
dueño ya no se borra al entrar una visita: se guarda a un lado y se le devuelve al salir, con lo que
además conservamos el registro de su consentimiento.

Dos cosas que el ticket daba por sabidas y no lo eran: los lectores de esa marca no eran los tres que
nombraba sino **siete**, en seis ficheros; y **el escáner de conteo no habría visto el bug** —26 sitios
antes, 26 después—, así que la red nueva censa el DOMINIO, no el número. Salen dos residuales a
`backlog` con su medición, uno de ellos hallazgo nuevo:
`secondary-entry-healing-writes-owner-not-session`, donde el kill-recovery de la entrada repara los
flags en el dominio del dueño mientras la siembra ya copió el valor viejo al cajón.

Nada de esto está visto en un teléfono todavía. Alcance real en producción: cero.

## La sesión anterior, en una línea

El enlace de invitación queda cerrado del todo (PR #65): quien lo toca ve el nombre del grupo que la
web acababa de enseñarle —también con la app cerrada—, un enlace sin el parámetro cosmético deja de
morir en silencio, y el botón de compartir ya no culpa a tu conexión cuando el fallo es permanente.

## Te espera a ti

1. **Publicar la app.** Los dos avisos de Grupos están completos en servidor y en los dos entornos;
   falta el cliente iOS. Ahora llevaría además el fix de identidad del recién llegado y los
   predeterminados del Panel.
2. **La tanda de QA: 27 tickets en 4 montajes.** Guion en **`qa/guion-tanda.md`**, sin tocar. El
   montaje de dos teléfonos cubre ahora TRES de golpe —`group-joiner-flag-consumers-still-narrow`,
   `groups-equal-split-shows-not-participating-on-peer` y `rejoin-tap-renotifies-admins`— con una
   precondición frágil: **B se une por enlace y NO relanza la app** antes de que A cree el gasto. Si
   B relanza, ninguno reproduce. Entra hoy `invite-link-five-causes-one-message`, y su parte visual
   cabe en el mismo montaje: tapear el enlace **con la app cerrada** y ver el nombre del grupo en la
   bienvenida.
3. **Dos decisiones de la web** (§9 del informe): el **texto legal de Grupos** —dice «vía iCloud, no
   por servidores nuestros» y el backend propio está al 100 % en prod— y si Vercel debe desplegar al
   mergear (hoy su rama de producción es `1.0`).

## Abiertos

Los 2 de `in-progress` esperan **código**, ninguno una decisión tuya:

- **`secondary-guest-exit-lock-and-outbox`** — decidido el 3-sep, **el código aprobado no está
  escrito**. Alcance real cero hoy (SECONDARY_SESSION al 0 %), pero bloquea el encendido. Su hermano
  `secondary-visitor-writes-owner-domain` salió a `qa` esta madrugada y ya no está aquí.
- **`reentry-counts-as-fresh-install`** — parado por falta de tiempo, no por bloqueo.
- Los **2 de `blocked`** esperan **hardware**.

**Al retomar cualquiera: las coordenadas de los tickets están sistemáticamente caducadas.** Greppea,
no abras la línea citada.

## Release 2.1 (sin cambios)

2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Board

108 tickets · backlog 55 · in-progress 2 · qa 28 · blocked 2 · done 16 · discarded 5. Índice cuadrado
(108 filas = 108 ficheros, verificado contra el disco). `qa` significa «esperando la tanda», no
«cerrado».

**El verde del CI no dice que los XCUITest pasaran:** su paso de UI es *advisory*, así que el job sale
`success` con 12 fallos dentro. Son 4 tests, **los mismos que ya fallan en `2.1`** sin cambio alguno —
comparados run a run. Uno tiene causa escrita hoy en `uitest-compara-fechas-sin-fijar-locale`: compara
una fecha contra un literal en inglés y acusa de un bug que no existe.
