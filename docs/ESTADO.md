---
updated: 2026-09-05
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-05 (Lima)

**Rama** `2.1` · HEAD `03f807ef` — el gasto del recién llegado a un grupo ya llega a su cuenta.
TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.** `yala-app.pe` sirve la web
nueva desde el 4-sep.

## Esta sesión, en una línea

Quien se une a un grupo por enlace ya ve su gasto en su cuenta real sin relanzar la app, y sus avisos
del grupo dejan de descartarse en silencio (PR #64).

## Te espera a ti

1. **Publicar la app.** Los dos avisos de Grupos están completos en servidor y en los dos entornos;
   falta el cliente iOS. Ahora llevaría además el fix de identidad del recién llegado y los
   predeterminados del Panel.
2. **La tanda de QA: 26 tickets en 4 montajes.** Guion en **`qa/guion-tanda.md`**, sin tocar. El
   montaje de dos teléfonos cubre ahora TRES de golpe —`group-joiner-flag-consumers-still-narrow`,
   `groups-equal-split-shows-not-participating-on-peer` y `rejoin-tap-renotifies-admins`— con una
   precondición frágil: **B se une por enlace y NO relanza la app** antes de que A cree el gasto. Si
   B relanza, ninguno reproduce.
3. **Dos decisiones de la web** (§9 del informe): el **texto legal de Grupos** —dice «vía iCloud, no
   por servidores nuestros» y el backend propio está al 100 % en prod— y si Vercel debe desplegar al
   mergear (hoy su rama de producción es `1.0`).

## Abiertos

Los 4 de `in-progress` esperan **código**, ninguno una decisión tuya:

- **`invite-link-five-causes-one-message`** — piezas 2, 3 y 4 son código. Sin tocar.
- **`secondary-visitor-writes-owner-domain`** y **`secondary-guest-exit-lock-and-outbox`** — decidido
  el 3-sep, **el código aprobado no está escrito**. Alcance real cero hoy (SECONDARY_SESSION al 0 %),
  pero bloquean el encendido.
- **`reentry-counts-as-fresh-install`** — parado por falta de tiempo, no por bloqueo.
- Los **2 de `blocked`** esperan **hardware**.

**Al retomar cualquiera: las coordenadas de los tickets están sistemáticamente caducadas.** Greppea,
no abras la línea citada.

## Release 2.1 (sin cambios)

2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Board

104 tickets · backlog 51 · in-progress 4 · qa 26 · blocked 2 · done 16 · discarded 5. Índice cuadrado
(104 filas = 104 ficheros). `qa` significa «esperando la tanda», no «cerrado».

**El verde del CI no dice que los XCUITest pasaran:** su paso de UI es *advisory*, así que el job sale
`success` con 12 fallos dentro. Son 4 tests, **los mismos que ya fallan en `2.1`** sin cambio alguno —
comparados run a run. Uno tiene causa escrita hoy en `uitest-compara-fechas-sin-fijar-locale`: compara
una fecha contra un literal en inglés y acusa de un bug que no existe.
