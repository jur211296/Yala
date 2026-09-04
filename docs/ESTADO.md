---
updated: 2026-09-04
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-04 (Lima)

**Rama** `2.1` · HEAD `d39d5740` — «el Panel de un usuario nuevo arranca con cuatro secciones y
cuatro widgets». TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**
**`yala-app.pe` sirve la web nueva desde hoy** (PR #62 mergeado; detalle en
`Web/REVISION-WEB-UX-A11Y-2026-09-03.md`).

## El día, en dos líneas

El CI llevaba día y medio sin ejecutar un test; se arregló y salieron 16 XCUITest en rojo —ninguno
bug de la app— más el de identidad del recién llegado a un grupo. Luego la web, desplegada; y el
Panel, que para quien instale ahora arranca con cuatro secciones y cuatro widgets.

## Te espera a ti

1. **Publicar la app.** Los dos avisos de Grupos están completos en servidor y en los dos entornos;
   falta el cliente iOS. Ahora llevaría además el fix de identidad y los predeterminados del Panel.
2. **La tanda de QA: 22 tickets en 4 montajes.** Guion en **`qa/guion-tanda.md`**, sin tocar. El
   nº 22 es `guest-decline-has-no-screen`, que entró hoy: servidor listo y verificado en producción,
   falta verlo en la app publicada.
3. **Dos decisiones de la web** (§9 del informe): el **texto legal de Grupos** —dice «vía iCloud, no
   por servidores nuestros» y el backend propio está al 100 % en prod— y si Vercel debe desplegar al
   mergear (hoy su rama de producción es `1.0`).

## Abiertos, por prioridad

Revisados los 7 `in-progress` uno a uno el 2026-09-04, verificando contra el árbol lo que cada
ticket afirma. Hallazgo: **ninguno esperaba una decisión tuya** — la tanda del 3-sep las cerró
todas. Dos salieron de `in-progress` en ese saneamiento; **quedan 5, y los 5 esperan código**.

- **`group-joiner-flag-consumers-still-narrow`** (high, en `backlog`) — al recién llegado ya se le
  reconoce, pero su gasto no llega a su cuenta personal hasta un arranque posterior y aterriza en la
  cuenta «Grupos». Trece consumidores del flag siguen estrechos.
- **`guest-journey-dead-screens`** — decidido el 12-ago, medido, y su freno era «no abrir un borrado
  de 10 ficheros de noche»: esa sesión cerró hace 23 días. **Dos de sus seis piezas ya están hechas
  y el ticket no lo registra** (el docblock se corrigió en `cd87cf3a`; el `if` vacío ya no existe).
- **`invite-link-five-causes-one-message`** — piezas 2, 3 y 4 son código. Sin tocar.
- **`secondary-visitor-writes-owner-domain`** y **`secondary-guest-exit-lock-and-outbox`** — las
  decisiones del 3-sep están tomadas y **el código aprobado no está escrito**. Alcance real hoy: cero
  (SECONDARY_SESSION al 0 % en prod), pero bloquean el encendido.
- **`reentry-counts-as-fresh-install`** — parado por falta de tiempo, no por bloqueo. Su área lleva
  22 días sin un commit.
- Los **2 de `blocked`** esperan **hardware**, no trabajo.

**Al retomar cualquiera: las coordenadas de los tickets están sistemáticamente caducadas** (en uno,
14 de ~20, y dos aterrizan hoy en código no relacionado). Greppea, no abras la línea citada.

## Release 2.1 (sin cambios)

2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Board

98 tickets · backlog 50 · in-progress 5 · qa 22 · blocked 2 · done 14 · discarded 5. Índice cuadrado
(98 filas = 98 ficheros, status y ruta de cada fila comprobados contra el disco). `qa` significa
«esperando la tanda», no «cerrado».

**Saneado el 2026-09-04.** `ci-verde-con-la-suite-en-rojo` → `done`: su alcance —el que tú fijaste,
hasta el paso 2— está completo y verificado; lo que quedaba fuera vive ahora en
`ci-warns-but-does-not-block` (backlog), incluido el dato que manda el orden: **no existe ningún pase
nocturno**, así que sacar la suite de UI del push la dejaría sin corrida automática.
`guest-decline-has-no-screen` → `qa`: su bloqueo declarado («falta aplicar a producción, no la veo
desde aquí») estaba **caducado y al revés** — medido hoy contra el servidor, `g13_02` está aplicada
en producción con las dos condiciones de la policy, y lo invisible es staging. Solo falta publicar el
cliente y mirarlo en la tanda. Y **el «sin rutas rotas» de ayer era falso**: el mapa de origen tenía
6 punteros a ubicaciones antiguas; corregidos.

**Del Panel, lo que vuelve a morder:** «aún no hay preferencias» se renderizaba como «enséñalo todo»,
así que los predeterminados se resuelven ahora también en LECTURA, no solo al sembrar. Y el área
`panel-dashboard-logic` cubría 20 ficheros de vistas pero ninguno de los que definen los
predeterminados: tocarlos no disparaba ni un XCUITest. Corregido.
